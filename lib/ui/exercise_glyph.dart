import 'package:flutter/material.dart';

import '../analysis/analyzer.dart';
import 'theme.dart';

/// A pictogram of each exercise: a push-up from the side, a squat from the
/// side, and a fighting stance from the front with the feet distance marked.
class ExerciseGlyph extends StatelessWidget {
  const ExerciseGlyph(this.exercise, {super.key, this.size = 40, this.color = Fa.ink, this.accent = Fa.green});
  final Exercise exercise;
  final double size;
  final Color color, accent;

  @override
  Widget build(BuildContext context) => Semantics(
        label: exercise.title,
        child: SizedBox.square(dimension: size, child: CustomPaint(painter: _GlyphPainter(exercise, color, accent))),
      );
}

/// The same figures as lists of strokes in a 100×100 box, so the website's
/// SVGs can be drawn from them too.
class Glyphs {
  /// Each figure: limbs (polylines), the head (centre, radius), and the floor line.
  static const pushup = (
    limbs: [
      [Offset(30, 46), Offset(60, 55), Offset(86, 64), Offset(90, 72)], // body, legs, toes
      [Offset(30, 46), Offset(31, 59), Offset(30, 72)], // arm
    ],
    head: (Offset(20, 40), 8.0),
    floor: (Offset(8, 76), Offset(94, 76)),
  );

  static const squat = (
    limbs: [
      [Offset(48, 29), Offset(38, 55)], // torso, leaning a little
      [Offset(38, 55), Offset(63, 58), Offset(57, 82), Offset(68, 84)], // thigh, shin, foot
      [Offset(47, 33), Offset(62, 38), Offset(78, 36)], // arms forward
    ],
    head: (Offset(51, 17), 8.0),
    floor: (Offset(16, 88), Offset(90, 88)),
  );

  static const stance = (
    limbs: [
      [Offset(50, 27), Offset(50, 55)], // torso
      [Offset(50, 31), Offset(38, 41), Offset(42, 25)], // guard, left
      [Offset(50, 31), Offset(62, 41), Offset(58, 25)], // guard, right
      [Offset(50, 55), Offset(34, 70), Offset(28, 86)], // left leg
      [Offset(50, 55), Offset(66, 70), Offset(72, 86)], // right leg
    ],
    head: (Offset(50, 15), 8.0),
    floor: (Offset(26, 94), Offset(74, 94)), // the measured feet distance
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.e, this.color, this.accent);
  final Exercise e;
  final Color color, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final g = switch (e) {
      Exercise.pushup => Glyphs.pushup,
      Exercise.squat => Glyphs.squat,
      Exercise.stance => Glyphs.stance,
    };
    canvas.scale(size.width / 100, size.height / 100);
    final limb = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final l in g.limbs) {
      canvas.drawPath(Path()..addPolygon(l, false), limb);
    }
    canvas.drawCircle(g.head.$1, g.head.$2, Paint()..color = color);
    final (a, b) = g.floor;
    final floor = Paint()
      ..color = accent
      ..strokeWidth = e == Exercise.stance ? 5 : 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, floor);
    if (e == Exercise.stance) {
      for (final p in [a, b]) {
        canvas.drawCircle(p, 5, Paint()..color = accent);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.e != e || oldDelegate.color != color;
}
