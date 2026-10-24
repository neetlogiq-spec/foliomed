import '../models/patient.dart';
import 'bilirubin.dart';

enum GuidelineChoice {
  aap('AAP 2022'),
  nice('NICE');

  const GuidelineChoice(this.label);
  final String label;
}

/// AAP 2022 covers 35 weeks and up; NICE (gestation-specific graphs) is
/// used below that.
const int kAapMinWeeks = 35;

/// The guideline for a baby's gestation: NICE below 35 weeks, AAP 2022 at
/// 35 weeks or more. Null until the gestational age is recorded.
GuidelineChoice? guidelineForGestation(int? weeks) {
  if (weeks == null) return null;
  return weeks < kAapMinWeeks ? GuidelineChoice.nice : GuidelineChoice.aap;
}

BilirubinGuideline guidelineFor(GuidelineChoice c) =>
    c == GuidelineChoice.aap ? const Aap2022() : const NiceCg98();

/// Assesses a reading for [p] with the guideline for its gestation
/// (BiliAssessment), or explains why it can't (BiliNotApplicable — e.g.
/// no gestational age, or AAP before risk factors are recorded).
Object assessReading(Patient p, DateTime measuredAt, double tsbUmol) {
  final born = p.bornAt;
  if (born == null) {
    return const BiliNotApplicable('Bilirubin', 'Add the date and time of birth.');
  }
  final c = guidelineForGestation(p.gestationWeeks);
  if (c == null) {
    return const BiliNotApplicable(
        'Bilirubin', 'Add the gestational age (Edit details) to compare with guideline thresholds.');
  }
  return guidelineFor(c).assess(
    gestationWeeks: p.gestationWeeks,
    hoursOfAge: measuredAt.difference(born).inMinutes / 60,
    tsbUmol: tsbUmol,
    neuroRisk: p.neuroRisk,
  );
}

/// [assessReading] when it gives a result, else null.
BiliAssessment? assessForPatient(Patient p, DateTime measuredAt, double tsbUmol) {
  final a = assessReading(p, measuredAt, tsbUmol);
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
  final c = guidelineForGestation(ga);
  if (ga == null || c == null) return null;
  if (c == GuidelineChoice.nice) {
    if (ga < NiceCg98.minPretermWeeks) return null;
    return ThresholdLines('NICE CG98', (h) => NiceCg98.thresholdsFor(ga, h)!.phototherapy,
        (h) => NiceCg98.thresholdsFor(ga, h)!.exchange);
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
