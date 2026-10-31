import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/early_warning.dart';
import 'package:foliomed/clinical/patient_status.dart';
import 'package:foliomed/models/observation.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/ward.dart';

final _now = DateTime.utc(2026, 10, 28, 9);

Patient _p({int age = 40, AgeUnit unit = AgeUnit.years, DateTime? born}) => Patient(
    id: 'p', name: 'P', age: age, ageUnit: unit, gender: '', wardId: 'w', bedNumber: '1',
    diagnosis: '', admittedAt: _now, bornAt: born);

Observation _o({
  int? rr = 16,
  int? spo2 = 97,
  bool scale2 = false,
  bool? o2 = false,
  int? sbp = 120,
  int? hr = 80,
  Consciousness? c = Consciousness.alert,
  double? t = 37.0,
  Duration ago = const Duration(minutes: 10),
}) =>
    Observation(
        patientId: 'p', takenAt: _now.subtract(ago), respRate: rr, spo2: spo2, spo2Scale2: scale2,
        onOxygen: o2, systolicBp: sbp, heartRate: hr, consciousness: c, tempC: t);

void main() {
  group('NEWS2 parameter table (RCP 2017) — every boundary', () {
    test('respiration rate', () {
      expect([8, 9, 11, 12, 20, 21, 24, 25].map(news2RespRate), [3, 1, 1, 0, 0, 2, 2, 3]);
    });
    test('SpO2 scale 1', () {
      expect([91, 92, 93, 94, 95, 96].map(news2Spo2Scale1), [3, 2, 2, 1, 1, 0]);
    });
    test('SpO2 scale 2: 88–92 scores 0; above 92 scores only on oxygen', () {
      expect([83, 84, 85, 86, 87, 88, 92].map((s) => news2Spo2Scale2(s, onOxygen: true)), [3, 2, 2, 1, 1, 0, 0]);
      expect([93, 94, 95, 96, 97].map((s) => news2Spo2Scale2(s, onOxygen: true)), [1, 1, 2, 2, 3]);
      expect([93, 97, 100].map((s) => news2Spo2Scale2(s, onOxygen: false)), [0, 0, 0]);
    });
    test('air or oxygen', () {
      expect([news2Oxygen(false), news2Oxygen(true)], [0, 2]);
    });
    test('systolic BP', () {
      expect([90, 91, 100, 101, 110, 111, 219, 220].map(news2SystolicBp), [3, 2, 2, 1, 1, 0, 0, 3]);
    });
    test('pulse', () {
      expect([40, 41, 50, 51, 90, 91, 110, 111, 130, 131].map(news2Pulse), [3, 1, 1, 0, 0, 1, 1, 2, 2, 3]);
    });
    test('consciousness: alert 0, new confusion / V / P / U 3', () {
      expect(Consciousness.values.map(news2Consciousness), [0, 3, 3, 3, 3]);
    });
    test('temperature (one decimal place)', () {
      expect([35.0, 35.1, 36.0, 36.1, 38.0, 38.1, 39.0, 39.1].map(news2Temp), [3, 1, 1, 0, 0, 1, 1, 2]);
    });
  });

  group('NEWS2 aggregate and bands', () {
    test('normal observations score 0, low', () {
      final s = news2(_o());
      expect([s.total, s.band, s.complete], [0, EarlyWarningBand.low, true]);
    });
    test('a single 3 is low–medium even with a total under 5', () {
      final s = news2(_o(hr: 135));
      expect([s.total, s.band], [3, EarlyWarningBand.lowMedium]);
    });
    test('5–6 medium, 7+ high', () {
      expect(news2(_o(rr: 22, o2: true, hr: 95)).band, EarlyWarningBand.medium); // 2+2+1 = 5
      final high = news2(_o(rr: 26, spo2: 93, o2: true, t: 38.5)); // 3+2+2+1 = 8
      expect([high.total, high.band], [8, EarlyWarningBand.high]);
    });
    test('missing parameters make it incomplete and are named', () {
      final s = news2(_o(sbp: null, t: null));
      expect(s.complete, isFalse);
      expect(s.missing, ['Systolic BP', 'Temperature']);
      expect(s.label, 'NEWS2 0 (incomplete — Systolic BP, Temperature missing)');
    });
    test('scale 2 needs to know air or oxygen', () {
      expect(news2(_o(scale2: true, spo2: 95, o2: null)).missing, containsAll(['SpO₂', 'Air or oxygen']));
    });
  });

  group('Brighton PEWS', () {
    Observation p0(int? b, int? c, int? r, {bool extra = false}) => Observation(
        patientId: 'p', takenAt: _now, pewsBehaviour: b, pewsCardio: c, pewsResp: r, pewsExtra: extra);
    test('total and bands: 0–2 low, 3 low–medium, 4+ medium, any 3 high', () {
      expect(pews(p0(1, 0, 1)).band, EarlyWarningBand.low);
      expect(pews(p0(1, 1, 1)).band, EarlyWarningBand.lowMedium);
      expect(pews(p0(1, 1, 2)).band, EarlyWarningBand.medium);
      expect(pews(p0(0, 0, 3)).band, EarlyWarningBand.high);
    });
    test('nebulisers / vomiting adds 2', () {
      final s = pews(p0(1, 0, 0, extra: true));
      expect([s.total, s.band], [3, EarlyWarningBand.lowMedium]);
    });
    test('needs all three parts to be complete', () {
      expect(pews(p0(1, null, 0)).missing, ['Cardiovascular']);
    });
    test('chart descriptions: four per part', () {
      expect([kPewsBehaviour.length, kPewsCardio.length, kPewsResp.length], [4, 4, 4]);
    });
  });

  group('which score', () {
    test('NEWS2 from 16 years, PEWS from 28 days, none for newborns', () {
      expect(earlyWarningFor(_p(age: 16), _now), EarlyWarningKind.news2);
      expect(earlyWarningFor(_p(age: 15), _now), EarlyWarningKind.pews);
      expect(earlyWarningFor(_p(age: 3, unit: AgeUnit.months), _now), EarlyWarningKind.pews);
      expect(earlyWarningFor(_p(age: 20, unit: AgeUnit.days), _now), isNull);
      expect(earlyWarningFor(_p(born: _now.subtract(const Duration(days: 10))), _now), isNull);
      expect(earlyWarningFor(_p(born: _now.subtract(const Duration(days: 40))), _now), EarlyWarningKind.pews);
    });
  });

  group('status dot from observations', () {
    PatientStatusResult st(Patient p, Observation? o, WardKind k) =>
        patientStatus(StatusInputs(patient: p, wardKind: k, now: _now, latestObservation: o));

    test('adult ward: NEWS2 medium/high red, single 3 amber, low green', () {
      expect(st(_p(), _o(rr: 22, o2: true, hr: 95), WardKind.adult).level, StatusLevel.act);
      expect(st(_p(), _o(hr: 135), WardKind.adult).level, StatusLevel.watch);
      final low = st(_p(), _o(), WardKind.adult);
      expect(low.level, StatusLevel.ok);
      expect(low.reasons.single.text, 'NEWS2 0 · Low');
    });
    test('paeds ward: PEWS', () {
      final o = Observation(patientId: 'p', takenAt: _now, pewsBehaviour: 1, pewsCardio: 1, pewsResp: 2);
      expect(st(_p(age: 6), o, WardKind.paeds).level, StatusLevel.act);
    });
    test('observations older than 12 h no longer colour the dot', () {
      final s = st(_p(), _o(hr: 140, ago: const Duration(hours: 13)), WardKind.adult);
      expect(s.level, StatusLevel.unknown);
      expect(s.reasons.single.text, 'No observations in 12 h');
    });
    test('an incomplete score can still raise the colour', () {
      expect(st(_p(), _o(rr: 28, o2: true, sbp: null, t: null), WardKind.adult).level, StatusLevel.act);
    });
    test('not on PICU / NICU / PNC', () {
      for (final k in [WardKind.picu, WardKind.nicu, WardKind.pnc]) {
        expect(st(_p(), _o(rr: 28, o2: true), k).reasons, isEmpty, reason: k.name);
      }
    });
  });
}
