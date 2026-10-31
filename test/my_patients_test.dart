import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/note.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/ward.dart';
import 'package:foliomed/models/ward_job.dart';
import 'package:foliomed/screens/patients/patient_board.dart';
import 'package:foliomed/widgets/patient_row.dart';

final _now = DateTime(2026, 10, 30, 9);

Patient _p(String id, {String? consultant, List<String> tags = const []}) => Patient(
    id: id, name: 'P$id', age: 5, gender: '', wardId: 'w', bedNumber: id, diagnosis: '',
    admittedAt: _now, consultant: consultant, tags: tags);

Note _note(String patient, String author, Duration ago) => Note(
    id: '$patient$author', wardId: 'w', patientId: patient, patientName: '', text: 'x',
    authorId: author, authorName: '', createdAt: _now.subtract(ago), updatedAt: _now);

void main() {
  test('involved: my notes in the last 48 h and my open jobs', () {
    final ids = involvedPatients(
      uid: 'me',
      now: _now,
      notes: [_note('a', 'me', const Duration(hours: 10)), _note('b', 'me', const Duration(hours: 50)), _note('c', 'you', Duration.zero)],
      jobs: [
        WardJob(id: 'j1', wardId: 'w', patientId: 'd', title: 't', assignedTo: 'me', createdAt: _now),
        WardJob(id: 'j2', wardId: 'w', patientId: 'e', title: 't', assignedTo: 'me', createdAt: _now, doneAt: _now),
        WardJob(id: 'j3', wardId: 'w', patientId: 'f', title: 't', assignedTo: 'you', createdAt: _now),
      ],
    );
    expect(ids, {'a', 'd'});
    expect(involvedPatients(uid: '', now: _now, notes: [_note('a', '', Duration.zero)], jobs: const []), isEmpty);
  });

  test('My Patients filter = followed or involved', () {
    final all = [_p('a'), _p('b'), _p('c')];
    final s = withStatuses(now: _now, admitted: all, signals: const {}, wardKinds: const {},
        followed: {'a'}, involved: {'b'});
    expect(all.where((p) => PatientFilter.mine.keeps(p, s[p.id]!)).map((p) => p.id), ['a', 'b']);
    expect(s['a']!.followed, isTrue);
    expect(s['b']!.followed, isFalse);
  });

  test('consultant and tag filters; consultant list A–Z, case-insensitive', () {
    final p = _p('a', consultant: ' Dr Rao ', tags: ['NPO']);
    expect(matchesTeamFilter(p, consultant: 'dr rao'), isTrue);
    expect(matchesTeamFilter(p, consultant: 'Dr Iyer'), isFalse);
    expect(matchesTeamFilter(p, tag: 'NPO'), isTrue);
    expect(matchesTeamFilter(p, tag: 'Isolation'), isFalse);
    expect(matchesTeamFilter(p), isTrue);
    expect(consultantsOf([_p('a', consultant: 'Dr Rao'), _p('b', consultant: 'dr rao'), _p('c', consultant: 'Dr Iyer'), _p('d')]),
        ['Dr Iyer', 'Dr Rao']);
  });

  test('rows map consultant, tags and ward tag list', () {
    final p = Patient.fromRow({'name': 'A', 'consultant': 'Dr Rao', 'tags': ['NPO']});
    expect([p.consultant, p.tags], ['Dr Rao', ['NPO']]);
    expect(p.toRow()['consultant'], 'Dr Rao');
    expect(p.toRow().containsKey('tags'), isFalse, reason: 'tags are saved on their own');
    expect(Patient.fromRow({'name': 'B'}).tags, isEmpty);
    expect(Ward.fromRow({'id': '1', 'name': 'W'}).tagOptions, kDefaultTagOptions);
    expect(Ward.fromRow({'id': '1', 'name': 'W', 'tag_options': ['Oxygen']}).tagOptions, ['Oxygen']);
  });

  testWidgets('row shows the star, consultant and tags', (t) async {
    t.view.physicalSize = const Size(2400, 1800);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PatientRow(
          patient: _p('4', consultant: 'Dr Rao', tags: ['NPO', 'Isolation']),
          signals: const PatientSignals(followed: true),
        ),
      ),
    ));
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.textContaining('Dr Rao'), findsOneWidget);
    expect(find.text('NPO'), findsOneWidget);
    expect(find.text('Isolation'), findsOneWidget);
  });
}
