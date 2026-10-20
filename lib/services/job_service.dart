import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/row_parsing.dart';
import '../models/ward_job.dart';
import 'supabase_service.dart';

/// Reads and writes `ward_jobs`. Who created, was assigned and completed a
/// job is stamped by the database; RLS keeps jobs inside their ward.
class JobService {
  JobService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _table => _client.from(Tables.wardJobs);

  /// Newest jobs considered live; older ones are history.
  static const int kLiveCap = 400;

  /// Jobs on the given wards (open and recently done), newest first.
  Stream<List<WardJob>> forWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _table
        .stream(primaryKey: ['id'])
        .inFilter('ward_id', wardIds)
        .order('created_at', ascending: false)
        .limit(kLiveCap)
        .map((rows) => rows.map(WardJob.fromRow).toList());
  }

  Stream<List<WardJob>> forPatient(String patientId) => _table
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(WardJob.fromRow).toList());

  Future<void> add({
    required String wardId,
    required String patientId,
    required String title,
    bool urgent = false,
    DateTime? dueBy,
    String? assignedTo,
  }) =>
      _table.insert(WardJob.newRow(
        wardId: wardId,
        patientId: patientId,
        title: title,
        urgent: urgent,
        dueBy: dueBy,
        assignedTo: assignedTo,
      ));

  Future<void> setDone(String jobId, bool done) => _table
      .update({'done_at': done ? toTimestamp(DateTime.now()) : null}).eq('id', jobId);

  /// [uid] null leaves the job for anyone.
  Future<void> assign(String jobId, String? uid) =>
      _table.update({'assigned_to': uid}).eq('id', jobId);

  Future<void> edit(String jobId, {required String title, required bool urgent, DateTime? dueBy}) =>
      _table.update({'title': title.trim(), 'urgent': urgent, 'due_by': toTimestampOrNull(dueBy)}).eq('id', jobId);

  Future<void> delete(String jobId) => _table.delete().eq('id', jobId);

  /// People who can take a job on [wardId], by name.
  Future<List<AppUser>> membersOf(String wardId) async {
    final rows = await _client
        .from(Tables.profiles)
        .select()
        .contains('ward_ids', [wardId])
        .order('name');
    return [for (final r in rows) AppUser.fromRow(r)];
  }
}
