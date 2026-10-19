/// Neonatal jaundice decision support: compares a total serum bilirubin
/// (TSB) against published treatment thresholds for the baby's age in
/// hours and gestation.
///
/// DECISION SUPPORT ONLY. It never replaces the guideline chart or
/// clinical judgement, and the UI says so wherever a result is shown.
library;

/// 1 mg/dL of bilirubin = 17.1 µmol/L.
const double kBilirubinUmolPerMgdl = 17.1;

double mgdlToUmol(double mgdl) => mgdl * kBilirubinUmolPerMgdl;
double umolToMgdl(double umol) => umol / kBilirubinUmolPerMgdl;

enum BiliAction {
  /// Below the repeat-measurement line.
  none('No action at this level', 'Below the repeat-measurement threshold.'),

  /// At/above "repeat bilirubin measurement".
  repeat('Repeat bilirubin', 'Repeat the bilirubin measurement.'),

  /// At/above "consider phototherapy and repeat in 6 hours".
  considerPhototherapy('Consider phototherapy',
      'Consider phototherapy and repeat the bilirubin in 6 hours.'),

  /// At/above "start phototherapy".
  phototherapy('Start phototherapy', 'Above the phototherapy threshold.'),

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
    required this.repeat,
    required this.considerPhototherapy,
    required this.phototherapy,
    required this.exchange,
  });

  final double repeat;
  final double considerPhototherapy;
  final double phototherapy;
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
  /// this guideline can't be applied.
  Object assess({
    required int? gestationWeeks,
    required double hoursOfAge,
    required double tsbUmol,
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
      'NICE CG98 Table 1 (≥38 weeks). Verify against the published NICE '
      'threshold table/graph before acting.';

  /// hours → [repeat, consider phototherapy, phototherapy, exchange] (µmol/L)
  static const Map<int, List<double>> table = {
    0: [100, 100, 100, 100],
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
    78: [212, 262, 312, 450],
    84: [225, 275, 325, 450],
    90: [237, 287, 337, 450],
    96: [250, 300, 350, 450],
  };

  static BiliThresholds thresholdsAt(double hours) {
    final h = hours.clamp(0, 96).toDouble();
    final lower = (h ~/ 6) * 6;
    final upper = lower >= 96 ? 96 : lower + 6;
    final a = table[lower]!;
    final b = table[upper]!;
    final t = upper == lower ? 0.0 : (h - lower) / (upper - lower);
    double lerp(int i) => a[i] + (b[i] - a[i]) * t;
    return BiliThresholds(
      repeat: lerp(0),
      considerPhototherapy: lerp(1),
      phototherapy: lerp(2),
      exchange: lerp(3),
    );
  }

  @override
  Object assess({
    required int? gestationWeeks,
    required double hoursOfAge,
    required double tsbUmol,
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
            : tsbUmol > th.considerPhototherapy
                ? BiliAction.considerPhototherapy
                : tsbUmol > th.repeat
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

/// AAP 2022 (Kemper et al., Pediatrics 2022) thresholds depend on
/// gestation (35–40+ weeks), hour of age and neurotoxicity risk factors.
/// The threshold tables are not yet loaded into FolioMed, so this reports
/// itself as unavailable rather than guessing.
class Aap2022 implements BilirubinGuideline {
  const Aap2022();

  @override
  String get name => 'AAP 2022';

  @override
  String get source => 'AAP 2022 hyperbilirubinemia guideline.';

  @override
  Object assess({
    required int? gestationWeeks,
    required double hoursOfAge,
    required double tsbUmol,
  }) =>
      BiliNotApplicable(name,
          'AAP 2022 thresholds are not built in yet — use the AAP chart or the official Bilitool.');
}

const List<BilirubinGuideline> kBilirubinGuidelines = [NiceCg98(), Aap2022()];
