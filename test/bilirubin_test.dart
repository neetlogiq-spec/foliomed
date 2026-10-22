import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/bilirubin.dart';

void main() {
  const nice = NiceCg98();

  BiliAssessment assess(double hours, double umol, {int ga = 39}) =>
      nice.assess(gestationWeeks: ga, hoursOfAge: hours, tsbUmol: umol)
          as BiliAssessment;

  group('NICE CG98 table (≥38 weeks)', () {
    test('exact table rows', () {
      final at48 = NiceCg98.thresholdsAt(48);
      expect([at48.repeat, at48.considerPhototherapy, at48.phototherapy, at48.exchange],
          [150, 200, 250, 450]);
      final at24 = NiceCg98.thresholdsAt(24);
      expect([at24.phototherapy, at24.exchange], [200, 300]);
      final at72 = NiceCg98.thresholdsAt(72);
      expect([at72.phototherapy, at72.exchange], [300, 450]);
    });

    test('interpolates between 6-hour steps and is flat from 96 h', () {
      expect(NiceCg98.thresholdsAt(51).phototherapy, closeTo(256, 0.01));
      expect(NiceCg98.thresholdsAt(96).phototherapy, 350);
      expect(NiceCg98.thresholdsAt(200).phototherapy, 350);
      expect(NiceCg98.thresholdsAt(200).exchange, 450);
    });

    test('actions at 48 h', () {
      expect(assess(48, 140).action, BiliAction.none);
      expect(assess(48, 160).action, BiliAction.repeat);
      expect(assess(48, 210).action, BiliAction.considerPhototherapy);
      expect(assess(48, 260).action, BiliAction.phototherapy);
      expect(assess(48, 460).action, BiliAction.exchange);
    });

    test('at the threshold value itself is not "above" (NICE uses >)', () {
      expect(assess(48, 250).action, BiliAction.considerPhototherapy);
    });

    test('mg/dL conversion: 14.6 mg/dL at 48 h ≈ 250 µmol/L', () {
      expect(mgdlToUmol(14.6), closeTo(249.7, 0.1));
      expect(umolToMgdl(342), closeTo(20, 0.01));
    });

    test('refuses under 22 weeks, unknown gestation and negative age', () {
      expect(nice.assess(gestationWeeks: 21, hoursOfAge: 48, tsbUmol: 100),
          isA<BiliNotApplicable>());
      expect(nice.assess(gestationWeeks: null, hoursOfAge: 48, tsbUmol: 200),
          isA<BiliNotApplicable>());
      expect(nice.assess(gestationWeeks: 39, hoursOfAge: -1, tsbUmol: 200),
          isA<BiliNotApplicable>());
    });
  });

  group('NICE CG98 graphs (22–37 weeks)', () {
    // Values from the data sheet formulas of NICE's "Treatment threshold
    // graphs" spreadsheet: 40 → weeks×10−100 and 80 → weeks×10 over 72 h.
    test('lines start at 40 / 80 µmol/L at birth', () {
      final t = NiceCg98.pretermAt(30, 0);
      expect(t.phototherapy, 40);
      expect(t.exchange, 80);
    });

    test('plateau from 72 h at weeks×10−100 and weeks×10', () {
      for (final h in [72.0, 100.0, 336.0]) {
        expect(NiceCg98.pretermAt(30, h).phototherapy, 200);
        expect(NiceCg98.pretermAt(30, h).exchange, 300);
      }
      expect(NiceCg98.pretermAt(22, 96).phototherapy, 120);
      expect(NiceCg98.pretermAt(37, 96).exchange, 370);
    });

    test('rises in a straight line (spreadsheet 6-hour steps)', () {
      // 32 weeks: phototherapy step (220−40)/12 = 15 per 6 h; exchange (320−80)/12 = 20.
      expect(NiceCg98.pretermAt(32, 6).phototherapy, closeTo(55, 1e-9));
      expect(NiceCg98.pretermAt(32, 36).phototherapy, closeTo(130, 1e-9));
      expect(NiceCg98.pretermAt(32, 36).exchange, closeTo(200, 1e-9));
    });

    test('assess uses the preterm graph and has no repeat/consider band', () {
      final a = nice.assess(gestationWeeks: 30, hoursOfAge: 72, tsbUmol: 210) as BiliAssessment;
      expect(a.action, BiliAction.phototherapy);
      expect(a.thresholds.repeat, isNull);
      final b = nice.assess(gestationWeeks: 30, hoursOfAge: 72, tsbUmol: 190) as BiliAssessment;
      expect(b.action, BiliAction.none);
      final c = nice.assess(gestationWeeks: 30, hoursOfAge: 72, tsbUmol: 301) as BiliAssessment;
      expect(c.action, BiliAction.exchange);
    });
  });

  test('AAP 2022 reports itself unavailable until its data is loaded', () {
    // (The AAP group below loads it.) Before loading, never guess.
    if (!Aap2022.isLoaded) {
      expect(const Aap2022().assess(gestationWeeks: 39, hoursOfAge: 48, tsbUmol: 200, neuroRisk: false),
          isA<BiliNotApplicable>());
    }
  });
}
