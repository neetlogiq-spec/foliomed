import 'row_parsing.dart';

class NoteComment {
  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String authorRole;
  final DateTime createdAt;
  final bool isAcknowledgement;

  const NoteComment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    this.isAcknowledgement = false,
  });

  /// Builds a comment from a `note_comments` row.
  factory NoteComment.fromRow(DbRow row) {
    return NoteComment(
      id: row['id'] as String? ?? '',
      text: row['text'] as String? ?? '',
      authorId: row['author_id'] as String? ?? '',
      authorName: row['author_name'] as String? ?? '',
      authorRole: row['author_role'] as String? ?? '',
      createdAt: parseTimestamp(row['created_at']),
      isAcknowledgement: row['is_acknowledgement'] as bool? ?? false,
    );
  }

  DbRow toRow(String noteId) => {
        'note_id': noteId,
        'text': text,
        'author_id': authorId.isEmpty ? null : authorId,
        'author_name': authorName,
        'author_role': authorRole,
        'is_acknowledgement': isAcknowledgement,
      };
}
