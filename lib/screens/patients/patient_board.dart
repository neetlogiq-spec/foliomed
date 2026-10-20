import '../../models/note.dart';
import '../../models/patient.dart';
import '../../models/patient_reminder.dart';
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

  bool get needsAttention => overdueReminders > 0 || urgentJobs > 0 || urgentNotes > 0;
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
        final sa = signals[a.id]?.needsAttention ?? false, sb = signals[b.id]?.needsAttention ?? false;
        if (sa != sb) return sa ? -1 : 1;
        return byBed(a, b);
      });
  }
  return out;
}
