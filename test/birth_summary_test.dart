import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/birth_summary.dart';
import 'package:foliomed/models/patient.dart';

Patient _baby(Map<String, dynamic> extra) => Patient.fromRow({
      'name': 'Baby',
      'gender': 'Male',
      // 19/10/2026 10:19 pm local
      'born_at': DateTime(2026, 10, 19, 22, 19).toUtc().toIso8601String(),
      ...extra,
    });

void main() {
  test('reproduces the ward line exactly', () {
    final p = _baby({
      'gestation_weeks': 39, 'gestation_days': 2, 'size_for_dates': 'AGA',
      'delivery_mode': 'LSCS', 'delivery_indication': 'CPD', 'birth_weight_g': 3100,
    });
    expect(birthSummaryLine(p),
        'TERM/MALE/AGA/LSCS (CPD) on 19/10/2026 at 10:19pm with birth weight of 3.1kgs');
  });

  test('maturity bands follow WHO cut-offs', () {
    expect(Maturity.fromGestation(33), Maturity.preterm);
    expect(Maturity.fromGestation(34), Maturity.latePreterm);
    expect(Maturity.fromGestation(36), Maturity.latePreterm);
    expect(Maturity.fromGestation(37), Maturity.term);
    expect(Maturity.fromGestation(41), Maturity.term);
    expect(Maturity.fromGestation(42), Maturity.postTerm);
    expect(Maturity.fromGestation(null), isNull);
  });

  test('preterm shows gestation; missing parts are skipped', () {
    final p = _baby({'gestation_weeks': 32, 'gestation_days': 4, 'gender': 'Female',
        'delivery_mode': 'NVD', 'birth_weight_g': 1850});
    expect(birthSummaryLine(p),
        'PRETERM (32+4 wks)/FEMALE/NVD on 19/10/2026 at 10:19pm with birth weight of 1.85kgs');
    expect(birthSummaryLine(_baby({'gender': ''})), 'Born on 19/10/2026 at 10:19pm');
    expect(birthSummaryLine(Patient.fromRow({'name': 'Adult'})), isNull);
  });

  test('weights and APGAR format', () {
    expect(formatBirthWeightKg(3000), '3kgs');
    expect(formatBirthWeightKg(2850), '2.85kgs');
    expect(formatBirthWeightKg(3105), '3.1kgs'); // 2 dp, trailing zero dropped
    expect(apgarLabel(_baby({'apgar_1': 8, 'apgar_5': 9})), 'APGAR 8/9');
    expect(apgarLabel(_baby({})), isNull);
  });

  test('birth details round-trip through rows', () {
    final row = _baby({'birth_weight_g': 3100, 'size_for_dates': 'SGA', 'delivery_mode': 'Vacuum',
        'delivery_indication': '  ', 'mother_blood_group': 'O+', 'apgar_1': 7, 'apgar_5': 9,
        'resuscitated': true}).toRow();
    expect(row['birth_weight_g'], 3100);
    expect(row['size_for_dates'], 'SGA');
    expect(row['delivery_indication'], isNull, reason: 'blank indication not stored');
    expect(row['mother_blood_group'], 'O+');
    expect(row['resuscitated'], isTrue);
  });
}
