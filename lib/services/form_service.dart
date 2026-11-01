import 'package:supabase_flutter/supabase_flutter.dart';

import '../forms/form_model.dart';
import '../models/patient_form.dart';
import 'supabase_service.dart';

/// Ward forms and filled patient forms (migration 20261103000000_forms).
class FormService {
  FormService({SupabaseClient? client}) : _client = client ?? supabase;
  final SupabaseClient _client;

  /// Live: the ward's own forms (archived included).
  Stream<List<FormTemplate>> watchWardForms(String wardId) => _client
      .from('form_templates')
      .stream(primaryKey: ['id'])
      .eq('ward_id', wardId)
      .order('name')
      .map((rows) => rows.map(FormTemplate.fromRow).toList());

  /// Doctors of the ward or its owner. Returns the new version.
  Future<int> saveTemplate({
    required String wardId,
    required String key,
    required String name,
    required String description,
    required FormDefinition definition,
    String? basedOn,
    bool archived = false,
  }) async {
    final v = await _client.rpc(
      'save_form_template',
      params: {
        'p_ward': wardId,
        'p_key': key,
        'p_name': name,
        'p_description': description,
        'p_definition': definition.toJson(),
        'p_based_on': basedOn,
        'p_archived': archived,
      },
    );
    return (v as num).toInt();
  }

  /// Live, newest first.
  Stream<List<PatientForm>> watchPatientForms(String patientId) => _client
      .from('patient_forms')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(PatientForm.fromRow).toList());

  /// The last filled form of this kind for the patient, if any.
  Future<PatientForm?> latest(String patientId, String key) async {
    final rows = await _client
        .from('patient_forms')
        .select()
        .eq('patient_id', patientId)
        .eq('template_key', key)
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : PatientForm.fromRow(rows.first);
  }

  /// For handover: each patient's newest form from the last [within] that
  /// has abnormal answers.
  Future<Map<String, PatientForm>> recentAbnormal(
    List<String> patientIds, {
    Duration within = const Duration(hours: 24),
  }) async {
    if (patientIds.isEmpty) return const {};
    final rows = await _client
        .from('patient_forms')
        .select()
        .inFilter('patient_id', patientIds)
        .gt('abnormal_count', 0)
        .gte('created_at', DateTime.now().subtract(within).toUtc().toIso8601String())
        .order('created_at', ascending: false);
    final out = <String, PatientForm>{};
    for (final f in rows.map(PatientForm.fromRow)) {
      out.putIfAbsent(f.patientId, () => f);
    }
    return out;
  }

  Future<String> save({
    required String patientId,
    required FormTemplate template,
    required Map<String, Object?> answers,
    required String summary,
    required int abnormalCount,
    required Map<String, double> vitals,
  }) async {
    final id = await _client.rpc(
      'save_patient_form',
      params: {
        'p_patient': patientId,
        'p_key': template.key,
        'p_name': template.name,
        'p_version': template.version,
        'p_definition': template.definition.toJson(),
        'p_answers': answers,
        'p_summary': summary,
        'p_abnormal': abnormalCount,
        'p_vitals': vitals,
      },
    );
    return id as String;
  }
}
