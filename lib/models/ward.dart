import 'row_parsing.dart';

/// A ward (team space). Its [id] is the 5-digit join code people share.
class Ward {
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

  final String id;
  final String name;

  /// Free text: floor, block or unit name.
  final String floor;
  final int capacity;

  /// Owner's display name, captured when the ward was created.
  final String headDoctorName;
  final String creatorId;
  final String creatorEmail;
  final DateTime createdAt;

  factory Ward.fromRow(DbRow r) => Ward(
        id: r['id'] as String? ?? '',
        name: r['name'] as String? ?? '',
        floor: r['floor'] as String? ?? '',
        capacity: (r['capacity'] as num?)?.toInt() ?? 0,
        headDoctorName: r['head_doctor_name'] as String? ?? '',
        creatorId: r['creator_id'] as String? ?? '',
        creatorEmail: r['creator_email'] as String? ?? '',
        createdAt: parseTimestamp(r['created_at']),
      );

  /// Includes [id]: a new ward claims its code on insert (the primary key
  /// rejects a code already taken).
  DbRow toRow() => {
        'id': id,
        'name': name,
        'floor': floor,
        'capacity': capacity,
        'head_doctor_name': headDoctorName,
        'creator_id': creatorId.isEmpty ? null : creatorId,
        'creator_email': creatorEmail,
      };
}
