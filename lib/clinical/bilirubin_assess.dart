import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient.dart';
import 'bilirubin.dart';

enum GuidelineChoice {
  aap('AAP 2022'),
  nice('NICE');

  const GuidelineChoice(this.label);
  final String label;
}

/// Which guideline the ward prefers on this device (chart lines, alerts,
/// handover). Defaults to AAP 2022, which covers 35 weeks and up.
class GuidelinePreference {
  GuidelinePreference._();
  static const _key = 'bilirubin_guideline_v1';
  static final ValueNotifier<GuidelineChoice> choice = ValueNotifier(GuidelineChoice.aap);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      choice.value = prefs.getString(_key) == 'nice' ? GuidelineChoice.nice : GuidelineChoice.aap;
    } catch (_) {}
  }

  static Future<void> set(GuidelineChoice c) async {
    choice.value = c;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, c.name);
    } catch (_) {}
  }
}

BilirubinGuideline guidelineFor(GuidelineChoice c) =>
    c == GuidelineChoice.aap ? const Aap2022() : const NiceCg98();

/// Assesses a reading for [p] with the preferred guideline, falling back to
/// the other when the preferred one can't be applied (e.g. AAP before risk
/// factors are recorded, NICE below 38 weeks). Null if neither applies.
/// The result names the guideline actually used.
BiliAssessment? assessForPatient(Patient p, DateTime measuredAt, double tsbUmol,
    {GuidelineChoice? prefer}) {
  final born = p.bornAt;
  if (born == null) return null;
  final hours = measuredAt.difference(born).inMinutes / 60;
  final first = prefer ?? GuidelinePreference.choice.value;
  for (final c in [first, ...GuidelineChoice.values.where((x) => x != first)]) {
    final a = guidelineFor(c).assess(
      gestationWeeks: p.gestationWeeks,
      hoursOfAge: hours,
      tsbUmol: tsbUmol,
      neuroRisk: p.neuroRisk,
    );
    if (a is BiliAssessment) return a;
  }
  return null;
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

ThresholdLines? linesForPatient(Patient p, GuidelineChoice c) {
  final ga = p.gestationWeeks;
  if (ga == null) return null;
  if (c == GuidelineChoice.nice) {
    if (ga < 38) return null;
    return ThresholdLines('NICE CG98',
        (h) => NiceCg98.thresholdsAt(h).phototherapy, (h) => NiceCg98.thresholdsAt(h).exchange);
  }
  final risk = p.neuroRisk;
  if (ga < 35 || risk == null || !Aap2022.isLoaded) return null;
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
