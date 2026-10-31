import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/screens/tools/exchange_tool.dart';
import 'package:foliomed/screens/tools/fluids_tool.dart';
import 'package:foliomed/screens/tools/infusion_tool.dart';
import 'package:foliomed/screens/tools/lines_tool.dart';
import 'package:foliomed/screens/tools/tools_screen.dart';
import 'package:provider/provider.dart';

Widget _app(Widget child) => ChangeNotifierProvider(
      create: (_) => AppearanceProvider(),
      child: MaterialApp(home: child),
    );

/// Types into the input row whose label is [label].
Future<void> _type(WidgetTester tester, String label, String value) async {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
  await tester.enterText(find.descendant(of: row, matching: find.byType(TextField)), value);
  await tester.pump();
}

void main() {
  // A tall phone-width screen, so every row is built without scrolling.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 2400 * 3);
    view.devicePixelRatio = 3;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
    ..resetPhysicalSize()
    ..resetDevicePixelRatio());

  testWidgets('Tools hub lists the tools and searches them', (tester) async {
    await tester.pumpWidget(_app(const ToolsScreen()));
    expect(find.text('Fluids & Glucose'), findsOneWidget);
    expect(find.text('Infusion Rate'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'uvc');
    await tester.pump();
    expect(find.text('Lines & Tubes'), findsOneWidget);
    expect(find.text('Fluids & Glucose'), findsNothing);
  });

  testWidgets('Fluids: day 1, 3 kg, 10% → 7.5 mL/h, GIR 4.2', (tester) async {
    await tester.pumpWidget(_app(const FluidsTool()));
    expect(find.textContaining('Not yet checked by your unit'), findsOneWidget);
    await _type(tester, 'Weight', '3');
    await _type(tester, 'Day of life', '1');
    expect(find.text('7.5 mL/h'), findsOneWidget);
    expect(find.text('180 mL'), findsOneWidget);
    expect(find.text('4.2 mg/kg/min'), findsOneWidget);
    // Default mix: 12.5% in 50 mL from 10% and 25%.
    expect(find.text('8.3 mL'), findsOneWidget);
  });

  testWidgets('Exchange: 3 kg term → 510 mL', (tester) async {
    await tester.pumpWidget(_app(const ExchangeTool()));
    await _type(tester, 'Weight', '3');
    expect(find.text('510 mL'), findsOneWidget);
  });

  testWidgets('Lines: 2 kg → UVC 8.5 cm, UAC 15 cm, ETT 3 mm', (tester) async {
    await tester.pumpWidget(_app(const LinesTool()));
    await _type(tester, 'Weight', '2');
    expect(find.text('8.5 cm'), findsOneWidget);
    expect(find.text('15 cm'), findsOneWidget);
    expect(find.text('3 mm'), findsOneWidget);
  });

  testWidgets('Infusion: 5 mcg/kg/min, 30 mg in 50 mL, 2 kg → 1 mL/h', (tester) async {
    await tester.pumpWidget(_app(const InfusionTool()));
    await _type(tester, 'Weight', '2');
    await _type(tester, 'Amount', '30');
    await _type(tester, 'Dose', '5');
    expect(find.text('1 mL/h'), findsOneWidget);
  });
}
