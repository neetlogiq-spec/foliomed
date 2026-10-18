import 'package:cloud_firestore/cloud_firestore.dart';

class Ward {
  final String id;
  final String name;
  final String floor;
  final int capacity;
  final String headDoctorName;
  final String creatorId;
  final String creatorEmail;
  final DateTime createdAt;

  const Ward({
    required this.id,
    required this.name,
    required this.floor,
    required this.capacity,
    required this.headDoctorName,
    this.creatorId = '',
    this.creatorEmail = '',
    required this.createdAt,
  });

  factory Ward.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Ward(
      id: doc.id,
      name: data['name'] as String? ?? '',
      floor: data['floor'] as String? ?? '',
      capacity: (data['capacity'] as num?)?.toInt() ?? 0,
      headDoctorName: data['headDoctorName'] as String? ?? '',
      creatorId: data['creatorId'] as String? ?? '',
      creatorEmail: data['creatorEmail'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'floor': floor,
      'capacity': capacity,
      'headDoctorName': headDoctorName,
      'creatorId': creatorId,
      'creatorEmail': creatorEmail,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
