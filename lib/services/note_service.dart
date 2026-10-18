import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';
import '../models/note_comment.dart';
import '../utils/app_constants.dart';
import 'metrics_service.dart';

class NoteService {
  final FirebaseFirestore _firestore;

  NoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notes =>
      _firestore.collection(AppConstants.notesCollection);

  /// Hard-capped at 150 to keep Firestore reads predictable. Older notes
  /// remain in the database — they just don't stream into the live feed.
  static const int kNoteFeedLimit = 150;

  Stream<List<Note>> getNotesForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _notes
        .where('wardId', whereIn: wardIds)
        .orderBy('createdAt', descending: true)
        .limit(kNoteFeedLimit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Note.fromFirestore).toList());
  }

  /// Capped at 150 — the badge shows '150+' if there are more, but we
  /// never read more than 150 docs to compute it. Without this cap a ward
  /// with thousands of un-ack'd notes would burn thousands of Firestore
  /// reads on every snapshot tick.
  static const int kUnackCountCap = 150;

  Stream<int> getUnacknowledgedCountForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(0);
    return _notes
        .where('wardId', whereIn: wardIds)
        .where('isAcknowledged', isEqualTo: false)
        .limit(kUnackCountCap)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<Note>> getNotesByWard(String wardId) {
    return _notes
        .where('wardId', isEqualTo: wardId)
        .orderBy('createdAt', descending: true)
        .limit(kNoteFeedLimit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Note.fromFirestore).toList());
  }

  /// Per-patient timeline. Capped at 100 — older notes still exist in
  /// Firestore, they just don't stream into the UI in one go.
  Stream<List<Note>> getNotesByPatient(String patientId) {
    return _notes
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Note.fromFirestore).toList());
  }

  Stream<List<Note>> getUnacknowledgedNotes(String wardId) {
    return _notes
        .where('wardId', isEqualTo: wardId)
        .where('isAcknowledged', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(kUnackCountCap)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Note.fromFirestore).toList());
  }

  Future<String> addNote(Note note) async {
    final ref = await _notes.add(note.toMap());
    MetricsService.bump('note',
        summary: '${note.authorName} → ${note.patientName}');
    return ref.id;
  }

  Future<void> updateNote(Note note) async {
    await _notes.doc(note.id).update({
      ...note.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> acknowledgeNote(String noteId, String acknowledgedBy) async {
    await _notes.doc(noteId).update({
      'isAcknowledged': true,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedAt': Timestamp.fromDate(DateTime.now()),
    });
    MetricsService.bump('ack', summary: '$acknowledgedBy ack\'d a note');
  }

  Future<void> acknowledgeAllNotes(
      List<String> noteIds, String acknowledgedBy) async {
    if (noteIds.isEmpty) return;
    final now = Timestamp.fromDate(DateTime.now());
    final batch = _firestore.batch();
    for (final id in noteIds) {
      batch.update(_notes.doc(id), {
        'isAcknowledged': true,
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedAt': now,
      });
    }
    await batch.commit();
    MetricsService.bump('ack',
        summary: '$acknowledgedBy cleared ${noteIds.length} notifications');
  }

  Future<void> unacknowledgeNote(String noteId) async {
    await _notes.doc(noteId).update({
      'isAcknowledged': false,
      'acknowledgedBy': null,
      'acknowledgedAt': null,
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _notes.doc(noteId).delete();
  }

  CollectionReference<Map<String, dynamic>> _commentsRef(String noteId) =>
      _notes.doc(noteId).collection('comments');

  /// Capped at 100 — a single note rarely needs more comments than that.
  /// Older replies still exist in Firestore, they just don't stream into
  /// the thread bubble in one go.
  Stream<List<NoteComment>> commentsStream(String noteId) {
    return _commentsRef(noteId)
        .orderBy('createdAt')
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(NoteComment.fromFirestore).toList());
  }

  Future<void> addComment(String noteId, NoteComment comment) async {
    await _commentsRef(noteId).add(comment.toMap());
    MetricsService.bump('comment',
        summary: '${comment.authorName} replied');
  }

  Future<void> deleteComment(String noteId, String commentId) async {
    await _commentsRef(noteId).doc(commentId).delete();
  }

  Stream<int> getUnacknowledgedCount(String wardId) {
    return _notes
        .where('wardId', isEqualTo: wardId)
        .where('isAcknowledged', isEqualTo: false)
        .limit(kUnackCountCap)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
