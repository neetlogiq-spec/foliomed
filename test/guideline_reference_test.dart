// Regression tests pinning FolioMed's threshold data to published values.
//
// NICE: CG98 threshold table (babies ≥38 weeks), transcribed from the
//   guideline PDF (µmol/L; null = blank cell).
// AAP: 120 anchor values (35 to ≥40 weeks, with/without neurotoxicity risk
//   factors, 24–120 h) from the PediTools-derived AAP 2022 table published
//   at pabau.com/templates/infant-bilirubin-chart (mg/dL).
// If a guideline is updated, update these together with the data and say
// so in the commit.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/bilirubin.dart';

const _nice = <int, List<double?>>{
  // hours: repeat 6–12 h, consider phototherapy, start phototherapy, exchange
  0: [null, null, 100, 100],
  6: [100, 112, 125, 150],
  12: [100, 125, 150, 200],
  18: [100, 137, 175, 250],
  24: [100, 150, 200, 300],
  30: [112, 162, 212, 350],
  36: [125, 175, 225, 400],
  42: [137, 187, 237, 450],
  48: [150, 200, 250, 450],
  54: [162, 212, 262, 450],
  60: [175, 225, 275, 450],
  66: [187, 237, 287, 450],
  72: [200, 250, 300, 450],
  78: [null, 262, 312, 450],
  84: [null, 275, 325, 450],
  90: [null, 287, 337, 450],
  96: [null, 300, 350, 450],
};

/// gestation (40 = ≥40), risk factors, hour → (phototherapy, exchange) mg/dL
const _aap = '''
35 n 24 10.6 17.9|35 n 48 14.2 20.7|35 n 72 16.8 22.9|35 n 96 18.6 24.5|35 n 120 18.7 24.7
36 n 24 11.2 19.1|36 n 48 14.8 21.9|36 n 72 17.5 24.1|36 n 96 19.3 25.5|36 n 120 19.4 25.7
37 n 24 11.7 20.3|37 n 48 15.4 23.1|37 n 72 18.1 25.2|37 n 96 20.0 26.6|37 n 120 20.2 26.7
38 n 24 12.3 21.4|38 n 48 16.0 24.0|38 n 72 18.8 25.9|38 n 96 20.7 27.0|38 n 120 20.9 27.0
39 n 24 12.8 21.4|39 n 48 16.6 24.0|39 n 72 19.5 25.9|39 n 96 21.5 27.0|39 n 120 21.6 27.0
40 n 24 13.3 21.4|40 n 48 17.0 24.0|40 n 72 19.8 25.9|40 n 96 21.8 27.0|40 n 120 21.8 27.0
35 y 24 8.9 16.1|35 y 48 12.2 18.5|35 y 72 14.6 20.1|35 y 96 16.1 21.1|35 y 120 16.3 21.3
36 y 24 9.4 16.6|36 y 48 12.8 19.1|36 y 72 15.4 20.9|36 y 96 17.0 22.1|36 y 120 17.1 22.3
37 y 24 10.0 17.2|37 y 48 13.5 19.7|37 y 72 16.1 21.7|37 y 96 17.9 23.1|37 y 120 18.0 23.2
38 y 24 10.5 17.7|38 y 48 14.0 20.1|38 y 72 16.6 22.1|38 y 96 18.2 23.5|38 y 120 18.2 23.5
39 y 24 10.5 17.7|39 y 48 14.0 20.1|39 y 72 16.6 22.1|39 y 96 18.2 23.5|39 y 120 18.2 23.5
40 y 24 10.5 17.7|40 y 48 14.0 20.1|40 y 72 16.6 22.1|40 y 96 18.2 23.5|40 y 120 18.2 23.5
''';

void main() {
  group('NICE CG98 matches the published table', () {
    for (final e in _nice.entries) {
      test('${e.key} h', () {
        final t = NiceCg98.thresholdsAt(e.key.toDouble());
        expect([t.repeat, t.considerPhototherapy, t.phototherapy, t.exchange], e.value);
      });
    }

    test('no "repeat" band after 72 h: a level below the consider line needs no action', () {
      final a = const NiceCg98().assess(gestationWeeks: 39, hoursOfAge: 84, tsbUmol: 230) as BiliAssessment;
      expect(a.action, BiliAction.none);
    });

    test('in the first 6 hours only the phototherapy and exchange lines apply', () {
      final t = NiceCg98.thresholdsAt(3);
      expect(t.repeat, isNull);
      expect(t.considerPhototherapy, isNull);
      expect(t.phototherapy, closeTo(112.5, 1e-9));
    });
  });

  group('AAP 2022 matches 120 published anchor values', () {
    setUpAll(() =>
        Aap2022.loadJson(File('assets/clinical/aap2022_bilirubin.json').readAsStringSync()));
    for (final row in _aap.trim().replaceAll('\n', '|').split('|')) {
      final f = row.trim().split(RegExp(r'\s+'));
      final ga = int.parse(f[0]), risk = f[1] == 'y', h = double.parse(f[2]);
      test('${ga == 40 ? '≥40' : ga} wk, ${risk ? 'with' : 'no'} risk, ${h.round()} h', () {
        expect(Aap2022.thresholdMgdl(ga, AapCurve.phototherapy, risk, h), double.parse(f[3]));
        expect(Aap2022.thresholdMgdl(ga, AapCurve.exchange, risk, h), double.parse(f[4]));
      });
    }
  });
}
