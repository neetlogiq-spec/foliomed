import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/app_user.dart';
import 'package:foliomed/models/note.dart';
import 'package:foliomed/models/note_reply.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/row_parsing.dart';
import 'package:foliomed/models/ward.dart';

void main() {
  group('row_parsing', () {
    test('parses ISO timestamps and falls back safely', () {
      final parsed = parseTimestampOrNull('2026-10-19T08:30:00+00:00');
      expect(parsed?.toUtc(), DateTime.utc(2026, 10, 19, 8, 30));
      expect(parseTimestampOrNull(null), isNull);
      expect(parseTimestampOrNull(''), isNull);
      expect(parseTimestampOrNull('not a date'), isNull);
      expect(parseTimestamp(null), isA<DateTime>());
    });

    test('parses string lists, dropping non-strings', () {
      expect(parseStringList(['12345', 7, null, '54321']), ['12345', '54321']);
      expect(parseStringList(null), isEmpty);
    });

    test('serialises timestamps as UTC ISO-8601', () {
      final local = DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal();
      expect(toTimestamp(local), '2026-01-02T03:04:05.000Z');
      expect(toTimestampOrNull(null), isNull);
    });
  });

  group('AppUser', () {
    test('fromRow maps profile columns', () {
      final user = AppUser.fromRow({
        'id': 'u1',
        'name': 'Dr K',
        'email': 'k@www.foliomed.app',
        'role': 'nurse',
        'ward_id': '12345',
        'ward_ids': ['12345', '67890'],
        'avatar_emoji': '🩺',
        'created_at': '2026-10-19T00:00:00Z',
      });
      expect(user.uid, 'u1');
      expect(user.role, UserRole.nurse);
      expect(user.wards, ['12345', '67890']);
      expect(user.emoji, '🩺');
    });

    test('unknown role falls back to nurse', () {
      expect(AppUser.fromRow({'role': 'superuser'}).role, UserRole.nurse);
    });

    test('roles carry their label and copyWith keeps identity', () {
      final u = AppUser.fromRow({'id': 'u1', 'role': 'admin', 'name': 'A'});
      expect(u.roleLabel, 'Admin');
      final renamed = u.copyWith(name: 'B');
      expect(renamed.uid, 'u1');
      expect(renamed.name, 'B');
      expect(renamed.role, UserRole.admin);
    });
  });

  group('Ward', () {
    test('round-trips through a row', () {
      final ward = Ward.fromRow({
        'id': '12345',
        'name': 'ICU',
        'floor': '2',
        'capacity': 12,
        'head_doctor_name': 'Dr K',
        'creator_id': 'u1',
        'creator_email': 'k@www.foliomed.app',
        'created_at': '2026-10-19T00:00:00Z',
      });
      final row = ward.toRow();
      expect(row['id'], '12345');
      expect(row['head_doctor_name'], 'Dr K');
      expect(row['creator_id'], 'u1');
    });

    test('empty creator id becomes null (FK-safe)', () {
      final ward = Ward(
        id: '12345',
        name: 'ICU',
        location: '',
        beds: 0,
        ownerName: '',
        createdAt: DateTime.now(),
      );
      expect(ward.toRow()['creator_id'], isNull);
    });
  });

  group('Patient', () {
    test('fromRow maps columns and defaults is_active', () {
      final p = Patient.fromRow({
        'id': 'p1',
        'name': 'Asha Rao',
        'age': 34,
        'ward_id': '12345',
        'bed_number': 'B4',
        'admitted_at': '2026-10-18T10:00:00Z',
      });
      expect(p.bedNumber, 'B4');
      expect(p.isActive, isTrue);
      expect(p.initials, 'AR');
    });

    test('toRow omits id so Postgres generates it', () {
      final row = Patient.fromRow({'id': 'p1', 'name': 'X'}).toRow();
      expect(row.containsKey('id'), isFalse);
      expect(row['ward_id'], '');
    });
  });

  group('Note', () {
    test('fromRow maps acknowledgement fields', () {
      final note = Note.fromRow({
        'id': 'n1',
        'patient_id': 'p1',
        'ward_id': '12345',
        'author_id': 'u1',
        'content': 'BP 120/80',
        'priority': 'Urgent',
        'is_acknowledged': true,
        'acknowledged_by': 'Nurse B',
        'acknowledged_at': '2026-10-19T01:00:00Z',
        'created_at': '2026-10-19T00:00:00Z',
        'updated_at': '2026-10-19T00:30:00Z',
      });
      expect(note.isConfirmed, isTrue);
      expect(note.confirmedAt, isNotNull);
      expect(note.kind, 'General');
    });

    test('toRow leaves server-managed columns out', () {
      final row = Note.fromRow({'id': 'n1', 'content': 'x'}).toRow();
      expect(row.containsKey('id'), isFalse);
      expect(row.containsKey('created_at'), isFalse);
      expect(row['author_id'], isNull);
      expect(row['acknowledged_at'], isNull);
    });
  });

  group('NoteReply', () {
    test('toRow attaches the parent note id and keeps the confirmation flag', () {
      final c = NoteReply.fromRow({
        'id': 'c1',
        'text': 'Seen',
        'author_id': 'u2',
        'is_acknowledgement': true,
      });
      expect(c.isConfirmation, isTrue);
      final row = c.toRow('n1');
      expect(row['note_id'], 'n1');
      expect(row['is_acknowledgement'], isTrue);
    });
  });
}
