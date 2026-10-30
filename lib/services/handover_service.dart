import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/handover_session.dart';
import 'supabase_service.dart';

/// I-PASS handover: contingencies per patient and shift-change sessions.
/// Session writes go through RPCs (names and times stamped server-side).
class HandoverService {
  HandoverService({SupabaseClient? client}) : _client = client ?? supabase;
  final SupabaseClient _client;

  // ── If / then ──
  Stream<List<Contingency>> contingencies(String patientId) => _client
      .from('patient_contingencies')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(Contingency.fromRow).toList());

  /// For many patients at once (handover list).
  Future<Map<String, List<Contingency>>> contingenciesFor(List<String> patientIds) async {
    if (patientIds.isEmpty) return const {};
    final rows = await _client
        .from('patient_contingencies')
        .select()
        .inFilter('patient_id', patientIds)
        .order('created_at', ascending: true);
    final out = <String, List<Contingency>>{};
    for (final c in rows.map(Contingency.fromRow)) {
      (out[c.patientId] ??= []).add(c);
    }
    return out;
  }

  Future<void> addContingency(
          {required String patientId, required String wardId, required String ifText, required String thenText}) =>
      _client.from('patient_contingencies').insert({
        'patient_id': patientId,
        'ward_id': wardId,
        'if_text': ifText.trim(),
        'then_text': thenText.trim(),
      });

  Future<void> deleteContingency(String id) => _client.from('patient_contingencies').delete().eq('id', id);

  // ── Sessions ──
  /// Handovers in these wards, newest first (open ones and recent history).
  Stream<List<HandoverSession>> sessions(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _client
        .from('handovers')
        .stream(primaryKey: ['id'])
        .inFilter('ward_id', wardIds)
        .order('started_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(HandoverSession.fromRow).toList());
  }

  Stream<List<HandoverEntry>> entries(String handoverId) => _client
      .from('handover_entries')
      .stream(primaryKey: ['id'])
      .eq('handover_id', handoverId)
      .order('position', ascending: true)
      .map((rows) => rows.map(HandoverEntry.fromRow).toList());

  Future<String> start(String wardId, {String? unitId}) async =>
      await _client.rpc('start_handover', params: {'p_ward': wardId, 'p_unit': unitId}) as String;

  Future<void> receive(String entryId, {String? question}) =>
      _client.rpc('receive_handover_entry', params: {'p_entry': entryId, 'p_question': question});

  Future<void> unreceive(String entryId) => _client.rpc('unreceive_handover_entry', params: {'p_entry': entryId});

  Future<void> finish(String handoverId) => _client.rpc('finish_handover', params: {'p_handover': handoverId});
}
