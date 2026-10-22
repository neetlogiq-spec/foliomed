import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/screens/tools/ballard_tool.dart';
import 'package:foliomed/screens/tools/bp_tool.dart';
import 'package:foliomed/screens/tools/electrolytes_tool.dart';
import 'package:foliomed/screens/tools/hypoglycaemia_tool.dart';
import 'package:foliomed/screens/tools/tools_screen.dart';
import 'package:provider/provider.dart';

Widget _app(Widget child) =>
    ChangeNotifierProvider(create: (_) => AppearanceProvider(), child: MaterialApp(home: child));

Future<void> _type(WidgetTester tester, String label, String value) async {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
  await tester.enterText(find.descendant(of: row, matching: find.byType(TextField)), value);
  await tester.pump();
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 6000 * 3);
    view.devicePixelRatio = 3;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
    ..resetPhysicalSize()
    ..resetDevicePixelRatio());

  testWidgets('hub lists the new tools', (tester) async {
    await tester.pumpWidget(_app(const ToolsScreen()));
    for (final t in ['Low Blood Glucose', 'Electrolytes', 'Blood Pressure', 'Vaccines', 'New Ballard']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.enterText(find.byType(CupertinoSearchTextField), 'bcg');
    await tester.pump();
    expect(find.text('Vaccines'), findsOneWidget);
    expect(find.text('Electrolytes'), findsNothing);
  });

  testWidgets('low glucose: 3 kg → 6 mL bolus, 10.8 mL/h for GIR 6', (tester) async {
    await tester.pumpWidget(_app(const HypoglycaemiaTool()));
    await _type(tester, 'Weight', '3');
    expect(find.text('6 mL'), findsOneWidget);
    expect(find.text('200 mg/kg'), findsOneWidget);
    expect(find.text('10.8 mL/h'), findsOneWidget);
  });

  testWidgets('electrolytes: Na 125 → 135 at 3 kg = 21 mmol', (tester) async {
    await tester.pumpWidget(_app(const ElectrolytesTool()));
    await _type(tester, 'Weight', '3');
    await _type(tester, 'Sodium', '125');
    expect(find.text('21 mmol'), findsOneWidget);
    expect(find.text('41 mL'), findsOneWidget); // 3% saline
  });

  testWidgets('BP: 40 weeks shows the table; 100 systolic is at the 99th', (tester) async {
    await tester.pumpWidget(_app(const BpTool()));
    await _type(tester, 'Postmenstrual age', '40');
    expect(find.text('95'), findsOneWidget);
    await _type(tester, 'Systolic', '100');
    expect(find.textContaining('at or above the 99th centile'), findsOneWidget);
  });

  testWidgets('BP day 1: 30 weeks, mean 20 is below the Zubrow lower limit', (tester) async {
    await tester.pumpWidget(_app(const BpTool()));
    await tester.tap(find.text('Day 1'));
    await tester.pumpAndSettle();
    await _type(tester, 'Gestation at birth', '30');
    expect(find.text('30 weeks at birth · day 1 (mmHg)'), findsOneWidget);
    await _type(tester, 'Mean', '20');
    expect(find.textContaining('below the lower limit'), findsOneWidget);
  });

  testWidgets('BP 1–17 years: boy 6 y, 118.9 cm, systolic 111 is stage 1', (tester) async {
    await tester.pumpWidget(_app(const BpTool()));
    await tester.tap(find.text('1–17 Years'));
    await tester.pumpAndSettle();
    await _type(tester, 'Age', '6');
    await _type(tester, 'Height', '118.9');
    expect(find.textContaining('50th height centile column'), findsOneWidget);
    await _type(tester, 'Systolic', '111');
    expect(find.text('Stage 1 hypertension'), findsOneWidget);
  });

  testWidgets('Ballard: score counts as signs are chosen', (tester) async {
    await tester.pumpWidget(_app(const BallardTool()));
    expect(find.text('0 of 12 signs scored'), findsOneWidget);
    await tester.tap(find.text('Arms and legs fully flexed'));
    await tester.pump();
    expect(find.text('1 of 12 signs scored'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
  });
}
