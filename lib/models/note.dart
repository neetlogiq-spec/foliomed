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

/// A ward note about one patient: written by one team member, confirmed
/// (seen and acted on) by another. Field names follow the `notes` table.
class Note {
  const Note({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.wardId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    required this.category,
    required this.priority,
    this.isAcknowledged = false,
    this.acknowledgedBy,
    this.acknowledgedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String wardId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String content;
  final String category;

  /// `Low` / `Normal` / `Urgent` — see [urgency].
  final String priority;

  /// Confirmed by a team member (the `is_acknowledged` column).
  final bool isAcknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteUrgency get urgency => NoteUrgency.parse(priority);
  bool get isUrgent => urgency == NoteUrgency.urgent;
  bool get isConfirmed => isAcknowledged;
  Color get priorityColor => urgency.color;

  /// System lines (transfer, discharge, results…) are posted already
  /// confirmed and authored by whoever triggered them.
  static const _icons = <String, IconData>{
    'medication': Icons.medication_outlined,
    'procedure': Icons.healing_outlined,
    'observation': Icons.monitor_heart_outlined,
    'alert': Icons.report_outlined,
    'transfer': Icons.swap_horiz,
    'discharge': Icons.logout,
    'admission': Icons.login,
    'investigation': Icons.science_outlined,
    'phototherapy': Icons.light_mode_outlined,
  };

  IconData get categoryIcon => _icons[category.toLowerCase()] ?? Icons.sticky_note_2_outlined;

  factory Note.fromRow(DbRow r) => Note(
        id: r['id'] as String? ?? '',
        patientId: r['patient_id'] as String? ?? '',
        patientName: r['patient_name'] as String? ?? '',
        wardId: r['ward_id'] as String? ?? '',
        authorId: r['author_id'] as String? ?? '',
        authorName: r['author_name'] as String? ?? '',
        authorRole: r['author_role'] as String? ?? '',
        content: r['content'] as String? ?? '',
        category: r['category'] as String? ?? 'General',
        priority: r['priority'] as String? ?? NoteUrgency.normal.label,
        isAcknowledged: r['is_acknowledged'] as bool? ?? false,
        acknowledgedBy: r['acknowledged_by'] as String?,
        acknowledgedAt: parseTimestampOrNull(r['acknowledged_at']),
        createdAt: parseTimestamp(r['created_at']),
        updatedAt: parseTimestamp(r['updated_at']),
      );

  /// Columns the app writes; `id` and timestamps belong to Postgres.
  DbRow toRow() => {
        'patient_id': patientId,
        'patient_name': patientName,
        'ward_id': wardId,
        'author_id': authorId.isEmpty ? null : authorId,
        'author_name': authorName,
        'author_role': authorRole,
        'content': content,
        'category': category,
        'priority': priority,
        'is_acknowledged': isAcknowledged,
        'acknowledged_by': acknowledgedBy,
        'acknowledged_at': toTimestampOrNull(acknowledgedAt),
      };
}
