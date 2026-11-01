/// Resuscitation card numbers for a child by age (and weight when known).
/// Formulas: APLS (estimated weight, normal vital signs), PALS 2020
/// (hypotension, shock energy), standard tube and airway sizing.
library;

/// APLS estimated weight (kg) from age in months; null over 12 years
/// (weigh the child).
double? estimatedWeightKg(double ageMonths) {
  if (ageMonths < 0) return null;
  if (ageMonths < 12) return 0.5 * ageMonths + 4;
  final years = ageMonths / 12;
  if (years < 6) return 2 * years.floor() + 8;
  if (years <= 12) return 3 * years.floor() + 7.0;
  return null;
}

class VitalRanges {
  const VitalRanges(this.ageBand, this.rr, this.hr, this.sbp);
  final String ageBand;
  final (int, int) rr, hr, sbp;
}

/// APLS normal ranges at rest.
VitalRanges normalVitals(double ageMonths) {
  final y = ageMonths / 12;
  if (y < 1) return const VitalRanges('Under 1 year', (30, 40), (110, 160), (70, 90));
  if (y < 2) return const VitalRanges('1–2 years', (25, 35), (100, 150), (80, 95));
  if (y < 5) return const VitalRanges('2–5 years', (25, 30), (95, 140), (80, 100));
  if (y <= 12) return const VitalRanges('5–12 years', (20, 25), (80, 120), (90, 110));
  return const VitalRanges('Over 12 years', (15, 20), (60, 100), (100, 120));
}

/// PALS: systolic BP below this is hypotension.
int hypotensionSbp(double ageMonths) {
  if (ageMonths < 1) return 60;
  if (ageMonths < 12) return 70;
  final y = ageMonths / 12;
  if (y <= 10) return 70 + 2 * y.floor();
  return 90;
}

class TubeSizes {
  const TubeSizes({required this.cuffed, required this.uncuffed, required this.oralCm, required this.suctionFr});
  final double cuffed, uncuffed;

  /// Oral tube depth at the lips.
  final double oralCm;
  final int suctionFr;
}

/// From 1 year: cuffed = age/4 + 3.5, uncuffed = age/4 + 4 (mm ID),
/// oral depth = age/2 + 12 cm. Under 1 year: cuffed 3.0–3.5, uncuffed
/// 3.5–4.0 (the lower value is returned). Null in the first month — size
/// newborn tubes by weight (Lines & Tubes).
TubeSizes? tubeSizes(double ageMonths) {
  if (ageMonths < 1) return null;
  if (ageMonths < 12) return const TubeSizes(cuffed: 3.0, uncuffed: 3.5, oralCm: 10.5, suctionFr: 8);
  final y = (ageMonths / 12).floorToDouble();
  double half(double v) => (v * 2).round() / 2;
  final uncuffed = half(y / 4 + 4);
  return TubeSizes(
    cuffed: half(y / 4 + 3.5),
    uncuffed: uncuffed,
    oralCm: y / 2 + 12,
    suctionFr: (uncuffed * 2).round(),
  );
}

/// Laryngeal mask size by weight.
String lmaSize(double kg) {
  if (kg < 5) return '1';
  if (kg < 10) return '1½';
  if (kg < 20) return '2';
  if (kg < 30) return '2½';
  if (kg < 50) return '3';
  if (kg < 70) return '4';
  return '5';
}

/// Shocks (J), rounded to whole joules: (first, second) for VF / pulseless
/// VT; (first, second) for synchronised cardioversion.
({int vf1, int vf2, int cv1, int cv2}) shockEnergies(double kg) =>
    (vf1: (2 * kg).round(), vf2: (4 * kg).round(), cv1: (0.5 * kg).round().clamp(1, 1000), cv2: (2 * kg).round());
