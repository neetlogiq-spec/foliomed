import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/tools/neonatal_formulas.dart';

void main() {
  group('fluids', () {
    test('day of life counts the first 24 h as day 1', () {
      final born = DateTime(2026, 10, 20, 8);
      expect(dayOfLife(born, DateTime(2026, 10, 20, 20)), 1);
      expect(dayOfLife(born, DateTime(2026, 10, 21, 8)), 2);
      expect(dayOfLife(born, DateTime(2026, 10, 27, 9)), 8);
    });

    test('day-of-life table: +15 a day from 60 / 80, capped at 150', () {
      expect([for (var d = 1; d <= 8; d++) totalFluidPerKgDay(dayOfLife: d, under1500g: false)],
          [60, 75, 90, 105, 120, 135, 150, 150]);
      expect([for (var d = 1; d <= 7; d++) totalFluidPerKgDay(dayOfLife: d, under1500g: true)],
          [80, 95, 110, 125, 140, 150, 150]);
    });

    test('volumes and GIR', () {
      final v = fluidVolumes(60, 3.0);
      expect(v.perDay, 180);
      expect(v.perHour, 7.5);
      // 10% at 60 mL/kg/day = 4.17 mg/kg/min; at 144 mL/kg/day exactly 10.
      expect(gir(dextrosePercent: 10, mlPerKgDay: 60), closeTo(4.1667, 1e-4));
      expect(gir(dextrosePercent: 10, mlPerKgDay: 144), 10);
    });

    test('mixing 12.5% from 10% and 25%', () {
      final m = mixDextrose(targetPercent: 12.5, totalMl: 60, weakPercent: 10, strongPercent: 25)!;
      expect(m.strongMl, 10);
      expect(m.weakMl, 50);
      expect(mixDextrose(targetPercent: 30, totalMl: 60, weakPercent: 10, strongPercent: 25), isNull);
    });
  });

  group('age', () {
    test('PMA and corrected age for a 30+2 week baby', () {
      final r = correctedAge(
          gestationAtBirth: WeeksDays.of(30, 2), born: DateTime(2026, 1, 1), on: DateTime(2026, 1, 15));
      expect(r.chronologicalDays, 14);
      expect(r.pma.toString(), '32+2');
      expect(r.correctedDays, isNull); // not yet 40 weeks
      final later = correctedAge(
          gestationAtBirth: WeeksDays.of(30, 2), born: DateTime(2026, 1, 1), on: DateTime(2026, 4, 1));
      expect(later.chronologicalDays, 90);
      expect(later.correctedDays, 90 - (280 - 212));
    });

    test('term babies have no corrected age', () {
      final r = correctedAge(gestationAtBirth: WeeksDays.of(39, 0), born: DateTime(2026, 1, 1), on: DateTime(2026, 3, 1));
      expect(r.correctedDays, isNull);
    });
  });

  group('blood', () {
    test('double-volume exchange', () {
      expect(doubleVolumeExchangeMl(kg: 3, preterm: false), 510);
      expect(doubleVolumeExchangeMl(kg: 1.5, preterm: true), 300);
    });

    test('partial exchange for Hct 70 → 55 at 3 kg term', () {
      expect(partialExchangeMl(kg: 3, preterm: false, observedHct: 70), closeTo(54.64, 0.01));
      expect(partialExchangeMl(kg: 3, preterm: false, observedHct: 50), 0);
    });
  });

  group('lines and tubes', () {
    test('Shukla UAC/UVC at 2 kg', () {
      expect(uacHighCm(2), 15);
      expect(uvcCm(2), 8.5);
    });

    test('ETT size and depth', () {
      expect(ettSizeMm(0.8), 2.5);
      expect(ettSizeMm(1.6), 3.0);
      expect(ettSizeMm(3.2), 3.5);
      expect(ettDepthByWeightCm(1.5), 7.5);
      expect(ettDepthByGestationCm(28), 6.5);
      expect(ettDepthByGestationCm(39), 8.5);
      expect(ettDepthByGestationCm(20), isNull);
    });
  });

  group('infusions', () {
    test('dopamine 5 mcg/kg/min, 30 mg in 50 mL, 2 kg', () {
      // 30 mg/50 mL = 600 mcg/mL; 5×2×60 = 600 mcg/h → 1 mL/h.
      final rate = infusionRateMlPerHour(dose: 5, unit: DoseUnit.mcgPerKgMin, kg: 2, drugMg: 30, volumeMl: 50);
      expect(rate, closeTo(1.0, 1e-9));
      expect(doseFromRate(mlPerHour: 1, unit: DoseUnit.mcgPerKgMin, kg: 2, drugMg: 30, volumeMl: 50),
          closeTo(5.0, 1e-9));
    });

    test('units convert consistently', () {
      final perMin = infusionRateMlPerHour(dose: 1, unit: DoseUnit.mcgPerKgMin, kg: 1, drugMg: 1, volumeMl: 10);
      final perHour = infusionRateMlPerHour(dose: 60, unit: DoseUnit.mcgPerKgHour, kg: 1, drugMg: 1, volumeMl: 10);
      expect(perMin, closeTo(perHour, 1e-9));
      expect(infusionRateMlPerHour(dose: 0.06, unit: DoseUnit.mgPerKgHour, kg: 1, drugMg: 1, volumeMl: 10),
          closeTo(perHour, 1e-9));
    });
  });
}
