import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../clinical/bilirubin_assess.dart';
import '../clinical/discharge_checklist.dart';
import '../models/newborn_screen.dart';
import '../models/newborn_tracking.dart';
import '../models/patient.dart';
import '../models/row_parsing.dart';
import 'newborn_screen_service.dart';
import 'supabase_service.dart';
import 'tracking_service.dart';

/// The ticked items of a newborn's discharge checklist (`discharge_checks`),
/// and the live checklist built from them plus the baby's recorded data.
class DischargeCheckService {
  DischargeCheckService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _table => _client.from(Tables.dischargeChecks);

  Stream<Map<String, TickedCheck>> ticked(String patientId) => _table
      .stream(primaryKey: ['patient_id', 'item'])
      .eq('patient_id', patientId)
      .map((rows) => {
            for (final r in rows)
              r['item'] as String: TickedCheck(
                doneAt: parseTimestamp(r['done_at']),
                doneByName: r['done_by_name'] as String?,
                detail: r['detail'] as String?,
              ),
          });

  /// Who/when is stamped by the database. Ticking again updates [detail].
  Future<void> tick(String patientId, String item, {String? detail}) => _table.upsert(
        {'patient_id': patientId, 'item': item, 'detail': detail},
        onConflict: 'patient_id,item',
      );

  Future<void> untick(String patientId, String item) =>
      _table.delete().eq('patient_id', patientId).eq('item', item);

  /// The full checklist for [patient], recomputed whenever any of its
  /// sources changes. Emits once every source has loaded.
  Stream<List<CheckLine>> watch(Patient patient) {
    final screens = NewbornScreenService(client: _client).forPatient(patient.id);
    final tracking = TrackingService(client: _client);
    late final StreamController<List<CheckLine>> out;
    final subs = <StreamSubscription<Object?>>[];
    List<NewbornScreen>? s;
    List<BilirubinReading>? bili;
    List<PhototherapySession>? photo;
    List<WeightEntry>? weights;
    Map<String, TickedCheck>? done;

    void emit() {
      if (s == null || bili == null || photo == null || weights == null || done == null) return;
      final latest = bili!.isEmpty ? null : bili!.last;
      out.add(dischargeChecklist(DischargeInputs(
        now: DateTime.now(),
        screens: s!,
        latestBilirubin: latest,
        bilirubinAssessment: latest == null ? null : assessForPatient(patient, latest.measuredAt, latest.umol),
        phototherapyRunning: photo!.any((p) => p.isRunning),
        birthWeightGrams: patient.birthWeightG,
        latestWeight: weights!.isEmpty ? null : weights!.last,
        ticked: done!,
      )));
    }

    void listen<T>(Stream<T> stream, void Function(T) store) =>
        subs.add(stream.listen((v) {
          store(v);
          emit();
        }, onError: out.addError));

    out = StreamController<List<CheckLine>>(
      onListen: () {
        listen(screens, (v) => s = v);
        listen(tracking.readings(patient.id), (v) => bili = v);
        listen(tracking.phototherapy(patient.id), (v) => photo = v);
        listen(tracking.weights(patient.id), (v) => weights = v);
        listen(ticked(patient.id), (v) => done = v);
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return out.stream;
  }
}
