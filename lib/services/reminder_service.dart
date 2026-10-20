import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/patient_reminder.dart';
import '../models/row_parsing.dart';
import 'supabase_service.dart';

class ReminderService {
  ReminderService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _table => _client.from(Tables.patientReminders);

  static const int kOpenCap = 300;

  /// Most recent reminders (open or done) kept live.
  static const int kLiveCap = 600;

  /// Open (not done) reminders across the caller's wards, soonest first.
  ///
  /// The live query is filtered on `ward_id`, never on `done_at`: Supabase
  /// realtime doesn't tell a filtered query about rows that stop matching
  /// (or are deleted), so a `done_at is null` filter left finished and
  /// re-planned reminders on screen. "Open" is applied here instead.
  Stream<List<PatientReminder>> openForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _table
        .stream(primaryKey: ['id'])
        .inFilter('ward_id', wardIds)
        .order('due_at', ascending: false)
        .limit(kLiveCap)
        .map((rows) {
          final open = [
            for (final r in rows.map(PatientReminder.fromRow))
              if (!r.isDone) r,
          ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
          return open.length > kOpenCap ? open.sublist(0, kOpenCap) : open;
        });
  }

  /// Every reminder on one patient (open and done), soonest first.
  Stream<List<PatientReminder>> forPatient(String patientId) {
    return _table
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('due_at', ascending: true)
        .map((rows) => rows.map(PatientReminder.fromRow).toList());
  }

  Future<void> add({
    required String patientId,
    required String wardId,
    required String patientName,
    required String title,
    required DateTime dueAt,
  }) =>
      _table.insert(PatientReminder.newRow(
        patientId: patientId,
        wardId: wardId,
        patientName: patientName,
        title: title,
        dueAt: dueAt,
      ));

  /// Who/when is stamped by the database trigger.
  Future<void> markDone(String reminderId) => _table
      .update({'done_at': toTimestamp(DateTime.now())}).eq('id', reminderId);

  Future<void> reopen(String reminderId) =>
      _table.update({'done_at': null}).eq('id', reminderId);

  /// "Not yet" — asks the whole ward again after [delay].
  Future<void> snooze(String reminderId, Duration delay) => _table.update({
        'snoozed_until': toTimestamp(DateTime.now().add(delay)),
      }).eq('id', reminderId);

  Future<void> delete(String reminderId) =>
      _table.delete().eq('id', reminderId);
}
