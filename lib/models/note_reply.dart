import 'row_parsing.dart';

/// A reply in a note's thread (`note_comments` table). A confirmation
/// reply records what was done when someone confirmed the note.
class NoteReply {
  const NoteReply({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    this.isConfirmation = false,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String authorRole;
  final DateTime createdAt;
  final bool isConfirmation;

  factory NoteReply.fromRow(DbRow r) => NoteReply(
        id: r['id'] as String? ?? '',
        text: r['text'] as String? ?? '',
        authorId: r['author_id'] as String? ?? '',
        authorName: r['author_name'] as String? ?? '',
        authorRole: r['author_role'] as String? ?? '',
        createdAt: parseTimestamp(r['created_at']),
        isConfirmation: r['is_acknowledgement'] as bool? ?? false,
      );

  DbRow toRow(String noteId) => {
        'note_id': noteId,
        'text': text,
        'author_id': authorId.isEmpty ? null : authorId,
        'author_name': authorName,
        'author_role': authorRole,
        'is_acknowledgement': isConfirmation,
      };
}
