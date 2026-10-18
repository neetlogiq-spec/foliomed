import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'row_parsing.dart';

enum UserRole { doctor, nurse, admin }

UserRole _roleFromString(String? value) {
  switch (value) {
    case 'doctor':
      return UserRole.doctor;
    case 'nurse':
      return UserRole.nurse;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.nurse;
  }
}

String _roleToString(UserRole role) => role.name;

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String wardId;
  final List<String> wardIds;
  final String? avatarUrl;
  final String? avatarEmoji;
  final String? specialty;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.wardId,
    this.wardIds = const [],
    this.avatarUrl,
    this.avatarEmoji,
    this.specialty,
    required this.createdAt,
  });

  /// Builds a user from a `profiles` row.
  factory AppUser.fromRow(DbRow row) {
    return AppUser(
      uid: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      role: _roleFromString(row['role'] as String?),
      wardId: row['ward_id'] as String? ?? '',
      wardIds: parseStringList(row['ward_ids']),
      avatarUrl: row['avatar_url'] as String?,
      avatarEmoji: row['avatar_emoji'] as String?,
      specialty: row['specialty'] as String?,
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  DbRow toRow() {
    return {
      'name': name,
      'email': email,
      'role': _roleToString(role),
      'ward_id': wardId,
      'ward_ids': wardIds,
      'avatar_url': avatarUrl,
      'avatar_emoji': avatarEmoji,
      'specialty': specialty,
    };
  }

  String get roleLabel {
    switch (role) {
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.nurse:
        return 'Nurse';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Color get roleColor {
    switch (role) {
      case UserRole.doctor:
        return AppColors.doctorColor;
      case UserRole.nurse:
        return AppColors.nurseColor;
      case UserRole.admin:
        return AppColors.adminColor;
    }
  }
}
