import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/row_parsing.dart';
import 'supabase_service.dart';

/// Length / height and head circumference for growth charts.
class Measurement {
  const Measurement({required this.id, required this.measuredAt, this.lengthCm, this.headCm, this.createdByName});
  final String id;
  final DateTime measuredAt;
  final double? lengthCm, headCm;
  final String? createdByName;

  static Measurement fromRow(DbRow row) => Measurement(
        id: row['id'] as String? ?? '',
        measuredAt: parseTimestamp(row['measured_at']),
        lengthCm: (row['length_cm'] as num?)?.toDouble(),
        headCm: (row['head_cm'] as num?)?.toDouble(),
        createdByName: row['created_by_name'] as String?,
      );
}

class MeasurementService {
  MeasurementService({SupabaseClient? client}) : _client = client ?? supabase;
  final SupabaseClient _client;

  Stream<List<Measurement>> watch(String patientId) => _client
      .from('patient_measurements')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('measured_at')
      .map((rows) => rows.map(Measurement.fromRow).toList());

  Future<void> add({
    required String patientId,
    required String wardId,
    required DateTime measuredAt,
    double? lengthCm,
    double? headCm,
  }) =>
      _client.from('patient_measurements').insert({
        'patient_id': patientId,
        'ward_id': wardId,
        'measured_at': toTimestamp(measuredAt),
        'length_cm': lengthCm,
        'head_cm': headCm,
      });

  Future<void> delete(String id) => _client.from('patient_measurements').delete().eq('id', id);
}
