import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/observation.dart';
import 'supabase_service.dart';

/// Observations (vital signs) for a patient. RLS: the patient's ward.
class ObservationService {
  ObservationService({SupabaseClient? client}) : _client = client ?? supabase;
  final SupabaseClient _client;

  /// Live, oldest first.
  Stream<List<Observation>> watch(String patientId) => _client
      .from('observations')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('taken_at', ascending: true)
      .map((rows) => rows.map(Observation.fromRow).toList());

  Future<void> add(Observation o) => _client.from('observations').insert(o.toRow());

  Future<void> delete(String id) => _client.from('observations').delete().eq('id', id);
}
