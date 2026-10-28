import '../../clinical/patient_status.dart';
import '../../models/newborn_tracking.dart';
import '../../models/note.dart';
import '../../models/observation.dart';
import '../../models/patient.dart';
import '../../models/patient_reminder.dart';
import '../../models/ward.dart';
import '../../models/ward_job.dart';

/// What a patient row shows beside the name — worked out once per list.
class PatientSignals {
  const PatientSignals({
    this.phototherapy = false,
    this.overdueReminders = 0,
    this.openJobs = 0,
    this.urgentJobs = 0,
    this.urgentNotes = 0,
    this.latestWeightG,
    this.status,
  });

  static const none = PatientSignals();

  final bool phototherapy;
  final int overdueReminders;
  final int openJobs;

  /// Open jobs that are urgent or past their time.
  final int urgentJobs;

  /// Urgent notes nobody has confirmed.
  final int urgentNotes;
  final int? latestWeightG;

  /// The status dot (admitted patients on the board), or null.
  final PatientStatusResult? status;

  /// Red or amber dot; without a status, any urgent task.
  bool get needsAttention =>
      status?.needsAttention ?? (overdueReminders > 0 || urgentJobs > 0 || urgentNotes > 0);

  /// 3 red, 2 amber, 1 green, 0 grey / none — for "Needs Attention First".
  int get attentionRank => status?.level.index ?? (needsAttention ? StatusLevel.act.index : 0);

  PatientSignals withStatus(PatientStatusResult s) => PatientSignals(
        phototherapy: phototherapy,
        overdueReminders: overdueReminders,
        openJobs: openJobs,
        urgentJobs: urgentJobs,
        urgentNotes: urgentNotes,
        latestWeightG: latestWeightG,
        status: s,
      );
}

/// Signals for every patient id that has any.
Map<String, PatientSignals> patientSignals({
  required DateTime now,
  required Iterable<PatientReminder> reminders,
  required Iterable<WardJob> jobs,
  required Iterable<Note> notes,
  Set<String> phototherapy = const {},
  Map<String, int> latestWeightG = const {},
}) {
  final overdue = <String, int>{}, open = <String, int>{}, urgentJob = <String, int>{}, urgentNote = <String, int>{};
  void bump(Map<String, int> m, String id) => m[id] = (m[id] ?? 0) + 1;
  for (final r in reminders) {
    if (r.isOverdueAt(now)) bump(overdue, r.patientId);
  }
  for (final j in jobs) {
    if (j.isDone) continue;
    bump(open, j.patientId);
    if (j.urgent || j.isOverdueAt(now)) bump(urgentJob, j.patientId);
  }
  for (final n in notes) {
    if (n.isUrgent && !n.isConfirmed) bump(urgentNote, n.patientId);
  }
  final ids = {...overdue.keys, ...open.keys, ...urgentNote.keys, ...phototherapy, ...latestWeightG.keys};
  return {
    for (final id in ids)
      id: PatientSignals(
        phototherapy: phototherapy.contains(id),
        overdueReminders: overdue[id] ?? 0,
        openJobs: open[id] ?? 0,
        urgentJobs: urgentJob[id] ?? 0,
        urgentNotes: urgentNote[id] ?? 0,
        latestWeightG: latestWeightG[id],
      ),
  };
}

/// [signals] plus a status dot for every admitted patient, using their
/// ward's type ([wardKinds] by ward id; unknown wards count as Other).
Map<String, PatientSignals> withStatuses({
  required DateTime now,
  required Iterable<Patient> admitted,
  required Map<String, PatientSignals> signals,
  required Map<String, WardKind> wardKinds,
  Map<String, BilirubinReading> latestBilirubin = const {},
  Map<String, Observation> latestObservation = const {},
}) {
  final out = {...signals};
  for (final p in admitted) {
    if (!p.isActive) continue;
    final s = signals[p.id] ?? PatientSignals.none;
    out[p.id] = s.withStatus(patientStatus(StatusInputs(
      patient: p,
      wardKind: wardKinds[p.wardId] ?? WardKind.other,
      now: now,
      urgentNotes: s.urgentNotes,
      overdueReminders: s.overdueReminders,
      urgentJobs: s.urgentJobs,
      latestBilirubin: latestBilirubin[p.id],
      phototherapyRunning: s.phototherapy,
      latestWeightG: s.latestWeightG,
      latestObservation: latestObservation[p.id],
    )));
  }
  return out;
}

enum PatientFilter {
  admitted('Admitted'),
  attention('Needs Attention'),
  newborns('Newborns'),
  phototherapy('Phototherapy'),
  discharged('Discharged');

  const PatientFilter(this.label);
  final String label;

  bool keeps(Patient p, PatientSignals s) => switch (this) {
        admitted || discharged => true,
        attention => s.needsAttention,
        newborns => p.bornAt != null,
        phototherapy => s.phototherapy,
      };
}

enum PatientSort {
  bed('Bed'),
  name('Name'),
  newest('Newest'),
  attention('Needs Attention First');

  const PatientSort(this.label);
  final String label;
}

/// Beds sort as people read them: 2 before 10, "4A" after "4".
int compareBeds(String a, String b) {
  if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1; // no bed last
  final na = int.tryParse(RegExp(r'^\d+').stringMatch(a) ?? '');
  final nb = int.tryParse(RegExp(r'^\d+').stringMatch(b) ?? '');
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  if ((na == null) != (nb == null)) return na == null ? 1 : -1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

List<Patient> sortPatients(List<Patient> list, PatientSort sort, Map<String, PatientSignals> signals) {
  int byBed(Patient a, Patient b) {
    final c = compareBeds(a.bedNumber, b.bedNumber);
    return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  final out = [...list];
  switch (sort) {
    case PatientSort.bed:
      out.sort(byBed);
    case PatientSort.name:
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case PatientSort.newest:
      out.sort((a, b) => b.admittedAt.compareTo(a.admittedAt));
    case PatientSort.attention:
      out.sort((a, b) {
        final ra = signals[a.id]?.attentionRank ?? 0, rb = signals[b.id]?.attentionRank ?? 0;
        if (ra != rb) return rb.compareTo(ra);
        return byBed(a, b);
      });
  }
  return out;
}
