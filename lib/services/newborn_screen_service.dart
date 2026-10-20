import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/newborn_screen.dart';
import 'supabase_service.dart';

/// Newborn investigation plans. Reads stream from the table; every change
/// goes through an RPC so the plan, its reminders and the timeline note
/// stay in step (see migration 20261020000000_newborn_screening.sql).
class NewbornScreenService {
  NewbornScreenService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  Stream<List<NewbornScreen>> forPatient(String patientId) => _client
      .from('newborn_screens')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('due_at', ascending: true)
      .map((rows) => rows.map(NewbornScreen.fromRow).toList());

  Future<NewbornScreen?> get(String screenId) async {
    final row = await _client
        .from('newborn_screens')
        .select()
        .eq('id', screenId)
        .maybeSingle();
    return row == null ? null : NewbornScreen.fromRow(row);
  }

  /// Plans the investigations at [hours] of life with a heads-up
  /// [leadHours] before. Replaces an unsent plan.
  Future<void> plan(String patientId, {required int hours, required int leadHours}) =>
      _client.rpc('plan_newborn_screen', params: {
        'p_patient': patientId,
        'p_hours': hours,
        'p_lead_hours': leadHours,
      });

  Future<void> markSent(String screenId) =>
      _client.rpc('mark_newborn_screen_sent', params: {'p_screen': screenId});

  Future<void> remindResults(String screenId, {int hours = 6}) =>
      _client.rpc('remind_newborn_results',
          params: {'p_screen': screenId, 'p_hours': hours});

  /// Stops asking for results; they can still be entered later.
  Future<void> skipResults(String screenId) =>
      _client.rpc('skip_newborn_results', params: {'p_screen': screenId});

  Future<void> saveResults(String screenId, NewbornResults results, String summary) =>
      _client.rpc('save_newborn_results', params: {
        'p_screen': screenId,
        'p_results': results.toJson(),
        'p_summary': summary,
      });
}
