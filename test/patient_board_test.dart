import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/note.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/patient_reminder.dart';
import 'package:foliomed/models/ward_job.dart';
import 'package:foliomed/screens/patients/patient_board.dart';

final _now = DateTime(2026, 10, 20, 14);

Patient _p(String id, String bed, {String? name, DateTime? admitted, DateTime? born}) => Patient(
      id: id,
      name: name ?? 'P$id',
      age: 1,
      gender: '',
      wardId: 'w',
      bedNumber: bed,
      diagnosis: '',
      admittedAt: admitted ?? _now,
      bornAt: born,
    );

void main() {
  test('beds sort naturally; no bed goes last', () {
    final beds = ['10', '2', '', '4A', '4', 'ICU1', '1'];
    beds.sort(compareBeds);
    expect(beds, ['1', '2', '4', '4A', '10', 'ICU1', '']);
  });

  test('signals: overdue reminders, open/urgent jobs, urgent unconfirmed notes, phototherapy', () {
    final s = patientSignals(
      now: _now,
      reminders: [
        PatientReminder(id: 'r', patientId: 'a', wardId: 'w', title: 't', dueAt: _now.subtract(const Duration(hours: 1)), createdAt: _now),
        PatientReminder(id: 'r2', patientId: 'b', wardId: 'w', title: 't', dueAt: _now.add(const Duration(hours: 1)), createdAt: _now),
      ],
      jobs: [
        WardJob(id: 'j1', wardId: 'w', patientId: 'b', title: 't', createdAt: _now),
        WardJob(id: 'j2', wardId: 'w', patientId: 'b', title: 't', urgent: true, createdAt: _now),
        WardJob(id: 'j3', wardId: 'w', patientId: 'b', title: 't', createdAt: _now, doneAt: _now),
      ],
      notes: [
        Note(id: 'n', wardId: 'w', patientId: 'c', patientName: '', text: 'x', urgency: NoteUrgency.urgent,
            authorId: 'u', authorName: 'A', createdAt: _now, updatedAt: _now),
        Note(id: 'n2', wardId: 'w', patientId: 'd', patientName: '', text: 'x', urgency: NoteUrgency.urgent,
            isConfirmed: true, authorId: 'u', authorName: 'A', createdAt: _now, updatedAt: _now),
      ],
      phototherapy: {'e'},
    );
    expect(s['a']!.overdueReminders, 1);
    expect(s['a']!.needsAttention, isTrue);
    expect(s['b']!.openJobs, 2);
    expect(s['b']!.urgentJobs, 1);
    expect(s['b']!.needsAttention, isTrue);
    expect(s['c']!.urgentNotes, 1);
    expect(s.containsKey('d'), isFalse);
    expect(s['e']!.phototherapy, isTrue);
    expect(s['e']!.needsAttention, isFalse);
  });

  test('filters', () {
    final baby = _p('1', '1', born: _now.subtract(const Duration(hours: 30)));
    final adult = _p('2', '2');
    expect(PatientFilter.newborns.keeps(baby, PatientSignals.none), isTrue);
    expect(PatientFilter.newborns.keeps(adult, PatientSignals.none), isFalse);
    expect(PatientFilter.attention.keeps(adult, const PatientSignals(overdueReminders: 1)), isTrue);
    expect(PatientFilter.phototherapy.keeps(baby, const PatientSignals(phototherapy: true)), isTrue);
  });

  test('sorts: bed, name, newest, attention first', () {
    final list = [
      _p('a', '10', name: 'Zara', admitted: _now.subtract(const Duration(days: 2))),
      _p('b', '2', name: 'Asha', admitted: _now),
      _p('c', '3', name: 'Mira', admitted: _now.subtract(const Duration(days: 1))),
    ];
    final signals = {'a': const PatientSignals(urgentNotes: 1)};
    expect(sortPatients(list, PatientSort.bed, signals).map((p) => p.id), ['b', 'c', 'a']);
    expect(sortPatients(list, PatientSort.name, signals).map((p) => p.id), ['b', 'c', 'a']);
    expect(sortPatients(list, PatientSort.newest, signals).map((p) => p.id), ['b', 'c', 'a']);
    expect(sortPatients(list, PatientSort.attention, signals).map((p) => p.id), ['a', 'b', 'c']);
  });
}
