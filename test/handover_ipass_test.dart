import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/handover.dart';
import 'package:foliomed/clinical/patient_status.dart';
import 'package:foliomed/models/handover_session.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/patient_reminder.dart';
import 'package:foliomed/models/ward_job.dart';
import 'package:foliomed/widgets/handover_card.dart';

final _now = DateTime(2026, 10, 30, 8);

Patient _p(String id, String bed, {String diagnosis = '', String? summary}) => Patient(
    id: id, name: 'Child $id', age: 4, gender: 'Male', wardId: 'w', bedNumber: bed,
    diagnosis: diagnosis, admittedAt: _now, handoverSummary: summary);

PatientStatusResult _st(StatusLevel l, [List<StatusReason> r = const []]) => PatientStatusResult(l, r);

void main() {
  final ifThen = Contingency(
      id: 'c', patientId: 'a', ifText: 'SpO₂ below 92%', thenText: 'call the registrar', createdAt: _now);

  test('summary: hand-kept, else diagnosis', () {
    expect(HandoverItem(patient: _p('a', '1', diagnosis: 'Bronchiolitis', summary: ' Day 2, HFNC '),
            unitName: null, openReminders: const []).summary,
        'Day 2, HFNC');
    expect(HandoverItem(patient: _p('a', '1', diagnosis: 'Bronchiolitis'), unitName: null, openReminders: const []).summary,
        'Bronchiolitis');
    expect(HandoverItem(patient: _p('a', '1'), unitName: null, openReminders: const []).summary, isNull);
  });

  test('action list: overdue and urgent first, assignee shown', () {
    final item = HandoverItem(
      patient: _p('a', '1'),
      unitName: null,
      openReminders: [
        PatientReminder(id: 'r1', patientId: 'a', wardId: 'w', title: 'Repeat gas', dueAt: _now.add(const Duration(hours: 2)), createdAt: _now),
        PatientReminder(id: 'r2', patientId: 'a', wardId: 'w', title: 'Chase CRP', dueAt: _now.subtract(const Duration(hours: 1)), createdAt: _now),
      ],
      openJobs: [
        WardJob(id: 'j1', wardId: 'w', patientId: 'a', title: 'Cannula', createdAt: _now),
        WardJob(id: 'j2', wardId: 'w', patientId: 'a', title: 'Blood culture', urgent: true, assignedName: 'Dr B', createdAt: _now),
      ],
    );
    expect(item.actions(_now), [
      'OVERDUE: Chase CRP',
      'URGENT job: Blood culture (Dr B)',
      'Pending: Repeat gas',
      'Job: Cannula',
    ]);
  });

  test('shared text follows I-PASS', () {
    final item = HandoverItem(
      patient: _p('a', '4', summary: 'Day 2 bronchiolitis on HFNC'),
      unitName: 'Unit A',
      openReminders: const [],
      status: _st(StatusLevel.act, const [StatusReason(StatusLevel.act, 'Marked Sick — desaturating')]),
      openJobs: [WardJob(id: 'j', wardId: 'w', patientId: 'a', title: 'Gas at 6 pm', createdAt: _now)],
      contingencies: [ifThen],
    );
    expect(item.toText(_now).split('\n'), [
      'Bed 4 · Child a · 4 y · Unit A',
      'I: Needs action — Marked Sick — desaturating',
      'P: Day 2 bronchiolitis on HFNC',
      'A: Job: Gas at 6 pm',
      'S: If SpO₂ below 92% → call the registrar',
    ]);
    final all = handoverText([item], 'Paeds', _now);
    expect(all, startsWith('Handover — Paeds — 30 Oct, 8:00 AM — 1 patient, 1 need action'));
  });

  test('sickest first: red, amber, then bed order', () {
    HandoverItem i(String id, String bed, StatusLevel? l) => HandoverItem(
        patient: _p(id, bed), unitName: null, openReminders: const [], status: l == null ? null : _st(l));
    final items = [i('a', '1', StatusLevel.ok), i('b', '2', StatusLevel.act), i('c', '3', StatusLevel.watch), i('d', '4', null)];
    items.sort((x, y) => compareHandover(x, y, const [], sickestFirst: true));
    expect(items.map((x) => x.patient.id), ['b', 'c', 'a', 'd']);
    items.sort((x, y) => compareHandover(x, y, const []));
    expect(items.map((x) => x.patient.id), ['a', 'b', 'c', 'd']);
  });

  test('session rows map', () {
    final s = HandoverSession.fromRow({'id': 'h', 'ward_id': 'w', 'scope_label': 'Paeds', 'given_by_name': 'Dr A',
        'started_at': _now.toUtc().toIso8601String()});
    expect([s.isOpen, s.scopeLabel], [true, 'Paeds']);
    final e = HandoverEntry.fromRow({'id': 'e', 'handover_id': 'h', 'patient_id': 'a', 'patient_name': 'A',
        'bed_number': '2', 'position': 1, 'received_at': _now.toUtc().toIso8601String(), 'question': 'Gas?'});
    expect([e.received, e.question], [true, 'Gas?']);
  });

  testWidgets('card shows the I-PASS parts and the footer', (t) async {
    t.view.physicalSize = const Size(2400, 4000);
    addTearDown(t.view.resetPhysicalSize);
    final item = HandoverItem(
      patient: _p('a', '4', summary: 'Day 2 bronchiolitis'),
      unitName: null,
      openReminders: const [],
      status: _st(StatusLevel.watch, const [StatusReason(StatusLevel.watch, 'NEWS2 3')]),
      contingencies: [ifThen],
    );
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: HandoverCard(item: item, now: _now, footer: const Text('receive here')))));
    for (final s in ['I', 'P', 'A', 'S', 'Watch — NEWS2 3', 'Day 2 bronchiolitis', 'No open jobs or reminders',
        'If SpO₂ below 92% → call the registrar', 'receive here']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });
}
