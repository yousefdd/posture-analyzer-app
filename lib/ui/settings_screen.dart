import 'package:flutter/material.dart';

import '../analysis/analyzer.dart';
import '../data/store.dart';
import 'theme.dart';

/// The desktop app's settings, as sliders and switches, saved on the phone.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings? _s;

  @override
  void initState() {
    super.initState();
    Store.settings().then((s) => mounted ? setState(() => _s = s) : null);
  }

  void _set(Settings s) {
    setState(() => _s = s);
    if (s.validate() == null) Store.saveSettings(s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final err = s?.validate();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.w800))),
      body: s == null
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              _section('الوقفة الرياضية', [
                _slider('أقل مسافة للقدمين', '× طول الجذع', s.minRatio, 0.2, 4, 0.05, 2, (v) => _set(s.copyWith(minRatio: v))),
                _slider('أقصى مسافة للقدمين', '× طول الجذع', s.maxRatio, 0.3, 5, 0.05, 2, (v) => _set(s.copyWith(maxRatio: v))),
              ]),
              _section('السكوات', [
                _slider('عمق السكوات (الركبة ≤)', '°', s.squatDepth, 40, 130, 5, 0, (v) => _set(s.copyWith(squatDepth: v))),
              ]),
              _section('البوش أب', [
                _slider('عمق البوش أب الكامل (≤)', '°', s.pushupDepth, 40, 120, 5, 0, (v) => _set(s.copyWith(pushupDepth: v))),
                _slider('الحساسية (أقل حركة)', '°', s.pushupMinMove, 10, 60, 5, 0, (v) => _set(s.copyWith(pushupMinMove: v))),
              ]),
              _section('عام', [
                _switch('تنبيه صوتي', 'صوت عند الخطأ وعند التكرار الممتاز', s.sound, (v) => _set(s.copyWith(sound: v))),
                _switch('قلب الكاميرا', 'عرض الصورة كالمرآة', s.mirror, (v) => _set(s.copyWith(mirror: v))),
                _switch('تسجيل فيديو التحليل', 'يُحفظ فيديو الجلسة في المعرض', s.record, (v) => _set(s.copyWith(record: v))),
              ]),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(err, style: const TextStyle(color: Fa.red, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _set(const Settings()),
                icon: const Icon(Icons.restore),
                label: const Text('استعادة الإعدادات الافتراضية'),
              ),
            ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: Fa.card(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Fa.green)),
            ...children,
          ]),
        ),
      );

  Widget _slider(String label, String unit, double v, double min, double max, double step, int digits, ValueChanged<double> on) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          // Degrees read "100°" in both directions; ratios keep their Arabic unit.
          unit == '°'
              ? Text('${v.toStringAsFixed(digits)}°',
                  textDirection: TextDirection.ltr, style: const TextStyle(color: Fa.ink2, fontWeight: FontWeight.w800))
              : Text('${v.toStringAsFixed(digits)} $unit', style: const TextStyle(color: Fa.ink2, fontWeight: FontWeight.w800)),
        ]),
        Slider(
          value: v.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          onChanged: (x) => on(double.parse(x.toStringAsFixed(2))),
        ),
      ]);

  Widget _switch(String label, String sub, bool v, ValueChanged<bool> on) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: v,
        onChanged: on,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub, style: const TextStyle(color: Fa.ink3)),
      );
}
