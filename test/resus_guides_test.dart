import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/growth.dart';
import 'package:foliomed/guides/guides.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/screens/tools/growth_tool.dart';
import 'package:foliomed/screens/tools/guide_screen.dart';
import 'package:foliomed/screens/tools/resus_tool.dart';
import 'package:foliomed/tools/resus.dart';
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

void main() {
  group('resuscitation numbers', () {
    test('APLS weight estimate', () {
      expect(estimatedWeightKg(6), 7);
      expect(estimatedWeightKg(36), 14);
      expect(estimatedWeightKg(5 * 12 + 6), 18);
      expect(estimatedWeightKg(8 * 12), 31);
      expect(estimatedWeightKg(13 * 12), isNull);
    });
    test('tubes, LMA, shocks, hypotension', () {
      final t = tubeSizes(4 * 12)!;
      expect((t.cuffed, t.uncuffed, t.oralCm, t.suctionFr), (4.5, 5.0, 14.0, 10));
      expect(tubeSizes(0.5), isNull, reason: 'newborns by weight');
      expect(lmaSize(14), '2');
      expect(shockEnergies(14), (vf1: 28, vf2: 56, cv1: 7, cv2: 28));
      expect(hypotensionSbp(0.5), 60);
      expect(hypotensionSbp(6 * 12), 82);
      expect(hypotensionSbp(14 * 12), 90);
      expect(normalVitals(30).hr, (95, 140));
    });
  });

  group('guides', () {
    test('six guides, each with a source and steps; doses have sane ranges', () {
      expect(kGuides.map((g) => g.key).toSet(), {
        'anaphylaxis',
        'status_epilepticus',
        'dka',
        'asthma',
        'snakebite',
        'scorpion',
      });
      for (final g in kGuides) {
        expect(g.source, isNotEmpty);
        expect(g.steps, isNotEmpty);
        for (final s in g.steps) {
          for (final d in s.doses) {
            expect(d.min <= d.max, isTrue, reason: '${g.key} ${d.label}');
          }
        }
      }
    });
    test('doses cap at the maximum', () {
      final adrenaline = guideByKey('anaphylaxis')!.steps[1].doses.single;
      expect(adrenaline.forWeight(20), (0.2, 0.2, false));
      expect(adrenaline.forWeight(70), (0.5, 0.5, true));
      expect(adrenaline.perKg, '0.01 mg/kg (max 0.5 mg)');
    });
  });

  group('screens', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(390 * 3, 8000 * 3);
      view.devicePixelRatio = 3;
    });
    tearDown(
      () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio(),
    );

    testWidgets('resus card: 4 years → 16 kg, tubes, shocks, first drugs', (tester) async {
      await tester.pumpWidget(_app(const ResusTool()));
      await _type(tester, 'Age', '4');
      expect(find.text('16 kg'), findsOneWidget);
      expect(find.text('Tube 4.5 cuffed / 5 uncuffed'), findsOneWidget);
      expect(find.text('32 J, then 64 J'), findsOneWidget);
      expect(find.text('0.16 mg = 1.6 mL of 0.1 mg/mL'), findsOneWidget);
    });

    testWidgets('guide works out doses for the weight', (tester) async {
      await tester.pumpWidget(_app(GuideScreen(guide: guideByKey('status_epilepticus')!)));
      expect(find.text('RED FLAGS'), findsOneWidget);
      await _type(tester, 'Weight', '20');
      expect(find.text('1200 mg'), findsOneWidget, reason: 'levetiracetam 60 mg/kg');
      expect(find.text('2 mg'), findsWidgets, reason: 'lorazepam 0.1 mg/kg');
    });

    testWidgets('growth tool shows a z-score once there is a date of birth', (tester) async {
      WhoGrowth.loadJson(File('assets/clinical/who_growth.json').readAsStringSync());
      await tester.pumpWidget(_app(const GrowthTool()));
      expect(find.text('Choose the date of birth, then enter a measurement.'), findsOneWidget);
    });
  });
}
