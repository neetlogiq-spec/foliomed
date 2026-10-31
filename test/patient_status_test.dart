import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/bilirubin.dart';
import 'package:foliomed/clinical/patient_status.dart';
import 'package:foliomed/models/newborn_tracking.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/ward.dart';

final _now = DateTime.utc(2026, 10, 27, 12);

Patient _p({
  DateTime? born,
  int? ga,
  int? birthG,
  List<String>? risk,
  String? acuity,
  String? reason,
  Duration setAgo = const Duration(hours: 1),
  List<String> tags = const [],
}) =>
    Patient(
      id: 'p',
      name: 'P',
      age: 5,
      gender: '',
      wardId: 'w',
      bedNumber: '1',
      diagnosis: '',
      admittedAt: _now,
      bornAt: born,
      gestationWeeks: ga,
      birthWeightG: birthG,
      neuroRiskFactors: risk,
      acuity: acuity,
      acuityReason: reason,
      acuitySetAt: acuity == null ? null : _now.subtract(setAgo),
      supportTags: tags,
    );

/// A baby born [hours] ago.
Patient _baby({int hours = 48, int? ga = 39, int? birthG = 3000, List<String>? risk = const [], String? acuity}) =>
    _p(born: _now.subtract(Duration(hours: hours)), ga: ga, birthG: birthG, risk: risk, acuity: acuity);

BilirubinReading _tsb(double umol, {Duration ago = const Duration(hours: 1)}) => BilirubinReading(
    id: 'b', patientId: 'p', measuredAt: _now.subtract(ago), value: umol, isUmol: true, transcutaneous: false);

PatientStatusResult _status(Patient p, WardKind kind,
        {int urgentNotes = 0, int overdue = 0, int urgentJobs = 0, BilirubinReading? bili,
        bool photo = false, int? weight}) =>
    patientStatus(StatusInputs(
      patient: p,
      wardKind: kind,
      now: _now,
      urgentNotes: urgentNotes,
      overdueReminders: overdue,
      urgentJobs: urgentJobs,
      latestBilirubin: bili,
      phototherapyRunning: photo,
      latestWeightG: weight,
    ));

