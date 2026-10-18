import 'row_parsing.dart';

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

  /// Builds a ward from a `wards` row.
  factory Ward.fromRow(DbRow row) {
    return Ward(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      floor: row['floor'] as String? ?? '',
      capacity: (row['capacity'] as num?)?.toInt() ?? 0,
      headDoctorName: row['head_doctor_name'] as String? ?? '',
      creatorId: row['creator_id'] as String? ?? '',
      creatorEmail: row['creator_email'] as String? ?? '',
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  /// Columns written on insert/update. `id` is included so a new ward can
  /// claim its 5-digit code; Postgres rejects duplicates via the PK.
  DbRow toRow() {
    return {
      'id': id,
      'name': name,
      'floor': floor,
      'capacity': capacity,
      'head_doctor_name': headDoctorName,
      'creator_id': creatorId.isEmpty ? null : creatorId,
      'creator_email': creatorEmail,
    };
  }
}
