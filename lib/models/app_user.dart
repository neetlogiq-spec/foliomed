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

/// A FolioMed account (`profiles` row).
class AppUser {
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
    this.roleConfirmed = true,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;

  /// Legacy "home" ward; [wardIds] is the full membership list.
  final String wardId;
  final List<String> wardIds;
  final String? avatarUrl;
  final String? avatarEmoji;
  final String? specialty;
  final DateTime createdAt;

  /// Whether the person has chosen doctor or nurse after first sign-in.
  final bool roleConfirmed;

  String get roleLabel => role.label;
  Color get roleColor => role.color;

  AppUser copyWith({String? name, String? avatarUrl, String? avatarEmoji, String? specialty}) => AppUser(
        uid: uid,
        name: name ?? this.name,
        email: email,
        role: role,
        wardId: wardId,
        wardIds: wardIds,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        specialty: specialty ?? this.specialty,
        createdAt: createdAt,
        roleConfirmed: roleConfirmed,
      );

  factory AppUser.fromRow(DbRow r) => AppUser(
        uid: r['id'] as String? ?? '',
        name: r['name'] as String? ?? '',
        email: r['email'] as String? ?? '',
        role: UserRole.parse(r['role'] as String?),
        wardId: r['ward_id'] as String? ?? '',
        wardIds: parseStringList(r['ward_ids']),
        avatarUrl: r['avatar_url'] as String?,
        avatarEmoji: r['avatar_emoji'] as String?,
        specialty: r['specialty'] as String?,
        createdAt: parseTimestamp(r['created_at']),
        roleConfirmed: r['role_confirmed'] as bool? ?? true,
      );
}
