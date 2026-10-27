import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import 'theme.dart';

/// The result: the score in a ring, the verdict, the details, and buttons to
/// analyse again, share the report or go home.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.session, this.onRetry});
  final Session session;
  final void Function(BuildContext context)? onRetry;

  @override
  Widget build(BuildContext context) {
    final r = session.report;
    final c = Fa.score(r.score);
    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة التحليل', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Text(r.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: r.score / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: _Ring(v, c),
                  child: Center(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${(v * 100).round()}', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: c)),
                        const TextSpan(text: '/100', style: TextStyle(fontSize: 18, color: Fa.ink2, fontWeight: FontWeight.w700)),
                      ]),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(r.evaluation, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: Fa.card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('تفاصيل الأداء والإحصائيات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final l in r.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 7, color: Fa.green)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l, style: const TextStyle(fontSize: 15.5, color: Fa.ink, height: 1.4))),
                  ]),
                ),
              if (session.video != null) ...[
                const Divider(color: Fa.border, height: 22),
                Row(children: [
                  const Icon(Icons.video_library_outlined, color: Fa.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(session.video!, style: const TextStyle(color: Fa.blue, fontWeight: FontWeight.w700))),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          if (onRetry != null) ...[
            OutlinedButton.icon(onPressed: () => onRetry!(context), icon: const Icon(Icons.replay), label: const Text('إعادة التحليل')),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: () => Share.share(r.asText(session.at), subject: r.title),
            icon: const Icon(Icons.ios_share),
            label: const Text('مشاركة التقرير'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.check),
            label: const Text('موافق'),
          ),
        ]),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.v, this.c);
  final double v;
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..color = Fa.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawArc(rect.deflate(8), 0, math.pi * 2, false, bg);
    canvas.drawArc(
        rect.deflate(8),
        -math.pi / 2,
        math.pi * 2 * v,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_Ring oldDelegate) => oldDelegate.v != v || oldDelegate.c != c;
}
