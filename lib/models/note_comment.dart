import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory NoteComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NoteComment(
      id: doc.id,
      text: data['text'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorRole: data['authorRole'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAcknowledgement: data['isAcknowledgement'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'createdAt': Timestamp.fromDate(createdAt),
        'isAcknowledgement': isAcknowledgement,
      };
}
