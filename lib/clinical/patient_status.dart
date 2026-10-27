/// The green / amber / red status dot for a patient.
///
/// Three layers, the most serious wins:
/// 1. the status staff set by hand (Stable / Watch / Sick),
/// 2. ward tasks (urgent notes to confirm, overdue reminders, urgent or
///    overdue jobs),
/// 3. automatic rules for the ward's type ([WardKind]) — newborn bilirubin
///    and weight on PNC/NICU, support tags on PICU. A ward of type
///    "Other" uses the newborn rules for babies under 28 days.
///
/// Staff can always raise the colour; an automatic red stays until its
/// cause is cleared. A hand-set status not reviewed within
/// [WardKind.reviewEvery] is shown faded ("Review status").
///
/// DECISION SUPPORT ONLY — a prompt to look, never a diagnosis.
library;

import '../models/newborn_tracking.dart';
import '../models/patient.dart';
import '../models/ward.dart';
import 'bilirubin.dart';
import 'bilirubin_assess.dart';

/// Status staff set by hand.
enum Acuity {
  stable('Stable'),
  watch('Watch'),
  sick('Sick');

  const Acuity(this.label);
  final String label;

  static Acuity? fromName(String? v) {
    for (final a in values) {
      if (a.name == v) return a;
    }
    return null;
  }

  StatusLevel get level => switch (this) {
        stable => StatusLevel.ok,
        watch => StatusLevel.watch,
        sick => StatusLevel.act,
      };
}

/// Organ support ticked by staff (mostly PICU). Names match the database
/// check constraint.
enum SupportTag {
  ventilated('Ventilated'),
  niv('NIV / HFNC'),
  inotropes('Inotropes'),
  centralLine('Central line'),
  crrt('CRRT'),
  sedation('Sedation');

  const SupportTag(this.label);
  final String label;

