/// WHO growth: z-scores and centiles from the LMS tables in
/// `assets/clinical/who_growth.json` — WHO Child Growth Standards (2006)
/// for 0–5 years and the WHO Growth Reference (2007) for 5–19 years.
/// Ages are in months (days ÷ 30.4375); values between months are
/// interpolated.
library;

import 'dart:convert';
import 'dart:math' as math;

enum GrowthIndicator {
  weight('Weight-for-age', 'Weight', 'kg', 'wfa'),
  length('Length/height-for-age', 'Length / height', 'cm', 'lhfa'),
  head('Head circumference-for-age', 'Head', 'cm', 'hcfa'),
  bmi('BMI-for-age', 'BMI', 'kg/m²', 'bmi');

  const GrowthIndicator(this.title, this.short, this.unit, this.key);
  final String title;
  final String short;
  final String unit;
  final String key;

  /// WHO restricts the LMS curve beyond ±3 SD for weight-based measures.
  bool get adjustsTails => this == weight || this == bmi;
}

const kDaysPerMonth = 30.4375;

class Lms {
  const Lms(this.l, this.m, this.s);
  final double l, m, s;

  /// The measurement at z-score [z].
  double valueAt(double z) => l.abs() < 1e-9 ? m * math.exp(s * z) : m * math.pow(1 + l * s * z, 1 / l).toDouble();

  double rawZ(double x) => l.abs() < 1e-9 ? math.log(x / m) / s : (math.pow(x / m, l) - 1) / (l * s);
}

class WhoGrowth {
  WhoGrowth._();

  static Map<String, Map<String, List<List<double>>>>? _data;
  static bool get isLoaded => _data != null;

  static void loadJson(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    final sexes = raw['sexes'] as Map<String, dynamic>;
    _data = {
      for (final s in sexes.entries)
        s.key: {
          for (final i in (s.value as Map<String, dynamic>).entries)
            i.key: [for (final r in i.value as List) (r as List).map((n) => (n as num).toDouble()).toList()],
        },
    };
  }

  static List<List<double>>? _table(GrowthIndicator ind, bool male) => _data?[male ? 'boys' : 'girls']?[ind.key];

  /// (first, last) month the table covers.
  static (double, double)? range(GrowthIndicator ind, bool male) {
    final t = _table(ind, male);
    return t == null || t.isEmpty ? null : (t.first[0], t.last[0]);
  }

  static Lms? lmsAt(GrowthIndicator ind, bool male, double months) {
    final t = _table(ind, male);
    if (t == null || t.isEmpty || months < t.first[0] || months > t.last[0]) return null;
    for (var i = 0; i < t.length; i++) {
      final r = t[i];
      if ((r[0] - months).abs() < 1e-9) return Lms(r[1], r[2], r[3]);
      if (r[0] > months) {
        final a = t[i - 1];
        final f = (months - a[0]) / (r[0] - a[0]);
        double lerp(int j) => a[j] + (r[j] - a[j]) * f;
        return Lms(lerp(1), lerp(2), lerp(3));
      }
    }
    return null;
  }

  /// z-score of [value] at [months], or null outside the tables.
  static double? zScore(GrowthIndicator ind, bool male, double months, double value) {
    final lms = lmsAt(ind, male, months);
    if (lms == null || value <= 0) return null;
    final z = lms.rawZ(value);
    if (!ind.adjustsTails || z.abs() <= 3) return z;
    // WHO's restricted application of the LMS method beyond ±3 SD.
    final sd3 = lms.valueAt(z > 0 ? 3 : -3), sd2 = lms.valueAt(z > 0 ? 2 : -2);
    return z > 0 ? 3 + (value - sd3) / (sd3 - sd2) : -3 + (value - sd3) / (sd2 - sd3);
  }

  /// The curve value at [months] for z-score [z].
  static double? valueAt(GrowthIndicator ind, bool male, double months, double z) =>
      lmsAt(ind, male, months)?.valueAt(z);
}

/// Standard normal cumulative distribution (Abramowitz–Stegun 7.1.26).
double normalCdf(double z) {
  final t = 1 / (1 + 0.3275911 * z.abs() / math.sqrt2);
  final y = 1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) *
          t *
          math.exp(-z * z / 2);
  return z >= 0 ? (1 + y) / 2 : (1 - y) / 2;
}

/// "12th centile", "below the 0.1st", "above the 99.9th".
String centileText(double z) {
  final c = normalCdf(z) * 100;
  if (c < 0.1) return 'below the 0.1st centile';
  if (c > 99.9) return 'above the 99.9th centile';
  final r = c < 1 || c > 99 ? double.parse(c.toStringAsFixed(1)) : c.roundToDouble();
  final n = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  final last = n.endsWith('11') || n.endsWith('12') || n.endsWith('13')
      ? 'th'
      : switch (n[n.length - 1]) { '1' => 'st', '2' => 'nd', '3' => 'rd', _ => 'th' };
  return '$n$last centile';
}

/// WHO's plain-language reading of a z-score for each indicator.
String? growthReading(GrowthIndicator ind, double z, double months) => switch (ind) {
      GrowthIndicator.weight when z < -3 => 'Severely underweight',
      GrowthIndicator.weight when z < -2 => 'Underweight',
      GrowthIndicator.length when z < -3 => 'Severely stunted',
      GrowthIndicator.length when z < -2 => 'Stunted',
      GrowthIndicator.length when z > 3 => 'Very tall',
      GrowthIndicator.head when z < -2 => 'Small head (below −2 SD)',
      GrowthIndicator.head when z > 2 => 'Large head (above +2 SD)',
      GrowthIndicator.bmi when z < -3 => 'Severe thinness',
      GrowthIndicator.bmi when z < -2 => 'Thinness',
      GrowthIndicator.bmi when z > 2 => 'Obesity',
      GrowthIndicator.bmi when z > 1 => 'Overweight',
      _ => null,
    };

/// Age in months for plotting: chronological, corrected for prematurity
/// (to 40 weeks) when born before 37 weeks and under 24 months corrected.
({double months, bool corrected}) plotAge({
  required DateTime born,
  required DateTime on,
  int? gestationWeeks,
}) {
  final chrono = on.difference(born).inHours / 24 / kDaysPerMonth;
  final ga = gestationWeeks;
  if (ga != null && ga < 37) {
    final corrected = chrono - (40 - ga) * 7 / kDaysPerMonth;
    if (corrected < 24) return (months: math.max(0, corrected), corrected: true);
  }
  return (months: chrono, corrected: false);
}

double bmiOf(double kg, double cm) => kg / math.pow(cm / 100, 2);
