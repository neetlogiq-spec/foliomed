import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/lab_report_parser.dart';

void main() {
  test('reads a typical Indian lab report', () {
    const report = '''
COMPLETE BLOOD COUNT
Haemoglobin            16.2      g/dL      14.5 - 22.5
Total Leucocyte Count  12,500    /cumm     9000 - 30000
Platelet Count         2.1       lakhs/cumm
PCV                    48        %
MCHC                   33.1      g/dL
THYROID
TSH                    6.1       µIU/mL
LIVER
Bilirubin Total        12.4      mg/dL
Bilirubin Direct       0.6       mg/dL
Bilirubin Indirect     11.8      mg/dL
RENAL
Blood Urea             18        mg/dL
S. Creatinine          0.6       mg/dL
Sodium (Na+)           138       mmol/L
Potassium (K+)         4.8       mmol/L
Chloride (Cl-)         104       mmol/L
''';
    final p = parseLabReport(report);
    expect(p.values, {
      'hb': 16.2,
      'tlc': 12.5,
      'platelets': 210.0,
      'hct': 48.0,
      'tsh': 6.1,
      'tsb_total': 12.4,
      'tsb_direct': 0.6,
      'urea': 18.0,
      'creatinine': 0.6,
      'sodium': 138.0,
      'potassium': 4.8,
      'chloride': 104.0,
    });
    expect(p.bilirubinInUmol, isFalse);
  });

  test('value on the next line, µmol/L bilirubin, platelets in /cumm', () {
    const report = 'Total Serum Bilirubin\n212 µmol/L\nPlatelets 180000 /cumm\nHb 15';
    final p = parseLabReport(report);
    expect(p.values['tsb_total'], 212);
    expect(p.bilirubinInUmol, isTrue);
    expect(p.values['platelets'], 180);
    expect(p.values['hb'], 15);
  });

  test('ignores impossible values and unrelated lines', () {
    final p = parseLabReport('HbA1c 5.6 %\nCreatinine clearance 90\nSodium 9999\nHb 160');
    expect(p.isEmpty, isTrue);
  });
}
