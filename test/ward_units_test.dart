import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/note.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/patient_reminder.dart';
import 'package:foliomed/models/ward_unit.dart';
import 'package:foliomed/utils/scope_filter.dart';

Patient _p(String id, String ward, String? unit) =>
    Patient.fromRow({'id': id, 'name': id, 'ward_id': ward, 'unit_id': unit});

Note _n(String patientId, String ward) => Note.fromRow(
    {'id': 'n$patientId', 'patient_id': patientId, 'ward_id': ward, 'content': 'x'});

void main() {
  final patients = [
    _p('a1', 'PNC', 'uA'),
    _p('a2', 'PNC', 'uA'),
    _p('b1', 'PNC', 'uB'),
    _p('x1', 'PNC', null),
    _p('n1', 'NICU', null),
  ];

  test('scope includes the right patients', () {
    bool inc(PatientScope s, Patient p) => s.includes(wardId: p.wardId, unitId: p.unitId);
    expect(patients.where((p) => inc(const PatientScope.all(), p)).length, 5);
    expect(patients.where((p) => inc(const PatientScope.ward('PNC'), p)).length, 4);
    expect(patients.where((p) => inc(const PatientScope.unit('PNC', 'uA'), p)).map((p) => p.id),
        ['a1', 'a2']);
    expect(patients.where((p) => inc(const PatientScope.unassigned('PNC'), p)).map((p) => p.id),
        ['x1']);
  });

  test('counts give total, per unit and unassigned', () {
    final c = UnitCounts.of(patients.where((p) => p.wardId == 'PNC').map((p) => p.unitId));
    expect(c.total, 4);
    expect(c.byUnit, {'uA': 2, 'uB': 1});
    expect(c.unassigned, 1);
  });

  test('scope round-trips through its stored form', () {
    for (final s in const [
      PatientScope.all(),
      PatientScope.ward('PNC'),
      PatientScope.unit('PNC', 'uA'),
      PatientScope.unassigned('PNC'),
    ]) {
      expect(PatientScope.decode(s.encode()), s);
    }
    expect(PatientScope.decode('garbage'), const PatientScope.all());
  });

  test('notes and reminders follow their patient into units', () {
    final f = ScopeFilter(const PatientScope.unit('PNC', 'uA'), patients);
    expect(f.note(_n('a1', 'PNC')), isTrue);
    expect(f.note(_n('b1', 'PNC')), isFalse);
    // Discharged patient (not in the admitted list): only ward scopes show it.
    expect(f.note(_n('gone', 'PNC')), isFalse);
    expect(ScopeFilter(const PatientScope.ward('PNC'), patients).note(_n('gone', 'PNC')), isTrue);
    expect(ScopeFilter(const PatientScope.ward('NICU'), patients).note(_n('a1', 'PNC')), isFalse);
    final r = PatientReminder.fromRow({'patient_id': 'b1', 'ward_id': 'PNC'});
    expect(ScopeFilter(const PatientScope.unit('PNC', 'uB'), patients).reminder(r), isTrue);
    expect(ScopeFilter(const PatientScope.unassigned('PNC'), patients).reminder(r), isFalse);
  });

  test('unit is read from rows but never written by toRow', () {
    final p = _p('a1', 'PNC', 'uA');
    expect(p.unitId, 'uA');
    expect(p.toRow().containsKey('unit_id'), isFalse, reason: 'moves go through the RPC');
  });
}
