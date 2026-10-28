import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/cloud.dart';
import 'institute_logo.dart';
import 'theme.dart';

/// Sign in, create an account, or ask for a password reset link: email and
/// password, for the desktop version.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _hide = true;
  String? _error, _info;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  String get _mail => _email.text.trim();

  Future<void> _submit() async {
    setState(() {
      _error = _info = null;
    });
    if (!_mail.contains('@') || !_mail.contains('.')) return setState(() => _error = 'اكتب بريداً إلكترونياً صحيحاً');
    if (_pass.text.length < 6) return setState(() => _error = 'كلمة المرور 6 أحرف على الأقل');
    if (_signUp && _pass.text != _pass2.text) return setState(() => _error = 'كلمتا المرور غير متطابقتين');
    setState(() => _busy = true);
    try {
      if (_signUp) {
        final r = await Cloud.auth.signUp(email: _mail, password: _pass.text, emailRedirectTo: Cloud.returnUrl);
        if (r.session == null && mounted) {
          setState(() {
            _info = 'أرسلنا رابط تأكيد إلى $_mail. افتحه ثم سجّل الدخول.';
            _signUp = false;
          });
        }
      } else {
        await Cloud.auth.signInWithPassword(email: _mail, password: _pass.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = Cloud.explain(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    setState(() {
      _error = _info = null;
    });
    if (!_mail.contains('@')) {
      return setState(() => _error = 'اكتب بريدك الإلكتروني أولاً، ثم اضغط «نسيت كلمة المرور؟»');
    }
    setState(() => _busy = true);
    try {
      await Cloud.auth.resetPasswordForEmail(_mail, redirectTo: Cloud.returnUrl);
      if (mounted) setState(() => _info = 'أرسلنا رابط إعادة تعيين كلمة المرور إلى $_mail.');
    } catch (e) {
      if (mounted) setState(() => _error = Cloud.explain(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, IconData icon, {Widget? suffix}) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Fa.ink3),
          suffixIcon: suffix,
          filled: true,
          fillColor: Fa.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Fa.green, width: 2)),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: InstituteLogo(size: 110)),
                  const SizedBox(height: 14),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/brand/icon_1024.png', width: 96, height: 96),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('محلل الوضعيات',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const Text('Posture Analyzer',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: Fa.ink2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Fa.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      for (final (up, label) in [(false, 'تسجيل الدخول'), (true, 'حساب جديد')])
                        Expanded(
                          child: GestureDetector(
                            onTap: _busy
                                ? null
                                : () => setState(() {
                                      _signUp = up;
                                      _error = _info = null;
                                    }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                  color: _signUp == up ? Fa.greenSoft : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800, color: _signUp == up ? Fa.green : Fa.ink2)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.email],
                    decoration: deco('البريد الإلكتروني', Icons.mail_outline),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    textDirection: TextDirection.ltr,
                    autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                    onSubmitted: (_) => _signUp ? null : _submit(),
                    decoration: deco('كلمة المرور', Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: _hide ? 'إظهار' : 'إخفاء',
                          onPressed: () => setState(() => _hide = !_hide),
                          icon: Icon(_hide ? Icons.visibility : Icons.visibility_off, color: Fa.ink3),
                        )),
                  ),
                  if (_signUp) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass2,
                      obscureText: _hide,
                      textDirection: TextDirection.ltr,
                      onSubmitted: (_) => _submit(),
                      decoration: deco('تأكيد كلمة المرور', Icons.lock_outline),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Fa.red, fontWeight: FontWeight.w700)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 12),
                    Text(_info!, style: const TextStyle(color: Fa.green, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF052E16)))
                        : Text(_signUp ? 'إنشاء الحساب' : 'دخول'),
                  ),
                  if (!_signUp)
                    TextButton(
                      onPressed: _busy ? null : _forgot,
                      child: const Text('نسيت كلمة المرور؟',
                          style: TextStyle(color: Fa.ink2, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// After a password reset link: choose the new password.
Future<void> showNewPasswordDialog(BuildContext context) async {
  final c = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('كلمة مرور جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: c,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
          if (error != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Fa.red))),
        ]),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () async {
              if (c.text.length < 6) return set(() => error = 'كلمة المرور 6 أحرف على الأقل');
              try {
                await Cloud.auth.updateUser(UserAttributes(password: c.text));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                set(() => error = Cloud.explain(e));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  c.dispose();
}
