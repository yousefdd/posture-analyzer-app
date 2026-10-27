import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../analysis/analyzer.dart';
import '../data/store.dart';
import '../pose/video_pose.dart';
import 'overlay.dart';
import 'report_screen.dart';
import 'theme.dart';

/// Analyses a video from the gallery frame by frame, showing each frame with
/// the overlay and the progress, then the report.
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.path, required this.exercise, required this.settings});
  final String path;
  final Exercise exercise;
  final Settings settings;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  // Beeps make no sense while a recorded video is analysed faster or slower than real time.
  late final Analyzer _a = Analyzer.of(widget.exercise, widget.settings)..sound = false;
  StreamSubscription<VideoSample>? _sub;
  Uint8List? _image;
  double _aspect = 9 / 16;
  double _t = 0, _duration = 0;
  int _tick = 0;
  bool _cancel = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sub = analyseVideo(widget.path, cancel: () => _cancel).listen(
      (s) {
        final pts = s.sample.points;
        if (pts == null) {
          _a.checkLost(s.seconds);
        } else {
          _a.update(pts, 1000 * s.sample.aspect, 1000, s.seconds);
        }
        if (mounted) {
          setState(() {
            _image = s.image;
            _aspect = s.sample.aspect;
            _t = s.seconds;
            _duration = s.duration;
            _tick++;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _error = 'تعذر فتح الفيديو أو صيغة الفيديو غير مدعومة');
      },
      onDone: _done,
    );
  }

  Future<void> _done() async {
    if (!mounted || _error != null) return;
    final duration = _t;
    _a.finish(duration);
    final session = Session(at: DateTime.now(), exercise: widget.exercise, source: 'video', report: _a.report(duration));
    await Store.add(session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReportScreen(
        session: session,
        onRetry: (ctx) => Navigator.of(ctx).pushReplacement(MaterialPageRoute(
          builder: (_) => VideoScreen(path: widget.path, exercise: widget.exercise, settings: widget.settings),
        )),
      ),
    ));
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _cancel = true;
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (status, tone) = _a.status(_t);
    final a = _a;
    final progress = _duration > 0 ? (_t / _duration).clamp(0.0, 1.0) : null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('تحليل الفيديو', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))))
          : Column(children: [
              LinearProgressIndicator(value: progress, minHeight: 6, color: Fa.green, backgroundColor: Fa.surface2),
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  if (_image != null)
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 1000 * _aspect,
                        height: 1000,
                        child: Stack(fit: StackFit.expand, children: [
                          Image.memory(_image!, fit: BoxFit.fill, gaplessPlayback: true),
                          CustomPaint(painter: AnalysisPainter(_a, _tick)),
                        ]),
                      ),
                    )
                  else
                    const Center(child: CircularProgressIndicator(color: Fa.green)),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: StatsPanel(_a, _t)),
                        if (a is RepAnalyzer) ...[const SizedBox(width: 8), RepCounter(a.reps)],
                      ]),
                      const Spacer(),
                      StatusBar(status, tone,
                          sub: _duration > 0 ? 'جارٍ التحليل: ${_t.toStringAsFixed(1)} من ${_duration.toStringAsFixed(1)} ثانية' : 'جارٍ تجهيز الفيديو…'),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Fa.red, foregroundColor: Colors.white),
                        onPressed: () {
                          _cancel = true;
                          _sub?.cancel();
                          _done();
                        },
                        icon: const Icon(Icons.flag),
                        label: const Text('إنهاء وعرض التقرير'),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
    );
  }
}
