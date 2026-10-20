/// Neonatal jaundice decision support: compares a total serum bilirubin
/// (TSB) against published treatment thresholds for the baby's age in
/// hours and gestation.
///
/// DECISION SUPPORT ONLY. It never replaces the guideline chart or
/// clinical judgement, and the UI says so wherever a result is shown.
library;

import 'dart:convert';

/// 1 mg/dL of bilirubin = 17.1 µmol/L.
const double kBilirubinUmolPerMgdl = 17.1;

double mgdlToUmol(double mgdl) => mgdl * kBilirubinUmolPerMgdl;
double umolToMgdl(double umol) => umol / kBilirubinUmolPerMgdl;

enum BiliAction {
  /// Below the repeat-measurement line.
  none('No action at this level', 'Below the repeat-measurement threshold.'),

  /// At/above "repeat bilirubin measurement".
  repeat('Repeat bilirubin', 'Repeat the bilirubin measurement in 6–12 hours.'),

  /// AAP: within 2 mg/dL below the phototherapy threshold.
  approaching('Near phototherapy threshold',
      'Within 2 mg/dL of the phototherapy threshold — plan follow-up bilirubin.'),

  /// At/above "consider phototherapy and repeat in 6 hours".
  considerPhototherapy('Consider phototherapy',
      'Consider phototherapy and repeat the bilirubin in 6 hours.'),

  /// At/above "start phototherapy".
  phototherapy('Start phototherapy', 'Above the phototherapy threshold.'),

  /// AAP: at/above the escalation-of-care threshold (exchange − 2 mg/dL).
  escalation('Escalation of care',
      'At or above the escalation-of-care threshold — urgent intensive phototherapy and preparation for exchange.'),

  /// At/above the exchange transfusion threshold.
  exchange('Exchange transfusion threshold',
      'Above the exchange transfusion threshold — escalate now.');

  const BiliAction(this.label, this.detail);
  final String label;
  final String detail;
}

/// Thresholds (µmol/L) at one age.
class BiliThresholds {
  const BiliThresholds({
    this.repeat,
    this.considerPhototherapy,
    required this.phototherapy,
    this.escalation,
    required this.exchange,
  });

  /// NICE only.
  final double? repeat;
  final double? considerPhototherapy;
  final double phototherapy;

  /// AAP only: exchange − 2 mg/dL.
  final double? escalation;
  final double exchange;
}

class BiliAssessment {
  const BiliAssessment({
    required this.guideline,
    required this.hoursOfAge,
    required this.tsbUmol,
    required this.thresholds,
    required this.action,
  });

  final String guideline;
  final double hoursOfAge;
  final double tsbUmol;
  final BiliThresholds thresholds;
  final BiliAction action;

  /// How far below (negative) or above the phototherapy line, in µmol/L.
  double get marginToPhototherapy => tsbUmol - thresholds.phototherapy;
}

/// Why a guideline couldn't assess this baby.
class BiliNotApplicable {
  const BiliNotApplicable(this.guideline, this.reason);
  final String guideline;
  final String reason;
}

abstract class BilirubinGuideline {
  String get name;
  String get source;

  /// Returns a [BiliAssessment], or a [BiliNotApplicable] explaining why
  /// this guideline can't be applied. [neuroRisk]: true/false once the
  /// neurotoxicity risk factors have been assessed, null if not (AAP needs it).
  Object assess({
    required int? gestationWeeks,
    required double hoursOfAge,
    required double tsbUmol,
    bool? neuroRisk,
  });
}

/// NICE CG98 (Jaundice in newborn babies under 28 days), Table 1:
/// consensus-based thresholds for babies of 38 weeks or more, in 6-hour
/// steps; values between steps are linearly interpolated (as the NICE
/// treatment threshold graph is drawn), and 96 hours onwards is flat.
class NiceCg98 implements BilirubinGuideline {
  const NiceCg98();

  @override
  String get name => 'NICE CG98';

  @override
  String get source =>
      'NICE CG98 threshold table (≥38 weeks, last updated 2016; NICE flagged '
      'the thresholds for review in 2023). Check the current NICE table and '
      'your laboratory\'s assay before acting.';

