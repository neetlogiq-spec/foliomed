import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/services/text_scan_service.dart';

void main() {
  group('Patient model', () {
    test('reads code, hospital id, age unit and discharge fields', () {
      final p = Patient.fromRow({
        'id': 'p1',
        'patient_code': 'FM000123',
        'hospital_id': '  IP-42 ',
        'name': 'Baby Anaya',
        'age': 12,
        'age_unit': 'days',
        'ward_id': '12345',
        'status': 'discharged',
        'discharged_at': '2026-10-19T10:00:00Z',
        'discharge_summary': 'Feeding well',
        'admitted_at': '2026-10-10T10:00:00Z',
      });
      expect(p.patientCode, 'FM000123');
      expect(p.hospitalId, 'IP-42');
      expect(p.ageUnit, AgeUnit.days);
      expect(p.ageLabel, '12 d');
      expect(p.isDischarged, isTrue);
      expect(p.isActive, isFalse);
      expect(p.dischargedAt, isNotNull);
      expect(p.dischargeSummary, 'Feeding well');
    });

    test('defaults: years, admitted, blank hospital id is null', () {
      final p = Patient.fromRow({'id': 'p1', 'name': 'Mr Rao', 'age': 61, 'hospital_id': ''});
      expect(p.ageUnit, AgeUnit.years);
      expect(p.ageLabel, '61 y');
      expect(p.status, PatientStatus.admitted);
      expect(p.hospitalId, isNull);
    });

    test('older rows without status fall back to is_active', () {
      expect(Patient.fromRow({'is_active': false}).isDischarged, isTrue);
      expect(Patient.fromRow({'is_active': true}).isActive, isTrue);
    });

    test('toRow never writes server-managed columns', () {
      final row = Patient.fromRow({
        'id': 'p1',
        'patient_code': 'FM000001',
        'name': 'X',
        'age': 5,
        'age_unit': 'months',
        'status': 'discharged',
      }).toRow();
      expect(row.containsKey('id'), isFalse);
      expect(row.containsKey('patient_code'), isFalse, reason: 'DB assigns it');
      expect(row.containsKey('status'), isFalse, reason: 'changed via RPCs');
      expect(row['age_unit'], 'months');
      expect(row['hospital_id'], isNull);
    });

    test('copyWith keeps identity and lifecycle fields', () {
      final p = Patient.fromRow({
        'id': 'p1',
        'patient_code': 'FM000009',
        'name': 'A',
        'status': 'discharged',
      });
      final edited = p.copyWith(name: 'B', ageUnit: AgeUnit.months);
      expect(edited.id, 'p1');
      expect(edited.patientCode, 'FM000009');
      expect(edited.isDischarged, isTrue);
      expect(edited.name, 'B');
      expect(edited.ageUnit, AgeUnit.months);
    });
  });

  group('cleanRecognizedText', () {
    test('trims lines and collapses blank runs to one paragraph break', () {
      expect(cleanRecognizedText('  Hb 9.8  \n\n\n  WBC 14.2\r\n'),
          'Hb 9.8\n\nWBC 14.2');
    });

    test('rejoins words hyphenated across a line break', () {
      expect(cleanRecognizedText('Para-\ncetamol 15 mg/kg'),
          'Paracetamol 15 mg/kg');
    });

    test('empty input stays empty', () {
      expect(cleanRecognizedText('\n  \n'), '');
    });
  });
}
