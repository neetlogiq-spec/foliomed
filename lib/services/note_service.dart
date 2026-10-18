import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note.dart';
import '../models/note_comment.dart';
import '../models/row_parsing.dart';
import 'metrics_service.dart';
import 'supabase_service.dart';

class NoteService {
  final SupabaseClient _client;

  NoteService({SupabaseClient? client}) : _client = client ?? supabase;

  SupabaseQueryBuilder get _notes => _client.from(Tables.notes);
  SupabaseQueryBuilder get _comments => _client.from(Tables.noteComments);

  /// Hard-capped at 150 to keep realtime payloads predictable. Older notes
  /// remain in the database — they just don't stream into the live feed.
  static const int kNoteFeedLimit = 150;

  /// Unacknowledged notes are capped at 150 — the badge shows '150+'.
  static const int kUnackCountCap = 150;

  static List<Note> _toNotes(List<DbRow> rows) =>
      rows.map(Note.fromRow).toList();

  Stream<List<Note>> getNotesForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _notes
        .stream(primaryKey: ['id'])
        .inFilter('ward_id', wardIds)
        .order('created_at', ascending: false)
        .limit(kNoteFeedLimit)
        .map(_toNotes);
  }

  /// Realtime streams accept a single filter, so this streams every
  /// unacknowledged note the caller can see (RLS already limits that to
  /// their wards) and narrows to [wardIds] client-side.
  Stream<List<Note>> _unacknowledgedForWards(List<String> wardIds) {
    final wanted = wardIds.toSet();
    return _notes
        .stream(primaryKey: ['id'])
        .eq('is_acknowledged', false)
        .order('created_at', ascending: false)
        .limit(kUnackCountCap)
        .map((rows) => _toNotes(rows)
            .where((n) => wanted.contains(n.wardId))
            .toList());
  }

  Stream<int> getUnacknowledgedCountForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(0);
    return _unacknowledgedForWards(wardIds).map((notes) => notes.length);
  }

  Stream<List<Note>> getNotesByWard(String wardId) {
    return _notes
        .stream(primaryKey: ['id'])
        .eq('ward_id', wardId)
        .order('created_at', ascending: false)
        .limit(kNoteFeedLimit)
        .map(_toNotes);
  }

  /// Per-patient timeline, capped at 100.
  Stream<List<Note>> getNotesByPatient(String patientId) {
    return _notes
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(100)
        .map(_toNotes);
  }

  Stream<List<Note>> getUnacknowledgedNotes(String wardId) =>
      _unacknowledgedForWards([wardId]);

  Stream<int> getUnacknowledgedCount(String wardId) =>
      getUnacknowledgedCountForWards([wardId]);

  /// Live acknowledgement state of a single note.
  Stream<bool> acknowledgedStream(String noteId) {
    return _notes
        .stream(primaryKey: ['id'])
        .eq('id', noteId)
        .map((rows) =>
            rows.isNotEmpty && (rows.first['is_acknowledged'] as bool? ?? false));
  }

  Future<String> addNote(Note note) async {
    final row = await _notes.insert(note.toRow()).select('id').single();
    MetricsService.bump('note',
        summary: '${note.authorName} → ${note.patientName}');
    return row['id'] as String;
  }

  Future<void> updateNote(Note note) async {
    await _notes.update(note.toRow()).eq('id', note.id);
  }

  Future<void> acknowledgeNote(String noteId, String acknowledgedBy) async {
    await _notes.update({
      'is_acknowledged': true,
      'acknowledged_by': acknowledgedBy,
      'acknowledged_at': toTimestamp(DateTime.now()),
    }).eq('id', noteId);
    MetricsService.bump('ack', summary: '$acknowledgedBy ack\'d a note');
  }

  Future<void> acknowledgeAllNotes(
      List<String> noteIds, String acknowledgedBy) async {
    if (noteIds.isEmpty) return;
    await _notes.update({
      'is_acknowledged': true,
      'acknowledged_by': acknowledgedBy,
      'acknowledged_at': toTimestamp(DateTime.now()),
    }).inFilter('id', noteIds);
    MetricsService.bump('ack',
        summary: '$acknowledgedBy cleared ${noteIds.length} notifications');
  }

  Future<void> unacknowledgeNote(String noteId) async {
    await _notes.update({
      'is_acknowledged': false,
      'acknowledged_by': null,
      'acknowledged_at': null,
    }).eq('id', noteId);
  }

  /// Comments cascade-delete in Postgres.
  Future<void> deleteNote(String noteId) async {
    await _notes.delete().eq('id', noteId);
  }

  /// Capped at 100 — a single note rarely needs more comments than that.
  Stream<List<NoteComment>> commentsStream(String noteId) {
    return _comments
        .stream(primaryKey: ['id'])
        .eq('note_id', noteId)
        .order('created_at', ascending: true)
        .limit(100)
        .map((rows) => rows.map(NoteComment.fromRow).toList());
  }

  Future<void> addComment(String noteId, NoteComment comment) async {
    await _comments.insert(comment.toRow(noteId));
    MetricsService.bump('comment',
        summary: '${comment.authorName} replied');
  }

  Future<void> deleteComment(String noteId, String commentId) async {
    await _comments.delete().eq('id', commentId).eq('note_id', noteId);
  }
}
