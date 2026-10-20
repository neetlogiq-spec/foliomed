import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'row_parsing.dart';

/// What someone does on the ward. Stored by [name] in `profiles.role`.
enum UserRole {
  doctor('Doctor', AppColors.doctorColor),
  nurse('Nurse', AppColors.nurseColor),
  admin('Admin', AppColors.adminColor);

  const UserRole(this.label, this.color);
  final String label;
  final Color color;

  /// Unknown values fall back to nurse, the least-privileged clinical role.
  static UserRole parse(String? v) => values.firstWhere((r) => r.name == v, orElse: () => nurse);
}

/// The signed-in person (or anyone in People): one `profiles` row.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.hasChosenRole = true,
    this.wards = const [],
    this.primaryWard = '',
    this.speciality,
    this.emoji,
    this.photoUrl,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;

  /// False until a new person picks doctor or nurse.
  final bool hasChosenRole;

  /// Codes of every ward the person belongs to.
  final List<String> wards;

  /// The first ward joined; kept for older rows, prefer [wards].
  final String primaryWard;
  final String? speciality;
  final String? emoji; // shown instead of initials when set
  final String? photoUrl;
  final DateTime createdAt;

  String get roleLabel => role.label;
  Color get roleColor => role.color;
  bool belongsTo(String wardCode) => wards.contains(wardCode);

  AppUser copyWith({String? name, String? speciality, String? emoji, String? photoUrl}) => AppUser(
        uid: uid,
        name: name ?? this.name,
        email: email,
        role: role,
        hasChosenRole: hasChosenRole,
        wards: wards,
        primaryWard: primaryWard,
        speciality: speciality ?? this.speciality,
        emoji: emoji ?? this.emoji,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt,
      );

  static AppUser fromRow(DbRow row) => AppUser(
        uid: row['id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        email: row['email'] as String? ?? '',
        role: UserRole.parse(row['role'] as String?),
        hasChosenRole: row['role_confirmed'] as bool? ?? true,
        wards: parseStringList(row['ward_ids']),
        primaryWard: row['ward_id'] as String? ?? '',
        speciality: row['specialty'] as String?,
        emoji: row['avatar_emoji'] as String?,
        photoUrl: row['avatar_url'] as String?,
        createdAt: parseTimestamp(row['created_at']),
      );
}
