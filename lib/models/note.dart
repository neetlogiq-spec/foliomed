import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'row_parsing.dart';

class Note {
  final String id;
  final String patientId;
  final String patientName;
  final String wardId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String content;
  final String category;
  final String priority;
  final bool isAcknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

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

  /// Builds a note from a `notes` row.
  factory Note.fromRow(DbRow row) {
    return Note(
      id: row['id'] as String? ?? '',
      patientId: row['patient_id'] as String? ?? '',
      patientName: row['patient_name'] as String? ?? '',
      wardId: row['ward_id'] as String? ?? '',
      authorId: row['author_id'] as String? ?? '',
      authorName: row['author_name'] as String? ?? '',
      authorRole: row['author_role'] as String? ?? '',
      content: row['content'] as String? ?? '',
      category: row['category'] as String? ?? 'General',
      priority: row['priority'] as String? ?? 'Normal',
      isAcknowledged: row['is_acknowledged'] as bool? ?? false,
      acknowledgedBy: row['acknowledged_by'] as String?,
      acknowledgedAt: parseTimestampOrNull(row['acknowledged_at']),
      createdAt: parseTimestamp(row['created_at']),
      updatedAt: parseTimestamp(row['updated_at']),
    );
  }

  /// Columns written on insert/update. `id`, `created_at` and
  /// `updated_at` are maintained by Postgres.
  DbRow toRow() {
    return {
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

  Color get priorityColor {
    switch (priority) {
      case 'Urgent':
        return AppColors.danger;
      case 'Low':
        return AppColors.textSecondary;
      case 'Normal':
      default:
        return AppColors.primary;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'medication':
        return Icons.medication_outlined;
      case 'procedure':
        return Icons.medical_services_outlined;
      case 'observation':
        return Icons.visibility_outlined;
      case 'alert':
        return Icons.warning_amber_outlined;
      case 'transfer':
        return Icons.swap_horiz;
      case 'discharge':
        return Icons.logout;
      case 'admission':
        return Icons.login;
      case 'investigation':
        return Icons.science_outlined;
      case 'phototherapy':
        return Icons.light_mode_outlined;
      case 'general':
      default:
        return Icons.notes_outlined;
    }
  }
}
