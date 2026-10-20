/// Hypoglycaemia bolus and electrolyte arithmetic. Doses are always typed
/// in by the user (from the unit protocol); FolioMed only turns a dose into
/// volumes and rates. Defaults, where shown, are the commonly cited ones.
library;

// ── Hypoglycaemia ───────────────────────────────────────────────────────

/// Bolus volume (mL) and glucose given (mg/kg) for [mlPerKg] of
/// [dextrosePercent] dextrose. AAP 2011: 200 mg/kg = 2 mL/kg of 10%.
({double ml, double mgPerKg}) dextroseBolus({required double kg, double mlPerKg = 2, double dextrosePercent = 10}) =>
    (ml: mlPerKg * kg, mgPerKg: mlPerKg * dextrosePercent * 10);

/// Pump rate (mL/h) giving [girMgKgMin] with [dextrosePercent] dextrose.
double rateForGir({required double girMgKgMin, required double kg, required double dextrosePercent}) =>
    girMgKgMin * kg * 6 / dextrosePercent;

// ── Sodium and water ────────────────────────────────────────────────────

/// mmol/mL of common sodium chloride strengths.
const double kNaCl3PercentMmolPerMl = 0.513;
const double kNaCl09PercentMmolPerMl = 0.154;

/// Sodium deficit (mmol) = (target − current) × body-water fraction × kg.
/// Body water is ~0.7–0.8 of weight in newborns, ~0.6 in children.
double sodiumDeficitMmol({required double currentNa, required double targetNa, required double kg, double water = 0.7}) =>
    targetNa <= currentNa ? 0 : (targetNa - currentNa) * water * kg;

/// Free-water deficit (litres) for high sodium: water × kg × (Na ÷ 140 − 1).
double freeWaterDeficitL({required double na, required double kg, double water = 0.7}) =>
    na <= 140 ? 0 : water * kg * (na / 140 - 1);

/// Sodium corrected for high glucose (Katz): + 1.6 per 100 mg/dL over 100.
double correctedSodium({required double na, required double glucoseMgDl}) =>
    glucoseMgDl <= 100 ? na : na + 1.6 * (glucoseMgDl - 100) / 100;

/// Serum osmolality (mOsm/kg) = 2 × Na + glucose ÷ 18 + BUN ÷ 2.8 (mg/dL).
/// Indian labs often report urea: BUN = urea ÷ 2.14.
double serumOsmolality({required double na, required double glucoseMgDl, required double bunMgDl}) =>
    2 * na + glucoseMgDl / 18 + bunMgDl / 2.8;

double bunFromUrea(double ureaMgDl) => ureaMgDl / 2.14;

/// Anion gap = Na − (Cl + HCO₃), or + K when [k] is given.
double anionGap({required double na, required double cl, required double hco3, double? k}) =>
    na + (k ?? 0) - cl - hco3;

// ── Doses → volumes ─────────────────────────────────────────────────────

/// Volume (mL) of a stock for a weight-based dose: dose/kg × kg ÷ stock
/// strength (same units, e.g. mmol/kg and mmol/mL, or mg/kg and mg/mL).
double doseVolumeMl({required double dosePerKg, required double kg, required double stockPerMl}) =>
    dosePerKg * kg / stockPerMl;

/// Calcium gluconate 10%: 100 mg/mL salt, ~9.3 mg/mL elemental calcium.
const double kCalciumGluconate10MgPerMl = 100;
const double kCalciumGluconate10ElementalMgPerMl = 9.3;

/// Magnesium sulphate 50%: 500 mg/mL.
const double kMagnesiumSulphate50MgPerMl = 500;

/// Potassium chloride 15%: 2 mmol/mL.
const double kKcl15MmolPerMl = 2;
