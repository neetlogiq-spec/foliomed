import 'package:intl/intl.dart';

import '../models/handover_session.dart';
import '../models/newborn_tracking.dart';
import '../models/patient.dart';
import '../models/patient_infusion.dart';
import '../models/patient_reminder.dart';
import '../models/ward_job.dart';
import 'bilirubin.dart';
import 'bilirubin_assess.dart';
import 'birth_summary.dart';
import 'patient_status.dart';

/// Everything the handover shows for one patient, in I-PASS order:
/// Illness severity ([status]), Patient summary ([summary]), Action list
/// ([openReminders], [openJobs]), Situation awareness & contingency
/// ([contingencies]). Synthesis by the receiver is the handover session.
class HandoverItem {
  HandoverItem({
    required this.patient,
    required this.unitName,
    required this.openReminders,
    this.bilirubin,
    this.phototherapy,
    this.weight,
    this.status,
    this.openJobs = const [],
    this.contingencies = const [],
    this.infusions = const [],
  });

  final Patient patient;
  final String? unitName;
  final List<PatientReminder> openReminders;
  final BilirubinReading? bilirubin;
  final PhototherapySession? phototherapy;
  final WeightEntry? weight;
  final PatientStatusResult? status;
  final List<WardJob> openJobs;
  final List<Contingency> contingencies;

  /// Running infusions.
  final List<PatientInfusion> infusions;

  /// The hand-kept summary, else the diagnosis, else the birth line.
  String? get summary {
    final p = patient;
    final s = p.handoverSummary?.trim() ?? '';
    if (s.isNotEmpty) return s;
    if (p.diagnosis.isNotEmpty) return p.diagnosis;
    return birthSummaryLine(p);
  }

  /// "Needs action — Weight −10.3% from birth; 1 overdue reminder".
  String? get severityLine {
    final st = status;
    if (st == null) return null;
    final why = st.reasons.where((r) => r.level.index >= StatusLevel.watch.index).map((r) => r.text).toList();
    return '${st.label}${st.needsReview ? ' (status due for review)' : ''}'
        '${why.isEmpty ? '' : ' — ${why.join('; ')}'}';
  }

  /// Action list: overdue reminders, urgent/overdue jobs, then the rest.
  List<String> actions(DateTime now) => [
        for (final r in openReminders.where((r) => r.isOverdueAt(now))) 'OVERDUE: ${r.title}',
        for (final j in openJobs.where((j) => j.urgent || j.isOverdueAt(now)))
          '${j.urgent ? 'URGENT' : 'OVERDUE'} job: ${j.title}${_who(j)}',
        for (final r in openReminders.where((r) => !r.isOverdueAt(now))) 'Pending: ${r.title}',
        for (final j in openJobs.where((j) => !j.urgent && !j.isOverdueAt(now))) 'Job: ${j.title}${_who(j)}',
      ];

  static String _who(WardJob j) => j.assignedName?.isNotEmpty ?? false ? ' (${j.assignedName})' : '';

  /// Guideline action for the latest bilirubin (preferred guideline, else
  /// the other), when it can be assessed.
  BiliAssessment? get assessment {
    final b = bilirubin;
    if (b == null) return null;
    return assessForPatient(patient, b.measuredAt, b.umol);
  }

  WeightChange? get weightChange {
    final birth = patient.birthWeightG, w = weight;
    return birth == null || w == null ? null : WeightChange(birth, w.grams);
  }

  /// Things to act on, most important first.
  List<String> flags(DateTime now) {
    final out = <String>[];
    final overdue = openReminders.where((r) => r.isOverdueAt(now)).toList();
    if (overdue.isNotEmpty) {
      out.add('OVERDUE: ${overdue.map((r) => r.title).join('; ')}');
    }
    final a = assessment;
    if (a != null && a.action.index >= BiliAction.considerPhototherapy.index) {
      out.add('Bilirubin: ${a.action.label}');
    }
    final wc = weightChange;
    if (wc != null && wc.flag != WeightFlag.ok) out.add('Weight ${wc.label} from birth');
    return out;
  }

