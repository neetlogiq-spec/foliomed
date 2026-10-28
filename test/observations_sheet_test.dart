import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/early_warning.dart';
import 'package:foliomed/models/observation.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/widgets/observations_section.dart';

void main() {
  final adult = Patient(
      id: 'p', name: 'A', age: 52, gender: '', wardId: 'w', bedNumber: '1', diagnosis: '',
      admittedAt: DateTime(2026, 10, 28));

  // The test font draws every glyph as a full-width square, so give the
  // sheet a wide, tall surface (800 × 1800 logical).
  void bigView(WidgetTester t) {
    t.view.physicalSize = const Size(2400, 5400);
    addTearDown(t.view.resetPhysicalSize);
  }

  Finder field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first, matching: find.byType(TextField));

  testWidgets('NEWS2 updates as you type; out-of-range values block Save', (t) async {
    bigView(t);
    Observation? saved;
    var popped = false;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              saved = await Navigator.of(context).push<Observation>(MaterialPageRoute(
                  builder: (_) => Scaffold(body: ObservationSheet(patient: adult, kind: EarlyWarningKind.news2))));
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('NEWS2 — enter observations'), findsOneWidget);
    final save = find.widgetWithText(CupertinoButton, 'Save');
    expect(t.widget<CupertinoButton>(save).onPressed, isNull, reason: 'nothing entered yet');

    await t.enterText(field('Heart rate'), '400');
    await t.pump();
    expect(t.widget<CupertinoButton>(save).onPressed, isNull);
    expect(find.text('Heart rate should be 0–300.'), findsOneWidget);

    await t.enterText(field('Heart rate'), '135');
    await t.pump();
    expect(find.textContaining('NEWS2 3 (incomplete'), findsOneWidget);

    await t.tap(save);
    await t.pumpAndSettle();
    expect(popped, isTrue);
    expect(saved?.heartRate, 135);
    expect(saved?.patientId, 'p');
  });

  testWidgets('PEWS asks for the three parts', (t) async {
    final child = Patient(
        id: 'c', name: 'C', age: 6, gender: '', wardId: 'w', bedNumber: '2', diagnosis: '',
        admittedAt: DateTime(2026, 10, 28));
    bigView(t);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ObservationSheet(patient: child, kind: EarlyWarningKind.pews))));
    expect(find.text('Behaviour'), findsOneWidget);
    expect(find.text('Cardiovascular'), findsOneWidget);
    expect(find.text('Respiratory'), findsOneWidget);
    expect(find.text('VITAL SIGNS (RECORDED, NOT SCORED)'), findsOneWidget);
  });
}
