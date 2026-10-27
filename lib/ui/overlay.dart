import 'package:flutter/material.dart';

import '../analysis/analyzer.dart';
import 'theme.dart';

/// Draws what the analysis sees, in the same coordinate box it measured in:
/// the feet line for the stance, the measured joint and body line for reps.
class AnalysisPainter extends CustomPainter {
  AnalysisPainter(this.a, this.tick);
  final Analyzer a;
  final int tick; // repaint trigger

  @override
  void paint(Canvas canvas, Size size) {
    final a = this.a;
    if (!a.person) return;
    if (a is StanceAnalyzer) {
      final l = a.left, r = a.right;
      if (l == null || r == null) return;
      final c = switch (a.st) {
        StanceStatus.narrow => Fa.red,
        StanceStatus.wide => Fa.yellow,
        _ => Fa.green,
      };
      final p = Paint()
        ..color = c
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(l, r, p);
      for (final x in [l, r]) {
        canvas.drawCircle(x, 22, Paint()..color = c);
        canvas.drawCircle(
            x,
            22,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
      }
      final ratio = a.ratio;
      if (ratio != null) _label(canvas, (l + r) / 2 + const Offset(0, -46), ratio.toStringAsFixed(2), c);
      return;
    }
    if (a is RepAnalyzer) {
      final j = a.joints;
      if (j == null) return;
      final grey = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      for (final (x, y) in a.extra) {
        canvas.drawLine(x, y, grey);
      }
      final c = Fa.tone(a.jointTone);
      final line = Paint()
        ..color = c
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(j[0], j[1], line);
      canvas.drawLine(j[1], j[2], line);
      for (final p in j) {
        canvas.drawCircle(p, 18, Paint()..color = c);
        canvas.drawCircle(
            p,
            18,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
      }
      final ang = a.angle;
      if (ang != null) _label(canvas, j[1] + const Offset(46, -46), '${ang.round()}°', c);
    }
  }

  void _label(Canvas canvas, Offset at, String text, Color c) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: 'Tajawal', fontSize: 38, fontWeight: FontWeight.w800, color: c),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: tp.width + 28, height: tp.height + 10),
      const Radius.circular(14),
    );
    canvas.drawRRect(r, Paint()..color = Colors.black.withOpacity(0.6));
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(AnalysisPainter oldDelegate) => oldDelegate.tick != tick;
}

/// A translucent panel over the camera.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: child,
      );
}

/// The numbers for the analysis on screen: counters, times, the target.
class StatsPanel extends StatelessWidget {
  const StatsPanel(this.a, this.now, {super.key});
  final Analyzer a;
  final double now;

  @override
  Widget build(BuildContext context) {
    final a = this.a;
    final rows = <(String, Color)>[];
    if (a is StanceAnalyzer) {
      rows.add(('تضييق: ${a.narrowCount} مرات (${a.narrowTime(now).toStringAsFixed(1)} ث)', Fa.red));
      rows.add(('اتساع: ${a.wideCount} مرات (${a.wideTime(now).toStringAsFixed(1)} ث)', Fa.yellow));
      rows.add(('المقبول: ${a.minR.toStringAsFixed(2)} – ${a.maxR.toStringAsFixed(2)} × طول الجذع', Fa.ink2));
    } else if (a is RepAnalyzer) {
      rows.add(('صحيحة: ${a.good}', Fa.green));
      rows.add(('${a.shortWord}: ${a.shallow}', Fa.yellow));
      rows.add(('تحذيرات الوضعية: ${a.badCount} (${a.badTime(now).toStringAsFixed(1)} ث)', Fa.red));
      final ang = a.angle;
      rows.add(('الزاوية: ${ang == null ? '--' : '${ang.round()}°'} | المطلوب ≤ ${a.depth.round()}°', Fa.ink2));
    }
    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        for (final (t, c) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(t,
                    style:
                        TextStyle(color: c == Fa.ink2 ? Fa.ink2 : Fa.ink, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// The big rep counter.
class RepCounter extends StatelessWidget {
  const RepCounter(this.reps, {super.key});
  final int reps;

  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('التكرارات', style: TextStyle(color: Fa.ink2, fontWeight: FontWeight.w700)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, an) => ScaleTransition(scale: Tween(begin: 1.4, end: 1.0).animate(an), child: c),
            child: Text('$reps',
                key: ValueKey(reps),
                style: const TextStyle(fontSize: 56, height: 1, fontWeight: FontWeight.w800, color: Fa.ink)),
          ),
        ]),
      );
}

/// The status line at the bottom: what to do now.
class StatusBar extends StatelessWidget {
  const StatusBar(this.text, this.tone, {super.key, this.sub});
  final String text;
  final Tone tone;
  final String? sub;

  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: Fa.tone(tone), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(text, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Fa.tone(tone))),
              if (sub != null) Text(sub!, style: const TextStyle(color: Fa.ink2, fontSize: 13)),
            ]),
          ),
        ]),
      );
}
