/// Early-warning scores from a set of observations.
///
/// * NEWS2 (Royal College of Physicians, National Early Warning Score 2,
///   2017) for patients aged 16 and over. Not validated in pregnancy or
///   under 16 — the UI says so.
/// * Brighton PEWS (Monaghan 2005) for children from 28 days to under 16
///   years. Behaviour, cardiovascular and respiratory are scored 0–3 by
///   staff from the chart descriptions (the "normal for age" ranges they
///   refer to differ between hospitals, so none are built in); +2 for
///   quarter-hourly nebulisers or persistent post-operative vomiting.
/// * No score under 28 days.
///
/// Not yet signed off clinically ([kEarlyWarningVerified] = false shows
/// the "not yet checked" banner). DECISION SUPPORT ONLY.
library;

import '../models/observation.dart';
import '../models/patient.dart';

/// Flip only after clinical sign-off of the NEWS2 table and the PEWS
/// bands below.
const bool kEarlyWarningVerified = false;

enum EarlyWarningKind {
  news2('NEWS2'),
  pews('PEWS');

  const EarlyWarningKind(this.label);
  final String label;
}

/// Age in days from the birth time, else from the recorded age (taken as
/// the age on admission, so it's approximate).
double? ageInDays(Patient p, DateTime now) {
  if (p.bornAt != null) return now.difference(p.bornAt!).inMinutes / (60 * 24);
  if (p.age <= 0 && p.ageUnit != AgeUnit.days) return null;
  return switch (p.ageUnit) {
    AgeUnit.days => p.age.toDouble(),
    AgeUnit.months => p.age * 30.44,
    AgeUnit.years => p.age * 365.25,
  };
}

/// Which score applies: NEWS2 from 16 years, PEWS from 28 days, else none.
EarlyWarningKind? earlyWarningFor(Patient p, DateTime now) {
  final days = ageInDays(p, now);
  if (days == null) return null;
  if (days >= 16 * 365.25) return EarlyWarningKind.news2;
  if (days >= 28) return EarlyWarningKind.pews;
  return null;
}

/// Response band. [low] = routine, [lowMedium] = a single parameter
/// scoring 3 (NEWS2) / PEWS 3, [medium] = urgent review, [high] =
/// emergency response.
enum EarlyWarningBand {
  low('Low'),
  lowMedium('Low–medium'),
  medium('Medium'),
  high('High');

  const EarlyWarningBand(this.label);
  final String label;
}

class EarlyWarningScore {
  const EarlyWarningScore({
    required this.kind,
    required this.total,
    required this.band,
    required this.complete,
    required this.parts,
    this.missing = const [],
  });

  final EarlyWarningKind kind;
  final int total;
  final EarlyWarningBand band;

  /// Every parameter was recorded. An incomplete score is a lower bound.
  final bool complete;

  /// Parameter → points, in chart order.
  final Map<String, int> parts;
  final List<String> missing;

  bool get anySingleThree => parts.values.any((v) => v >= 3);

  /// "NEWS2 6 · Medium" / "PEWS 2 (incomplete)".
  String get label => '${kind.label} $total'
      '${complete ? ' · ${band.label}' : ' (incomplete — ${missing.join(', ')} missing)'}';

  /// What the band asks for, in one line.
  String get response => switch ((kind, band)) {
        (EarlyWarningKind.news2, EarlyWarningBand.high) =>
          'Emergency response — urgent assessment by a clinical team with critical-care skills.',
        (EarlyWarningKind.news2, EarlyWarningBand.medium) =>
          'Urgent response — urgent review by a clinician; consider critical-care outreach.',
        (EarlyWarningKind.news2, EarlyWarningBand.lowMedium) =>
          'A single parameter scores 3 — urgent ward-based review by a clinician.',
        (EarlyWarningKind.news2, EarlyWarningBand.low) =>
          total == 0 ? 'Routine observations.' : 'Assessment by a registered nurse; decide on frequency.',
        (EarlyWarningKind.pews, EarlyWarningBand.high) =>
          'Any component scoring 3, or a total of 4 or more — doctor review now.',
        (EarlyWarningKind.pews, EarlyWarningBand.medium) =>
          'Total of 4 or more — doctor review now.',
        (EarlyWarningKind.pews, EarlyWarningBand.lowMedium) =>
          'Total of 3 — increase observations and tell the nurse in charge.',
        (EarlyWarningKind.pews, EarlyWarningBand.low) => 'Routine observations.',
      };
}

// ── NEWS2 (RCP 2017, chart 1) ────────────────────────────────────────

int news2RespRate(int rr) => rr <= 8 ? 3 : rr <= 11 ? 1 : rr <= 20 ? 0 : rr <= 24 ? 2 : 3;

/// Scale 1 (most patients).
int news2Spo2Scale1(int s) => s <= 91 ? 3 : s <= 93 ? 2 : s <= 95 ? 1 : 0;

/// Scale 2 (prescribed target 88–92%): above 92% scores only on oxygen.
int news2Spo2Scale2(int s, {required bool onOxygen}) {
  if (s <= 83) return 3;
  if (s <= 85) return 2;
  if (s <= 87) return 1;
  if (s <= 92 || !onOxygen) return 0;
  return s <= 94 ? 1 : s <= 96 ? 2 : 3;
}

