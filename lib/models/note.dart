import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'row_parsing.dart';

/// Kinds of note a person can post (system lines use their own kinds).
const List<String> kNoteKinds = ['General', 'Observation', 'Medication', 'Procedure', 'Alert'];

/// How pressing a note is. Stored as its [label] in `notes.priority`.
enum NoteUrgency {
  low('Low'),
  normal('Normal'),
  urgent('Urgent');

  const NoteUrgency(this.label);
  final String label;

  static NoteUrgency parse(String? v) =>
      values.firstWhere((u) => u.label == v, orElse: () => normal);

  Color get color => switch (this) {
        low => AppColors.textSecondary,
        normal => AppColors.primary,
        urgent => AppColors.danger,
      };
}

/// One message on a patient's timeline. A team member posts it; someone
/// else confirms it once it has been seen and dealt with. System lines
/// (transfer, discharge, results…) arrive already confirmed.
class Note {
  const Note({
    required this.id,
    required this.wardId,
    required this.patientId,
    required this.patientName,
    required this.text,
    this.kind = 'General',
    this.urgency = NoteUrgency.normal,
    required this.authorId,
    required this.authorName,
    this.authorRole = '',
    this.isConfirmed = false,
    this.confirmedBy,
    this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String wardId;
  final String patientId;
  final String patientName;
  final String text;
  final String kind; // one of [kNoteKinds], or a system kind
  final NoteUrgency urgency;
  final String authorId;
  final String authorName;
  final String authorRole;
  final bool isConfirmed;
  final String? confirmedBy; // display name
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isUrgent => urgency == NoteUrgency.urgent;

  static const _kindIcons = <String, IconData>{
    'medication': Icons.medication_outlined,
    'procedure': Icons.healing_outlined,
    'observation': Icons.monitor_heart_outlined,
    'alert': Icons.report_outlined,
    'transfer': Icons.swap_horiz,
    'discharge': Icons.logout,
    'admission': Icons.login,
    'investigation': Icons.science_outlined,
    'phototherapy': Icons.light_mode_outlined,
    'status': Icons.circle_outlined,
    'photo': Icons.photo_camera_outlined,
    'infusion': Icons.water_drop_outlined,
  };

  IconData get kindIcon => _kindIcons[kind.toLowerCase()] ?? Icons.sticky_note_2_outlined;

  /// Maps a `notes` row. Column names predate the app's vocabulary:
  /// content → [text], category → [kind], priority → [urgency],
  /// is_acknowledged → [isConfirmed].
  static Note fromRow(DbRow row) {
    String str(String column) => row[column] as String? ?? '';
    return Note(
      id: str('id'),
      wardId: str('ward_id'),
      patientId: str('patient_id'),
      patientName: str('patient_name'),
      text: str('content'),
      kind: row['category'] as String? ?? 'General',
      urgency: NoteUrgency.parse(row['priority'] as String?),
      authorId: str('author_id'),
      authorName: str('author_name'),
      authorRole: str('author_role'),
      isConfirmed: row['is_acknowledged'] as bool? ?? false,
      confirmedBy: row['acknowledged_by'] as String?,
      confirmedAt: parseTimestampOrNull(row['acknowledged_at']),
      createdAt: parseTimestamp(row['created_at']),
      updatedAt: parseTimestamp(row['updated_at']),
    );
  }

  /// What the app inserts; `id` and the timestamps come from Postgres.
  DbRow toRow() => {
        'ward_id': wardId,
        'patient_id': patientId,
        'patient_name': patientName,
        'content': text,
        'category': kind,
        'priority': urgency.label,
        'author_id': authorId.isEmpty ? null : authorId,
        'author_name': authorName,
        'author_role': authorRole,
        'is_acknowledged': isConfirmed,
        'acknowledged_by': confirmedBy,
        'acknowledged_at': toTimestampOrNull(confirmedAt),
      };
}
