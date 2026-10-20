import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note.dart';
import '../models/note_reply.dart';
import '../models/row_parsing.dart';
import 'usage_counters.dart';
import 'supabase_service.dart';

/// Reads and writes ward notes and their reply threads. Row-level security
/// limits every query to the caller's wards.
class NotesRepository {
  NotesRepository({SupabaseClient? client}) : _db = client ?? supabase;

  final SupabaseClient _db;

  /// Newest notes kept live per feed.
  static const feedSize = 150;

  /// Ceiling for the "waiting for confirmation" count.
  static const pendingCap = 150;

  SupabaseQueryBuilder get _notes => _db.from(Tables.notes);
  SupabaseQueryBuilder get _replies => _db.from(Tables.noteComments);

  Stream<List<Note>> _live(SupabaseStreamBuilder q, {int limit = feedSize}) => q
      .order('created_at', ascending: false)
      .limit(limit)
      .map((rows) => [for (final r in rows) Note.fromRow(r)]);

  /// Newest notes across [wardIds].
  Stream<List<Note>> wardsFeed(List<String> wardIds) => wardIds.isEmpty
      ? Stream.value(const [])
      : _live(_notes.stream(primaryKey: ['id']).inFilter('ward_id', wardIds));

  /// One ward's notes (admin view).
  Stream<List<Note>> wardFeed(String wardId) =>
      _live(_notes.stream(primaryKey: ['id']).eq('ward_id', wardId));

  /// One patient's timeline.
  Stream<List<Note>> patientTimeline(String patientId) =>
      _live(_notes.stream(primaryKey: ['id']).eq('patient_id', patientId), limit: 100);

  /// How many notes in [wardIds] still wait for confirmation. Realtime
  /// allows one filter, so the ward narrowing happens here.
  Stream<int> pendingCount(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(0);
    final wards = wardIds.toSet();
    return _live(_notes.stream(primaryKey: ['id']).eq('is_acknowledged', false), limit: pendingCap)
        .map((notes) => notes.where((n) => wards.contains(n.wardId)).length);
  }

  /// Whether one note is confirmed, live.
  Stream<bool> confirmedState(String noteId) => _notes
      .stream(primaryKey: ['id'])
      .eq('id', noteId)
      .map((rows) => rows.isNotEmpty && rows.first['is_acknowledged'] == true);

  Future<void> post(Note note) async {
    await _notes.insert(note.toRow());
    UsageCounters.bump('note', summary: 'A note was posted');
  }

  Map<String, dynamic> _confirmation(String byName) => {
        'is_acknowledged': true,
        'acknowledged_by': byName,
        'acknowledged_at': toTimestamp(DateTime.now()),
      };

  Future<void> confirm(String noteId, String byName) async {
    await _notes.update(_confirmation(byName)).eq('id', noteId);
    UsageCounters.bump('ack', summary: 'A note was confirmed');
  }

  Future<void> confirmMany(List<String> noteIds, String byName) async {
    if (noteIds.isEmpty) return;
    await _notes.update(_confirmation(byName)).inFilter('id', noteIds);
    UsageCounters.bump('ack', summary: '${noteIds.length} notes were confirmed');
  }

  Future<void> undoConfirm(String noteId) => _notes.update({
        'is_acknowledged': false,
        'acknowledged_by': null,
        'acknowledged_at': null,
      }).eq('id', noteId);

  /// Replies go with it (cascade).
  Future<void> remove(String noteId) => _notes.delete().eq('id', noteId);

  Stream<List<NoteReply>> replies(String noteId) => _replies
      .stream(primaryKey: ['id'])
      .eq('note_id', noteId)
      .order('created_at', ascending: true)
      .limit(100)
      .map((rows) => [for (final r in rows) NoteReply.fromRow(r)]);

  Future<void> reply(String noteId, NoteReply r) async {
    await _replies.insert(r.toRow(noteId));
    UsageCounters.bump('comment', summary: 'A reply was posted');
  }

  Future<void> removeReply(String noteId, String replyId) =>
      _replies.delete().eq('id', replyId).eq('note_id', noteId);
}
