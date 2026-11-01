import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medication.dart';
import 'supabase_service.dart';

/// Medicines and allergies on a patient. Every write goes through an RPC
/// (migration 20261102000000_medications) that stamps who and when and adds
/// a timeline note.
class MedicationService {
  MedicationService({SupabaseClient? client}) : _client = client ?? supabase;
  final SupabaseClient _client;

  Stream<List<PatientMedication>> watchMedications(String patientId) => _client
      .from('patient_medications')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('created_at')
      .map((rows) => rows.map(PatientMedication.fromRow).toList());

  Stream<List<MedicationEvent>> watchEvents(String patientId) => _client
      .from('patient_medication_events')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('at')
      .map((rows) => rows.map(MedicationEvent.fromRow).toList());

  Stream<List<PatientAllergy>> watchAllergies(String patientId) => _client
      .from('patient_allergies')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('created_at')
      .map((rows) => rows.map(PatientAllergy.fromRow).toList());

  /// Active admission medicines and allergies for these patients (one fetch
  /// each), for handover.
  Future<(Map<String, List<PatientMedication>>, Map<String, List<PatientAllergy>>)> snapshot(
    List<String> patientIds,
  ) async {
    if (patientIds.isEmpty) return (const <String, List<PatientMedication>>{}, const <String, List<PatientAllergy>>{});
    final results = await Future.wait([
      _client
          .from('patient_medications')
          .select()
          .inFilter('patient_id', patientIds)
          .eq('context', 'inpatient')
          .isFilter('stopped_at', null)
          .order('created_at'),
      _client.from('patient_allergies').select().inFilter('patient_id', patientIds).order('created_at'),
    ]);
    final meds = <String, List<PatientMedication>>{};
    for (final m in results[0].map(PatientMedication.fromRow)) {
      (meds[m.patientId] ??= []).add(m);
    }
    final allergies = <String, List<PatientAllergy>>{};
    for (final a in results[1].map(PatientAllergy.fromRow)) {
      (allergies[a.patientId] ??= []).add(a);
    }
    return (meds, allergies);
  }

  Future<String> add({
    required String patientId,
    required MedContext context,
    String? drugKey,
    required String name,
    double? dose,
    String unit = '',
    String route = '',
    String frequency = '',
    String? indication,
    DateTime? startedOn,
    String? infoSource,
    String? note,
  }) async {
    final id = await _client.rpc(
      'add_medication',
      params: {
        'p_patient': patientId,
        'p_context': context.name,
        'p_drug_key': drugKey ?? '',
        'p_name': name,
        'p_dose': dose,
        'p_unit': unit,
        'p_route': route,
        'p_freq': frequency,
        'p_indication': indication,
        'p_started_on': startedOn == null
            ? null
            : '${startedOn.year.toString().padLeft(4, '0')}-${startedOn.month.toString().padLeft(2, '0')}-'
                  '${startedOn.day.toString().padLeft(2, '0')}',
        'p_info_source': infoSource,
        'p_note': note,
      },
    );
    return id as String;
  }

  Future<void> change(
    String id, {
    double? dose,
    required String unit,
    required String route,
    required String frequency,
    String? reason,
  }) => _client.rpc(
    'change_medication',
    params: {'p_id': id, 'p_dose': dose, 'p_unit': unit, 'p_route': route, 'p_freq': frequency, 'p_reason': reason},
  );

  Future<void> stop(String id, {String? reason}) =>
      _client.rpc('stop_medication', params: {'p_id': id, 'p_reason': reason});

  Future<String> addAllergy({
    required String patientId,
    required String substance,
    String? reaction,
    AllergySeverity severity = AllergySeverity.unknown,
    AllergyKind kind = AllergyKind.drug,
    String? infoSource,
  }) async {
    final id = await _client.rpc(
      'add_allergy',
      params: {
        'p_patient': patientId,
        'p_substance': substance,
        'p_reaction': reaction,
        'p_severity': severity.name,
        'p_kind': kind.name,
        'p_info_source': infoSource,
      },
    );
    return id as String;
  }

  Future<void> removeAllergy(String id, String reason) =>
      _client.rpc('remove_allergy', params: {'p_id': id, 'p_reason': reason});

  Future<void> setNoKnownAllergies(String patientId) =>
      _client.rpc('set_no_known_allergies', params: {'p_patient': patientId});
}
