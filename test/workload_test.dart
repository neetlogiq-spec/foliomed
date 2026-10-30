import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/workload.dart';

DateTime _t(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m);

WorkloadEvent _job(DateTime at, {DateTime? done, bool urgent = false, String? who}) =>
    WorkloadEvent(kind: WorkloadKind.job, at: at, doneAt: done, urgent: urgent, who: who);

void main() {
  const starts = kDefaultShiftStarts; // 08:00, 14:00, 20:00

  test('shifts: day shifts and the night that wraps past midnight', () {
    expect(shiftAt(_t(30, 9), starts), Shift(_t(30, 8), _t(30, 14)));
    expect(shiftAt(_t(30, 14), starts), Shift(_t(30, 14), _t(30, 20)));
    expect(shiftAt(_t(30, 22), starts), Shift(_t(30, 20), _t(31, 8)));
    expect(shiftAt(_t(31, 3), starts), Shift(_t(30, 20), _t(31, 8)), reason: '3 am belongs to the night before');
    expect(shiftAt(_t(30, 9), starts).label, '08:00–14:00');
    expect(shiftAt(_t(30, 22), [420, 1140]).label, '19:00–07:00');
  });

  test('median and labels', () {
    expect(median([]), isNull);
    expect(median(const [Duration(minutes: 5), Duration(minutes: 30), Duration(minutes: 10)]), const Duration(minutes: 10));
    expect(median(const [Duration(minutes: 10), Duration(minutes: 20)]), const Duration(minutes: 15));
    expect(durationLabel(const Duration(minutes: 125)), '2 h 5 min');
    expect(durationLabel(const Duration(minutes: 7)), '7 min');
    expect(clockLabel(1200), '20:00');
  });

  test('per-shift numbers', () {
    final end = _t(30, 14);
    final s = WorkloadStats([
      _job(_t(30, 9), done: _t(30, 9, 30), urgent: true, who: 'Nurse B'),
      _job(_t(30, 10), done: _t(30, 15), who: 'Dr A'), // done after the shift → left open
      _job(_t(30, 11)),
      WorkloadEvent(kind: WorkloadKind.urgentNote, at: _t(30, 9), doneAt: _t(30, 9, 12), who: 'Nurse B'),
      WorkloadEvent(kind: WorkloadKind.urgentNote, at: _t(30, 12), doneAt: _t(30, 12, 40), who: 'nurse b'),
      WorkloadEvent(kind: WorkloadKind.urgentNote, at: _t(30, 13)),
      WorkloadEvent(kind: WorkloadKind.reminder, at: _t(30, 10), doneAt: _t(30, 10, 20), who: 'Dr A'),
      WorkloadEvent(kind: WorkloadKind.reminder, at: _t(30, 11), doneAt: _t(30, 12), who: 'Dr A'),
      WorkloadEvent(kind: WorkloadKind.handover, at: _t(30, 13, 50), who: 'Dr A', total: 12, missed: 2),
    ], end: end);
    expect([s.jobsCreated, s.urgentJobs, s.jobsDone], [3, 1, 1]);
    expect(s.jobTurnaround, const Duration(minutes: 165), reason: 'median of 30 min and 5 h');
    expect([s.urgentNotes, s.unconfirmed], [3, 1]);
    expect([s.confirmMedian, s.confirmSlowest], [const Duration(minutes: 26), const Duration(minutes: 40)]);
    expect([s.remindersDue, s.remindersLate], [2, 1]);
    expect(s.leftOpen, 2, reason: 'one job done after the shift, one never');
    expect([s.handovers, s.handoverPatients, s.handoverMissed], [1, 12, 2]);
    final people = s.people;
    expect(people.map((p) => p.name), ['Dr A', 'Nurse B'], reason: 'A–Z, names merged ignoring case');
    expect([people[0].jobs, people[0].reminders, people[0].handovers], [1, 2, 1]);
    expect([people[1].jobs, people[1].confirmed], [1, 2]);
  });

  test('grouped by shift, newest first, empty shifts left out', () {
    final groups = byShift([_job(_t(30, 9)), _job(_t(30, 22)), _job(_t(31, 2)), _job(_t(30, 10))], starts);
    expect(groups.map((g) => g.$1.label), ['20:00–08:00', '08:00–14:00']);
    expect(groups.map((g) => g.$2.jobsCreated), [2, 2]);
  });

  test('rows map from the database', () {
    final e = WorkloadEvent.fromRow({'kind': 'urgent_note', 'at': '2026-10-30T09:00:00Z', 'done_at': null,
        'urgent': true, 'who': ' Dr A '});
    expect([e.kind, e.doneAt, e.who], [WorkloadKind.urgentNote, null, 'Dr A']);
  });
}
