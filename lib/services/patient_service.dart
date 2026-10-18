import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/patient.dart';
import '../models/row_parsing.dart';
import 'metrics_service.dart';
import 'supabase_service.dart';

class PatientService {
  final SupabaseClient _client;

  PatientService({SupabaseClient? client}) : _client = client ?? supabase;

  SupabaseQueryBuilder get _patients => _client.from(Tables.patients);

  /// Even a busy ward rarely has >100 active patients; 200 is a generous cap.
  static const int kPatientsListCap = 200;

  static List<Patient> _activeOnly(List<DbRow> rows) => rows
      .map(Patient.fromRow)
      .where((p) => p.isActive)
      .toList();

  /// Realtime streams accept one filter, so `is_active` is applied
  /// client-side. Discharged patients are rare enough that the cap holds.
  Stream<List<Patient>> getActivePatientsForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _patients
        .stream(primaryKey: ['id'])
        .inFilter('ward_id', wardIds)
        .order('admitted_at', ascending: false)
        .limit(kPatientsListCap)
        .map(_activeOnly);
  }

  Stream<List<Patient>> getPatientsByWard(String wardId) {
    return _patients
        .stream(primaryKey: ['id'])
        .eq('ward_id', wardId)
        .order('admitted_at', ascending: false)
        .limit(kPatientsListCap)
        .map(_activeOnly);
  }

  Future<Patient?> getPatient(String patientId) async {
    final row = await _patients.select().eq('id', patientId).maybeSingle();
    return row == null ? null : Patient.fromRow(row);
  }

  Future<String> addPatient(Patient patient) async {
    final row = await _patients.insert(patient.toRow()).select('id').single();
    MetricsService.bump('patient', summary: 'Admitted ${patient.name}');
    return row['id'] as String;
  }

  Future<void> updatePatient(Patient patient) async {
    await _patients.update(patient.toRow()).eq('id', patient.id);
  }

  Future<void> saveHlsUrl(String patientId, String url) async {
    await _patients.update({'hls_stream_url': url.trim()}).eq('id', patientId);
  }

  /// Notes and their comments cascade-delete in Postgres.
  Future<void> deletePatient(String patientId) async {
    await _patients.delete().eq('id', patientId);
  }

  Stream<int> getPatientCount(String wardId) =>
      getPatientsByWard(wardId).map((patients) => patients.length);
}
