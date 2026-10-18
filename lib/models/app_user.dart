import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

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

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: _roleFromString(data['role'] as String?),
      wardId: data['wardId'] as String? ?? '',
      wardIds: (data['wardIds'] as List?)?.whereType<String>().toList() ??
          const [],
      avatarUrl: data['avatarUrl'] as String?,
      avatarEmoji: data['avatarEmoji'] as String?,
      specialty: data['specialty'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': _roleToString(role),
      'wardId': wardId,
      'wardIds': wardIds,
      'avatarUrl': avatarUrl,
      'avatarEmoji': avatarEmoji,
      'specialty': specialty,
      'createdAt': Timestamp.fromDate(createdAt),
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
