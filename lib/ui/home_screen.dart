import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../analysis/analyzer.dart';
import '../data/cloud.dart';
import '../data/store.dart';
import 'exercise_glyph.dart';
import 'history_screen.dart';
import 'institute_logo.dart';
import 'live_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'video_screen.dart';

const _info = {
  Exercise.stance: [
    'المسافة المقبولة بين القدمين نسبةً إلى طول الجذع',
    'تضييق: خط أحمر — اتساع زائد: خط أصفر',
    'اضغط «معايرة» أثناء التحليل لتثبيت وقفتك الصحيحة',
  ],
  Exercise.squat: [
    'تُقاس زاوية الركبة (الورك – الركبة – الكاحل)',
    'التكرار الصحيح: النزول حتى الزاوية المحددة',
    'صوّر من الجانب والجسم كاملاً في الصورة',
  ],
  Exercise.pushup: [
    'تُقاس زاوية الكوع واستقامة الجسم',
    'يُحسب كل تكرار حسب حساسية الحركة',
    'صوّر من الجانب والجسم كاملاً في الصورة',
  ],
};

/// Pick an exercise, then analyse live with the camera or a video.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Exercise _ex = Exercise.stance;
  Settings _s = const Settings();
  bool _front = true;
  List<Session> _recent = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await Store.exercise(),
        s = await Store.settings(),
        f = await Store.frontCamera(),
        h = await Store.history();
    if (mounted) {
      setState(() {
        _ex = e;
        _s = s;
        _front = f;
        _recent = h;
      });
    }
  }

  Future<void> _live() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LiveScreen(exercise: _ex, settings: _s, front: _front)));
    _load();
  }

  Future<void> _video() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => VideoScreen(path: file.path, exercise: _ex, settings: _s)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // A comfortable column on a wide computer screen.
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/brand/icon_1024.png',
                      width: 52, height: 52, filterQuality: FilterQuality.medium),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('محلل الوضعيات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
                    Text('Posture Analyzer',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: Fa.ink2, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const InstituteLogo(size: 46),
                const SizedBox(width: 4),
                if (Cloud.user != null)
                  PopupMenuButton<String>(
                    tooltip: 'الحساب',
                    icon: const Icon(Icons.account_circle_outlined, color: Fa.ink),
                    color: Fa.surface,
                    onSelected: (_) => Cloud.auth.signOut(),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(Cloud.user?.email ?? '',
                            textDirection: TextDirection.ltr, style: const TextStyle(color: Fa.ink2)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'out',
                        child: Row(
                            children: [Icon(Icons.logout, color: Fa.red), SizedBox(width: 8), Text('تسجيل الخروج')]),
                      ),
                    ],
                  ),
                IconButton(
                  tooltip: 'السجل',
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                    _load();
                  },
                  icon: const Icon(Icons.history, color: Fa.ink),
                ),
                IconButton(
                  tooltip: 'الإعدادات',
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    _load();
                  },
                  icon: const Icon(Icons.tune, color: Fa.ink),
                ),
              ]),
              const SizedBox(height: 22),
              const Text('اختر التمرين', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Fa.ink2)),
              const SizedBox(height: 10),
              Row(children: [
                for (final e in Exercise.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ExerciseCard(
                        e,
                        selected: e == _ex,
                        onTap: () {
                          setState(() => _ex = e);
                          Store.saveExercise(e);
                        },
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_ex),
                  padding: const EdgeInsets.all(16),
                  decoration: Fa.card(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final l in _info[_ex]!)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(Icons.check_circle, size: 17, color: Fa.green)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l, style: const TextStyle(fontSize: 15, height: 1.35))),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: _live, icon: const Icon(Icons.videocam), label: const Text('ابدأ التحليل بالكاميرا')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _video,
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('حلّل فيديو')),
                ),
                // A computer has one camera; the phone has two.
                if (!kIsWeb) const SizedBox(width: 10),
                if (!kIsWeb)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _front = !_front);
                        Store.saveFrontCamera(_front);
                      },
                      icon: Icon(_front ? Icons.camera_front : Icons.camera_rear),
                      label: Text(_front ? 'كاميرا أمامية' : 'كاميرا خلفية'),
                    ),
                  ),
              ]),
              if (_s.record)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.fiber_manual_record, color: Fa.red, size: 14),
                    SizedBox(width: 6),
                    Text(kIsWeb ? 'سيُنزَّل فيديو الجلسة عند الإنهاء' : 'سيُسجَّل فيديو الجلسة في المعرض',
                        style: TextStyle(color: Fa.ink2, fontWeight: FontWeight.w700)),
                  ]),
                ),
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 26),
                const Text('آخر الجلسات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Fa.ink2)),
                const SizedBox(height: 8),
                for (final s in _recent.take(3)) SessionTile(s),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(this.e, {required this.selected, required this.onTap});
  final Exercise e;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: selected ? Fa.greenSoft : Fa.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? Fa.green : Fa.border, width: 2),
            ),
            child: Column(children: [
              ExerciseGlyph(e, size: 46, color: selected ? Fa.ink : Fa.ink2, accent: selected ? Fa.green : Fa.ink3),
              const SizedBox(height: 6),
              Text(e.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: selected ? Fa.ink : Fa.ink2)),
            ]),
          ),
        ),
      );
}
