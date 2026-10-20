import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/tools/electrolytes.dart';

void main() {
  test('dextrose bolus: 2 mL/kg D10 at 3 kg = 6 mL, 200 mg/kg', () {
    final b = dextroseBolus(kg: 3);
    expect(b.ml, 6);
    expect(b.mgPerKg, 200);
  });

  test('rate for GIR: 6 mg/kg/min of D10 at 3 kg = 10.8 mL/h', () {
    expect(rateForGir(girMgKgMin: 6, kg: 3, dextrosePercent: 10), closeTo(10.8, 1e-9));
  });

  test('sodium deficit and free water', () {
    expect(sodiumDeficitMmol(currentNa: 125, targetNa: 135, kg: 3), closeTo(21, 1e-9));
    expect(sodiumDeficitMmol(currentNa: 140, targetNa: 135, kg: 3), 0);
    expect(freeWaterDeficitL(na: 160, kg: 3), closeTo(0.3, 1e-9));
  });

  test('corrected sodium, osmolality, anion gap', () {
    expect(correctedSodium(na: 130, glucoseMgDl: 600), closeTo(138, 1e-9));
    expect(correctedSodium(na: 130, glucoseMgDl: 90), 130);
    expect(serumOsmolality(na: 140, glucoseMgDl: 90, bunMgDl: 14), closeTo(290, 1e-9));
    expect(bunFromUrea(30), closeTo(14.02, 0.01));
    expect(anionGap(na: 140, cl: 105, hco3: 22), 13);
    expect(anionGap(na: 140, cl: 105, hco3: 22, k: 4), 17);
  });

  test('dose volumes', () {
    // Calcium gluconate 10%: 200 mg/kg at 2 kg = 4 mL.
    expect(doseVolumeMl(dosePerKg: 200, kg: 2, stockPerMl: kCalciumGluconate10MgPerMl), 4);
    // MgSO4 50 mg/kg at 3 kg from 50% = 0.3 mL.
    expect(doseVolumeMl(dosePerKg: 50, kg: 3, stockPerMl: kMagnesiumSulphate50MgPerMl), closeTo(0.3, 1e-9));
    // 3% NaCl for 21 mmol = 40.9 mL.
    expect(21 / kNaCl3PercentMmolPerMl, closeTo(40.94, 0.01));
  });
}
