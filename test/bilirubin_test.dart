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

    test('refuses below 22 weeks, unknown gestation and negative age', () {
      expect(nice.assess(gestationWeeks: 21, hoursOfAge: 48, tsbUmol: 200),
          isA<BiliNotApplicable>());
      expect(nice.assess(gestationWeeks: null, hoursOfAge: 48, tsbUmol: 200),
          isA<BiliNotApplicable>());
      expect(nice.assess(gestationWeeks: 39, hoursOfAge: -1, tsbUmol: 200),
          isA<BiliNotApplicable>());
    });
  });

  group('NICE CG98 preterm graphs (22–37 weeks)', () {
    test('marked unverified until checked against the NICE graphs', () {
      expect(NiceCg98.pretermVerified, isFalse);
    });

    test('40 / 80 µmol/L at birth, rising to weeks×10 − 100 / weeks×10 at 72 h, then flat', () {
      final b = NiceCg98.pretermThresholdsAt(30, 0);
      expect([b.phototherapy, b.exchange], [40, 80]);
      final at72 = NiceCg98.pretermThresholdsAt(30, 72);
      expect([at72.phototherapy, at72.exchange], [200, 300]);
      final at36 = NiceCg98.pretermThresholdsAt(30, 36);
      expect([at36.phototherapy, at36.exchange], [120, 190]);
      expect(NiceCg98.pretermThresholdsAt(30, 200).phototherapy, 200);
      expect(NiceCg98.pretermThresholdsAt(23, 100).exchange, 230);
      expect(NiceCg98.pretermThresholdsAt(37, 100).phototherapy, 270);
    });

    test('thresholdsFor picks the preterm graph below 38 weeks, Table 1 from 38', () {
      expect(NiceCg98.thresholdsFor(21, 48), isNull);
      // NICE's spreadsheet draws graphs from 22 weeks (plateau 120 / 220).
      expect(NiceCg98.thresholdsFor(22, 72)!.phototherapy, 120);
      expect(NiceCg98.thresholdsFor(22, 72)!.exchange, 220);
      expect(NiceCg98.thresholdsFor(34, 72)!.phototherapy, 240);
      expect(NiceCg98.thresholdsFor(38, 48)!.phototherapy, 250);
    });

    test('actions for a 32-week baby at 48 h (photo 160, exchange 240)', () {
      expect(assess(48, 140, ga: 32).action, BiliAction.none);
      expect(assess(48, 160, ga: 32).action, BiliAction.none, reason: 'NICE uses >');
      expect(assess(48, 170, ga: 32).action, BiliAction.phototherapy);
      expect(assess(48, 250, ga: 32).action, BiliAction.exchange);
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
