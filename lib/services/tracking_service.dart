import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/newborn_tracking.dart';
import '../models/row_parsing.dart';
import 'supabase_service.dart';

/// Bilirubin readings, phototherapy sessions and weights for newborns.
class TrackingService {
  TrackingService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  Stream<List<T>> _stream<T>(String table, String patientId, String orderBy,
          T Function(DbRow) map) =>
      _client
          .from(table)
          .stream(primaryKey: ['id'])
          .eq('patient_id', patientId)
          .order(orderBy, ascending: true)
          .map((rows) => rows.map(map).toList());

  Stream<List<BilirubinReading>> readings(String patientId) =>
      _stream('bilirubin_readings', patientId, 'measured_at', BilirubinReading.fromRow);

  Stream<List<PhototherapySession>> phototherapy(String patientId) =>
      _stream('phototherapy_sessions', patientId, 'started_at', PhototherapySession.fromRow);

  Stream<List<WeightEntry>> weights(String patientId) =>
      _stream('weights', patientId, 'measured_at', WeightEntry.fromRow);

  Future<void> addReading({
    required String patientId,
    required String wardId,
    required DateTime measuredAt,
    required double value,
    required bool umol,
    required bool transcutaneous,
  }) =>
      _client.from('bilirubin_readings').insert({
        'patient_id': patientId,
        'ward_id': wardId,
        'measured_at': toTimestamp(measuredAt),
        'value': value,
        'unit': umol ? 'umol' : 'mgdl',
        'method': transcutaneous ? 'transcutaneous' : 'serum',
      });

  Future<void> deleteReading(String id) =>
      _client.from('bilirubin_readings').delete().eq('id', id);

  Future<void> startPhototherapy(String patientId, String wardId, PhototherapyKind kind,
          {DateTime? at}) =>
      _client.from('phototherapy_sessions').insert({
        'patient_id': patientId,
        'ward_id': wardId,
        'kind': kind.dbName,
        'started_at': toTimestamp(at ?? DateTime.now()),
      });

  Future<void> stopPhototherapy(String sessionId, {DateTime? at}) => _client
      .from('phototherapy_sessions')
      .update({'stopped_at': toTimestamp(at ?? DateTime.now())}).eq('id', sessionId);

  Future<void> addWeight({
    required String patientId,
    required String wardId,
    required DateTime measuredAt,
    required int grams,
  }) =>
      _client.from('weights').insert({
        'patient_id': patientId,
        'ward_id': wardId,
        'measured_at': toTimestamp(measuredAt),
        'grams': grams,
      });

  Future<void> deleteWeight(String id) => _client.from('weights').delete().eq('id', id);

  /// Latest reading / running phototherapy / latest weight for many
  /// patients at once (handover list). One query per table.
  Future<TrackingSnapshot> snapshot(List<String> patientIds) async {
    if (patientIds.isEmpty) return TrackingSnapshot.empty();
    final results = await Future.wait([
      _client.from('bilirubin_readings').select().inFilter('patient_id', patientIds)
          .order('measured_at', ascending: false).limit(1000),
      _client.from('phototherapy_sessions').select().inFilter('patient_id', patientIds)
          .isFilter('stopped_at', null),
      _client.from('weights').select().inFilter('patient_id', patientIds)
          .order('measured_at', ascending: false).limit(1000),
    ]);
    final latestBili = <String, BilirubinReading>{};
    for (final r in results[0].map(BilirubinReading.fromRow)) {
      latestBili.putIfAbsent(r.patientId, () => r);
    }
    final running = {
      for (final s in results[1].map(PhototherapySession.fromRow)) s.patientId: s,
    };
    final latestWeight = <String, WeightEntry>{};
    for (final w in results[2].map(WeightEntry.fromRow)) {
      latestWeight.putIfAbsent(w.patientId, () => w);
    }
    return TrackingSnapshot(latestBili, running, latestWeight);
  }
}

class TrackingSnapshot {
  TrackingSnapshot(this.latestBilirubin, this.runningPhototherapy, this.latestWeight);
  TrackingSnapshot.empty() : this(const {}, const {}, const {});

  final Map<String, BilirubinReading> latestBilirubin;
  final Map<String, PhototherapySession> runningPhototherapy;
  final Map<String, WeightEntry> latestWeight;
}
