import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/patient.dart';
import 'metrics_service.dart';
import 'supabase_service.dart';

class PatientService {
  final SupabaseClient _client;

  PatientService({SupabaseClient? client}) : _client = client ?? supabase;

  SupabaseQueryBuilder get _patients => _client.from(Tables.patients);

  /// Even a busy ward rarely has >100 active patients; 200 is a generous cap.
  static const int kPatientsListCap = 200;

  /// Discharged patients shown in the "Discharged" list, newest first.
  static const int kDischargedListCap = 100;

  /// Realtime streams accept one filter, so status is filtered by the
  /// server and the ward ids client-side (RLS already limits rows to the
  /// caller's wards). Filtering status server-side keeps a growing pile of
  /// discharged patients from crowding admitted ones out of the cap.
  Stream<List<Patient>> _byStatus(
    String status,
    Set<String> wardIds, {
    required String orderBy,
    required int limit,
  }) {
    return _patients
        .stream(primaryKey: ['id'])
        .eq('status', status)
        .order(orderBy, ascending: false)
        .limit(limit)
        .map((rows) => rows
            .map(Patient.fromRow)
            .where((p) => wardIds.contains(p.wardId))
            .toList());
  }

  Stream<List<Patient>> getActivePatientsForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _byStatus('admitted', wardIds.toSet(),
        orderBy: 'admitted_at', limit: kPatientsListCap);
  }

  Stream<List<Patient>> getPatientsByWard(String wardId) =>
      getActivePatientsForWards([wardId]);

  Stream<List<Patient>> getDischargedPatientsForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _byStatus('discharged', wardIds.toSet(),
        orderBy: 'discharged_at', limit: kDischargedListCap);
  }

  /// Live view of one patient (status, ward and bed change under you when a
  /// teammate discharges or transfers them).
  Stream<Patient?> watchPatient(String patientId) {
    return _patients
        .stream(primaryKey: ['id'])
        .eq('id', patientId)
        .map((rows) => rows.isEmpty ? null : Patient.fromRow(rows.first));
  }

  Future<Patient?> getPatient(String patientId) async {
    final row = await _patients.select().eq('id', patientId).maybeSingle();
    return row == null ? null : Patient.fromRow(row);
  }

  Future<String> addPatient(Patient patient) async {
    final row = await _patients
        .insert({...patient.toRow(), 'unit_id': patient.unitId})
        .select('id')
        .single();
    MetricsService.bump('patient', summary: 'Admitted ${patient.name}');
    return row['id'] as String;
  }

  /// Throws if nothing was updated (RLS blocks silently with zero rows).
  Future<void> updatePatient(Patient patient) async {
    final rows = await _patients
        .update(patient.toRow())
        .eq('id', patient.id)
        .select('id');
    if (rows.isEmpty) {
      throw const PostgrestException(
          message: "You can't edit this patient — you may no longer be in their ward.",
          code: '42501');
    }
  }

  /// Discharge with an optional summary; logged on the patient's timeline.
  Future<void> dischargePatient(String patientId, {String summary = ''}) =>
      _client.rpc('discharge_patient', params: {
        'p_patient': patientId,
        'p_summary': summary.trim(),
      });

  Future<void> readmitPatient(String patientId) =>
      _client.rpc('readmit_patient', params: {'p_patient': patientId});

  /// Moves the patient — with their notes and replies — to another ward.
  /// The caller must belong to both wards (enforced by the database).
  Future<void> transferPatient(
    String patientId, {
    required String targetWardId,
    String reason = '',
    String? bedNumber,
  }) =>
      _client.rpc('transfer_patient', params: {
        'p_patient': patientId,
        'p_target_ward': targetWardId,
        'p_reason': reason.trim(),
        'p_bed': bedNumber?.trim(),
      });

  /// Moves the patient to [unitId] (null = unassigned); logged on the
  /// timeline.
  Future<void> moveToUnit(String patientId, String? unitId) => _client.rpc(
      'move_patient_unit', params: {'p_patient': patientId, 'p_unit': unitId});

  /// Records the AAP neurotoxicity risk factors (empty list = none).
  Future<void> setNeuroRiskFactors(String patientId, List<String> factors) async {
    final rows = await _patients
        .update({'neuro_risk_factors': factors})
        .eq('id', patientId)
        .select('id');
    if (rows.isEmpty) {
      throw const PostgrestException(
          message: "You can't edit this patient — you may no longer be in their ward.",
          code: '42501');
    }
  }

  /// Notes and their comments cascade-delete in Postgres.
  Future<void> deletePatient(String patientId) async {
    await _patients.delete().eq('id', patientId);
  }

  Stream<int> getPatientCount(String wardId) =>
      getPatientsByWard(wardId).map((patients) => patients.length);
}
