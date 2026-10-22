import '../models/patient.dart';
import 'bilirubin.dart';

/// Gestation (completed weeks) from which FolioMed uses AAP 2022; below it,
/// NICE CG98.
const int kAapFromWeeks = 35;

/// The guideline for a baby of [gestationWeeks]: NICE CG98 under 35 weeks,
/// AAP 2022 from 35 weeks. Null when the gestation isn't recorded.
BilirubinGuideline? guidelineForGestation(int? gestationWeeks) {
  if (gestationWeeks == null) return null;
  return gestationWeeks < kAapFromWeeks ? const NiceCg98() : const Aap2022();
}

/// A [BiliAssessment] with the guideline for the gestation, or a
/// [BiliNotApplicable] saying what is missing.
Object assessByGestation({
  required int? gestationWeeks,
  required double hoursOfAge,
  required double tsbUmol,
  bool? neuroRisk,
}) {
  final g = guidelineForGestation(gestationWeeks);
  if (g == null) {
    return const BiliNotApplicable(
        'Bilirubin', 'Add the gestational age to compare with guideline thresholds.');
  }
  return g.assess(
    gestationWeeks: gestationWeeks,
    hoursOfAge: hoursOfAge,
    tsbUmol: tsbUmol,
    neuroRisk: neuroRisk,
  );
}

/// Assesses a reading for [p] with the guideline for its gestation. Null
/// when it can't be applied (no birth time or gestation, or AAP before the
/// risk factors are recorded). The result names the guideline used.
BiliAssessment? assessForPatient(Patient p, DateTime measuredAt, double tsbUmol) {
  final born = p.bornAt;
  if (born == null) return null;
  final a = assessByGestation(
    gestationWeeks: p.gestationWeeks,
    hoursOfAge: measuredAt.difference(born).inMinutes / 60,
    tsbUmol: tsbUmol,
    neuroRisk: p.neuroRisk,
  );
  return a is BiliAssessment ? a : null;
}

/// Threshold lines (µmol/L by hours of age) for the chart, or null when
/// the guideline can't be drawn for this baby.
class ThresholdLines {
  const ThresholdLines(this.guideline, this.phototherapy, this.exchange, {this.escalation});
  final String guideline;
  final double? Function(double hours) phototherapy;
  final double? Function(double hours)? escalation;
  final double? Function(double hours) exchange;
}

ThresholdLines? linesForPatient(Patient p) {
  final ga = p.gestationWeeks;
  if (ga == null) return null;
  if (ga < kAapFromWeeks) {
    if (ga < NiceCg98.pretermFromWeeks) return null;
    return ThresholdLines('NICE CG98', (h) => NiceCg98.thresholdsFor(ga, h).phototherapy,
        (h) => NiceCg98.thresholdsFor(ga, h).exchange);
  }
  final risk = p.neuroRisk;
  if (risk == null || !Aap2022.isLoaded) return null;
  double? photo(double h) {
    final v = Aap2022.thresholdMgdl(ga, AapCurve.phototherapy, risk, h);
    return v == null ? null : mgdlToUmol(v);
  }
  double? exch(double h) {
    final v = Aap2022.thresholdMgdl(ga, AapCurve.exchange, risk, h);
    return v == null ? null : mgdlToUmol(v);
  }
  return ThresholdLines('AAP 2022', photo, exch, escalation: (h) {
    final e = exch(h);
    return e == null ? null : e - mgdlToUmol(2);
  });
}
