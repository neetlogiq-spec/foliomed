import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String wardId;
  final String bedNumber;
  final String diagnosis;
  final String? bloodGroup;
  final DateTime admittedAt;
  final bool isActive;
  final String hlsStreamUrl;

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.wardId,
    required this.bedNumber,
    required this.diagnosis,
    this.bloodGroup,
    required this.admittedAt,
    this.isActive = true,
    this.hlsStreamUrl = '',
  });

  factory Patient.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Patient(
      id: doc.id,
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      gender: data['gender'] as String? ?? '',
      wardId: data['wardId'] as String? ?? '',
      bedNumber: data['bedNumber'] as String? ?? '',
      diagnosis: data['diagnosis'] as String? ?? '',
      bloodGroup: data['bloodGroup'] as String?,
      admittedAt:
          (data['admittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      hlsStreamUrl: data['hlsStreamUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'wardId': wardId,
      'bedNumber': bedNumber,
      'diagnosis': diagnosis,
      'bloodGroup': bloodGroup,
      'admittedAt': Timestamp.fromDate(admittedAt),
      'isActive': isActive,
    };
  }

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1][0]
        : (parts.first.length > 1 ? parts.first[1] : '');
    return (first + second).toUpperCase();
  }
}
