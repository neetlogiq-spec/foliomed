/// Bedside newborn formulas used by the Tools tab. Pure functions; every
/// number on screen comes from here, and every constant names its source.
///
/// None of this has been checked by a clinician yet: [kToolsVerified]
/// stays false (and the UI says so) until it has.
library;

import 'dart:math' as math;

const bool kToolsVerified = false;

// ── Fluids ──────────────────────────────────────────────────────────────

/// Day of life, counting the first 24 hours as day 1.
int dayOfLife(DateTime bornAt, DateTime now) =>
    math.max(1, now.difference(bornAt).inHours ~/ 24 + 1);

/// Total fluid (mL/kg/day) by day of life, from a common day-of-life table
/// (e.g. AIIMS NICU protocols): start 60 (≥1500 g) or 80 (<1500 g) and add
/// 15 a day to 150. Units differ — the screen lets you override it.
int totalFluidPerKgDay({required int dayOfLife, required bool under1500g}) {
  final start = under1500g ? 80 : 60;
  return math.min(150, start + 15 * (math.max(1, dayOfLife) - 1));
}

/// mL/day and mL/h for [mlPerKgDay] at [kg].
({double perDay, double perHour}) fluidVolumes(double mlPerKgDay, double kg) {
  final day = mlPerKgDay * kg;
  return (perDay: day, perHour: day / 24);
}

/// Glucose infusion rate, mg/kg/min: dextrose % × mL/kg/day ÷ 144.
double gir({required double dextrosePercent, required double mlPerKgDay}) =>
    dextrosePercent * mlPerKgDay / 144;

/// Mixes [totalMl] of [targetPercent] dextrose from a weaker and a stronger
/// stock. Null when the target isn't between the two.
({double weakMl, double strongMl})? mixDextrose({
  required double targetPercent,
  required double totalMl,
  required double weakPercent,
  required double strongPercent,
}) {
  if (strongPercent <= weakPercent ||
      targetPercent < weakPercent ||
      targetPercent > strongPercent ||
      totalMl <= 0) {
    return null;
  }
  final strong = totalMl * (targetPercent - weakPercent) / (strongPercent - weakPercent);
  return (weakMl: totalMl - strong, strongMl: strong);
}

// ── Age ─────────────────────────────────────────────────────────────────

/// Weeks + days, e.g. 33+4.
class WeeksDays {
  const WeeksDays(this.totalDays);
  WeeksDays.of(int weeks, int days) : totalDays = weeks * 7 + days;
  final int totalDays;
  int get weeks => totalDays ~/ 7;
  int get days => totalDays % 7;
  @override
  String toString() => '$weeks+$days';
}

class AgeResult {
  const AgeResult({required this.chronologicalDays, required this.pma, this.correctedDays});
  final int chronologicalDays;

  /// Postmenstrual age: gestation at birth + chronological age.
  final WeeksDays pma;

  /// Age corrected to 40 weeks, for babies born before 37 weeks once they
  /// have passed term. Null if born at term, or not yet at 40 weeks PMA.
  final int? correctedDays;
}

AgeResult correctedAge({required WeeksDays gestationAtBirth, required DateTime born, required DateTime on}) {
  final birthDay = DateTime(born.year, born.month, born.day);
  final today = DateTime(on.year, on.month, on.day);
  final chrono = math.max(0, today.difference(birthDay).inDays);
  final pma = WeeksDays(gestationAtBirth.totalDays + chrono);
  final preterm = gestationAtBirth.totalDays < 37 * 7;
  final corrected = chrono - (40 * 7 - gestationAtBirth.totalDays);
  return AgeResult(
    chronologicalDays: chrono,
    pma: pma,
    correctedDays: preterm && corrected >= 0 ? corrected : null,
  );
}

// ── Blood ───────────────────────────────────────────────────────────────

/// Estimated blood volume, mL/kg: ~85 at term, ~100 preterm (textbook
/// ranges 80–90 and 90–105).
int bloodVolumePerKg({required bool preterm}) => preterm ? 100 : 85;

/// Double-volume exchange transfusion: 2 × blood volume.
double doubleVolumeExchangeMl({required double kg, required bool preterm}) =>
    2 * bloodVolumePerKg(preterm: preterm) * kg;

/// Partial exchange for polycythaemia, mL of saline to exchange:
/// blood volume × (observed Hct − target Hct) ÷ observed Hct.
double partialExchangeMl({
  required double kg,
  required bool preterm,
  required double observedHct,
  double targetHct = 55,
}) {
  if (observedHct <= targetHct || observedHct <= 0) return 0;
  return bloodVolumePerKg(preterm: preterm) * kg * (observedHct - targetHct) / observedHct;
}

// ── Lines and tubes ─────────────────────────────────────────────────────

/// High UAC insertion length, cm (Shukla & Ferrara 1986): 3 × kg + 9.
double uacHighCm(double kg) => 3 * kg + 9;

/// UVC insertion length, cm (Shukla): UAC ÷ 2 + 1.
double uvcCm(double kg) => uacHighCm(kg) / 2 + 1;

/// ETT internal diameter (mm) by weight, per NRP: <1 kg 2.5, 1–2 kg 3.0,
/// over 2 kg 3.5.
double ettSizeMm(double kg) => kg < 1 ? 2.5 : (kg <= 2 ? 3.0 : 3.5);

/// Oral ETT depth at the lip, cm, by weight (Tochen 1979): kg + 6.
double ettDepthByWeightCm(double kg) => kg + 6;

/// Oral ETT depth at the lip, cm, by gestation (Kempley et al. 2008).
double? ettDepthByGestationCm(int weeks) => switch (weeks) {
      23 || 24 => 5.5,
      25 || 26 => 6.0,
      27 || 28 || 29 => 6.5,
      30 || 31 || 32 => 7.0,
      33 || 34 => 7.5,
      35 || 36 || 37 => 8.0,
      38 || 39 || 40 => 8.5,
      41 || 42 || 43 => 9.0,
      _ => null,
    };

// ── Infusions ───────────────────────────────────────────────────────────

enum DoseUnit {
  mcgPerKgMin('mcg/kg/min'),
  mcgPerKgHour('mcg/kg/h'),
  mgPerKgHour('mg/kg/h');

  const DoseUnit(this.label);
  final String label;

  /// The dose as mcg/kg/h.
  double toMcgPerKgHour(double dose) => switch (this) {
        mcgPerKgMin => dose * 60,
        mcgPerKgHour => dose,
        mgPerKgHour => dose * 1000,
      };
}

/// Pump rate (mL/h) for [dose] when [drugMg] is made up to [volumeMl].
double infusionRateMlPerHour({
  required double dose,
  required DoseUnit unit,
  required double kg,
  required double drugMg,
  required double volumeMl,
}) {
  final mcgPerMl = drugMg * 1000 / volumeMl;
  return unit.toMcgPerKgHour(dose) * kg / mcgPerMl;
}

/// The dose a pump rate delivers — the reverse of [infusionRateMlPerHour].
double doseFromRate({
  required double mlPerHour,
  required DoseUnit unit,
  required double kg,
  required double drugMg,
  required double volumeMl,
}) {
  final mcgPerKgHour = mlPerHour * (drugMg * 1000 / volumeMl) / kg;
  return switch (unit) {
    DoseUnit.mcgPerKgMin => mcgPerKgHour / 60,
    DoseUnit.mcgPerKgHour => mcgPerKgHour,
    DoseUnit.mgPerKgHour => mcgPerKgHour / 1000,
  };
}
