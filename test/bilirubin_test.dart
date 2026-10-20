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

    test('refuses preterm, unknown gestation and negative age', () {
      expect(nice.assess(gestationWeeks: 36, hoursOfAge: 48, tsbUmol: 200),
          isA<BiliNotApplicable>());
      expect(nice.assess(gestationWeeks: null, hoursOfAge: 48, tsbUmol: 200),
          isA<BiliNotApplicable>());
      expect(nice.assess(gestationWeeks: 39, hoursOfAge: -1, tsbUmol: 200),
          isA<BiliNotApplicable>());
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
