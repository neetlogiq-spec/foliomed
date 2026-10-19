import '../models/newborn_tracking.dart';
import '../models/patient.dart';
import '../models/patient_reminder.dart';
import 'bilirubin.dart';
import 'birth_summary.dart';

/// Everything the handover shows for one patient.
class HandoverItem {
  HandoverItem({
    required this.patient,
    required this.unitName,
    required this.openReminders,
    this.bilirubin,
    this.phototherapy,
    this.weight,
  });

  final Patient patient;
  final String? unitName;
  final List<PatientReminder> openReminders;
  final BilirubinReading? bilirubin;
  final PhototherapySession? phototherapy;
  final WeightEntry? weight;

  /// NICE action for the latest bilirubin, when it can be assessed.
  BiliAssessment? get niceAssessment {
    final b = bilirubin, born = patient.bornAt;
    if (b == null || born == null) return null;
    final a = const NiceCg98().assess(
      gestationWeeks: patient.gestationWeeks,
      hoursOfAge: b.measuredAt.difference(born).inMinutes / 60,
      tsbUmol: b.umol,
    );
    return a is BiliAssessment ? a : null;
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
    final a = niceAssessment;
    if (a != null && a.action.index >= BiliAction.considerPhototherapy.index) {
      out.add('Bilirubin: ${a.action.label}');
    }
    final wc = weightChange;
    if (wc != null && wc.flag != WeightFlag.ok) out.add('Weight ${wc.label} from birth');
    return out;
  }

  /// Plain-text block for sharing.
  String toText(DateTime now) {
    final p = patient;
    final head = [
      if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}',
      p.name,
      p.ageLabel,
      if (unitName != null) unitName!,
    ].join(' · ');
    final lines = <String>[
      head,
      if (p.diagnosis.isNotEmpty) p.diagnosis else if (birthSummaryLine(p) != null) birthSummaryLine(p)!,
      if (phototherapy != null)
        '${phototherapy!.kind.label} phototherapy for ${phototherapy!.durationAt(now).inHours} h',
      if (bilirubin != null)
        'Last ${bilirubin!.transcutaneous ? 'TcB' : 'TSB'} ${_n(bilirubin!.value)} '
            '${bilirubin!.isUmol ? 'µmol/L' : 'mg/dL'} at '
            '${p.bornAt == null ? '' : '${bilirubin!.measuredAt.difference(p.bornAt!).inHours} h'}'
            '${niceAssessment == null ? '' : ' (NICE: ${niceAssessment!.action.label})'}',
      if (weightChange != null) 'Weight ${(weight!.grams / 1000).toStringAsFixed(2)} kg (${weightChange!.label})',
      for (final r in openReminders.where((r) => !r.isOverdueAt(now)).take(2))
        'Pending: ${r.title}',
      ...flags(now).map((f) => '⚠ $f'),
    ];
    return lines.join('\n');
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Sort for handover: unit (in the ward's order), then bed (numbers
/// numerically), then name.
int compareHandover(HandoverItem a, HandoverItem b, List<String> unitOrder) {
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
