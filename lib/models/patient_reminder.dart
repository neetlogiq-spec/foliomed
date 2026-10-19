import 'row_parsing.dart';

/// A ward-shared, due-at reminder on a patient — e.g. "Send 48-hour
/// investigations". Completion is stamped (who/when) by the database.
class PatientReminder {
  final String id;
  final String patientId;
  final String wardId;
  final String patientName;
  final String title;
  final DateTime dueAt;
  final DateTime? snoozedUntil;
  final DateTime? doneAt;
  final String? doneByName;
  final DateTime createdAt;

  /// 'general', or a step of a newborn investigation plan:
  /// 'newborn_prep' (heads-up), 'newborn_send' (sent?), 'newborn_results'.
  final String kind;
  final String? screenId;

  const PatientReminder({
    required this.id,
    required this.patientId,
    required this.wardId,
    this.patientName = '',
    required this.title,
    required this.dueAt,
    this.snoozedUntil,
    this.doneAt,
    this.doneByName,
    required this.createdAt,
    this.kind = 'general',
    this.screenId,
  });

  bool get isNewbornStep => screenId != null && kind.startsWith('newborn_');

  bool get isDone => doneAt != null;

  /// Due (and not snoozed) at [now].
  bool isDueAt(DateTime now) {
    if (isDone || dueAt.isAfter(now)) return false;
    return snoozedUntil == null || !snoozedUntil!.isAfter(now);
  }

  bool isOverdueAt(DateTime now) => !isDone && dueAt.isBefore(now);

  /// When it should next fire: the due time, or the end of a snooze.
  DateTime get nextAlertAt =>
      snoozedUntil != null && snoozedUntil!.isAfter(dueAt) ? snoozedUntil! : dueAt;

  factory PatientReminder.fromRow(DbRow row) => PatientReminder(
        id: row['id'] as String? ?? '',
        patientId: row['patient_id'] as String? ?? '',
        wardId: row['ward_id'] as String? ?? '',
        patientName: row['patient_name'] as String? ?? '',
        title: row['title'] as String? ?? '',
        dueAt: parseTimestamp(row['due_at']),
        snoozedUntil: parseTimestampOrNull(row['snoozed_until']),
        doneAt: parseTimestampOrNull(row['done_at']),
        doneByName: row['done_by_name'] as String?,
        createdAt: parseTimestamp(row['created_at']),
        kind: row['kind'] as String? ?? 'general',
        screenId: row['screen_id'] as String?,
      );

  /// Columns for a new reminder (creator is stamped by the database).
  static DbRow newRow({
    required String patientId,
    required String wardId,
    required String patientName,
    required String title,
    required DateTime dueAt,
  }) =>
      {
        'patient_id': patientId,
        'ward_id': wardId,
        'patient_name': patientName,
        'title': title.trim(),
        'due_at': toTimestamp(dueAt),
      };
}
