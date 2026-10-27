import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/cloud.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only on the phone: the frame rotation handed to ML Kit assumes it.
  if (!kIsWeb) await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Cloud.init();
  runApp(const PostureAnalyzerApp());
}

class PostureAnalyzerApp extends StatelessWidget {
  const PostureAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'محلل الوضعيات',
      debugShowCheckedModeBanner: false,
      theme: Fa.theme(),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Cloud.enabled ? const AuthGate() : const HomeScreen(),
    );
  }
}

/// The desktop version: the login screen until signed in, then the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Cloud.auth.onAuthStateChange.listen((s) {
      if (!mounted) return;
      setState(() {});
      // The reset link from the email opens the app: ask for the new password.
      if (s.event == AuthChangeEvent.passwordRecovery) showNewPasswordDialog(context);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Cloud.user == null ? const LoginScreen() : HomeScreen(key: ValueKey(Cloud.user!.id));
}