  /// hours → [repeat, consider phototherapy, phototherapy, exchange]
  /// (µmol/L), as published; null = the cell is blank in the NICE table
  /// (no "repeat"/"consider" band at birth, no "repeat" band after 72 h).
  static const Map<int, List<double?>> table = {
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

  static BiliThresholds thresholdsAt(double hours) {
    final h = hours.clamp(0, 96).toDouble();
    final lower = (h ~/ 6) * 6;
    final upper = lower >= 96 ? 96 : lower + 6;
    final a = table[lower]!;
    final b = table[upper]!;
    final t = upper == lower ? 0.0 : (h - lower) / (upper - lower);
    // A blank cell at either end means no band between those rows.
    double? lerp(int i) {
      final x = a[i], y = b[i];
      if (t == 0) return x;
      if (x == null || y == null) return null;
      return x + (y - x) * t;
    }
    return BiliThresholds(
      repeat: lerp(0),
      considerPhototherapy: lerp(1),
      phototherapy: lerp(2)!,
      exchange: lerp(3)!,
    );
  }

  @override
  Object assess({
    required int? gestationWeeks,
    required double hoursOfAge,
    required double tsbUmol,
    bool? neuroRisk,
  }) {
    if (gestationWeeks == null) {
      return BiliNotApplicable(
          name, 'Add the gestational age to compare with NICE thresholds.');
    }
    if (gestationWeeks < 38) {
      return BiliNotApplicable(name,
          'NICE uses gestation-specific graphs below 38 weeks — not built in yet. Use the NICE preterm chart.');
    }
    if (hoursOfAge < 0) {
      return BiliNotApplicable(name, 'The sample time is before the birth time.');
    }
    final th = thresholdsAt(hoursOfAge);
    final action = tsbUmol > th.exchange
        ? BiliAction.exchange
        : tsbUmol > th.phototherapy
            ? BiliAction.phototherapy
            : th.considerPhototherapy != null && tsbUmol > th.considerPhototherapy!
                ? BiliAction.considerPhototherapy
                : th.repeat != null && tsbUmol > th.repeat!
                    ? BiliAction.repeat
                    : BiliAction.none;
    return BiliAssessment(
      guideline: name,
      hoursOfAge: hoursOfAge,
      tsbUmol: tsbUmol,
      thresholds: th,
      action: action,
    );
  }
}

/// AAP 2022 neurotoxicity risk factors (other than gestation, which
/// selects the curve). Any one of them selects the "with risk factors"
/// curves.
enum NeuroRiskFactor {
  isoimmune('Isoimmune haemolytic disease (positive DAT)'),
  g6pd('G6PD deficiency'),
  otherHaemolysis('Other haemolytic condition'),
  sepsis('Sepsis'),
  instability('Significant clinical instability in the past 24 h'),
  lowAlbumin('Albumin below 3.0 g/dL');

  const NeuroRiskFactor(this.label);
  final String label;

  static NeuroRiskFactor? fromName(String v) {
    for (final f in values) {
      if (f.name == v) return f;
    }
    return null;
  }
}

enum AapCurve { phototherapy, exchange }

/// AAP 2022 (Kemper et al., Pediatrics 2022;150(3):e2022058859) hourly
/// thresholds for infants born at 35 weeks or more, from Supplemental
/// Tables 1–4, loaded from `assets/clinical/aap2022_bilirubin.json`.
///
/// Rules implemented: the curve is chosen by gestational age and by
/// whether any neurotoxicity risk factor is present; thresholds are looked
/// up at completed hours of age (no interpolation — the tables are hourly);
/// after the last tabulated hour the threshold stays flat; "at or above"
/// a threshold counts as reaching it; escalation of care = exchange − 2.
class Aap2022 implements BilirubinGuideline {
  const Aap2022();

  static Map<String, dynamic>? _data;

  /// Whether the loaded dataset has been checked value-by-value against
  /// the AAP supplemental tables.
  static bool get dataVerified => _data?['verified'] == true;
  static bool get isLoaded => _data != null;

  static void loadJson(String json) => _data = jsonDecode(json) as Map<String, dynamic>;

  @override
  String get name => 'AAP 2022';

  @override
  String get source => dataVerified
      ? 'AAP 2022 Supplemental Tables 1–4 (35 weeks or more).'
      : 'AAP 2022 thresholds (35 weeks or more) — this dataset has not yet '
          'been checked against the AAP supplemental tables. Confirm on the AAP chart.';

  /// Curve key for the gestation: photo without risk uses 35–39 and 40 (=40+);
  /// everything else uses 35–37 and 38 (=38+).
  static String _gaKey(int weeks, AapCurve curve, bool risk) {
    final top = curve == AapCurve.phototherapy && !risk ? 40 : 38;
    return '${weeks.clamp(35, top)}';
  }

