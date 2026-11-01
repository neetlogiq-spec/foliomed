import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/growth.dart';

void main() {
  setUpAll(() => WhoGrowth.loadJson(File('assets/clinical/who_growth.json').readAsStringSync()));

  group('WHO tables reproduce WHO’s printed SD lines', () {
    // From WHO's z-score tables (rounded to 0.1 as printed).
    test('weight-for-age', () {
      expect(WhoGrowth.valueAt(GrowthIndicator.weight, true, 0, 0), closeTo(3.3, 0.05));
      expect(WhoGrowth.valueAt(GrowthIndicator.weight, true, 0, 2), closeTo(4.4, 0.05));
      expect(WhoGrowth.valueAt(GrowthIndicator.weight, true, 60, -2), closeTo(14.1, 0.05));
      expect(WhoGrowth.valueAt(GrowthIndicator.weight, false, 60, 3), closeTo(29.5, 0.05));
    });
    test('length, height and head', () {
      expect(WhoGrowth.valueAt(GrowthIndicator.length, true, 0, 0), closeTo(49.9, 0.05));
      expect(WhoGrowth.valueAt(GrowthIndicator.length, true, 24, 0), closeTo(87.1, 0.05), reason: 'standing from 24 mo');
      expect(WhoGrowth.valueAt(GrowthIndicator.length, false, 60, -2), closeTo(99.9, 0.05));
      expect(WhoGrowth.valueAt(GrowthIndicator.head, true, 0, 0), closeTo(34.5, 0.05));
      expect(WhoGrowth.valueAt(GrowthIndicator.head, false, 60, 2), closeTo(52.8, 0.05));
    });
    test('5–19 years reference', () {
      expect(WhoGrowth.valueAt(GrowthIndicator.length, true, 228, 0), closeTo(176.543, 0.01));
      expect(WhoGrowth.valueAt(GrowthIndicator.bmi, false, 61, 1), closeTo(16.87, 0.01));
      expect(WhoGrowth.range(GrowthIndicator.weight, true), (0, 60));
      expect(WhoGrowth.range(GrowthIndicator.bmi, true), (61, 228));
    });
  });

  group('z-scores', () {
    test('round trip and interpolation between months', () {
      final v = WhoGrowth.valueAt(GrowthIndicator.weight, true, 7.5, -1.2)!;
      expect(WhoGrowth.zScore(GrowthIndicator.weight, true, 7.5, v), closeTo(-1.2, 1e-9));
      final a = WhoGrowth.valueAt(GrowthIndicator.head, false, 7, 0)!, b = WhoGrowth.valueAt(GrowthIndicator.head, false, 8, 0)!;
      expect(WhoGrowth.valueAt(GrowthIndicator.head, false, 7.5, 0), closeTo((a + b) / 2, 1e-9));
    });

    test('WHO restricted method beyond ±3 SD for weight', () {
      final sd3 = WhoGrowth.valueAt(GrowthIndicator.weight, true, 12, 3)!;
      final sd2 = WhoGrowth.valueAt(GrowthIndicator.weight, true, 12, 2)!;
      expect(WhoGrowth.zScore(GrowthIndicator.weight, true, 12, sd3 + (sd3 - sd2)), closeTo(4, 1e-9));
      final m3 = WhoGrowth.valueAt(GrowthIndicator.weight, true, 12, -3)!;
      final m2 = WhoGrowth.valueAt(GrowthIndicator.weight, true, 12, -2)!;
      expect(WhoGrowth.zScore(GrowthIndicator.weight, true, 12, m3 - (m2 - m3)), closeTo(-4, 1e-9));
    });

    test('outside the tables is null', () {
      expect(WhoGrowth.zScore(GrowthIndicator.weight, true, 61, 18), isNull);
      expect(WhoGrowth.zScore(GrowthIndicator.head, true, -1, 34), isNull);
    });
  });

  group('centiles and readings', () {
    test('normal CDF and wording', () {
      expect(normalCdf(0), closeTo(0.5, 1e-7));
      expect(normalCdf(-1.96), closeTo(0.025, 1e-4));
      expect(centileText(0), '50th centile');
      expect(centileText(-1.881), '3rd centile');
      expect(centileText(2.326), '99th centile');
      expect(centileText(-3.2), 'below the 0.1st centile');
      expect(centileText(-0.3), '38th centile');
    });
    test('WHO cut-offs', () {
      expect(growthReading(GrowthIndicator.weight, -2.5, 12), 'Underweight');
      expect(growthReading(GrowthIndicator.length, -3.2, 12), 'Severely stunted');
      expect(growthReading(GrowthIndicator.bmi, 1.5, 100), 'Overweight');
      expect(growthReading(GrowthIndicator.weight, 0, 12), isNull);
    });
  });

  test('corrected age for preterm babies until 24 months', () {
    final born = DateTime(2026, 1, 1);
    final r = plotAge(born: born, on: DateTime(2026, 7, 1), gestationWeeks: 30);
    expect(r.corrected, isTrue);
    expect(r.months, closeTo((181 - 70) / kDaysPerMonth, 0.01));
    expect(plotAge(born: born, on: DateTime(2026, 7, 1), gestationWeeks: 38).corrected, isFalse);
    expect(plotAge(born: born, on: DateTime(2028, 6, 1), gestationWeeks: 30).corrected, isFalse);
  });
}
