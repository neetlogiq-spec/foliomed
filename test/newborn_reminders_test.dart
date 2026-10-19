import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/patient_reminder.dart';
import 'package:foliomed/providers/reminder_provider.dart';
import 'package:foliomed/services/reminder_notifications.dart';
import 'package:foliomed/services/reminder_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _born = DateTime.utc(2026, 10, 18, 6, 30);

PatientReminder _reminder({
  String id = 'r1',
  required DateTime due,
  DateTime? snoozedUntil,
  DateTime? doneAt,
}) =>
    PatientReminder(
      id: id,
      patientId: 'p1',
      wardId: 'w1',
      patientName: 'Baby Anaya',
      title: 'Send 48-hour investigations',
      dueAt: due,
      snoozedUntil: snoozedUntil,
      doneAt: doneAt,
      createdAt: _born,
    );

class _FakeService extends ReminderService {
  _FakeService() : super(client: SupabaseClient('http://localhost', 'test'));
  final controller = StreamController<List<PatientReminder>>();
  final calls = <String>[];

  @override
  Stream<List<PatientReminder>> openForWards(List<String> wardIds) =>
      controller.stream;
  @override
  Future<void> markDone(String reminderId) async => calls.add('done:$reminderId');
  @override
  Future<void> snooze(String reminderId, Duration delay) async =>
      calls.add('snooze:$reminderId:${delay.inMinutes}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('age from birth time', () {
    test('hours for the first week', () {
      expect(ageSinceBirthLabel(_born, _born.add(const Duration(hours: 47, minutes: 59))), '47 h');
      expect(ageSinceBirthLabel(_born, _born.add(const Duration(hours: 167))), '167 h');
    });
    test('then days, months, years', () {
      expect(ageSinceBirthLabel(_born, _born.add(const Duration(days: 12))), '12 d');
      expect(ageSinceBirthLabel(_born, DateTime.utc(2027, 3, 20)), '5 mo');
      expect(ageSinceBirthLabel(_born, DateTime.utc(2029, 11, 1)), '3 y');
    });
    test('birth time in the future reads as 0 h', () {
      expect(ageSinceBirthLabel(_born, _born.subtract(const Duration(minutes: 5))), '0 h');
    });
    test('patient uses birth time over stored age and round-trips born_at', () {
      final p = Patient.fromRow({'name': 'Baby', 'age': 3, 'age_unit': 'years', 'born_at': _born.toIso8601String()});
      expect(p.bornAt!.isAtSameMomentAs(_born), isTrue);
      expect(p.hoursSinceBirth(_born.add(const Duration(hours: 72))), 72);
      expect(p.toRow()['born_at'], isNotNull);
      expect(Patient.fromRow({'name': 'Adult'}).hoursSinceBirth(), isNull);
    });
  });

  group('PatientReminder timing', () {
    final now = _born.add(const Duration(hours: 50));
    test('due once the time passes, unless done or snoozed', () {
      expect(_reminder(due: now.add(const Duration(hours: 1))).isDueAt(now), isFalse);
      expect(_reminder(due: now.subtract(const Duration(hours: 2))).isDueAt(now), isTrue);
      expect(_reminder(due: now.subtract(const Duration(hours: 2)), doneAt: now).isDueAt(now), isFalse);
      expect(_reminder(due: now.subtract(const Duration(hours: 2)), snoozedUntil: now.add(const Duration(minutes: 30))).isDueAt(now), isFalse);
      expect(_reminder(due: now.subtract(const Duration(hours: 2)), snoozedUntil: now.subtract(const Duration(minutes: 1))).isDueAt(now), isTrue);
    });
    test('next alert is the end of a snooze, otherwise the due time', () {
      final due = now.subtract(const Duration(hours: 2));
      expect(_reminder(due: due).nextAlertAt, due);
      final until = now.add(const Duration(hours: 1));
      expect(_reminder(due: due, snoozedUntil: until).nextAlertAt, until);
    });
    test('new rows carry patient name; newborn steps are recognised', () {
      expect(PatientReminder.fromRow({'kind': 'newborn_send', 'screen_id': 's1'}).isNewbornStep, isTrue);
      expect(PatientReminder.fromRow({'kind': 'general'}).isNewbornStep, isFalse);
      final row = PatientReminder.newRow(patientId: 'p1', wardId: 'w1', patientName: 'Baby', title: '  Send  ', dueAt: _born);
      expect(row['title'], 'Send');
      expect(row['patient_name'], 'Baby');
      expect(row.containsKey('done_by'), isFalse, reason: 'server stamps it');
    });
    test('notification text follows the newborn step', () {
      PatientReminder k(String kind) => PatientReminder.fromRow(
          {'kind': kind, 'screen_id': 's', 'patient_name': 'Baby Anaya'});
      expect(notificationBody(k('newborn_prep')), contains('get ready'));
      expect(notificationBody(k('newborn_send')), contains('been sent'));
      expect(notificationBody(k('newborn_results')), contains('results back'));
      expect(notificationBody(k('general')), contains('has this been done'));
    });

    test('notification ids are stable and non-negative', () {
      const id = '7f0c2c4e-1b2a-4c55-9f0e-0b8f6f1a2d33';
      expect(notificationId(id), notificationId(id));
      expect(notificationId(id), isNonNegative);
      expect(notificationId(id), isNot(notificationId('${id}x')));
    });
  });

  group('ReminderProvider due prompt', () {
    test('asks once per due reminder, again only after a snooze runs out', () async {
      var clock = _born.add(const Duration(hours: 49));
      final service = _FakeService();
      final provider = ReminderProvider(service: service, clock: () => clock);
      final asked = <String>[];
      provider.onDue = (r) async => asked.add(r.id);
      provider.subscribe(['w1']);

      service.controller.add([
        _reminder(id: 'due', due: _born.add(const Duration(hours: 48))),
        _reminder(id: 'later', due: _born.add(const Duration(hours: 72))),
      ]);
      await pumpEventQueue();
      expect(asked, ['due']);
      expect(provider.dueCount, 1);

      await provider.checkDue();
      expect(asked, ['due'], reason: 'not re-asked on the next tick');

      // Someone tapped "Not yet": snoozed for an hour, then it runs out.
      service.controller.add([
        _reminder(id: 'due', due: _born.add(const Duration(hours: 48)), snoozedUntil: clock.add(const Duration(hours: 1))),
      ]);
      await pumpEventQueue();
      expect(asked, ['due']);
      clock = clock.add(const Duration(hours: 1, minutes: 1));
      await provider.checkDue();
      expect(asked, ['due', 'due']);

      expect(await provider.snooze(provider.due.single), isTrue);
      expect(await provider.markDone(provider.due.single), isTrue);
      expect(service.calls, ['snooze:due:60', 'done:due']);
      provider.dispose();
    });
  });
}