  /// Plain-text block for sharing, in I-PASS order.
  String toText(DateTime now) {
    final p = patient;
    final head = [
      if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}',
      p.name,
      p.ageLabel,
      if (unitName != null) unitName!,
    ].join(' · ');
    final acts = actions(now);
    final lines = <String>[
      head,
      if (severityLine != null) 'I: $severityLine',
      if (summary != null) 'P: $summary',
      if (infusions.isNotEmpty) 'Infusions: ${infusions.map((i) => i.line).join('; ')}',
      if (phototherapy != null)
        '${phototherapy!.kind.label} phototherapy for ${phototherapy!.durationAt(now).inHours} h',
      if (bilirubin != null)
        'Last ${bilirubin!.transcutaneous ? 'TcB' : 'TSB'} ${_n(bilirubin!.value)} '
            '${bilirubin!.isUmol ? 'µmol/L' : 'mg/dL'} at '
            '${p.bornAt == null ? '' : '${bilirubin!.measuredAt.difference(p.bornAt!).inHours} h'}'
            '${assessment == null ? '' : ' (${assessment!.guideline}: ${assessment!.action.label})'}',
      if (weightChange != null) 'Weight ${(weight!.grams / 1000).toStringAsFixed(2)} kg (${weightChange!.label})',
      if (acts.isNotEmpty) 'A: ${acts.first}',
      for (final a in acts.skip(1)) '   $a',
      for (final c in contingencies) 'S: ${c.line}',
      // Without a status line, the newborn flags carry the warnings.
      if (status == null) ...flags(now).map((f) => '⚠ $f'),
    ];
    return lines.join('\n');
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// The whole list as shareable text (WhatsApp etc.), I-PASS per patient.
String handoverText(List<HandoverItem> items, String scope, DateTime now) {
  final red = items.where((i) => i.status?.level == StatusLevel.act).length;
  final header = 'Handover — $scope — ${DateFormat('d MMM, h:mm a').format(now)} — '
      '${items.length} patient${items.length == 1 ? '' : 's'}${red == 0 ? '' : ', $red need action'}';
  return [header, 'I: illness severity · P: summary · A: actions · S: if/then', for (final i in items) i.toText(now)]
      .join('\n\n');
}

/// Sort for handover: unit (in the ward's order), then bed (numbers
/// numerically), then name. With [sickestFirst], red before amber before
/// the rest, then that order.
int compareHandover(HandoverItem a, HandoverItem b, List<String> unitOrder, {bool sickestFirst = false}) {
  if (sickestFirst) {
    final ra = a.status?.level.index ?? 0, rb = b.status?.level.index ?? 0;
    if (ra != rb) return rb.compareTo(ra);
  }
  int unitRank(HandoverItem i) {
    final idx = unitOrder.indexOf(i.patient.unitId ?? '');
    return idx < 0 ? unitOrder.length : idx;
  }

  final u = unitRank(a).compareTo(unitRank(b));
  if (u != 0) return u;
  final ab = int.tryParse(a.patient.bedNumber), bb = int.tryParse(b.patient.bedNumber);
  if (ab != null && bb != null && ab != bb) return ab.compareTo(bb);
  final bed = a.patient.bedNumber.compareTo(b.patient.bedNumber);
  if (bed != 0) return bed;
  return a.patient.name.toLowerCase().compareTo(b.patient.name.toLowerCase());
}

/// Census numbers for one day.
class DayCensus {
  DayCensus({required this.current, required this.admitted, required this.discharged, required this.born});

  final int current;
  final int admitted;
  final int discharged;
  final int born;

  static bool _sameDay(DateTime? a, DateTime d) {
    if (a == null) return false;
    final l = a.toLocal();
    return l.year == d.year && l.month == d.month && l.day == d.day;
  }

  static DayCensus of({
    required List<Patient> active,
    required List<Patient> discharged,
    required DateTime day,
  }) {
    final everyone = [...active, ...discharged];
    return DayCensus(
      current: active.length,
      admitted: everyone.where((p) => _sameDay(p.admittedAt, day)).length,
      discharged: discharged.where((p) => _sameDay(p.dischargedAt, day)).length,
      born: everyone.where((p) => _sameDay(p.bornAt, day)).length,
    );
  }
}
