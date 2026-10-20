import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/bilirubin.dart';
import 'package:foliomed/clinical/handover.dart';
import 'package:foliomed/models/newborn_tracking.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/patient_reminder.dart';

final _now = DateTime(2026, 10, 21, 9);
final _born = _now.subtract(const Duration(hours: 50));

Patient _baby({String id = 'p1', String bed = '4', String? unit, int? birthG = 3100, int ga = 39}) =>
    Patient.fromRow({
      'id': id,
      'name': 'Baby of $id',
      'ward_id': 'PNC',
      'bed_number': bed,
      'unit_id': unit,
      'born_at': _born.toUtc().toIso8601String(),
      'gestation_weeks': ga,
      'birth_weight_g': birthG,
      'admitted_at': _born.toUtc().toIso8601String(),
    });

void main() {
  group('weight change', () {
    test('percent from birth weight with flags at 7% and 10%', () {
      expect(WeightChange(3100, 2950).label, '−4.8%');
      expect(WeightChange(3100, 2950).flag, WeightFlag.ok);
      expect(WeightChange(3100, 2860).flag, WeightFlag.watch); // −7.7%
      expect(WeightChange(3100, 2790).flag, WeightFlag.alert); // −10.0%
      expect(WeightChange(3100, 3200).label, '+3.2%');
    });
  });

  group('readings', () {
    test('mg/dL readings convert to µmol/L for the chart', () {
      final r = BilirubinReading.fromRow(
          {'id': 'r', 'patient_id': 'p1', 'measured_at': _now.toIso8601String(), 'value': 14.6, 'unit': 'mgdl', 'method': 'transcutaneous'});
      expect(r.umol, closeTo(mgdlToUmol(14.6), 1e-9));
      expect(r.transcutaneous, isTrue);
      expect(r.fromScreen, isFalse);
    });

    test('phototherapy kind and running duration', () {
      final s = PhototherapySession.fromRow({
        'id': 's', 'patient_id': 'p1', 'kind': 'double',
        'started_at': _now.subtract(const Duration(hours: 6)).toIso8601String(),
      });
      expect(s.kind, PhototherapyKind.double_);
      expect(s.kind.dbName, 'double');
      expect(s.isRunning, isTrue);
      expect(s.durationAt(_now).inHours, 6);
    });
  });

  group('handover', () {
    test('flags overdue reminders, bilirubin above NICE line and weight loss', () {
      final item = HandoverItem(
        patient: _baby(),
        unitName: 'Unit A',
        openReminders: [
          PatientReminder.fromRow({'id': 'r1', 'patient_id': 'p1', 'title': 'Send 48-hour newborn investigations',
              'due_at': _now.subtract(const Duration(hours: 2)).toIso8601String()}),
          PatientReminder.fromRow({'id': 'r2', 'patient_id': 'p1', 'title': 'Repeat TSB',
              'due_at': _now.add(const Duration(hours: 4)).toIso8601String()}),
        ],
        bilirubin: BilirubinReading.fromRow({'id': 'b', 'patient_id': 'p1', 'value': 16,
            'unit': 'mgdl', 'measured_at': _now.subtract(const Duration(hours: 1)).toIso8601String()}),
        weight: WeightEntry.fromRow({'id': 'w', 'patient_id': 'p1', 'grams': 2780,
            'measured_at': _now.toIso8601String()}),
      );
      final flags = item.flags(_now);
      expect(flags[0], startsWith('OVERDUE: Send 48-hour'));
      expect(flags[1], 'Bilirubin: Start phototherapy'); // 16 mg/dL ≈ 274 > 252 at 49 h
      expect(flags[2], 'Weight −10.3% from birth');
      final text = item.toText(_now);
      expect(text, startsWith('Bed 4 · Baby of p1 · '));
      expect(text.split('\n').first, endsWith(' · Unit A'));
      expect(text, contains('Pending: Repeat TSB'));
      expect(text, contains('(NICE CG98: Start phototherapy)'));
    });

    test('sorts by unit order, then bed numerically, then name', () {
      HandoverItem i(String id, String bed, String? unit) =>
          HandoverItem(patient: _baby(id: id, bed: bed, unit: unit), unitName: null, openReminders: const []);
      final items = [i('c', '10', 'uA'), i('a', '2', 'uB'), i('b', '9', 'uA'), i('d', '1', null)]
        ..sort((a, b) => compareHandover(a, b, ['uA', 'uB']));
      expect(items.map((x) => x.patient.id), ['b', 'c', 'a', 'd']);
    });
  });

  test('census counts admissions, discharges and births for the day', () {
    final day = DateTime(2026, 10, 19);
    final active = [_baby(id: 'a1')];
    final discharged = [
      Patient.fromRow({'id': 'd1', 'name': 'x', 'status': 'discharged',
          'admitted_at': DateTime(2026, 10, 18, 10).toUtc().toIso8601String(),
          'discharged_at': DateTime(2026, 10, 19, 16).toUtc().toIso8601String()}),
      Patient.fromRow({'id': 'd2', 'name': 'y', 'status': 'discharged',
          'admitted_at': DateTime(2026, 10, 19, 1).toUtc().toIso8601String(),
          'born_at': DateTime(2026, 10, 19, 0, 30).toUtc().toIso8601String(),
          'discharged_at': DateTime(2026, 10, 20, 9).toUtc().toIso8601String()}),
    ];
    final c = DayCensus.of(active: active, discharged: discharged, day: day);
    expect(c.current, 1);
    expect(c.admitted, 2); // a1 (born/admitted 19 Oct 07:00) + d2
    expect(c.discharged, 1);
    expect(c.born, 2);
  });
}