  /// Hourly thresholds (mg/dL) for one curve; index = completed hours.
  static List<double?>? curveValues(int weeks, AapCurve curve, bool risk) {
    final d = _data;
    if (d == null || weeks < 35) return null;
    final table = (d[curve == AapCurve.phototherapy ? 'phototherapy' : 'exchange']
        as Map<String, dynamic>)[risk ? 'with_risk' : 'no_risk'] as Map<String, dynamic>;
    final values = table[_gaKey(weeks, curve, risk)] as List<dynamic>?;
    return values?.map((v) => (v as num?)?.toDouble()).toList();
  }

  /// Threshold in mg/dL at [hours] of age, or null outside the data.
  static double? thresholdMgdl(int weeks, AapCurve curve, bool risk, double hours) {
    final v = curveValues(weeks, curve, risk);
    if (v == null || hours < 1) return null;
    final h = hours.floor();
    if (h < v.length) return v[h];
    for (var i = v.length - 1; i >= 0; i--) {
      if (v[i] != null) return v[i];
    }
    return null;
  }

  @override
  Object assess({
    required int? gestationWeeks,
    required double hoursOfAge,
    required double tsbUmol,
    bool? neuroRisk,
  }) {
    if (!isLoaded) return BiliNotApplicable(name, 'AAP thresholds could not be loaded.');
    if (gestationWeeks == null) {
      return BiliNotApplicable(name, 'Add the gestational age to compare with AAP thresholds.');
    }
    if (gestationWeeks < 35) {
      return BiliNotApplicable(name,
          'AAP 2022 covers babies born at 35 weeks or more — use a preterm chart.');
    }
    if (neuroRisk == null) {
      return BiliNotApplicable(name,
          'Record the neurotoxicity risk factors (patient page → Bilirubin) to compare with AAP thresholds.');
    }
    if (hoursOfAge < 1) {
      return BiliNotApplicable(name, 'AAP thresholds start at 1 hour of age.');
    }
    final photo = thresholdMgdl(gestationWeeks, AapCurve.phototherapy, neuroRisk, hoursOfAge);
    final exch = thresholdMgdl(gestationWeeks, AapCurve.exchange, neuroRisk, hoursOfAge);
    if (photo == null || exch == null) {
      return BiliNotApplicable(name, 'No AAP threshold for this age.');
    }
    final escal = exch - 2;
    final tsb = umolToMgdl(tsbUmol);
    // Compare in mg/dL (the table's unit) with 0.05 tolerance for rounding.
    bool atOrAbove(double t) => tsb >= t - 0.05;
    final action = atOrAbove(exch)
        ? BiliAction.exchange
        : atOrAbove(escal)
            ? BiliAction.escalation
            : atOrAbove(photo)
                ? BiliAction.phototherapy
                : atOrAbove(photo - 2)
                    ? BiliAction.approaching
                    : BiliAction.none;
    return BiliAssessment(
      guideline: name,
      hoursOfAge: hoursOfAge,
      tsbUmol: tsbUmol,
      thresholds: BiliThresholds(
        phototherapy: mgdlToUmol(photo),
        escalation: mgdlToUmol(escal),
        exchange: mgdlToUmol(exch),
      ),
      action: action,
    );
  }
}

/// Rate of rise between the last two readings, mg/dL per hour (null if
/// fewer than two readings or no time between them).
double? riseRateMgdlPerHour(List<({DateTime at, double umol})> readings) {
  if (readings.length < 2) return null;
  final sorted = [...readings]..sort((a, b) => a.at.compareTo(b.at));
  final a = sorted[sorted.length - 2], b = sorted.last;
  final hours = b.at.difference(a.at).inMinutes / 60;
  if (hours <= 0) return null;
  return (umolToMgdl(b.umol) - umolToMgdl(a.umol)) / hours;
}

/// AAP 2022: a rise of ≥0.3 mg/dL/h in the first 24 h, or ≥0.2 mg/dL/h
/// after, suggests haemolysis.
bool isRapidRise(double rateMgdlPerHour, double ageHours) =>
    rateMgdlPerHour >= (ageHours < 24 ? 0.3 : 0.2) - 1e-9;

const List<BilirubinGuideline> kBilirubinGuidelines = [NiceCg98(), Aap2022()];
