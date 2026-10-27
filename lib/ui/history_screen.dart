import 'package:flutter/material.dart';

import '../analysis/analyzer.dart';
import '../data/store.dart';
import 'exercise_glyph.dart';
import 'report_screen.dart';
import 'theme.dart';

/// Every finished session, newest first; tap to see its report.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Session>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await Store.history();
    if (mounted) setState(() => _list = h);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الجلسات', style: TextStyle(fontWeight: FontWeight.w800))),
      body: list == null
          ? const SizedBox.shrink()
          : list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('لا توجد جلسات بعد.\nابدأ تحليلاً وستظهر نتيجته هنا.',
                        textAlign: TextAlign.center, style: TextStyle(color: Fa.ink2, fontSize: 17, height: 1.5)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => Dismissible(
                    key: ValueKey(list[i].at.toIso8601String()),
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Fa.red.withOpacity(0.3),
                      child: const Icon(Icons.delete, color: Fa.red),
                    ),
                    onDismissed: (_) async {
                      await Store.remove(i);
                      _load();
                    },
                    child: SessionTile(list[i]),
                  ),
                ),
    );
  }
}

/// One session in a list: exercise, date, source and score.
class SessionTile extends StatelessWidget {
  const SessionTile(this.s, {super.key});
  final Session s;

  @override
  Widget build(BuildContext context) {
    final d = s.at;
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Fa.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(session: s))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              ExerciseGlyph(s.exercise, size: 36, color: Fa.ink2, accent: Fa.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.exercise.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}',
                      textDirection: TextDirection.ltr, style: const TextStyle(color: Fa.ink3, fontSize: 13)),
                ]),
              ),
              Text('${s.report.score}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Fa.score(s.report.score))),
              const Text('/100', style: TextStyle(color: Fa.ink3, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}
