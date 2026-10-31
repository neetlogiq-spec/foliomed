import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/screens/tools/emergency_drugs_tool.dart';
import 'package:foliomed/screens/tools/infusion_tool.dart';
import 'package:foliomed/tools/drugs/drug_model.dart';
import 'package:provider/provider.dart';

Widget _app(Widget child) => ChangeNotifierProvider(
  create: (_) => AppearanceProvider(),
  child: MaterialApp(home: child),
);

Future<void> _type(WidgetTester tester, String label, String value) async {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
  await tester.enterText(find.descendant(of: row, matching: find.byType(TextField)), value);
  await tester.pump();
}

Future<void> _search(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(CupertinoSearchTextField), q);
  await tester.pump();
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 9000 * 3);
    view.devicePixelRatio = 3;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio(),
  );

  group('Emergency Drugs', () {
    testWidgets('newborn adrenaline at 3 kg: dose and volume of 1:10,000', (tester) async {
      await tester.pumpWidget(_app(const EmergencyDrugsTool()));
      await _search(tester, 'adrenaline');
      expect(find.text('0.01–0.03 mg/kg'), findsOneWidget, reason: 'per kg before the weight');
      await _type(tester, 'Weight', '3');
      expect(find.text('0.03–0.09 mg'), findsOneWidget);
      expect(find.text('0.3–0.9 mL of 0.1 mg/mL'), findsOneWidget);
      expect(find.textContaining('9 mL sodium chloride 0.9%'), findsWidgets);
    });

    testWidgets('PICU arrest dose caps at 1 mg for a big child', (tester) async {
      await tester.pumpWidget(_app(const EmergencyDrugsTool(initialCare: CareSetting.picu)));
      await _search(tester, 'adrenaline');
      await _type(tester, 'Weight', '120');
      expect(find.text('Max 1 mg per dose — reached at this weight'), findsOneWidget);
      expect(find.text('10 mL of 0.1 mg/mL'), findsOneWidget);
    });

    testWidgets('infusions show the standard syringe for the weight', (tester) async {
      await tester.pumpWidget(_app(const EmergencyDrugsTool()));
      await tester.tap(find.text('Infusions'));
      await tester.pump();
      await _search(tester, 'dopamine');
      await _type(tester, 'Weight', '1');
      expect(find.text('1 mL/h = 10 mcg/kg/min'), findsOneWidget);
      expect(find.text('Draw 0.75 mL of 40 mg/mL (30 mg), make up to 50 mL'), findsOneWidget);
    });

    testWidgets('table layout lists dose and volume', (tester) async {
      await tester.pumpWidget(_app(const EmergencyDrugsTool()));
      await tester.tap(find.text('Table'));
      await tester.pump();
      await _type(tester, 'Weight', '2');
      expect(find.text('Glucose 10%\nLow blood glucose'), findsOneWidget);
      expect(find.text('4 mL'), findsOneWidget);
    });

    testWidgets('PICU-only drugs stay out of the NICU list', (tester) async {
      await tester.pumpWidget(_app(const EmergencyDrugsTool()));
      await _search(tester, 'naloxone');
      expect(find.text('No drugs match.'), findsOneWidget);
    });
  });

  group('Infusion Rate with a drug', () {
    testWidgets('dopamine 1 kg: make-up, rate table, rate for a dose, 2× strength', (tester) async {
      await tester.pumpWidget(_app(const InfusionTool(drugKey: 'dopamine', care: CareSetting.nicu, weightKg: 1)));
      expect(find.text('Draw 0.75 mL of Dopamine 40 mg/mL (30 mg).'), findsOneWidget);
      expect(find.text('10 mcg/kg/min'), findsOneWidget);
      await _type(tester, 'Dose', '5');
      expect(find.text('0.5 mL/h'), findsWidgets);
      await tester.tap(find.text('2×'));
      await tester.pump();
      expect(find.text('Draw 1.5 mL of Dopamine 40 mg/mL (60 mg).'), findsOneWidget);
    });

    testWidgets('tiny insulin doses use the 1 unit/mL stock first', (tester) async {
      await tester.pumpWidget(_app(const InfusionTool(drugKey: 'insulin', care: CareSetting.nicu, weightKg: 1)));
      expect(find.textContaining('First: 1 mL (100 units) made up to 100 mL'), findsOneWidget);
      expect(find.text('Draw 2.5 mL of Insulin (soluble) 1 unit/mL (2.5 units).'), findsOneWidget);
    });

    testWidgets('warns when a rate is outside the usual range', (tester) async {
      await tester.pumpWidget(_app(const InfusionTool(drugKey: 'dopamine', care: CareSetting.nicu, weightKg: 1)));
      await _type(tester, 'Dose', '30');
      expect(find.text('Outside the usual 2–20 mcg/kg/min'), findsOneWidget);
    });
  });
}
