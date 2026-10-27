import 'dart:math' as math;
import 'dart:ui' show Offset;

/// One body point from the pose model: position in the image (0..1) and how
/// sure the model is that it is visible (0..1). Indices follow MediaPipe /
/// ML Kit's 33-point body: 11/12 shoulders, 13/14 elbows, 15/16 wrists,
/// 23/24 hips, 25/26 knees, 27/28 ankles, 29/30 heels, 31/32 toes.
class Lm {
  const Lm(this.x, this.y, [this.v = 1]);
  final double x, y, v;
}

enum Exercise { stance, squat, pushup }

extension ExerciseName on Exercise {
  String get title => const {
        Exercise.stance: 'الوقفة الرياضية',
        Exercise.squat: 'سكوات',
        Exercise.pushup: 'بوش أب',
      }[this]!;
}

/// The user's settings, with the desktop app's defaults.
class Settings {
  const Settings({
    this.minRatio = 0.9,
    this.maxRatio = 1.9,
    this.squatDepth = 100,
    this.pushupDepth = 95,
    this.pushupMinMove = 20,
    this.sound = true,
    this.mirror = true,
    this.record = false,
  });

  final double minRatio, maxRatio, squatDepth, pushupDepth, pushupMinMove;
  final bool sound, mirror, record;

  Settings copyWith({
    double? minRatio,
    double? maxRatio,
    double? squatDepth,
    double? pushupDepth,
    double? pushupMinMove,
    bool? sound,
    bool? mirror,
    bool? record,
  }) =>
      Settings(
        minRatio: minRatio ?? this.minRatio,
        maxRatio: maxRatio ?? this.maxRatio,
        squatDepth: squatDepth ?? this.squatDepth,
        pushupDepth: pushupDepth ?? this.pushupDepth,
        pushupMinMove: pushupMinMove ?? this.pushupMinMove,
        sound: sound ?? this.sound,
        mirror: mirror ?? this.mirror,
        record: record ?? this.record,
      );

  Map<String, dynamic> toJson() => {
        'min_ratio': minRatio,
        'max_ratio': maxRatio,
        'squat_depth': squatDepth,
        'pushup_depth': pushupDepth,
        'pushup_min_move': pushupMinMove,
        'sound': sound,
        'mirror': mirror,
        'record': record,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] is num) ? (j[k] as num).toDouble() : def;
    bool b(String k, bool def) => j[k] is bool ? j[k] as bool : def;
    return Settings(
      minRatio: d('min_ratio', 0.9),
      maxRatio: d('max_ratio', 1.9),
      squatDepth: d('squat_depth', 100),
      pushupDepth: d('pushup_depth', 95),
      pushupMinMove: d('pushup_min_move', 20),
      sound: b('sound', true),
      mirror: b('mirror', true),
      record: b('record', false),
    );
  }

  /// Null if valid, else the reason (same limits as the desktop app).
  String? validate() {
    if (!(0.2 <= minRatio && minRatio < maxRatio && maxRatio <= 5)) return 'يجب أن تكون أقل مسافة أصغر من أقصى مسافة';
    if (!(40 <= squatDepth && squatDepth <= 130)) return 'عمق السكوات يجب أن يكون بين 40 و130 درجة';
    if (!(40 <= pushupDepth && pushupDepth <= 120)) return 'عمق البوش أب يجب أن يكون بين 40 و120 درجة';
    if (!(10 <= pushupMinMove && pushupMinMove <= 60)) return 'حساسية البوش أب يجب أن تكون بين 10 و60 درجة';
    return null;
  }
}

/// What the screen should colour a line or message.
enum Tone { good, warn, bad, info, muted }

/// A sound to play: the desktop app's beep frequencies.
enum Beep { narrow, wide, form, shallow }

const visMin = 0.4;
const smooth = 0.7;

