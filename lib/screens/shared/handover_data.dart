import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../clinical/handover.dart';
import '../../models/handover_session.dart';
import '../../models/patient.dart';
import '../../models/patient_infusion.dart';
import '../../models/ward.dart';
import '../../providers/job_board.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/drug_service.dart';
import '../../services/handover_service.dart';
import '../../services/tracking_service.dart';
import '../patients/patient_board.dart';

/// The one-shot data a handover list needs beyond the live providers:
/// newborn tracking, latest observations and the If/then lines.
class HandoverExtras {
  const HandoverExtras(this.tracking, this.contingencies, [this.infusions = const {}]);
  HandoverExtras.empty() : this(TrackingSnapshot.empty(), const {});

  final TrackingSnapshot tracking;
  final Map<String, List<Contingency>> contingencies;

  /// Running infusions by patient.
  final Map<String, List<PatientInfusion>> infusions;

  static Future<HandoverExtras> load(List<String> patientIds) async {
    final results = await Future.wait([
      TrackingService().snapshot(patientIds).catchError((Object _) => TrackingSnapshot.empty()),
      HandoverService()
          .contingenciesFor(patientIds)
          .catchError((Object _) => const <String, List<Contingency>>{}),
      DrugService().runningFor(patientIds).catchError((Object _) => const <String, List<PatientInfusion>>{}),
    ]);
    return HandoverExtras(results[0] as TrackingSnapshot, results[1] as Map<String, List<Contingency>>,
        results[2] as Map<String, List<PatientInfusion>>);
  }
}

/// I-PASS items for [patients], sorted by unit and bed (or sickest first).
/// Reads reminders, jobs and notes from the live providers.
List<HandoverItem> handoverItems(
  BuildContext context, {
  required List<Patient> patients,
  required List<Ward> wards,
  required HandoverExtras extras,
  bool sickestFirst = false,
}) {
  final units = context.read<UnitProvider>();
  final reminders = context.read<ReminderProvider>().open;
  final jobs = context.read<JobBoard>().open();
  final now = DateTime.now();
  final t = extras.tracking;
  final signals = withStatuses(
    now: now,
    admitted: patients,
    signals: patientSignals(
      now: now,
      reminders: reminders,
      jobs: jobs,
      notes: context.read<WardFeed>().feed,
      phototherapy: t.runningPhototherapy.keys.toSet(),
      latestWeightG: {for (final e in t.latestWeight.entries) e.key: e.value.grams},
    ),
    wardKinds: {for (final w in wards) w.id: w.kind},
    latestBilirubin: t.latestBilirubin,
    latestObservation: t.latestObservation,
  );
  final items = [
    for (final p in patients)
      HandoverItem(
        patient: p,
        unitName: units.unitById(p.unitId)?.name,
        openReminders: reminders.where((r) => r.patientId == p.id).toList(),
        bilirubin: t.latestBilirubin[p.id],
        phototherapy: t.runningPhototherapy[p.id],
        weight: t.latestWeight[p.id],
        status: signals[p.id]?.status,
        openJobs: jobs.where((j) => j.patientId == p.id).toList(),
        contingencies: extras.contingencies[p.id] ?? const [],
        infusions: extras.infusions[p.id] ?? const [],
      ),
  ];
  final unitOrder = units.units.map((u) => u.id).toList();
  items.sort((a, b) => compareHandover(a, b, unitOrder, sickestFirst: sickestFirst));
  return items;
}
