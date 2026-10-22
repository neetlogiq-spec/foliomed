import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/bilirubin.dart';
import 'package:foliomed/clinical/bilirubin_assess.dart';
import 'package:foliomed/models/patient.dart';

const aap = Aap2022();

BiliAssessment a(int ga, double h, double mgdl, {bool risk = false}) =>
    aap.assess(gestationWeeks: ga, hoursOfAge: h, tsbUmol: mgdlToUmol(mgdl), neuroRisk: risk)
        as BiliAssessment;

double th(BiliAssessment x, double Function(BiliThresholds) f) =>
    double.parse(umolToMgdl(f(x.thresholds)).toStringAsFixed(1));

void main() {
  setUpAll(() => Aap2022.loadJson(File('assets/clinical/aap2022_bilirubin.json').readAsStringSync()));

  group('dataset', () {
    final data = jsonDecode(File('assets/clinical/aap2022_bilirubin.json').readAsStringSync())
        as Map<String, dynamic>;

    test('is marked unverified until checked against the AAP tables', () {
      expect(data['verified'], isFalse);
      expect(Aap2022.dataVerified, isFalse);
      expect(aap.source, contains('not yet been checked'));
    });

    test('every curve rises steadily and phototherapy stays below exchange', () {
      for (final kind in ['phototherapy', 'exchange']) {
        for (final risk in ['no_risk', 'with_risk']) {
          final curves = (data[kind] as Map)[risk] as Map;
          for (final e in curves.entries) {
            final v = (e.value as List).map((x) => (x as num?)?.toDouble()).toList();
            expect(v.first, isNull, reason: '$kind $risk ${e.key}: hour 0 has no threshold');
            for (var i = 2; i < v.length; i++) {
              expect(v[i]! >= v[i - 1]! - 1e-9, isTrue, reason: '$kind $risk ${e.key} dips at $i h');
            }
          }
        }
      }
      for (final ga in [35, 36, 37, 38, 39, 40]) {
        for (final risk in [false, true]) {
          for (final h in <double>[1, 12, 24, 48, 72, 96, 200, 340]) {
            final photo = Aap2022.thresholdMgdl(ga, AapCurve.phototherapy, risk, h)!;
            final exch = Aap2022.thresholdMgdl(ga, AapCurve.exchange, risk, h)!;
            expect(photo < exch, isTrue, reason: 'GA $ga risk $risk $h h');
          }
        }
      }
    });

    test('risk factors lower the thresholds; lower gestation lowers them', () {
      for (final h in <double>[24, 48, 72]) {
        expect(Aap2022.thresholdMgdl(39, AapCurve.phototherapy, true, h)!,
            lessThan(Aap2022.thresholdMgdl(39, AapCurve.phototherapy, false, h)!));
        expect(Aap2022.thresholdMgdl(35, AapCurve.phototherapy, false, h)!,
            lessThan(Aap2022.thresholdMgdl(38, AapCurve.phototherapy, false, h)!));
      }
    });
  });

  group('lookup', () {
    test('values at tabulated hours (40 wk, no risk factors)', () {
      final x = a(40, 24, 10);
      expect(th(x, (t) => t.phototherapy), 13.3);
      expect(th(x, (t) => t.exchange), 21.4);
      expect(th(x, (t) => t.escalation!), 19.4); // exchange − 2
      expect(th(a(39, 48, 10), (t) => t.phototherapy), 16.6);
      expect(th(a(38, 72, 10), (t) => t.phototherapy), 18.8);
    });

    test('curve keys: photo no-risk tops out at 40, everything else at 38', () {
      expect(th(a(42, 24, 10), (t) => t.phototherapy), 13.3); // ≥40
      expect(th(a(41, 24, 10, risk: true), (t) => t.phototherapy), 10.5); // ≥38 with risk
      expect(th(a(40, 24, 10), (t) => t.exchange), th(a(38, 24, 10), (t) => t.exchange));
      // Gestation and risk are separate inputs: 36 wk without risk ≠ 36 wk with risk.
      expect(th(a(36, 24, 10), (t) => t.phototherapy), 11.2);
      expect(th(a(36, 24, 10, risk: true), (t) => t.phototherapy), 9.4);
    });

    test('completed hours (no rounding up) and a flat plateau after the table', () {
      expect(th(a(40, 24.9, 10), (t) => t.phototherapy), 13.3);
      expect(th(a(40, 200, 10), (t) => t.phototherapy), 21.8);
      expect(th(a(40, 5000, 10), (t) => t.exchange), 27.0);
    });

    test('actions use "at or above" each threshold', () {
      expect(a(40, 24, 11.2).action, BiliAction.none);
      expect(a(40, 24, 11.3).action, BiliAction.approaching); // photo − 2
      expect(a(40, 24, 13.3).action, BiliAction.phototherapy); // exactly at
      expect(a(40, 24, 19.4).action, BiliAction.escalation);
      expect(a(40, 24, 21.4).action, BiliAction.exchange);
    });

    test('refuses rather than guesses', () {
      Object r(int? ga, double h, bool? risk) =>
          aap.assess(gestationWeeks: ga, hoursOfAge: h, tsbUmol: 200, neuroRisk: risk);
      expect(r(34, 48, false), isA<BiliNotApplicable>());
      expect(r(null, 48, false), isA<BiliNotApplicable>());
      expect(r(39, 48, null), isA<BiliNotApplicable>(), reason: 'risk factors not assessed');
      expect(r(39, 0.5, false), isA<BiliNotApplicable>());
    });
  });

  group('guideline by gestation: NICE under 35 weeks, AAP from 35', () {
    Patient baby({int ga = 39, List<String>? risk}) => Patient.fromRow({
          'name': 'B',
          'born_at': DateTime.utc(2026, 10, 18).toIso8601String(),
          'gestation_weeks': ga,
          'neuro_risk_factors': risk,
        });
    final at = DateTime.utc(2026, 10, 20); // 48 h

    test('35 weeks and over use AAP', () {
      expect(guidelineForGestation(35)!.name, 'AAP 2022');
      expect(assessForPatient(baby(risk: []), at, 200)!.guideline, 'AAP 2022');
      expect(assessForPatient(baby(ga: 35, risk: ['sepsis']), at, 200)!.guideline, 'AAP 2022');
    });

    test('AAP without recorded risk factors does not fall back to NICE', () {
      expect(assessForPatient(baby(), at, 200), isNull);
      expect(linesForPatient(baby()), isNull);
    });

    test('under 35 weeks use NICE, risk factors not needed', () {
      expect(guidelineForGestation(34)!.name, 'NICE CG98');
      final a = assessForPatient(baby(ga: 34), at, 200)!;
      expect(a.guideline, 'NICE CG98');
      // 34 weeks at 48 h: 40 + (240 − 40) × 48/72 ≈ 173 → above phototherapy.
      expect(a.action, BiliAction.phototherapy);
      expect(linesForPatient(baby(ga: 30))!.phototherapy(96), 200);
    });

    test('no gestation, no guideline', () {
      expect(guidelineForGestation(null), isNull);
      expect(assessByGestation(gestationWeeks: null, hoursOfAge: 48, tsbUmol: 200),
          isA<BiliNotApplicable>());
    });

    test('chart lines: AAP adds an escalation line 2 mg/dL under exchange', () {
      final l = linesForPatient(baby(risk: []))!;
      expect(umolToMgdl(l.exchange(48)! - l.escalation!(48)!), closeTo(2, 1e-9));
      expect(linesForPatient(baby(ga: 30))!.escalation, isNull);
    });
  });

  group('rate of rise', () {
    final t0 = DateTime.utc(2026, 10, 19, 8);
    test('uses the last two readings, in mg/dL per hour', () {
      final rate = riseRateMgdlPerHour([
        (at: t0, umol: mgdlToUmol(5)),
        (at: t0.add(const Duration(hours: 10)), umol: mgdlToUmol(8)),
        (at: t0.add(const Duration(hours: 20)), umol: mgdlToUmol(11)),
      ])!;
      expect(rate, closeTo(0.3, 1e-9));
      expect(riseRateMgdlPerHour([(at: t0, umol: 100)]), isNull);
    });

    test('AAP rapid-rise cut-offs: 0.3 in the first 24 h, 0.2 after', () {
      expect(isRapidRise(0.3, 20), isTrue);
      expect(isRapidRise(0.25, 20), isFalse);
      expect(isRapidRise(0.2, 30), isTrue);
      expect(isRapidRise(0.19, 30), isFalse);
    });
  });
}
