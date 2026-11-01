import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lab_result.dart';
import 'supabase_service.dart';

/// Lab results and growth measurements (migration 20261105000000).
class LabService {
  LabService({SupabaseClient? client}) : _client = client ?? supabase;
  final SupabaseClient _client;

  /// Live, oldest first.
  Stream<List<LabResult>> watch(String patientId) => _client
      .from('lab_results')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('sampled_at')
      .map((rows) => rows.map(LabResult.fromRow).toList());

  Future<int> add({
    required String patientId,
    required DateTime sampledAt,
    required List<LabEntry> entries,
    bool scanned = false,
  }) async {
    final n = await _client.rpc(
      'add_lab_results',
      params: {
        'p_patient': patientId,
        'p_sampled_at': sampledAt.toUtc().toIso8601String(),
        'p_results': [for (final e in entries) e.toJson()],
        'p_summary': labSummary(entries),
        'p_source': scanned ? 'scan' : 'manual',
      },
    );
    return (n as num).toInt();
  }

  Future<void> delete(String id) => _client.from('lab_results').delete().eq('id', id);

  /// For handover: flagged results from the last [within], by patient.
  Future<Map<String, List<LabResult>>> recentFlagged(
    List<String> patientIds, {
    Duration within = const Duration(hours: 24),
  }) async {
    if (patientIds.isEmpty) return const {};
    final rows = await _client
        .from('lab_results')
        .select()
        .inFilter('patient_id', patientIds)
        .not('flag', 'is', null)
        .gte('sampled_at', DateTime.now().subtract(within).toUtc().toIso8601String())
        .order('sampled_at', ascending: false);
    final out = <String, List<LabResult>>{};
    for (final r in rows.map(LabResult.fromRow)) {
      final l = out[r.patientId] ??= [];
      if (!l.any((x) => x.testKey == r.testKey)) l.add(r);
    }
    return out;
  }
}
