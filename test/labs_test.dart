import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/handover.dart';
import 'package:foliomed/clinical/lab_parser.dart';
import 'package:foliomed/clinical/labs.dart';
import 'package:foliomed/models/lab_result.dart';
import 'package:foliomed/models/patient.dart';

ParsedLab? _find(List<ParsedLab> l, String key) => l.where((p) => p.test.key == key).firstOrNull;

void main() {
  group('reading a report', () {
    const report = '''
CITY DIAGNOSTICS            Patient: Baby of Asha   Age: 3 yrs
HAEMATOLOGY
Haemoglobin            9.1    g/dL     11.5 - 15.5
Total Leucocyte Count  12,500 /cumm    4000 - 11000
Platelet Count         1.8 lakhs       1.5 - 4.5 lakhs
MCHC                   31     g/dL     32 - 36
BIOCHEMISTRY
Serum Sodium           128    mmol/L   135 - 145
Potassium              6.8    mmol/L   3.5 - 5.1
S. Creatinine          44     umol/L   27 - 62
Glucose (Random)       3.2    mmol/L
C-Reactive Protein     48     mg/L     < 6
Calcium                9.4    mg/dL
Blood culture: No growth after 48 hours
''';

    test('values, units converted, reference ranges kept', () {
      final r = parseLabText(report);
      final hb = _find(r, 'hb')!;
      expect((hb.value, hb.refLow, hb.refHigh), (9.1, 11.5, 15.5));
      expect(_find(r, 'tlc')!.value, 12.5);
      expect((_find(r, 'tlc')!.refLow, _find(r, 'tlc')!.refHigh), (4, 11));
      expect(_find(r, 'platelets')!.value, 180);
      expect(_find(r, 'na')!.value, 128);
      expect(_find(r, 'k')!.refHigh, 5.1);
      expect(_find(r, 'creatinine')!.value, closeTo(0.498, 0.001));
      expect(_find(r, 'glucose')!.value, closeTo(57.6, 0.01));
      expect((_find(r, 'crp')!.value, _find(r, 'crp')!.refLow, _find(r, 'crp')!.refHigh), (48, null, 6));
      expect(_find(r, 'calcium')!.value, 9.4);
      expect(_find(r, 'blood_culture')!.text, 'No growth after 48 hours');
    });

    test('MCHC is not mistaken for Hb; names and ages are not results', () {
      final r = parseLabText(report);
      expect(_find(r, 'hb')!.value, 9.1);
      expect(_find(r, 'pt'), isNull);
      expect(_find(r, 'magnesium'), isNull, reason: '"mg/dL" is a unit, not magnesium');
    });

    test('impossible numbers are dropped', () {
      expect(parseLabText('Sodium 1.35'), isEmpty);
      expect(parseLabText('Haemoglobin 95'), hasLength(1), reason: '95 g/L → 9.5 g/dL');
      expect(_find(parseLabText('Haemoglobin 95 g/L'), 'hb')!.value, 9.5);
    });
  });

  group('flags', () {
    final k = labTestByKey('k'), hb = labTestByKey('hb'), crp = labTestByKey('crp');
    test('critical values first, then the report range', () {
      expect(flagFor(k, 6.8, refLow: 3.5, refHigh: 5.1), LabFlag.criticalHigh);
      expect(flagFor(k, 5.6, refLow: 3.5, refHigh: 5.1), LabFlag.high);
      expect(flagFor(k, 4.0, refLow: 3.5, refHigh: 5.1), isNull);
      expect(flagFor(hb, 6.5), LabFlag.criticalLow);
      expect(flagFor(crp, 48), isNull, reason: 'no range, not critical: no guess');
      expect(flagFor(crp, 48, refHigh: 6), LabFlag.high);
    });

    test('summary puts critical results first', () {
      final entries = [
        LabEntry(test: hb!, value: 9.1, refLow: 11.5, refHigh: 15.5),
        LabEntry(test: labTestByKey('na')!, value: 138),
        LabEntry(test: k!, value: 6.8),
        LabEntry(test: labTestByKey('blood_culture')!, text: 'no growth'),
      ];
      expect(
        labSummary(entries),
        'Labs: Potassium 6.8 mmol/L ⚠↑, Hb 9.1 g/dL ↓, Sodium 138 mmol/L, Blood culture: no growth.',
      );
    });

    test('handover shows flagged results', () {
      final p = Patient(
        id: 'p',
        name: 'C',
        age: 3,
        gender: 'Male',
        wardId: 'w',
        bedNumber: '1',
        diagnosis: '',
        admittedAt: DateTime(2026, 11, 5),
      );
      LabResult r(String key, String name, double v, LabFlag f, String unit) => LabResult(
        id: key,
        patientId: 'p',
        testKey: key,
        testName: name,
        value: v,
        unit: unit,
        flag: f,
        sampledAt: DateTime(2026, 11, 5, 6),
      );
      final item = HandoverItem(
        patient: p,
        unitName: null,
        openReminders: const [],
        flaggedLabs: [
          r('hb', 'Hb', 9.1, LabFlag.low, 'g/dL'),
          r('k', 'Potassium', 6.8, LabFlag.criticalHigh, 'mmol/L'),
        ],
      );
      expect(item.labsLine, 'Labs: Potassium 6.8 mmol/L ⚠↑, Hb 9.1 g/dL ↓');
    });
  });
}
