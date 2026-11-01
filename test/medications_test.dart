import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/handover.dart';
import 'package:foliomed/clinical/medications.dart';
import 'package:foliomed/models/medication.dart';
import 'package:foliomed/models/patient.dart';

PatientAllergy _a(String s, {String? reaction, AllergySeverity sev = AllergySeverity.unknown}) => PatientAllergy(
  id: s,
  patientId: 'p',
  substance: s,
  reaction: reaction,
  severity: sev,
  createdAt: DateTime(2026, 11, 1),
);

PatientMedication _m(String name, {double? dose, String unit = '', String route = '', String freq = ''}) =>
    PatientMedication(
      id: name,
      patientId: 'p',
      context: MedContext.inpatient,
      drugName: name,
      dose: dose,
      doseUnit: unit,
      route: route,
      frequency: freq,
      createdAt: DateTime(2026, 11, 1),
    );

void main() {
  group('allergy matching', () {
    test('same name, either way round, any case', () {
      expect(allergyHits('Ceftriaxone', [_a('ceftriaxone')]).single.possible, isFalse);
      expect(allergyHits('Paracetamol 500', [_a('Paracetamol')]), hasLength(1));
      expect(allergyHits('Ibuprofen', [_a('Paracetamol')]), isEmpty);
    });

    test('drug groups: amoxicillin vs "penicillin", ibuprofen vs "NSAIDs"', () {
      expect(allergyHits('Amoxicillin', [_a('Penicillin')]).single.possible, isFalse);
      expect(allergyHits('Co-amoxiclav', [_a('Penicillins')]), hasLength(1));
      expect(allergyHits('Ibuprofen', [_a('NSAIDs')]), hasLength(1));
      expect(allergyHits('Septran', [_a('Sulfa drugs')]), hasLength(1));
      expect(allergyHits('Gentamicin', [_a('Amikacin')]), hasLength(1), reason: 'same group');
    });

    test('penicillin allergy flags cephalosporins and carbapenems as possible', () {
      final h = allergyHits('Cefotaxime', [_a('Amoxicillin', reaction: 'rash')]);
      expect(h.single.possible, isTrue);
      expect(h.single.message, 'Possible cross-reaction: recorded allergy to Amoxicillin (rash).');
      expect(allergyHits('Meropenem', [_a('Penicillin')]).single.possible, isTrue);
      expect(allergyHits('Penicillin', [_a('Ceftriaxone')]), isEmpty, reason: 'only one way round');
    });

    test('short or blank names do not match everything', () {
      expect(allergyHits('', [_a('Penicillin')]), isEmpty);
      expect(allergyHits('Amoxicillin', [_a('Egg')]), isEmpty);
    });
  });

  group('dose check against the drug list', () {
    test('per kg above the largest listed dose warns', () {
      expect(doseWarning(drugKey: 'phenobarbitone', dose: 20, unit: 'mg/kg'), isNull);
      expect(doseWarning(drugKey: 'phenobarbitone', dose: 25, unit: 'mg/kg'), contains('20 mg/kg'));
      expect(
        doseWarning(drugKey: 'adrenaline', dose: 200, unit: 'mcg/kg'),
        isNotNull,
        reason: 'mcg vs mg; ET max 0.1 mg/kg',
      );
      expect(doseWarning(drugKey: 'adrenaline', dose: 10, unit: 'mcg/kg'), isNull);
    });

    test('absolute doses use the weight, then the maximum single dose', () {
      expect(doseWarning(drugKey: 'phenytoin', dose: 300, unit: 'mg', weightKg: 10), contains('mg/kg'));
      expect(doseWarning(drugKey: 'phenytoin', dose: 150, unit: 'mg', weightKg: 10), isNull);
      expect(doseWarning(drugKey: 'phenytoin', dose: 1800, unit: 'mg', weightKg: 100), contains('1500 mg'));
    });

    test('silent when it cannot compare', () {
      expect(doseWarning(drugKey: null, dose: 999, unit: 'mg/kg'), isNull);
      expect(
        doseWarning(drugKey: 'dopamine', dose: 999, unit: 'mg/kg'),
        isNull,
        reason: 'infusion only',
      );
      expect(doseWarning(drugKey: 'phenytoin', dose: 999, unit: 'tab'), isNull);
      expect(
        doseWarning(drugKey: 'phenytoin', dose: 999, unit: 'mg'),
        isNull,
        reason: 'no weight, no cap hit',
      );
    });
  });

  group('lines', () {
    test('medicine and allergy wording', () {
      expect(_m('Amoxicillin', dose: 30, unit: 'mg/kg', route: 'IV', freq: 'TDS').line, 'Amoxicillin 30 mg/kg IV TDS');
      expect(_m('Vitamin D').line, 'Vitamin D');
      expect(
        _a('Penicillin', reaction: 'Urticaria', sev: AllergySeverity.moderate).line,
        'Penicillin (Urticaria, moderate)',
      );
    });

    test('handover puts allergies first and lists what the patient is on', () {
      final p = Patient(
        id: 'p',
        name: 'Child',
        age: 4,
        gender: 'Male',
        wardId: 'w',
        bedNumber: '3',
        diagnosis: 'Pneumonia',
        admittedAt: DateTime(2026, 11, 1),
      );
      final text = HandoverItem(
        patient: p,
        unitName: null,
        openReminders: const [],
        allergies: [_a('Penicillin', reaction: 'rash')],
        medications: [_m('Ceftriaxone', dose: 50, unit: 'mg/kg', route: 'IV', freq: 'OD')],
      ).toText(DateTime(2026, 11, 1, 9)).split('\n');
      expect(text[1], '⚠ ALLERGY: Penicillin (rash)');
      expect(text[2], 'P: Pneumonia');
      expect(text[3], 'On: Ceftriaxone 50 mg/kg IV OD');
    });
  });
}
