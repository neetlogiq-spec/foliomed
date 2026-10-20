import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/app_user.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/ward_job.dart';
import 'package:foliomed/models/ward_unit.dart';
import 'package:foliomed/providers/account_provider.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/providers/job_board.dart';
import 'package:foliomed/utils/scope_filter.dart';
import 'package:foliomed/widgets/job_row.dart';
import 'package:provider/provider.dart';

final _now = DateTime(2026, 10, 20, 14);

WardJob _job(String id,
        {bool urgent = false, DateTime? dueBy, DateTime? doneAt, String? assignedTo, String patientId = 'p1'}) =>
    WardJob(
      id: id,
      wardId: '11111',
      patientId: patientId,
      patientName: 'Baby Anaya',
      title: 'Job $id',
      urgent: urgent,
      dueBy: dueBy,
      assignedTo: assignedTo,
      assignedName: assignedTo == null ? null : 'Nurse B',
      createdAt: _now.subtract(Duration(minutes: int.parse(id))),
      doneAt: doneAt,
      doneByName: doneAt == null ? null : 'Nurse B',
    );

Patient _patient(String id, {String ward = '11111', String? unit}) => Patient(
      id: id,
      name: 'P$id',
      age: 1,
      gender: 'Female',
      wardId: ward,
      bedNumber: '4',
      diagnosis: '',
      admittedAt: _now,
      unitId: unit,
    );

class _FakeAccount extends ChangeNotifier implements AccountProvider {
  _FakeAccount(this.currentUser);
  @override
  final AppUser? currentUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WardJob', () {
    test('maps a row, including server-stamped names', () {
      final j = WardJob.fromRow({
        'id': 'j1',
        'ward_id': '11111',
        'patient_id': 'p1',
        'patient_name': 'Baby Anaya',
        'title': 'Repeat TSB',
        'urgent': true,
        'due_by': '2026-10-20T12:30:00Z',
        'assigned_to': 'u2',
        'assigned_name': 'Nurse B',
        'created_by_name': 'Dr A',
        'created_at': '2026-10-20T10:00:00Z',
        'done_at': null,
      });
      expect(j.title, 'Repeat TSB');
      expect(j.urgent, isTrue);
      expect(j.dueBy!.isAtSameMomentAs(DateTime.utc(2026, 10, 20, 12, 30)), isTrue);
      expect(j.isFor('u2'), isTrue);
      expect(j.isFor(''), isFalse);
      expect(j.isDone, isFalse);
      expect(j.createdByName, 'Dr A');
    });

    test('new rows send only what the client owns', () {
      final row = WardJob.newRow(wardId: '11111', patientId: 'p1', title: '  Send TSH ', assignedTo: 'u2');
      expect(row.keys, unorderedEquals(['ward_id', 'patient_id', 'title', 'urgent', 'due_by', 'assigned_to']));
      expect(row['title'], 'Send TSH');
      expect(row['due_by'], isNull);
    });

    test('overdue only when open and past its time', () {
      expect(_job('1', dueBy: _now.subtract(const Duration(minutes: 1))).isOverdueAt(_now), isTrue);
      expect(_job('1', dueBy: _now.add(const Duration(minutes: 1))).isOverdueAt(_now), isFalse);
      expect(_job('1').isOverdueAt(_now), isFalse);
      expect(_job('1', dueBy: _now.subtract(const Duration(hours: 1)), doneAt: _now).isOverdueAt(_now), isFalse);
    });

    test('priority: urgent/overdue, then timed (soonest), then untimed (oldest), then done', () {
      final jobs = [
        _job('1', doneAt: _now),
        _job('2'),
        _job('3', dueBy: _now.add(const Duration(hours: 3))),
        _job('4', urgent: true),
        _job('5', dueBy: _now.add(const Duration(hours: 1))),
        _job('6', dueBy: _now.subtract(const Duration(hours: 1))),
        _job('7'),
      ]..sort((a, b) => WardJob.byPriority(a, b, _now));
      expect(jobs.map((j) => j.id), ['6', '4', '5', '3', '7', '2', '1']);
    });
  });

  group('ScopeFilter.job', () {
    final patients = [_patient('p1', unit: 'uA'), _patient('p2', unit: 'uB')];

    test('hides jobs whose patient is not admitted (e.g. discharged)', () {
      final f = ScopeFilter(const PatientScope.all(), patients);
      expect(f.job(_job('1', patientId: 'p1')), isTrue);
      expect(f.job(_job('1', patientId: 'gone')), isFalse);
    });

    test('follows the unit of the patient', () {
      final f = ScopeFilter(const PatientScope.unit('11111', 'uA'), patients);
      expect(f.job(_job('1', patientId: 'p1')), isTrue);
      expect(f.job(_job('1', patientId: 'p2')), isFalse);
    });
  });

  group('JobRow', () {
    final me = AppUser(uid: 'u2', name: 'Nurse B', email: 'b@x.com', role: UserRole.nurse, createdAt: _now);

    Future<void> pump(WidgetTester tester, WardJob job) => tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppearanceProvider()),
            ChangeNotifierProvider<AccountProvider>.value(value: _FakeAccount(me)),
            ChangeNotifierProvider(create: (_) => JobBoard()),
          ],
          child: MaterialApp(home: Scaffold(body: JobRow(job: job))),
        ));

    testWidgets('open urgent job assigned to me', (tester) async {
      await pump(tester, _job('1', urgent: true, assignedTo: 'u2'));
      expect(find.text('Job 1'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.textContaining('You'), findsOneWidget);
    });

    testWidgets('overdue job says so', (tester) async {
      await pump(tester, _job('1', dueBy: DateTime.now().subtract(const Duration(hours: 1))));
      expect(find.textContaining('Overdue'), findsOneWidget);
      expect(find.textContaining('Anyone'), findsOneWidget);
    });

    testWidgets('done job shows who did it and no urgent badge', (tester) async {
      await pump(tester, _job('1', urgent: true, doneAt: DateTime.now()));
      expect(find.textContaining('Done by Nurse B'), findsOneWidget);
      expect(find.text('Urgent'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
