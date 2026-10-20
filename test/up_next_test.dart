import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/note.dart';
import 'package:foliomed/models/patient_reminder.dart';
import 'package:foliomed/models/ward_job.dart';
import 'package:foliomed/screens/today/up_next.dart';

final _now = DateTime(2026, 10, 20, 14);

PatientReminder _rem(String id, Duration fromNow, {DateTime? snoozedUntil, DateTime? doneAt}) => PatientReminder(
      id: id,
      patientId: 'p1',
      wardId: 'w',
      title: id,
      dueAt: _now.add(fromNow),
      snoozedUntil: snoozedUntil,
      doneAt: doneAt,
      createdAt: _now,
    );

Note _note(String id, {bool urgent = true, bool confirmed = false, int minsAgo = 10}) => Note(
      id: id,
      wardId: 'w',
      patientId: 'p1',
      patientName: 'Baby',
      text: id,
      urgency: urgent ? NoteUrgency.urgent : NoteUrgency.normal,
      authorId: 'a',
      authorName: 'Dr A',
      isConfirmed: confirmed,
      createdAt: _now.subtract(Duration(minutes: minsAgo)),
      updatedAt: _now,
    );

WardJob _job(String id, {String? to, bool urgent = false, Duration? due, bool done = false}) => WardJob(
      id: id,
      wardId: 'w',
      patientId: 'p1',
      title: id,
      urgent: urgent,
      dueBy: due == null ? null : _now.add(due),
      assignedTo: to,
      createdAt: _now.subtract(const Duration(hours: 1)),
      doneAt: done ? _now : null,
    );

List<String> _ids(List<UpNext> items) => [
      for (final i in items)
        switch (i) {
          UpNextReminder(:final reminder) => 'r:${reminder.id}',
          UpNextNote(:final note) => 'n:${note.id}',
          UpNextJob(:final job) => 'j:${job.id}',
        },
    ];

void main() {
  test('includes only what needs attention now', () {
    final items = upNext(
      now: _now,
      uid: 'me',
      reminders: [
        _rem('overdue', const Duration(minutes: -30)),
        _rem('soon', const Duration(hours: 1)),
        _rem('later', const Duration(hours: 5)),
        _rem('snoozed', const Duration(minutes: -30), snoozedUntil: _now.add(const Duration(hours: 3))),
        _rem('done', const Duration(minutes: -30), doneAt: _now),
      ],
      notes: [_note('urgent'), _note('normal', urgent: false), _note('confirmed', confirmed: true)],
      jobs: [
        _job('mine', to: 'me'),
        _job('theirs', to: 'other'),
        _job('urgent-anyone', urgent: true),
        _job('overdue-anyone', due: const Duration(minutes: -5)),
        _job('mine-done', to: 'me', done: true),
      ],
    );
    expect(_ids(items).toSet(),
        {'r:overdue', 'r:soon', 'n:urgent', 'j:mine', 'j:urgent-anyone', 'j:overdue-anyone'});
  });

  test('orders act-now first, then soon, then whenever; earliest first within each', () {
    final items = upNext(
      now: _now,
      uid: 'me',
      reminders: [_rem('soon', const Duration(hours: 1)), _rem('overdue', const Duration(minutes: -30))],
      notes: [_note('urgent', minsAgo: 5)],
      jobs: [_job('mine-untimed', to: 'me'), _job('mine-timed', to: 'me', due: const Duration(minutes: 30))],
    );
    expect(_ids(items), ['r:overdue', 'n:urgent', 'j:mine-timed', 'r:soon', 'j:mine-untimed']);
  });
}
