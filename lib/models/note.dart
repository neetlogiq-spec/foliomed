import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

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

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Note(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      patientName: data['patientName'] as String? ?? '',
      wardId: data['wardId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorRole: data['authorRole'] as String? ?? '',
      content: data['content'] as String? ?? '',
      category: data['category'] as String? ?? 'General',
      priority: data['priority'] as String? ?? 'Normal',
      isAcknowledged: data['isAcknowledged'] as bool? ?? false,
      acknowledgedBy: data['acknowledgedBy'] as String?,
      acknowledgedAt: (data['acknowledgedAt'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'wardId': wardId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'content': content,
      'category': category,
      'priority': priority,
      'isAcknowledged': isAcknowledged,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedAt': acknowledgedAt == null
          ? null
          : Timestamp.fromDate(acknowledgedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
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
      case 'general':
      default:
        return Icons.notes_outlined;
    }
  }
}
