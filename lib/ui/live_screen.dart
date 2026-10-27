import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../analysis/analyzer.dart';
import '../data/store.dart';
import '../pose/live_source.dart';
import '../pose/pose_camera.dart';
import 'overlay.dart';
import 'report_screen.dart';
import 'sfx.dart';
import 'theme.dart';

/// Live analysis with the phone camera: a 3-2-1 countdown, then the overlay,
/// the numbers and the status line, until the player finishes.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.exercise, required this.settings, required this.front});
  final Exercise exercise;
  final Settings settings;
  final bool front;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final Analyzer _a = Analyzer.of(widget.exercise, widget.settings)
    ..sound = widget.settings.sound
    ..onBeep = Sfx.beep;
  late final LiveSource _camera = liveSource(front: widget.front, mirror: widget.settings.mirror);
  final _clock = Stopwatch();
  StreamSubscription<PoseSample>? _sub;
  Timer? _ticker;
  int _tick = 0;
  int _countdown = 3;
  bool _paused = false;
  bool _finishing = false;
  String? _error;
  int _lastGood = 0;

  double get _now => _clock.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _start();
  }

  Future<void> _start() async {
    try {
      await _camera.start(record: widget.settings.record);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح الكاميرا. اسمح للتطبيق باستخدامها من الإعدادات.');
      return;
    }
    _sub = _camera.samples.listen(_onSample);
    // The screen keeps time even when no frame arrives (the clock, "lost").
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_clock.isRunning) {
        _a.checkLost(_now);
        if (mounted) setState(() => _tick++);
      }
    });
    for (var i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      if (widget.settings.sound) Sfx.play('tick');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _countdown = 0);
    _clock.start();
  }

  void _onSample(PoseSample s) {
    if (_countdown > 0 || _paused || _finishing) return;
    final pts = s.points;
    if (pts == null) {
      _a.checkLost(_now);
    } else {
      _a.update(pts, 1000 * s.aspect, 1000, _now);
    }
    final a = _a;
    if (a is RepAnalyzer && a.good > _lastGood) {
      _lastGood = a.good;
      if (widget.settings.sound) Sfx.play('good');
    }
    if (mounted) setState(() => _tick++);
  }

  Future<void> _togglePause() async {
    if (_countdown > 0) return;
    if (_paused) {
      await _camera.resume();
      _clock.start();
    } else {
      _clock.stop();
      await _camera.pause();
    }
    setState(() => _paused = !_paused);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    _clock.stop();
    final duration = _now;
    _a.finish(duration);
    final report = _a.report(duration);
    final video = await _camera.stop(save: true);
    final session = Session(
      at: DateTime.now(),
      exercise: widget.exercise,
      source: 'camera',
      report: report,
      video: video,
    );
    await Store.add(session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReportScreen(
        session: session,
        onRetry: (ctx) => Navigator.of(ctx).pushReplacement(MaterialPageRoute(
          builder: (_) => LiveScreen(exercise: widget.exercise, settings: widget.settings, front: widget.front),
        )),
      ),
    ));
  }

  Future<bool> _confirmLeave() async {
    if (_countdown > 0 && _clock.elapsed == Duration.zero) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء الجلسة؟'),
        content: const Text('اختر «إنهاء وعرض التقرير» لحفظ النتيجة، أو «خروج» للخروج بدون حفظ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('متابعة')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ticker?.cancel();
    _sub?.cancel();
    if (!_finishing) _camera.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final (status, tone) = _a.status(now);
    final a = _a;
    String? sub;
    if (a is RepAnalyzer && a.repTimes.isNotEmpty) sub = 'آخر تكرار: ${a.repTimes.last.toStringAsFixed(1)} ثانية';
    final mins = now ~/ 60, secs = now.toInt() % 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _error != null
            ? _errorView()
            : Stack(fit: StackFit.expand, children: [
                _camera.preview(overlay: CustomPaint(painter: AnalysisPainter(_a, _tick))),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: [
                      // On a wide computer screen the panels keep a phone's width.
                      Align(
                        alignment: AlignmentDirectional.topStart,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: StatsPanel(_a, now)),
                            if (a is RepAnalyzer) ...[const SizedBox(width: 8), RepCounter(a.reps)],
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Glass(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        if (_camera.recording) ...[
                          const SizedBox(width: 8),
                          Glass(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 14, color: (_tick ~/ 2).isEven && !_paused ? Fa.red : Fa.ink3),
                              const SizedBox(width: 4),
                              const Text('REC', style: TextStyle(fontWeight: FontWeight.w800, color: Fa.red)),
                            ]),
                          ),
                        ],
                      ]),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(children: [
                          StatusBar(status, tone, sub: sub),
                          const SizedBox(height: 10),
                          _controls(),
                        ]),
                      ),
                    ]),
                  ),
                ),
                if (_countdown > 0) _countdownView(),
                if (_paused) _pausedView(),
              ]),
      ),
    );
  }

  Widget _controls() {
    final stance = _a is StanceAnalyzer;
    Widget btn(IconData icon, String label, VoidCallback? onTap, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: color ?? Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(height: 2),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Row(children: [
      btn(_paused ? Icons.play_arrow : Icons.pause, _paused ? 'متابعة' : 'إيقاف', _togglePause),
      btn(Icons.restart_alt, 'تصفير', () => setState(() => _a.reset(_now))),
      if (stance)
        btn(Icons.straighten, 'معايرة', () {
          final msg = (_a).calibrate(_now);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          setState(() {});
        }),
      btn(_a.sound ? Icons.volume_up : Icons.volume_off, _a.sound ? 'الصوت' : 'مكتوم',
          () => setState(() => _a.sound = !_a.sound)),
      btn(Icons.flag, 'إنهاء', _finishing ? null : _finish, color: Fa.red.withOpacity(0.85)),
    ]);
  }

  Widget _countdownView() => Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_countdown', style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w800, color: Colors.white)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_tip(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Fa.ink2)),
          ),
        ]),
      );

  String _tip() => switch (widget.exercise) {
        Exercise.stance => 'قف بحيث يظهر جسمك من الكتفين حتى القدمين',
        Exercise.squat => 'صوّر من الجانب بحيث يظهر الورك والركبة والكاحل',
        Exercise.pushup => 'صوّر من الجانب بحيث يظهر جسمك كاملاً',
      };

  Widget _pausedView() => Container(
        color: Colors.black.withOpacity(0.6),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('متوقف مؤقتاً', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
              onPressed: _togglePause,
              icon: const Icon(Icons.play_arrow),
              label: const Text('متابعة'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(140, 52), backgroundColor: Fa.red, foregroundColor: Colors.white),
              onPressed: _finish,
              icon: const Icon(Icons.flag),
              label: const Text('إنهاء'),
            ),
          ]),
        ]),
      );

  Widget _errorView() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.no_photography_outlined, size: 64, color: Fa.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('رجوع')),
          ]),
        ),
      );
}