void main() {
  setUpAll(() => Aap2022.loadJson(File('assets/clinical/aap2022_bilirubin.json').readAsStringSync()));

  group('every ward', () {
    test('staff-set status gives the colour', () {
      expect(_status(_p(acuity: 'stable'), WardKind.adult).level, StatusLevel.ok);
      expect(_status(_p(acuity: 'watch'), WardKind.adult).level, StatusLevel.watch);
      final sick = _status(_p(acuity: 'sick', reason: 'septic'), WardKind.adult);
      expect(sick.level, StatusLevel.act);
      expect(sick.reasons.first.text, 'Marked Sick — septic');
    });

    test('ward tasks turn red whatever the status says', () {
      expect(_status(_p(acuity: 'stable'), WardKind.adult, urgentNotes: 1).level, StatusLevel.act);
      expect(_status(_p(), WardKind.picu, overdue: 2).reasons.single.text, '2 overdue reminders');
      expect(_status(_p(), WardKind.paeds, urgentJobs: 1).level, StatusLevel.act);
    });

    test('no status: grey on staff-led wards, green elsewhere', () {
      for (final k in [WardKind.picu, WardKind.paeds, WardKind.adult]) {
        expect(_status(_p(), k).level, StatusLevel.unknown, reason: k.name);
      }
      expect(_status(_p(), WardKind.other).level, StatusLevel.ok);
      expect(_status(_baby(), WardKind.pnc).level, StatusLevel.ok);
    });

    test('a status older than the review window is flagged but keeps its colour', () {
      final picu = _status(_p(acuity: 'stable', setAgo: const Duration(hours: 13)), WardKind.picu);
      expect(picu.needsReview, isTrue);
      expect(picu.level, StatusLevel.ok);
      expect(picu.reasons.map((r) => r.text), contains('Status not reviewed in 12 h'));
      expect(_status(_p(acuity: 'stable', setAgo: const Duration(hours: 13)), WardKind.adult).needsReview, isFalse);
      expect(_status(_p(acuity: 'stable', setAgo: const Duration(hours: 25)), WardKind.adult).needsReview, isTrue);
      expect(_status(_p(acuity: 'sick', setAgo: const Duration(hours: 30)), WardKind.adult).level, StatusLevel.act);
    });

    test('reasons are listed most serious first', () {
      final s = _status(_p(acuity: 'watch'), WardKind.adult, overdue: 1);
      expect(s.reasons.map((r) => r.level), [StatusLevel.act, StatusLevel.watch]);
    });
  });

  group('PICU support tags', () {
    test('ventilated or inotropes while marked Stable prompts a review', () {
      final s = _status(_p(acuity: 'stable', tags: ['ventilated', 'inotropes']), WardKind.picu);
      expect(s.level, StatusLevel.watch);
      expect(s.reasons.first.text, 'Ventilated and Inotropes but marked Stable — review');
      expect(_status(_p(acuity: 'stable', tags: ['centralLine', 'sedation']), WardKind.picu).level, StatusLevel.ok);
      expect(_status(_p(acuity: 'sick', tags: ['ventilated']), WardKind.picu).level, StatusLevel.act);
    });
  });

  group('newborn rules (PNC / NICU, or Other under 28 days)', () {
    test('bilirubin above the phototherapy line: red unless phototherapy is running', () {
      // 39 wk, no risk factors, 48 h: AAP phototherapy ≈ 16+ mg/dL; 300 µmol/L ≈ 17.5.
      final red = _status(_baby(), WardKind.pnc, bili: _tsb(300));
      expect(red.level, StatusLevel.act);
      expect(red.reasons.first.text, contains('phototherapy not running'));
      final photo = _status(_baby(), WardKind.pnc, bili: _tsb(300), photo: true);
      expect(photo.level, StatusLevel.watch);
      expect(photo.reasons.map((r) => r.text), contains('Under phototherapy'));
    });

    test('exchange level is red even under phototherapy', () {
      expect(_status(_baby(), WardKind.pnc, bili: _tsb(500), photo: true).level, StatusLevel.act);
    });

    test('near the line is amber; well below is green', () {
      expect(_status(_baby(), WardKind.pnc, bili: _tsb(260)).level, StatusLevel.watch);
      expect(_status(_baby(), WardKind.pnc, bili: _tsb(100)).level, StatusLevel.ok);
    });

    test('preterm babies use NICE', () {
      // 32 wk at 48 h: NICE phototherapy 160, exchange 240 µmol/L.
      final s = _status(_baby(ga: 32, risk: null), WardKind.nicu, bili: _tsb(200));
      expect(s.level, StatusLevel.act);
      expect(s.reasons.first.text, contains('NICE CG98'));
    });

    test('readings older than 72 h no longer colour the dot', () {
      expect(_status(_baby(hours: 120), WardKind.pnc, bili: _tsb(500, ago: const Duration(hours: 73))).level,
          StatusLevel.ok);
    });

    test('missing gestation or risk factors is amber', () {
      expect(_status(_baby(ga: null), WardKind.pnc).reasons.single.text, 'Gestational age not recorded');
      expect(_status(_baby(risk: null), WardKind.pnc).reasons.single.text,
          'Neurotoxicity risk factors not recorded');
      expect(_status(_baby(ga: 33, risk: null), WardKind.pnc).level, StatusLevel.ok,
          reason: 'NICE (below 35 weeks) needs no risk factors');
    });

    test('weight loss: amber beyond 7%, red at 10%', () {
      expect(_status(_baby(), WardKind.pnc, weight: 2850).level, StatusLevel.ok);
      expect(_status(_baby(), WardKind.pnc, weight: 2760).level, StatusLevel.watch);
      final red = _status(_baby(), WardKind.pnc, weight: 2700);
      expect(red.level, StatusLevel.act);
      expect(red.reasons.first.text, 'Weight −10.0% from birth');
    });

    test('NICU: birth weight not regained by day 14', () {
      final s = _status(_baby(hours: 24 * 15), WardKind.nicu, weight: 2900);
      expect(s.reasons.single.text, 'Birth weight not regained by day 14');
      expect(_status(_baby(hours: 24 * 15), WardKind.pnc, weight: 2900).level, StatusLevel.ok);
    });

    test('Other wards apply them only under 28 days; staff-led wards never', () {
      expect(_status(_baby(ga: null), WardKind.other).level, StatusLevel.watch);
      expect(_status(_baby(hours: 24 * 30, ga: null), WardKind.other).level, StatusLevel.ok);
      expect(_status(_baby(ga: null), WardKind.picu).level, StatusLevel.unknown);
    });
  });
}
