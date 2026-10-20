import 'row_parsing.dart';

/// A task on a patient for today's team: "Repeat TSB", "Send TSH",
/// "Paeds review". Optionally assigned to one ward member and due by a
/// time. Creator, assignee name and completer are stamped by the database.
class WardJob {
  const WardJob({
    required this.id,
    required this.wardId,
    required this.patientId,
    this.patientName = '',
    required this.title,
    this.urgent = false,
    this.dueBy,
    this.assignedTo,
    this.assignedName,
    this.createdByName,
    required this.createdAt,
    this.doneAt,
    this.doneByName,
  });

  final String id;
  final String wardId;
  final String patientId;
  final String patientName;
  final String title;
  final bool urgent;
  final DateTime? dueBy;
  final String? assignedTo;
  final String? assignedName;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime? doneAt;
  final String? doneByName;

  bool get isDone => doneAt != null;
  bool get isUnassigned => assignedTo == null;
  bool isFor(String uid) => assignedTo != null && assignedTo == uid;
  bool isOverdueAt(DateTime now) => !isDone && dueBy != null && dueBy!.isBefore(now);

  /// Open jobs first; then urgent, overdue/soonest due, oldest.
  static int byPriority(WardJob a, WardJob b, DateTime now) {
    int rank(WardJob j) => j.isDone ? 3 : (j.urgent || j.isOverdueAt(now) ? 0 : (j.dueBy != null ? 1 : 2));
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    if (a.isDone) return b.doneAt!.compareTo(a.doneAt!); // latest done first
    final ad = a.dueBy, bd = b.dueBy;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if (ad != null && bd == null) return -1;
    if (bd != null && ad == null) return 1;
    return a.createdAt.compareTo(b.createdAt);
  }

  static WardJob fromRow(DbRow row) => WardJob(
        id: row['id'] as String? ?? '',
        wardId: row['ward_id'] as String? ?? '',
        patientId: row['patient_id'] as String? ?? '',
        patientName: row['patient_name'] as String? ?? '',
        title: row['title'] as String? ?? '',
        urgent: row['urgent'] as bool? ?? false,
        dueBy: parseTimestampOrNull(row['due_by']),
        assignedTo: row['assigned_to'] as String?,
        assignedName: row['assigned_name'] as String?,
        createdByName: row['created_by_name'] as String?,
        createdAt: parseTimestamp(row['created_at']),
        doneAt: parseTimestampOrNull(row['done_at']),
        doneByName: row['done_by_name'] as String?,
      );

  /// Columns the app sends for a new job; the rest is stamped server-side.
  static DbRow newRow({
    required String wardId,
    required String patientId,
    required String title,
    bool urgent = false,
    DateTime? dueBy,
    String? assignedTo,
  }) =>
      {
        'ward_id': wardId,
        'patient_id': patientId,
        'title': title.trim(),
        'urgent': urgent,
        'due_by': toTimestampOrNull(dueBy),
        'assigned_to': assignedTo,
      };
}

/// Quick picks offered when adding a job (newborn / postnatal ward).
const List<String> kCommonJobs = [
  'Repeat TSB',
  'Send TSH',
  'Send CBC',
  'Blood grouping',
  'OAE hearing screen',
  'Paeds review',
  'Check feeds',
  'Weigh baby',
  'Chase lab report',
  'Discharge papers',
];
