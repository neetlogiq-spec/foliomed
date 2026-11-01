/// Step-by-step emergency guides with weight-based doses.
library;

/// A dose worked out for the weight: [min]–[max] per kg, limited to
/// [maxDose] (same unit, absolute).
class GuideDose {
  const GuideDose(this.label, this.min, this.max, this.unit, {this.maxDose, this.how});
  final String label;
  final double min, max;

  /// Amount unit ("mg", "mL", "units", "mcg").
  final String unit;
  final double? maxDose;

  /// Route and rate, e.g. "IV over 10 min".
  final String? how;

  /// (low, high, capped) for [kg].
  (double, double, bool) forWeight(double kg) {
    double cap(double v) => maxDose == null || v <= maxDose! ? v : maxDose!;
    return (cap(min * kg), cap(max * kg), maxDose != null && max * kg > maxDose! + 1e-9);
  }

  String get perKg {
    String n(double v) => v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    final range = (max - min).abs() < 1e-9 ? n(min) : '${n(min)}–${n(max)}';
    return '$range $unit/kg${maxDose == null ? '' : ' (max ${n(maxDose!)} $unit)'}';
  }
}

class GuideStep {
  const GuideStep(this.title, {this.when, this.points = const [], this.doses = const [], this.caution});
  final String title;

  /// Timing, e.g. "0–5 min".
  final String? when;
  final List<String> points;
  final List<GuideDose> doses;
  final String? caution;
}

class Guide {
  const Guide({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.steps,
    this.redFlags = const [],
    this.needsWeight = true,
  });

  final String key;
  final String title;
  final String subtitle;
  final String source;
  final List<String> redFlags;
  final List<GuideStep> steps;
  final bool needsWeight;
}
