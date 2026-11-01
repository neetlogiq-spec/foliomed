import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../clinical/handover.dart';
import '../../forms/builtin_forms.dart';
import '../../models/handover_session.dart';
import '../../models/lab_result.dart';
import '../../models/medication.dart';
import '../../models/patient.dart';
import '../../models/patient_form.dart';
import '../../models/patient_infusion.dart';
import '../../models/ward.dart';
import '../../providers/job_board.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/drug_service.dart';
import '../../services/form_service.dart';
import '../../services/handover_service.dart';
import '../../services/lab_service.dart';
import '../../services/medication_service.dart';
import '../../services/tracking_service.dart';
import '../patients/patient_board.dart';

/// The one-shot data a handover list needs beyond the live providers:
/// newborn tracking, latest observations and the If/then lines.
class HandoverExtras {
  const HandoverExtras(
    this.tracking,
    this.contingencies, [
    this.infusions = const {},
    this.medications = const {},
    this.allergies = const {},
    this.abnormalForms = const {},
    this.filledForms,
    this.flaggedLabs = const {},
  ]);
  HandoverExtras.empty() : this(TrackingSnapshot.empty(), const {});

  final TrackingSnapshot tracking;
  final Map<String, List<Contingency>> contingencies;

  /// Running infusions by patient.
  final Map<String, List<PatientInfusion>> infusions;

  /// Active admission medicines and allergies by patient.
  final Map<String, List<PatientMedication>> medications;
  final Map<String, List<PatientAllergy>> allergies;

  /// Newest form with abnormal answers in the last 24 h, by patient.
  final Map<String, PatientForm> abnormalForms;

  /// Admission-form keys filled, by patient; null if they couldn't load.
  final Map<String, Set<String>>? filledForms;

  /// Flagged lab results in the last 24 h, by patient.
  final Map<String, List<LabResult>> flaggedLabs;

  static Future<HandoverExtras> load(List<String> patientIds) async {
    final results = await Future.wait([
      TrackingService().snapshot(patientIds).catchError((Object _) => TrackingSnapshot.empty()),
      HandoverService().contingenciesFor(patientIds).catchError((Object _) => const <String, List<Contingency>>{}),
      DrugService().runningFor(patientIds).catchError((Object _) => const <String, List<PatientInfusion>>{}),
      MedicationService()
          .snapshot(patientIds)
          .catchError(
            (Object _) => (const <String, List<PatientMedication>>{}, const <String, List<PatientAllergy>>{}),
          ),
      FormService().recentAbnormal(patientIds).catchError((Object _) => const <String, PatientForm>{}),
      FormService()
          .filledKeys(patientIds, kAdmissionFormKeys.keys)
          .then<Map<String, Set<String>>?>((v) => v)
          .catchError((Object _) => null),
      LabService().recentFlagged(patientIds).catchError((Object _) => const <String, List<LabResult>>{}),
    ]);
    final meds = results[3] as (Map<String, List<PatientMedication>>, Map<String, List<PatientAllergy>>);
    return HandoverExtras(
      results[0] as TrackingSnapshot,
      results[1] as Map<String, List<Contingency>>,
      results[2] as Map<String, List<PatientInfusion>>,
      meds.$1,
      meds.$2,
      results[4] as Map<String, PatientForm>,
      results[5] as Map<String, Set<String>>?,
      results[6] as Map<String, List<LabResult>>,
    );
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
        medications: extras.medications[p.id] ?? const [],
        allergies: extras.allergies[p.id] ?? const [],
        abnormalForm: extras.abnormalForms[p.id],
        filledFormKeys: extras.filledForms?[p.id],
        flaggedLabs: extras.flaggedLabs[p.id] ?? const [],
      ),
  ];
  final unitOrder = units.units.map((u) => u.id).toList();
  items.sort((a, b) => compareHandover(a, b, unitOrder, sickestFirst: sickestFirst));
  return items;
}
