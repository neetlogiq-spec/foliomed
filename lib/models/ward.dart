import 'row_parsing.dart';

/// A team space people join with its 5-digit [id] (the code they share).
/// Dart names are FolioMed's; [Ward.fromRow] maps the `wards` columns.
class Ward {
  const Ward({
    required this.id,
    required this.name,
    this.location = '',
    this.beds = 0,
    this.ownerName = '',
    this.ownerId = '',
    this.ownerEmail = '',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String location; // floor, block or building — free text
  final int beds;
  final String ownerName; // captured when the ward was set up
  final String ownerId;
  final String ownerEmail;
  final DateTime createdAt;

  bool ownedBy(String uid) => uid.isNotEmpty && uid == ownerId;

  static Ward fromRow(DbRow row) {
    String text(String column) => row[column] as String? ?? '';
    return Ward(
      id: text('id'),
      name: text('name'),
      location: text('floor'),
      beds: (row['capacity'] as num?)?.toInt() ?? 0,
      ownerName: text('head_doctor_name'),
      ownerId: text('creator_id'),
      ownerEmail: text('creator_email'),
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  /// The row to insert. It carries [id] because a new ward claims its code
  /// on insert; a code that is already taken fails the primary key.
  DbRow toRow() => {
        'id': id,
        'name': name,
        'floor': location,
        'capacity': beds,
        'head_doctor_name': ownerName,
        'creator_id': ownerId.isEmpty ? null : ownerId,
        'creator_email': ownerEmail,
      };
}