double? angleAt(Offset a, Offset b, Offset c) {
  final v1 = a - b, v2 = c - b;
  final d = v1.distance * v2.distance;
  if (d == 0) return null;
  final cos = ((v1.dx * v2.dx + v1.dy * v2.dy) / d).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// Shared by the three analyses: smoothing, person tracking, messages, beeps.
abstract class Analyzer {
  Analyzer(this.exercise, this.settings);

  final Exercise exercise;
  final Settings settings;

  final _pts = <int, (Offset, double)>{};
  bool person = false;
  double? lastSeen;
  (String, double)? toast;
  double _lastBeep = -10;
  bool sound = true;

  /// Called with each sound the screen should play.
  void Function(Beep beep)? onBeep;

  factory Analyzer.of(Exercise e, Settings s) => e == Exercise.stance ? StanceAnalyzer(s) : RepAnalyzer(e, s);

  double vis(List<Lm> lm, int i) => lm[i].v;

  /// The point in pixels, smoothed over the last half second.
  Offset pt(List<Lm> lm, int i, double w, double h, double now) {
    final p = Offset(lm[i].x * w, lm[i].y * h);
    final old = _pts[i];
    final Offset out;
    if (old == null || now - old.$2 > 0.5) {
      out = p;
    } else {
      out = Offset(smooth * p.dx + (1 - smooth) * old.$1.dx, smooth * p.dy + (1 - smooth) * old.$1.dy);
    }
    _pts[i] = (out, now);
    return out;
  }

  void beep(Beep b, double now) {
    if (!sound) return;
    if (now - _lastBeep < 1.5) return;
    _lastBeep = now;
    onBeep?.call(b);
  }

  /// A frame with a body in it.
  void update(List<Lm> lm, double w, double h, double now);

  /// A frame with no body.
  void checkLost(double now);

  /// Closes open timers at the end.
  void finish(double now);

  void reset(double now);

  (String, Tone) status(double now);

  Report report(double duration);
}

class Report {
  const Report({required this.title, required this.score, required this.evaluation, required this.lines});
  final String title;
  final int score;
  final String evaluation;
  final List<String> lines;

  String asText(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '$title\n${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}\n\n'
        'النتيجة: $score/100\n$evaluation\n\n${lines.join('\n')}\n';
  }
}

String evaluationFor(int score, Exercise kind) {
  if (kind == Exercise.stance) {
    if (score >= 90) return 'ممتاز - ثبات رائع في وقفة الملاكمة';
    if (score >= 75) return 'جيد جداً - حركة متوازنة مع أخطاء بسيطة';
    if (score >= 60) return 'مقبول - يحتاج للتركيز على مسافة القدمين';
    return 'يحتاج إلى تحسين وتدريب على ثبات الوقفة';
  }
  if (score >= 90) return 'ممتاز - تكرارات كاملة ووضعية سليمة';
  if (score >= 75) return 'جيد جداً - مع بعض التكرارات غير الكاملة';
  if (score >= 60) return 'مقبول - ركز على العمق والوضعية';
  return 'يحتاج إلى تحسين العمق والوضعية';
}

// ---------------------------------------------------------------- stance

enum StanceStatus { lost, unknown, ok, narrow, wide }

/// The distance between the feet, as a share of the torso length.
class StanceAnalyzer extends Analyzer {
  StanceAnalyzer(Settings s)
      : minR = s.minRatio,
        maxR = s.maxRatio,
        super(Exercise.stance, s);

  double minR, maxR;
  double? unit, ratio;
  Offset? left, right;
  int? _footType;
  StanceStatus st = StanceStatus.lost;
  int narrowCount = 0, wideCount = 0;
  double totalNarrow = 0, totalWide = 0;
  StanceStatus? _cur; // narrow or wide while it lasts
  double _since = 0;

  // Heels, ankles, toes; heels slightly preferred.
  static const _feet = [((29, 30), 1.05), ((27, 28), 1.0), ((31, 32), 0.9)];

  (int, int)? _pickFeet(List<Lm> lm) {
    final scores = <(double, double, int)>[];
    for (var n = 0; n < _feet.length; n++) {
      final (pair, weight) = _feet[n];
      final v = math.min(vis(lm, pair.$1), vis(lm, pair.$2));
      scores.add((v * weight, v, n));
    }
    final best = scores.reduce((a, b) => a.$1 >= b.$1 ? a : b);
    final cur = _footType;
    if (cur != null && scores[cur].$2 >= 0.25 && best.$1 < scores[cur].$1 + 0.2) return _feet[cur].$1;
    if (best.$2 < 0.25) return null;
    _footType = best.$3;
    return _feet[best.$3].$1;
  }

  bool _setViolation(StanceStatus? name, double now) {
    if (_cur == name) return false;
    if (_cur == StanceStatus.narrow) totalNarrow += now - _since;
    if (_cur == StanceStatus.wide) totalWide += now - _since;
    _cur = name;
    _since = now;
    if (name == StanceStatus.narrow) narrowCount++;
    if (name == StanceStatus.wide) wideCount++;
    return name != null;
  }

  @override
  void update(List<Lm> lm, double w, double h, double now) {
    person = true;
    lastSeen = now;
    double? torso;
    const ids = [11, 12, 23, 24];
    if (ids.map((i) => vis(lm, i)).reduce(math.min) >= 0.3) {
      final p = ids.map((i) => pt(lm, i, w, h, now)).toList();
      final s = (p[0] + p[1]) / 2, hp = (p[2] + p[3]) / 2;
      torso = (s - hp).distance;
    }
    if (torso != null && torso > 20) unit = unit == null ? torso : 0.85 * unit! + 0.15 * torso;

    final pair = _pickFeet(lm);
    if (pair == null || unit == null || unit == 0) {
      left = right = ratio = null;
      st = StanceStatus.unknown;
      _setViolation(null, now);
      return;
    }
    left = pt(lm, pair.$1, w, h, now);
    right = pt(lm, pair.$2, w, h, now);
    final r = (right! - left!).distance / unit!;
    ratio = r;

    var low = minR, high = maxR;
    if (st == StanceStatus.narrow) low += 0.05;
    if (st == StanceStatus.wide) high -= 0.05;
    st = r < low
        ? StanceStatus.narrow
        : r > high
            ? StanceStatus.wide
            : StanceStatus.ok;
    if (st == StanceStatus.ok) {
      _setViolation(null, now);
    } else if (_setViolation(st, now)) {
      beep(st == StanceStatus.narrow ? Beep.narrow : Beep.wide, now);
    }
  }

  /// Sets the accepted range around the current stance (C on the desktop).
  String calibrate(double now) {
    final r = ratio;
    if (r == null) {
      toast = ('تعذرت المعايرة: لا توجد قياسات', now);
    } else {
      minR = (r * 0.8 * 100).round() / 100;
      maxR = (r * 1.25 * 100).round() / 100;
      toast = ('تمت المعايرة: ${minR.toStringAsFixed(2)} - ${maxR.toStringAsFixed(2)}', now);
    }
    return toast!.$1;
  }

  @override
  void checkLost(double now) {
    if (!person || lastSeen == null || now - lastSeen! <= 0.6) return;
    person = false;
    st = StanceStatus.lost;
    left = right = null;
    _setViolation(null, now);
  }

  @override
  void finish(double now) => _setViolation(null, now);

  @override
  void reset(double now) {
    final keep = (minR, maxR);
    final fresh = StanceAnalyzer(settings);
    unit = fresh.unit;
    ratio = null;
    left = right = null;
    _footType = null;
    st = StanceStatus.lost;
    narrowCount = wideCount = 0;
    totalNarrow = totalWide = 0;
    _cur = null;
    minR = keep.$1;
    maxR = keep.$2;
    person = false;
    toast = ('تم تصفير العدادات', now);
  }

  double narrowTime(double now) => totalNarrow + (_cur == StanceStatus.narrow ? now - _since : 0);
  double wideTime(double now) => totalWide + (_cur == StanceStatus.wide ? now - _since : 0);

  @override
  (String, Tone) status(double now) {
    final t = toast;
    if (t != null && now - t.$2 < 2.5) return (t.$1, Tone.info);
    return switch (st) {
      StanceStatus.ok => ('الوضع طبيعي (أخضر)', Tone.good),
      StanceStatus.narrow => ('ضيق جداً (أحمر)', Tone.bad),
      StanceStatus.wide => ('واسع جداً (أصفر)', Tone.warn),
      StanceStatus.unknown => ('ابتعد قليلاً ليظهر الجسم والقدمان كاملين', Tone.warn),
      StanceStatus.lost => ('لا يوجد شخص في الصورة', Tone.muted),
    };
  }

  @override
  Report report(double duration) {
    final n = narrowCount, w = wideCount, tn = totalNarrow, tw = totalWide;
    var acc = duration > 0 ? (((duration - tn - tw) / duration) * 100).truncate() : 100;
    acc = acc.clamp(0, 100);
    final score = (acc - 3 * (n + w)).clamp(0, 100);
    return Report(
      title: 'تقرير تحليل حركة القدمين',
      score: score,
      evaluation: evaluationFor(score, Exercise.stance),
      lines: [
        'عدد مرات التضييق: $n مرات  (المدة: ${tn.toStringAsFixed(1)} ثانية)',
        'عدد مرات الاتساع: $w مرات  (المدة: ${tw.toStringAsFixed(1)} ثانية)',
        'إجمالي مدة التحليل: ${duration.toStringAsFixed(1)} ثانية',
        'نسبة الالتزام بالوقفة المثالية: $acc%',
      ],
    );
  }
}

// ---------------------------------------------------------------- reps

enum RepPhase { up, down }

/// Squats (knee angle) and push-ups (elbow angle, body line).
class RepAnalyzer extends Analyzer {
  RepAnalyzer(super.exercise, super.settings)
      : depth = exercise == Exercise.squat ? settings.squatDepth : settings.pushupDepth,
        upAngle = exercise == Exercise.squat ? 160 : 0,
        downAngle = exercise == Exercise.squat ? math.max(130, settings.squatDepth + 15) : 0,
        minRepTime = exercise == Exercise.squat ? 0.3 : 0.15,
        relative = exercise == Exercise.pushup,
        minMove = settings.pushupMinMove;

  final double depth, upAngle, downAngle, minRepTime, minMove;
  final bool relative;

  RepPhase? phase;
  int reps = 0, good = 0, shallow = 0;
  double? repMin;
  double downStart = 0;
  final repTimes = <double>[];
  final depths = <double>[];
  double? angle;
  List<Offset>? joints;
  List<(Offset, Offset)> extra = [];
  String? formMsg, hint;
  (String, Tone, double)? fb;
  String? side;
  double? outSince;
  bool formBad = false;
  double formStart = 0;
  int badCount = 0;
  double badTotal = 0;
  double? peak;

  static const legs = {
    'L': [23, 25, 27],
    'R': [24, 26, 28]
  };
  static const arms = {
    'L': [11, 13, 15],
    'R': [12, 14, 16]
  };

  String? _pickSide(List<Lm> lm, Map<String, List<int>> ids) {
    final scores = {for (final s in ids.keys) s: ids[s]!.map((i) => vis(lm, i)).reduce(math.min)};
    var s = side;
    if (s == null || scores[s]! < visMin) {
      s = scores['L']! >= scores['R']! ? 'L' : 'R';
    } else {
      final other = s == 'L' ? 'R' : 'L';
      if (scores[other]! > scores[s]! + 0.2) s = other;
    }
    side = s;
    return scores[s]! < visMin ? null : s;
  }

  void _setForm(String? msg, double now) {
    formMsg = msg;
    final bad = msg != null;
    if (bad && !formBad) {
      formBad = true;
      formStart = now;
      badCount++;
      beep(Beep.form, now);
    } else if (!bad && formBad) {
      formBad = false;
      badTotal += now - formStart;
    }
  }

  void _outOfPosition(double now) {
    _setForm(null, now);
    if (outSince == null) {
      outSince = now;
    } else if (now - outSince! > 1.0 && phase != null) {
      phase = null;
      repMin = null;
      peak = null;
    }
  }

  void _noMeasure(double now, String h) {
    angle = null;
    joints = null;
    extra = [];
    hint = h;
    _outOfPosition(now);
  }

  void _addRep(double now) {
    final dur = now - downStart;
    if (dur < minRepTime) {
      repMin = null;
      return;
    }
    reps++;
    repTimes.add(dur);
    depths.add(repMin!);
    if (repMin! <= depth) {
      good++;
      fb = ('تكرار ممتاز', Tone.good, now);
    } else {
      shallow++;
      if (exercise == Exercise.squat) {
        fb = ('تكرار غير كامل - انزل أكثر', Tone.warn, now);
        beep(Beep.shallow, now);
      } else {
        fb = ('تكرار قصير', Tone.warn, now);
      }
    }
    repMin = null;
  }

  void _countRelative(double a, double now) {
    if (peak == null) {
      peak = a;
      phase = RepPhase.up;
      return;
    }
    if (phase == RepPhase.up) {
      peak = math.max(a, peak! - 0.3);
      if (a <= peak! - minMove && a <= 155) {
        phase = RepPhase.down;
        repMin = a;
        downStart = now;
      }
      return;
    }
    repMin = math.min(repMin!, a);
    if (a >= repMin! + minMove) {
      phase = RepPhase.up;
      peak = a;
      _addRep(now);
    }
  }

  void _count(double a, double now) {
    if (relative) return _countRelative(a, now);
    if (phase == null) {
      if (a >= upAngle) phase = RepPhase.up;
      return;
    }
    if (phase == RepPhase.up) {
      if (a <= downAngle) {
        phase = RepPhase.down;
        repMin = a;
        downStart = now;
      }
      return;
    }
    repMin = math.min(repMin!, a);
    if (a < upAngle) return;
    phase = RepPhase.up;
    _addRep(now);
  }

  void _apply(
      double a, List<Offset> j, List<(Offset, Offset)> ex, bool inPosition, String? h, String? form, double now) {
    joints = j;
    extra = ex;
    angle = a;
    if (!inPosition) {
      hint = h;
      _outOfPosition(now);
      return;
    }
    hint = null;
    outSince = null;
    _count(a, now);
    _setForm(form, now);
  }

  @override
  void update(List<Lm> lm, double w, double h, double now) {
    person = true;
    lastSeen = now;
    exercise == Exercise.squat ? _squat(lm, w, h, now) : _pushup(lm, w, h, now);
  }

  void _squat(List<Lm> lm, double w, double h, double now) {
    const far = 'ابتعد ليظهر الورك والركبة والكاحل (صوّر من الجانب)';
    final s = _pickSide(lm, legs);
    if (s == null) return _noMeasure(now, far);
    final p = legs[s]!.map((i) => pt(lm, i, w, h, now)).toList();
    final a = angleAt(p[0], p[1], p[2]);
    if (a == null) return _noMeasure(now, far);
    final ex = <(Offset, Offset)>[];
    String? form;
    final shI = s == 'L' ? 11 : 12;
    if (vis(lm, shI) >= visMin) {
      final sh = pt(lm, shI, w, h, now);
      ex.add((sh, p[0]));
      final lean = math.atan2((sh.dx - p[0].dx).abs(), math.max((sh.dy - p[0].dy).abs(), 1)) * 180 / math.pi;
      if (phase == RepPhase.down && lean > 65) form = 'ظهرك مائل للأمام كثيراً - ارفع صدرك';
    }
    _apply(a, p, ex, true, null, form, now);
  }

  void _pushup(List<Lm> lm, double w, double h, double now) {
    const far = 'ابتعد ليظهر جسمك كاملاً (صوّر من الجانب)';
    final s = _pickSide(lm, arms);
    if (s == null) return _noMeasure(now, far);
    final p = arms[s]!.map((i) => pt(lm, i, w, h, now)).toList();
    final sh = p[0];
    final a = angleAt(p[0], p[1], p[2]);
    if (a == null) return _noMeasure(now, far);
    final [hipI, kneeI, ankI] = legs[s]!;

    Offset? anchor;
    for (final i in [ankI, kneeI, hipI]) {
      if (vis(lm, i) >= 0.3) {
        anchor = pt(lm, i, w, h, now);
        break;
      }
    }
    var inPosition = true;
    String? h0;
    if (anchor == null) {
      inPosition = false;
      h0 = far;
    } else {
      final dx = (anchor.dx - sh.dx).abs(), dy = (anchor.dy - sh.dy).abs();
      if (dy > 0.6 * dx) {
        inPosition = false;
        h0 = 'اتخذ وضعية البوش أب (الكاميرا من الجانب)';
      }
    }

    var ex = <(Offset, Offset)>[];
    String? form;
    if (inPosition && vis(lm, hipI) >= 0.3 && vis(lm, ankI) >= 0.3) {
      final hip = pt(lm, hipI, w, h, now), ank = pt(lm, ankI, w, h, now);
      ex = [(sh, hip), (hip, ank)];
      final body = angleAt(sh, hip, ank);
      if (body != null && body < 155) {
        var lineY = sh.dy;
        if ((ank.dx - sh.dx).abs() > 1) {
          final t = (hip.dx - sh.dx) / (ank.dx - sh.dx);
          lineY = sh.dy + t * (ank.dy - sh.dy);
        }
        form =
            hip.dy > lineY ? 'الورك منخفض - شدّ بطنك واجعل جسمك مستقيماً' : 'الورك مرتفع - اخفضه ليصبح جسمك مستقيماً';
      }
    }
    _apply(a, p, ex, inPosition, h0, form, now);
  }

  @override
  void checkLost(double now) {
    if (!person || lastSeen == null || now - lastSeen! <= 0.6) return;
    person = false;
    joints = null;
    extra = [];
    angle = null;
    hint = null;
    _setForm(null, now);
  }

  @override
  void finish(double now) => _setForm(null, now);

  @override
  void reset(double now) {
    phase = null;
    reps = good = shallow = 0;
    repMin = null;
    repTimes.clear();
    depths.clear();
    angle = null;
    joints = null;
    extra = [];
    formMsg = hint = null;
    fb = null;
    side = null;
    outSince = null;
    formBad = false;
    badCount = 0;
    badTotal = 0;
    peak = null;
    person = false;
    toast = ('تم تصفير العدادات', now);
  }

  double badTime(double now) => badTotal + (formBad ? now - formStart : 0);

  @override
  (String, Tone) status(double now) {
    final t = toast;
    if (t != null && now - t.$2 < 2.5) return (t.$1, Tone.info);
    if (!person) return ('لا يوجد شخص في الصورة', Tone.muted);
    if (hint != null) return (hint!, Tone.warn);
    if (formMsg != null) return (formMsg!, Tone.bad);
    final f = fb;
    if (f != null && now - f.$3 < 2.5) return (f.$1, f.$2);
    if (phase == null) return ('قف في وضع البداية', Tone.info);
    if (phase == RepPhase.up) return ('جاهز - ابدأ النزول', Tone.good);
    if (angle != null && angle! <= depth) return ('عمق ممتاز - اصعد', Tone.good);
    if (exercise == Exercise.pushup) return ('جارٍ التكرار', Tone.good);
    return ('انزل أكثر', Tone.warn);
  }

  /// The joint lines' colour: red on a form warning, yellow while too shallow.
  Tone get jointTone {
    if (formMsg != null) return Tone.bad;
    if (phase == RepPhase.down) return angle != null && angle! <= depth ? Tone.good : Tone.warn;
    return Tone.good;
  }

  String get shortWord => exercise == Exercise.pushup ? 'قصيرة' : 'غير كاملة';

  @override
  Report report(double duration) {
    final total = reps;
    var formPct = duration > 0 ? ((1 - badTotal / duration) * 100).truncate() : 100;
    formPct = formPct.clamp(0, 100);
    final shortCredit = exercise == Exercise.pushup ? 0.7 : 0.0;
    final lines = ['إجمالي التكرارات: $total', 'صحيحة: $good     $shortWord: $shallow'];
    int score;
    String evaluation;
    if (total > 0) {
      final credit = good + shortCredit * shallow;
      score = (0.65 * (credit / total) * 100 + 0.35 * formPct).round();
      evaluation = evaluationFor(score, exercise);
      final avgTime = repTimes.reduce((a, b) => a + b) / repTimes.length;
      final avgDepth = depths.reduce((a, b) => a + b) / depths.length;
      lines.add('متوسط أعمق زاوية: ${avgDepth.truncate()}° (الهدف ≤ ${depth.truncate()}°)');
      lines.add('متوسط زمن التكرار: ${avgTime.toStringAsFixed(1)} ثانية');
      if (duration > 0) lines.add('المعدل: ${(total * 60 / duration).toStringAsFixed(1)} تكرار في الدقيقة');
    } else {
      score = 0;
      evaluation = 'لم يتم رصد أي تكرار - تأكد من ظهور الجسم كاملاً وزاوية التصوير';
    }
    lines.add('تحذيرات الوضعية: $badCount مرات  (المدة: ${badTotal.toStringAsFixed(1)} ثانية)');
    lines.add('إجمالي مدة التحليل: ${duration.toStringAsFixed(1)} ثانية');
    lines.add('نسبة الالتزام بالوضعية السليمة: $formPct%');
    return Report(title: 'تقرير تمرين ${exercise.title}', score: score, evaluation: evaluation, lines: lines);
  }
}
