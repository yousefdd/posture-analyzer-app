import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:foot_analyzer/analysis/analyzer.dart';

/// A full body: every point at (0.5, 0.5) and well visible, then [set] moves some.
List<Lm> body(Map<int, (double, double)> set, {double v = 0.95}) =>
    List.generate(33, (i) => set.containsKey(i) ? Lm(set[i]!.$1, set[i]!.$2, v) : Lm(0.5, 0.5, v));

/// Feeds 30 frames a second for [seconds], with [frame] giving the body at time t.
double play(Analyzer a, double from, double seconds, List<Lm> Function(double t) frame) {
  var t = from;
  while (t < from + seconds) {
    a.update(frame(t), 1000, 1000, t);
    t += 1 / 30;
  }
  return t;
}

void main() {
  test('push-ups: a deep rep is good, a short one is short, a sagging hip is warned', () {
    final a = RepAnalyzer(Exercise.pushup, const Settings());
    final beeps = <Beep>[];
    a.onBeep = beeps.add;
    // Side view: shoulder above wrist, elbow out to the side; the further out,
    // the more bent. Hip and ankle make a straight, level body.
    List<Lm> pose(double bend, {double hipY = 0.42}) {
      final k = 0.1 / math.tan(bend * math.pi / 360);
      return body({
        12: (0.3, 0.4), 14: (0.3 + k, 0.5), 16: (0.3, 0.6),
        24: (0.6, hipY), 26: (0.75, 0.43), 28: (0.9, 0.44),
        11: (0.3, 0.4), 13: (0.3 + k, 0.5), 15: (0.3, 0.6),
        23: (0.6, hipY), 25: (0.75, 0.43), 27: (0.9, 0.44),
      });
    }

    double rep(double t, double low) {
      t = play(a, t, 0.6, (_) => pose(170));
      t = play(a, t, 0.5, (_) => pose(low));
      return play(a, t, 0.6, (_) => pose(170));
    }

    var t = rep(0, 80); // deep: good
    t = rep(t, 120); // short
    expect(a.reps, 2);
    expect(a.good, 1);
    expect(a.shallow, 1);
    expect(a.formMsg, isNull);

    play(a, t, 0.5, (_) => pose(170, hipY: 0.6)); // hip sags well below the line
    expect(a.formMsg, contains('الورك منخفض'));
    expect(beeps, contains(Beep.form));

    final r = a.report(5);
    expect(r.lines.first, 'إجمالي التكرارات: 2');
    expect(r.score, inInclusiveRange(1, 100));
  });

  test('squats: down to the depth counts as good, half way is not complete', () {
    final a = RepAnalyzer(Exercise.squat, const Settings());
    List<Lm> pose(double knee) {
      final k = 0.2 / math.tan(knee * math.pi / 360);
      return body({
        11: (0.5, 0.1), 23: (0.5, 0.4), 25: (0.5 + k, 0.6), 27: (0.5, 0.8),
        12: (0.5, 0.1), 24: (0.5, 0.4), 26: (0.5 + k, 0.6), 28: (0.5, 0.8),
      });
    }

    var t = play(a, 0, 0.5, (_) => pose(175));
    t = play(a, t, 0.6, (_) => pose(90));
    t = play(a, t, 0.5, (_) => pose(175));
    t = play(a, t, 0.6, (_) => pose(125));
    play(a, t, 0.5, (_) => pose(175));
    expect(a.reps, 2);
    expect(a.good, 1);
    expect(a.shallow, 1);
  });

  test('stance: narrow and wide feet are counted and timed, calibration resets the range', () {
    final a = StanceAnalyzer(const Settings());
    // Torso 300 px tall; heels apart by [gap] px.
    List<Lm> pose(double gap) => body({
          11: (0.4, 0.3), 12: (0.6, 0.3), 23: (0.42, 0.6), 24: (0.58, 0.6),
          29: (0.5 - gap / 2000, 0.95), 30: (0.5 + gap / 2000, 0.95),
        });

    var t = play(a, 0, 1, (_) => pose(400)); // 1.33: fine
    expect(a.st, StanceStatus.ok);
    t = play(a, t, 1, (_) => pose(150)); // 0.5: narrow
    expect(a.st, StanceStatus.narrow);
    t = play(a, t, 1, (_) => pose(400));
    t = play(a, t, 1, (_) => pose(700)); // 2.33: wide
    expect(a.st, StanceStatus.wide);
    a.finish(t);
    expect(a.narrowCount, 1);
    expect(a.wideCount, 1);
    expect(a.totalNarrow, closeTo(1, 0.1));

    play(a, t, 0.5, (_) => pose(400));
    a.calibrate(t + 0.5);
    expect(a.minR, closeTo(1.33 * 0.8, 0.02));
    expect(a.maxR, closeTo(1.33 * 1.25, 0.02));

    final r = a.report(4);
    expect(r.score, lessThan(100));
    expect(r.lines.first, startsWith('عدد مرات التضييق: 1'));
  });

  test('settings keep the desktop limits', () {
    expect(const Settings().validate(), isNull);
    expect(const Settings(minRatio: 2, maxRatio: 1).validate(), isNotNull);
    expect(const Settings(squatDepth: 20).validate(), isNotNull);
    final s = Settings.fromJson(const Settings(pushupDepth: 80).toJson());
    expect(s.pushupDepth, 80);
  });
}
