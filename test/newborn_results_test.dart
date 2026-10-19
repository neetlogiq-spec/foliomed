import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/newborn_screen.dart';
import 'package:foliomed/models/patient.dart';

void main() {
  test('indirect bilirubin is total minus direct, never negative', () {
    expect(const NewbornResults(tsbTotal: 12.4, tsbDirect: 0.6).tsbIndirect, closeTo(11.8, 1e-9));
    expect(const NewbornResults(tsbTotal: 1, tsbDirect: 2).tsbIndirect, 0);
    expect(const NewbornResults(tsbTotal: 12).tsbIndirect, isNull);
  });

  test('JSON round-trip keeps every field', () {
    final r = NewbornResults(
      sampledAt: DateTime.utc(2026, 10, 20, 6),
      hb: 16.2, tlc: 12.5, platelets: 210, hct: 48, tsh: 6.1,
      babyBloodGroup: 'B+', motherBloodGroup: 'O+',
      biliUnit: BiliUnit.umol, tsbTotal: 212, tsbDirect: 10,
      urea: 18, creatinine: 0.6, sodium: 138, potassium: 4.8, chloride: 104,
      oaeRight: OaeResult.pass, oaeLeft: OaeResult.refer, remarks: ' ok ',
    );
    final back = NewbornResults.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
    expect(back.oaeLeft, OaeResult.refer);
    expect(back.biliUnit, BiliUnit.umol);
    expect(back.remarks, 'ok');
  });

  test('empty results are recognised; summary reads like a ward note', () {
    expect(const NewbornResults().isEmpty, isTrue);
    final s = const NewbornResults(
      hb: 16.2, tsh: 6.1, babyBloodGroup: 'B+', motherBloodGroup: 'O+',
      tsbTotal: 12.4, tsbDirect: 0.6, creatinine: 0.6,
      oaeRight: OaeResult.pass, oaeLeft: OaeResult.refer,
    ).summary(biliAssessment: 'NICE CG98 at 50 h: Repeat bilirubin');
    expect(s, contains('CBC: Hb 16.2'));
    expect(s, contains('TSH 6.1 µIU/mL'));
    expect(s, contains('Blood group B+ (mother O+)'));
    expect(s, contains('TSB 12.4 / D 0.6 / I 11.8 mg/dL'));
    expect(s, contains('RFT: Cr 0.6'));
    expect(s, contains('OAE R Pass / L Refer'));
    expect(s, endsWith('NICE CG98 at 50 h: Repeat bilirubin'));
  });

  test('screen row parses status and results', () {
    final sc = NewbornScreen.fromRow({
      'id': 's1', 'patient_id': 'p1', 'ward_id': 'w', 'planned_hours': 72,
      'lead_hours': 8, 'due_at': '2026-10-21T06:00:00Z', 'status': 'resulted',
      'results': {'tsb_total': 12.4},
    });
    expect(sc.status, ScreenStatus.resulted);
    expect(sc.plannedHours, 72);
    expect(sc.results.tsbTotal, 12.4);
  });

  test('patient gestation round-trips and labels', () {
    final p = Patient.fromRow({'name': 'Baby', 'gestation_weeks': 39, 'gestation_days': 2});
    expect(p.gestationLabel, '39+2 wk');
    expect(p.toRow()['gestation_weeks'], 39);
    expect(p.toRow()['gestation_days'], 2);
    expect(Patient.fromRow({'name': 'A'}).toRow()['gestation_days'], isNull);
  });
}