  static SupportTag? fromName(String v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

/// Dot colours, least to most serious. [unknown] = staff-led ward and
/// no status set yet (grey).
enum StatusLevel { unknown, ok, watch, act }

extension WardKindStatus on WardKind {
  /// Wards where the colour mostly comes from staff (no automatic data).
  bool get staffLed => this == WardKind.picu || this == WardKind.paeds || this == WardKind.adult;

  /// A hand-set status older than this is shown as "Review status".
  Duration get reviewEvery =>
      this == WardKind.picu ? const Duration(hours: 12) : const Duration(hours: 24);

  /// Whether the newborn rules apply to [p] on this ward.
  bool newbornRulesFor(Patient p, DateTime now) => switch (this) {
        WardKind.pnc || WardKind.nicu => p.bornAt != null,
        WardKind.other => p.bornAt != null && now.difference(p.bornAt!) < const Duration(days: 28),
        _ => false,
      };
}

/// What a reason is about (the row shows an icon for some).
enum StatusTopic { staff, review, tasks, bilirubin, phototherapy, weight, missingData, support }

/// One thing behind the colour.
class StatusReason {
  const StatusReason(this.level, this.text, [this.topic = StatusTopic.staff]);
  final StatusLevel level;
  final String text;
  final StatusTopic topic;

  @override
  String toString() => '$level: $text';
}

class PatientStatusResult {
  const PatientStatusResult(this.level, this.reasons, {this.needsReview = false});

  final StatusLevel level;

  /// Most serious first.
  final List<StatusReason> reasons;

  /// A hand-set status that's older than the ward's review window.
  final bool needsReview;

  bool get needsAttention => level == StatusLevel.watch || level == StatusLevel.act;

  /// "Needs action", "Watch", "Settled", "No status".
  String get label => switch (level) {
        StatusLevel.act => 'Needs action',
        StatusLevel.watch => 'Watch',
        StatusLevel.ok => 'Settled',
        StatusLevel.unknown => 'No status',
      };
}

/// Everything the rules look at for one patient.
class StatusInputs {
  const StatusInputs({
    required this.patient,
    required this.wardKind,
    required this.now,
    this.urgentNotes = 0,
    this.overdueReminders = 0,
    this.urgentJobs = 0,
    this.latestBilirubin,
    this.phototherapyRunning = false,
    this.latestWeightG,
  });

  final Patient patient;
  final WardKind wardKind;
  final DateTime now;
  final int urgentNotes;
  final int overdueReminders;
  final int urgentJobs;
  final BilirubinReading? latestBilirubin;
  final bool phototherapyRunning;
  final int? latestWeightG;
}

/// Bilirubin readings older than this don't colour the dot.
const Duration kStatusBilirubinMaxAge = Duration(hours: 72);

String _plural(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

/// The dot for one admitted patient (discharged patients get no dot —
/// callers skip them).
PatientStatusResult patientStatus(StatusInputs i) {
  final p = i.patient;
  final reasons = <StatusReason>[];
  void add(StatusLevel l, String text, [StatusTopic topic = StatusTopic.staff]) =>
      reasons.add(StatusReason(l, text, topic));

  // 1. Staff-set status.
  final acuity = Acuity.fromName(p.acuity);
  final tags = [for (final t in p.supportTags) SupportTag.fromName(t)].whereType<SupportTag>().toSet();
  var needsReview = false;
  if (acuity != null) {
    final reason = p.acuityReason?.trim() ?? '';
    add(acuity.level, 'Marked ${acuity.label}${reason.isEmpty ? '' : ' — $reason'}');
    final setAt = p.acuitySetAt;
    needsReview = setAt == null || i.now.difference(setAt) > i.wardKind.reviewEvery;
    // Shown faded with this note; doesn't change the colour by itself.
    if (needsReview) {
      add(StatusLevel.ok, 'Status not reviewed in ${i.wardKind.reviewEvery.inHours} h', StatusTopic.review);
    }
  }

  // 2. Ward tasks.
  if (i.urgentNotes > 0) add(StatusLevel.act, '${_plural(i.urgentNotes, 'urgent note')} to confirm', StatusTopic.tasks);
  if (i.overdueReminders > 0) add(StatusLevel.act, _plural(i.overdueReminders, 'overdue reminder'), StatusTopic.tasks);
  if (i.urgentJobs > 0) add(StatusLevel.act, _plural(i.urgentJobs, 'urgent or overdue job'), StatusTopic.tasks);

  // 3. Ward-type rules.
  if (i.wardKind.newbornRulesFor(p, i.now)) _newbornRules(i, add);
  if (tags.isNotEmpty) _supportRules(acuity, tags, add);

  reasons.sort((a, b) => b.level.index.compareTo(a.level.index));
  var level = reasons.isEmpty
      ? StatusLevel.unknown
      : reasons.map((r) => r.level).reduce((a, b) => a.index >= b.index ? a : b);
  if (level == StatusLevel.unknown && !i.wardKind.staffLed) level = StatusLevel.ok;
  return PatientStatusResult(level, reasons, needsReview: needsReview);
}

void _newbornRules(StatusInputs i, void Function(StatusLevel, String, [StatusTopic]) add) {
  final p = i.patient;
  final ga = p.gestationWeeks;
  if (ga == null) {
    add(StatusLevel.watch, 'Gestational age not recorded', StatusTopic.missingData);
  } else if (ga >= kAapMinWeeks && p.neuroRisk == null) {
    add(StatusLevel.watch, 'Neurotoxicity risk factors not recorded', StatusTopic.missingData);
  }

  // A reading older than this no longer describes the baby.
  final b = i.latestBilirubin;
  final recent = b != null && i.now.difference(b.measuredAt) <= kStatusBilirubinMaxAge;
  final a = recent ? assessForPatient(p, b.measuredAt, b.umol) : null;
  if (a != null) {
    final what = '${b!.transcutaneous ? 'TcB' : 'Bilirubin'} ${a.action.label.toLowerCase()} (${a.guideline})';
    switch (a.action) {
      case BiliAction.exchange || BiliAction.escalation:
        add(StatusLevel.act, what, StatusTopic.bilirubin);
      case BiliAction.phototherapy:
        add(i.phototherapyRunning ? StatusLevel.watch : StatusLevel.act,
            i.phototherapyRunning ? what : '$what — phototherapy not running', StatusTopic.bilirubin);
      case BiliAction.considerPhototherapy || BiliAction.approaching || BiliAction.repeat:
        add(StatusLevel.watch, what, StatusTopic.bilirubin);
      case BiliAction.none:
        break;
    }
  }
  if (i.phototherapyRunning) add(StatusLevel.watch, 'Under phototherapy', StatusTopic.phototherapy);

  final birth = p.birthWeightG, w = i.latestWeightG;
  if (birth != null && w != null) {
    final change = WeightChange(birth, w);
    switch (change.flag) {
      case WeightFlag.alert:
        add(StatusLevel.act, 'Weight ${change.label} from birth', StatusTopic.weight);
      case WeightFlag.watch:
        add(StatusLevel.watch, 'Weight ${change.label} from birth', StatusTopic.weight);
      case WeightFlag.ok:
        break;
    }
    final born = p.bornAt;
    if (i.wardKind == WardKind.nicu && born != null && w < birth &&
        i.now.difference(born) >= const Duration(days: 14)) {
      add(StatusLevel.watch, 'Birth weight not regained by day 14', StatusTopic.weight);
    }
  }
}

void _supportRules(
    Acuity? acuity, Set<SupportTag> tags, void Function(StatusLevel, String, [StatusTopic]) add) {
  final major = tags.where((t) => t == SupportTag.ventilated || t == SupportTag.inotropes).toList();
  if (major.isNotEmpty && acuity == Acuity.stable) {
    add(StatusLevel.watch, '${major.map((t) => t.label).join(' and ')} but marked Stable — review', StatusTopic.support);
  }
}
