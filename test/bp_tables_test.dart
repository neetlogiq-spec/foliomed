import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/tools/bp_aap2017.dart';
import 'package:foliomed/tools/bp_zubrow.dart';

void main() {
  group('AAP 2017 tables (Flynn, Tables 4–5)', () {
    test('shape: 17 ages, 7 rising heights, 50th < 90th < 95th everywhere', () {
      for (final table in [kAapBpBoys, kAapBpGirls]) {
        expect(table.map((r) => r.years), List.generate(17, (i) => i + 1));
        for (final r in table) {
          expect(r.heightsCm.length, 7);
          for (var i = 1; i < 7; i++) {
            expect(r.heightsCm[i], greaterThan(r.heightsCm[i - 1]));
          }
          for (final rows in [r.sbp, r.dbp]) {
            for (var c = 0; c < 7; c++) {
              expect(rows[0][c] < rows[1][c] && rows[1][c] < rows[2][c], isTrue, reason: '${r.years} y col $c');
            }
          }
        }
      }
    });

    test('anchor cells match the published tables', () {
      AapBpLevels at(bool male, int y, double h) => aapBpLevels(male: male, years: y, heightCm: h)!;
      final b1 = at(true, 1, 77.2);
      expect((b1.heightCentile, b1.sbp, b1.dbp), (5, (85, 98, 102), (40, 52, 54)));
      final b17 = at(true, 17, 187.5);
      expect((b17.heightCentile, b17.sbp, b17.dbp), (95, (118, 134, 138), (70, 83, 87)));
      expect(b17.sbpStage2, 150);
      final g10 = at(false, 10, 141);
      expect((g10.heightCentile, g10.sbp, g10.dbp), (50, (99, 112, 116), (60, 73, 76)));
      final g17 = at(false, 17, 152.4);
      expect((g17.sbp, g17.dbp, g17.dbpStage2), ((107, 120, 125), (64, 76, 80), 92));
      final b13 = at(true, 13, 147);
      expect(b13.dbp, (61, 74, 78));
    });

    test('nearest height column; ends clamp; outside 1–17 years is null', () {
      expect(aapBpLevels(male: true, years: 6, heightCm: 117)!.heightCentile, 25);
      expect(aapBpLevels(male: true, years: 6, heightCm: 100)!.heightCentile, 5);
      expect(aapBpLevels(male: true, years: 6, heightCm: 200)!.heightCentile, 95);
      expect(aapBpLevels(male: true, years: 0, heightCm: 70), isNull);
      expect(aapBpLevels(male: false, years: 18, heightCm: 160), isNull);
    });
  });

  group('AAP 2017 staging (Table 3)', () {
    // Boy, 6 y, 50th height: SBP 95/107/111 (+12 = 123), DBP 56/68/71 (+12 = 83).
    final six = aapBpLevels(male: true, years: 6, heightCm: 118.9)!;
    AapBpCategory? c(AapBpLevels l, int? s, int? d) => aapBpCategory(l, sbp: s, dbp: d);

    test('under 13 years uses the centiles', () {
      expect(c(six, 106, 60), AapBpCategory.normal);
      expect(c(six, 107, 60), AapBpCategory.elevated);
      expect(c(six, 111, 60), AapBpCategory.stage1);
      expect(c(six, 123, 60), AapBpCategory.stage2);
      expect(c(six, 100, 71), AapBpCategory.stage1);
      expect(c(six, 100, 83), AapBpCategory.stage2);
      expect(c(six, null, null), isNull);
    });

    test('under 13 years, 120/80 caps the thresholds when lower', () {
      // Boy, 12 y, 95th height: SBP 90th is 122, so 120 is already elevated.
      final tall12 = aapBpLevels(male: true, years: 12, heightCm: 165.5)!;
      expect(c(tall12, 120, 60), AapBpCategory.elevated);
      expect(c(tall12, 128, 60), AapBpCategory.stage1);
    });

    test('13 years and over use adult cut-offs', () {
      final teen = aapBpLevels(male: false, years: 14, heightCm: 161.3)!;
      expect(c(teen, 119, 79), AapBpCategory.normal);
      expect(c(teen, 125, 70), AapBpCategory.elevated);
      expect(c(teen, 125, 80), AapBpCategory.stage1);
      expect(c(teen, 119, 89), AapBpCategory.stage1);
      expect(c(teen, 140, 70), AapBpCategory.stage2);
      expect(c(teen, 110, 90), AapBpCategory.stage2);
    });
  });

  group('Zubrow 1995 (EPIQ Tables 1–2)', () {
    test('rows cover 22–42 (day 1) and 24–46 weeks (post-conceptional)', () {
      expect(kZubrowDay1.map((r) => r.weeks), List.generate(21, (i) => i + 22));
      expect(kZubrowByPca.map((r) => r.weeks), List.generate(23, (i) => i + 24));
    });

    test('anchor cells match the published tables', () {
      final d30 = zubrowRowFor(kZubrowDay1, 30.9)!;
      expect((d30.weeks, d30.sbp, d30.dbp, d30.map), (30, (35, 50, 66), (22, 31, 39), (26, 37, 48)));
      expect(zubrowRowFor(kZubrowDay1, 22)!.sbp, (22, 39, 55));
      expect(zubrowRowFor(kZubrowDay1, 42)!.dbp, (34, 43, 51));
      final p46 = zubrowRowFor(kZubrowByPca, 46)!;
      expect((p46.sbp, p46.dbp, p46.map), ((71, 89, 102), (36, 51, 66), (48, 64, 78)));
      expect(zubrowRowFor(kZubrowByPca, 24)!.map, (20, 36, 53));
    });

    test('mean is (systolic + 2 × diastolic) / 3 within 1 mmHg', () {
      for (final r in [...kZubrowDay1, ...kZubrowByPca]) {
        for (final (s, d, m) in [
          (r.sbp.$1, r.dbp.$1, r.map.$1),
          (r.sbp.$2, r.dbp.$2, r.map.$2),
          (r.sbp.$3, r.dbp.$3, r.map.$3),
        ]) {
          expect(((s + 2 * d) / 3 - m).abs(), lessThanOrEqualTo(1), reason: '${r.weeks} wk');
        }
      }
    });

    test('outside the table is null; bands', () {
      expect(zubrowRowFor(kZubrowDay1, 21.9), isNull);
      expect(zubrowRowFor(kZubrowByPca, 47), isNull);
      expect(zubrowBand(34, (35, 50, 66)), ZubrowBand.low);
      expect(zubrowBand(35, (35, 50, 66)), ZubrowBand.normal);
      expect(zubrowBand(66, (35, 50, 66)), ZubrowBand.normal);
      expect(zubrowBand(67, (35, 50, 66)), ZubrowBand.high);
    });
  });
}
