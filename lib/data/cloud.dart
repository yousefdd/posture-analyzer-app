import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'store.dart';

/// Accounts and the session history online, for the desktop (web) version.
/// The phone version keeps everything on the phone and never signs in.
class Cloud {
  static const url = 'https://lnbhmstwdonkowpvcczy.supabase.co';
  // The publishable key: made to ship inside apps; the database's row rules
  // keep every user to their own sessions.
  static const key = 'sb_publishable_GVe_BwcPk02FVbDjfcN75Q_XLvO_7K1';

  // NO_LOGIN is for local testing of the camera screens only.
  static bool get enabled => kIsWeb && !const bool.fromEnvironment('NO_LOGIN');
  static bool _ready = false;

  static Future<void> init() async {
    if (!enabled || _ready) return;
    await Supabase.initialize(url: url, publishableKey: key);
    _ready = true;
  }

  static SupabaseClient get _c => Supabase.instance.client;
  static GoTrueClient get auth => _c.auth;
  static User? get user => _ready ? auth.currentUser : null;

  /// Where the email links (confirm, reset password) bring the user back.
  static String get returnUrl {
    final u = Uri.base;
    return Uri(scheme: u.scheme, host: u.host, port: u.port, path: u.path).toString();
  }

  static Future<List<Session>> history() async {
    final rows = await _c.from('pa_sessions').select().order('at', ascending: false).limit(Store.maxHistory);
    return [
      for (final r in rows)
        if (Session.fromJson(<String, dynamic>{
          ...Map<String, dynamic>.from(r['report'] as Map),
          'id': r['id'],
          'at': r['at'],
          'exercise': r['exercise'],
          'source': r['source'],
        })
            case final s?)
          s,
    ];
  }

  static Future<void> add(Session s) async {
    final j = s.toJson();
    await _c.from('pa_sessions').insert({
      'at': s.at.toUtc().toIso8601String(),
      'exercise': s.exercise.name,
      'source': s.source,
      'report': {
        'title': j['title'],
        'score': j['score'],
        'evaluation': j['evaluation'],
        'lines': j['lines'],
        'video': j['video'],
      },
    });
  }

  static Future<void> remove(String id) async => _c.from('pa_sessions').delete().eq('id', id);

  /// Arabic for the errors a person can fix.
  static String explain(Object e) {
    final m = e is AuthException ? e.message.toLowerCase() : '$e'.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) return 'الإيميل أو كلمة المرور غير صحيحة';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'هذا الإيميل مسجّل من قبل. سجّل الدخول بدلاً من ذلك';
    }
    if (m.contains('email not confirmed')) return 'أكّد بريدك أولاً من الرابط الذي أرسلناه إليك';
    if (m.contains('password') && (m.contains('6') || m.contains('short') || m.contains('weak'))) {
      return 'كلمة المرور قصيرة أو ضعيفة: استخدم 6 أحرف على الأقل';
    }
    if (m.contains('valid email') || m.contains('invalid format')) return 'اكتب بريداً إلكترونياً صحيحاً';
    if (m.contains('rate limit') || m.contains('too many')) return 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً';
    if (m.contains('network') || m.contains('failed to fetch') || m.contains('socket')) {
      return 'لا يوجد اتصال بالإنترنت';
    }
    return 'حدث خطأ. حاول مرة أخرى';
  }
}
