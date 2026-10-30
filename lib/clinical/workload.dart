/// Workload report: tasks per shift and response times, worked out from
/// the raw timings `ward_workload()` returns. Pure; all times are shown in
/// the phone's local time.
///
/// For planning staffing — counts per person are listed A–Z, never
/// ranked.
library;

import 'dart:math';

import '../models/row_parsing.dart';

enum WorkloadKind { job, urgentNote, reminder, handover }

/// One row from `ward_workload()`.
class WorkloadEvent {
  const WorkloadEvent({
    required this.kind,
    required this.at,
    this.doneAt,
    this.urgent = false,
    this.dueAt,
    this.who,
    this.total,
    this.missed,
  });

  final WorkloadKind kind;

  /// Job created / note posted / reminder due / handover started.
  final DateTime at;

  /// Done / confirmed / done / finished.
  final DateTime? doneAt;
  final bool urgent;
  final DateTime? dueAt;

  /// Who did it (job, reminder), confirmed it (note) or gave it (handover).
  final String? who;
  final int? total;
  final int? missed;

  factory WorkloadEvent.fromRow(DbRow r) => WorkloadEvent(
        kind: switch (r['kind']) {
          'job' => WorkloadKind.job,
          'urgent_note' => WorkloadKind.urgentNote,
          'reminder' => WorkloadKind.reminder,
          _ => WorkloadKind.handover,
        },
        at: parseTimestamp(r['at']).toLocal(),
        doneAt: parseTimestampOrNull(r['done_at'])?.toLocal(),
        urgent: r['urgent'] as bool? ?? false,
        dueAt: parseTimestampOrNull(r['due_at'])?.toLocal(),
        who: (r['who'] as String?)?.trim(),
        total: (r['total'] as num?)?.toInt(),
        missed: (r['missed'] as num?)?.toInt(),
      );
}

/// A reminder done more than this after it was due counts as late.
const Duration kReminderLateAfter = Duration(minutes: 30);

/// Default shift starts: 08:00, 14:00, 20:00 (minutes after midnight).
const List<int> kDefaultShiftStarts = [480, 840, 1200];

/// "08:00".
String clockLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// One shift on one day: [start] up to (not including) [end].
class Shift {
  const Shift(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// "08:00–14:00".
  String get label => '${clockLabel(start.hour * 60 + start.minute)}–${clockLabel(end.hour * 60 + end.minute)}';

  @override
  bool operator ==(Object other) => other is Shift && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}

/// The shift (from [starts], minutes after local midnight) that [t] falls in.
Shift shiftAt(DateTime t, List<int> starts) {
  final s = ([...starts]..sort()).toSet().toList();
  final day = DateTime(t.year, t.month, t.day);
  DateTime at(DateTime d, int m) => DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
  // Candidate starts: yesterday's last one, then today's.
  final yesterday = day.subtract(const Duration(days: 1));
  final candidates = [at(yesterday, s.last), for (final m in s) at(day, m)];
  var start = candidates.first;
  for (final c in candidates) {
    if (!c.isAfter(t)) start = c;
  }
  final i = candidates.indexOf(start);
  final end = i + 1 < candidates.length ? candidates[i + 1] : at(day.add(const Duration(days: 1)), s.first);
  return Shift(start, end);
}

Duration? median(List<Duration> xs) {
  if (xs.isEmpty) return null;
  final sorted = [...xs]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) ~/ 2;
}

/// "12 min", "2 h 5 min".
String durationLabel(Duration d) {
  final m = max(0, d.inMinutes);
  if (m < 60) return '$m min';
  return m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min';
}

/// The numbers for one shift (or the whole range).
class WorkloadStats {
  WorkloadStats(this.events, {required this.end});

  final List<WorkloadEvent> events;

  /// "Left for the next shift" counts what is still open at [end].
  final DateTime end;

  Iterable<WorkloadEvent> _of(WorkloadKind k) => events.where((e) => e.kind == k);

  int get jobsCreated => _of(WorkloadKind.job).length;
  int get urgentJobs => _of(WorkloadKind.job).where((e) => e.urgent).length;
  int get jobsDone => _of(WorkloadKind.job).where((e) => e.doneAt != null && !e.doneAt!.isAfter(end)).length;
  Duration? get jobTurnaround => median([
        for (final e in _of(WorkloadKind.job))
          if (e.doneAt != null) e.doneAt!.difference(e.at),
      ]);

  int get urgentNotes => _of(WorkloadKind.urgentNote).length;
  List<Duration> get _confirmTimes => [
        for (final e in _of(WorkloadKind.urgentNote))
          if (e.doneAt != null) e.doneAt!.difference(e.at),
      ];
  Duration? get confirmMedian => median(_confirmTimes);
  Duration? get confirmSlowest => _confirmTimes.isEmpty ? null : _confirmTimes.reduce((a, b) => a > b ? a : b);
  int get unconfirmed => _of(WorkloadKind.urgentNote).where((e) => e.doneAt == null).length;

  int get remindersDue => _of(WorkloadKind.reminder).length;
  int get remindersLate => _of(WorkloadKind.reminder)
      .where((e) => e.doneAt != null && e.doneAt!.difference(e.at) > kReminderLateAfter)
      .length;

  /// Jobs and reminders from this period still open when it ended.
  int get leftOpen => events
      .where((e) =>
          (e.kind == WorkloadKind.job || e.kind == WorkloadKind.reminder) &&
          (e.doneAt == null || e.doneAt!.isAfter(end)))
      .length;

  int get handovers => _of(WorkloadKind.handover).length;
  int get handoverPatients => _of(WorkloadKind.handover).fold(0, (a, e) => a + (e.total ?? 0));
  int get handoverMissed => _of(WorkloadKind.handover).fold(0, (a, e) => a + (e.missed ?? 0));

  bool get isEmpty => events.isEmpty;

  /// Jobs done, urgent notes confirmed and reminders done per person,
  /// A–Z (not ranked). Handovers given are counted too.
  List<PersonCounts> get people {
    final map = <String, PersonCounts>{};
    for (final e in events) {
      final who = e.who;
      if (who == null || who.isEmpty) continue;
      final p = map.putIfAbsent(who.toLowerCase(), () => PersonCounts(who));
      switch (e.kind) {
        case WorkloadKind.job:
          if (e.doneAt != null) p.jobs++;
        case WorkloadKind.urgentNote:
          if (e.doneAt != null) p.confirmed++;
        case WorkloadKind.reminder:
          if (e.doneAt != null) p.reminders++;
        case WorkloadKind.handover:
          p.handovers++;
      }
    }
    return map.values.where((p) => p.total > 0).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}

class PersonCounts {
  PersonCounts(this.name);
  final String name;
  int jobs = 0, confirmed = 0, reminders = 0, handovers = 0;
  int get total => jobs + confirmed + reminders + handovers;
}

/// Events grouped by the shift they started in, newest shift first.
/// Shifts with nothing in them are left out.
List<(Shift, WorkloadStats)> byShift(List<WorkloadEvent> events, List<int> starts) {
  final groups = <Shift, List<WorkloadEvent>>{};
  for (final e in events) {
    (groups[shiftAt(e.at, starts)] ??= []).add(e);
  }
  final shifts = groups.keys.toList()..sort((a, b) => b.start.compareTo(a.start));
  return [for (final s in shifts) (s, WorkloadStats(groups[s]!, end: s.end))];
}
