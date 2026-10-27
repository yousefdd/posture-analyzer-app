import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only: the frame rotation handed to ML Kit assumes an upright phone.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      home: const HomeScreen(),
    );
  }
}
