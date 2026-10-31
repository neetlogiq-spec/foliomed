import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/patient_status.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/screens/patients/patient_board.dart';
import 'package:foliomed/widgets/patient_row.dart';
import 'package:foliomed/widgets/status_dot.dart';

void main() {
  final patient = Patient(
      id: 'p', name: 'Asha', age: 6, gender: 'Female', wardId: 'w', bedNumber: '4',
      diagnosis: 'Bronchiolitis', admittedAt: DateTime(2026, 10, 27));

  Future<void> pump(WidgetTester t, Widget child) =>
      t.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [child]))));

  testWidgets('row shows the dot and reads the status out first', (t) async {
    final s = PatientSignals.none.withStatus(const PatientStatusResult(StatusLevel.act, [
      StatusReason(StatusLevel.act, 'Marked Sick — on HFNC'),
      StatusReason(StatusLevel.act, 'Weight −10.5% from birth', StatusTopic.weight),
    ]));
    final handle = t.ensureSemantics();
    await pump(t, PatientRow(patient: patient, signals: s));
    expect(find.byType(StatusDot), findsOneWidget);
    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp(r'^Needs action: Marked Sick — on HFNC, Weight −10.5% from birth\. Bed 4\. Asha')),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('no dot without a status (e.g. discharged list)', (t) async {
    await pump(t, PatientRow(patient: patient));
    expect(find.byType(StatusDot), findsNothing);
  });

  testWidgets('a status due for review is drawn faded', (t) async {
    await pump(t, const StatusDot(status: PatientStatusResult(StatusLevel.ok, [], needsReview: true)));
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);
    await pump(t, const StatusLegend());
    expect(find.text('Needs action'), findsOneWidget);
    expect(find.text('No status'), findsOneWidget);
  });
}