int news2Oxygen(bool onOxygen) => onOxygen ? 2 : 0;

int news2SystolicBp(int sbp) => sbp <= 90 ? 3 : sbp <= 100 ? 2 : sbp <= 110 ? 1 : sbp <= 219 ? 0 : 3;

int news2Pulse(int hr) => hr <= 40 ? 3 : hr <= 50 ? 1 : hr <= 90 ? 0 : hr <= 110 ? 1 : hr <= 130 ? 2 : 3;

int news2Consciousness(Consciousness c) => c == Consciousness.alert ? 0 : 3;

/// Temperatures are recorded to one decimal place.
int news2Temp(double t) {
  final x = (t * 10).round() / 10;
  return x <= 35.0 ? 3 : x <= 36.0 ? 1 : x <= 38.0 ? 0 : x <= 39.0 ? 1 : 2;
}

EarlyWarningScore news2(Observation o) {
  final parts = <String, int>{};
  final missing = <String>[];
  void part(String name, int? Function() score) {
    final v = score();
    if (v == null) {
      missing.add(name);
    } else {
      parts[name] = v;
    }
  }

  part('Respiration rate', () => o.respRate == null ? null : news2RespRate(o.respRate!));
  part('SpO₂', () {
    final s = o.spo2;
    if (s == null) return null;
    if (o.spo2Scale2) return o.onOxygen == null ? null : news2Spo2Scale2(s, onOxygen: o.onOxygen!);
    return news2Spo2Scale1(s);
  });
  part('Air or oxygen', () => o.onOxygen == null ? null : news2Oxygen(o.onOxygen!));
  part('Systolic BP', () => o.systolicBp == null ? null : news2SystolicBp(o.systolicBp!));
  part('Pulse', () => o.heartRate == null ? null : news2Pulse(o.heartRate!));
  part('Consciousness', () => o.consciousness == null ? null : news2Consciousness(o.consciousness!));
  part('Temperature', () => o.tempC == null ? null : news2Temp(o.tempC!));

  final total = parts.values.fold(0, (a, b) => a + b);
  final band = total >= 7
      ? EarlyWarningBand.high
      : total >= 5
          ? EarlyWarningBand.medium
          : parts.values.any((v) => v >= 3)
              ? EarlyWarningBand.lowMedium
              : EarlyWarningBand.low;
  return EarlyWarningScore(
      kind: EarlyWarningKind.news2, total: total, band: band, complete: missing.isEmpty, parts: parts, missing: missing);
}

// ── Brighton PEWS (Monaghan 2005) ────────────────────────────────────

/// Chart descriptions for each 0–3 score, shown when staff pick one.
const List<String> kPewsBehaviour = [
  'Playing / appropriate',
  'Sleeping',
  'Irritable',
  'Lethargic / confused, or reduced response to pain',
];
const List<String> kPewsCardio = [
  'Pink, or capillary refill 1–2 s',
  'Pale, or capillary refill 3 s',
  'Grey, or capillary refill 4 s, or heart rate 20 above normal',
  'Grey and mottled, or capillary refill 5 s or more, or heart rate 30 above normal, or bradycardia',
];
const List<String> kPewsResp = [
  'Within normal parameters, no recession or tracheal tug',
  'More than 10 above normal, using accessory muscles, or 30%+ FiO₂ or 3+ L/min',
  'More than 20 above normal, recession, tracheal tug, or 40%+ FiO₂ or 6+ L/min',
  '5 below normal with sternal recession, tracheal tug or grunting, or 50%+ FiO₂ or 8+ L/min',
];

EarlyWarningScore pews(Observation o) {
  final parts = <String, int>{};
  final missing = <String>[];
  for (final (name, v) in [
    ('Behaviour', o.pewsBehaviour),
    ('Cardiovascular', o.pewsCardio),
    ('Respiratory', o.pewsResp),
  ]) {
    if (v == null) {
      missing.add(name);
    } else {
      parts[name] = v;
    }
  }
  if (o.pewsExtra) parts['Nebulisers / vomiting'] = 2;
  final total = parts.values.fold(0, (a, b) => a + b);
  final single3 = [o.pewsBehaviour, o.pewsCardio, o.pewsResp].any((v) => v == 3);
  final band = single3
      ? EarlyWarningBand.high
      : total >= 4
          ? EarlyWarningBand.medium
          : total == 3
              ? EarlyWarningBand.lowMedium
              : EarlyWarningBand.low;
  return EarlyWarningScore(
      kind: EarlyWarningKind.pews, total: total, band: band, complete: missing.isEmpty, parts: parts, missing: missing);
}

/// The score for [p] from [o], or null when none applies (under 28 days,
/// unknown age) or nothing scorable was recorded.
EarlyWarningScore? scoreObservation(Patient p, Observation o, DateTime now) {
  final s = switch (earlyWarningFor(p, now)) {
    EarlyWarningKind.news2 => news2(o),
    EarlyWarningKind.pews => pews(o),
    null => null,
  };
  return s == null || s.parts.isEmpty ? null : s;
}
