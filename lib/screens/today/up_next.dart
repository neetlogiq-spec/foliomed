import '../../models/note.dart';
import '../../models/patient_reminder.dart';
import '../../models/ward_job.dart';

/// One thing that needs someone now, from any source.
sealed class UpNext {
  const UpNext();

  /// 0 = act now (overdue / urgent), 1 = soon or timed, 2 = when you can.
  int get tier;

  /// When it was (or is) due; ties within a tier go earliest first.
  DateTime get when;
}

class UpNextReminder extends UpNext {
  const UpNextReminder(this.reminder, this.now);
  final PatientReminder reminder;
  final DateTime now;

  bool get overdue => reminder.isOverdueAt(now);
  @override
  int get tier => overdue ? 0 : 1;
  @override
  DateTime get when => reminder.dueAt;
}

class UpNextNote extends UpNext {
  const UpNextNote(this.note);
  final Note note;
  @override
  int get tier => 0;
  @override
  DateTime get when => note.createdAt;
}

class UpNextJob extends UpNext {
  const UpNextJob(this.job, this.now);
  final WardJob job;
  final DateTime now;
  @override
  int get tier => job.urgent || job.isOverdueAt(now) ? 0 : (job.dueBy != null ? 1 : 2);
  @override
  DateTime get when => job.dueBy ?? job.createdAt;
}

/// How far ahead a reminder counts as "up next".
const Duration kUpNextWindow = Duration(hours: 2);

/// What needs the signed-in person now, most pressing first:
/// * reminders that are overdue or due within [kUpNextWindow] (not snoozed),
/// * urgent notes nobody has confirmed,
/// * jobs assigned to them, plus anyone's urgent or overdue jobs.
List<UpNext> upNext({
  required DateTime now,
  required String uid,
  required Iterable<PatientReminder> reminders,
  required Iterable<Note> notes,
  required Iterable<WardJob> jobs,
}) {
  final items = <UpNext>[
    for (final r in reminders)
      if (!r.isDone && r.nextAlertAt.isBefore(now.add(kUpNextWindow))) UpNextReminder(r, now),
    for (final n in notes)
      if (n.isUrgent && !n.isConfirmed) UpNextNote(n),
    for (final j in jobs)
      if (!j.isDone && (j.isFor(uid) || j.urgent || j.isOverdueAt(now))) UpNextJob(j, now),
  ];
  items.sort((a, b) {
    final t = a.tier.compareTo(b.tier);
    return t != 0 ? t : a.when.compareTo(b.when);
  });
  return items;
}
