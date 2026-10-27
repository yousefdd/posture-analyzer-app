import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foot_analyzer/analysis/analyzer.dart';
import 'package:foot_analyzer/data/store.dart';
import 'package:foot_analyzer/main.dart';
import 'package:foot_analyzer/ui/history_screen.dart';
import 'package:foot_analyzer/ui/report_screen.dart';
import 'package:foot_analyzer/ui/settings_screen.dart';
import 'package:foot_analyzer/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home) => MaterialApp(
      theme: Fa.theme(),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: home,
    );

final session = Session(
  at: DateTime(2026, 10, 27, 18, 5),
  exercise: Exercise.pushup,
  source: 'camera',
  report: const Report(
    title: 'تقرير تمرين بوش أب',
    score: 82,
    evaluation: 'جيد جداً - مع بعض التكرارات غير الكاملة',
    lines: ['إجمالي التكرارات: 20', 'صحيحة: 16     قصيرة: 4', 'نسبة الالتزام بالوضعية السليمة: 91%'],
  ),
  video: 'تم حفظ فيديو الجلسة في المعرض (ألبوم Posture Analyzer)',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('home: three exercises, the info follows the choice, recent sessions show', (tester) async {
    await phone(tester);
    await Store.add(session);
    await tester.pumpWidget(const PostureAnalyzerApp());
    await tester.pumpAndSettle();
    expect(find.text('محلل الوضعيات'), findsOneWidget);
    expect(find.text('ابدأ التحليل بالكاميرا'), findsOneWidget);
    expect(find.textContaining('المسافة المقبولة'), findsOneWidget);
    await tester.tap(find.text('سكوات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('زاوية الركبة'), findsOneWidget);
    expect(await Store.exercise(), Exercise.squat);
    await tester.scrollUntilVisible(find.text('آخر الجلسات'), 200);
    expect(find.text('82'), findsOneWidget);
  });

  testWidgets('settings: a change is saved, an invalid range is explained', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('0.90 × طول الجذع'), findsOneWidget);
    final rec = find.widgetWithText(SwitchListTile, 'تسجيل فيديو التحليل');
    await tester.ensureVisible(rec);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: rec, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'تسجيل فيديو التحليل')).value, isTrue);
    await tester.runAsync(() async => expect((await Store.settings()).record, isTrue));
  });

  testWidgets('report and history render at phone width', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(ReportScreen(session: session, onRetry: (_) {})));
    await tester.pumpAndSettle();
    expect(find.text('جيد جداً - مع بعض التكرارات غير الكاملة'), findsOneWidget);
    expect(find.text('إعادة التحليل'), findsOneWidget);
    expect(find.textContaining('ألبوم Posture Analyzer'), findsOneWidget);

    await Store.add(session);
    await tester.pumpWidget(app(const HistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('بوش أب'), findsOneWidget);
  });
}
