import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../models/patient.dart';
import '../models/patient_infusion.dart';
import '../services/drug_service.dart';
import '../services/medication_service.dart';
import '../services/tracking_service.dart';
import '../tools/drugs/drug_list.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_sheet.dart';
import 'inset_group.dart';
import 'medication_sheets.dart';

const _stopReasons = ['Course complete', 'Side effect', 'No longer needed', 'Changed to oral', 'Entered in error'];
const _removeReasons = ['Entered in error', 'Wrong patient', 'Not an allergy (intolerance)', 'Retested — not allergic'];

Future<void> _run(BuildContext context, Future<void> Function() job, String done) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await job();
    Haptics.success();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (e) {
    Haptics.error();
    messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
  }
}

/// Red when allergies are recorded, green for "no known allergies", grey
/// with quick actions when nobody has asked yet.
class AllergyBanner extends StatefulWidget {
  const AllergyBanner({super.key, required this.patient});
  final Patient patient;

  @override
  State<AllergyBanner> createState() => _AllergyBannerState();
}

class _AllergyBannerState extends State<AllergyBanner> {
  late final Stream<List<PatientAllergy>> _stream = MedicationService().watchAllergies(widget.patient.id);

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return StreamBuilder<List<PatientAllergy>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final all = snap.data!;
        final (color, icon, title, detail) = all.isNotEmpty
            ? (AppColors.danger, Icons.warning_rounded, 'Allergies', all.map((a) => a.line).join(' · '))
            : p.nkaRecordedAt != null
            ? (
                AppColors.stable,
                Icons.check_circle_outline,
                'No known allergies',
                'Recorded ${formatDay(p.nkaRecordedAt!)}${p.nkaRecordedByName == null ? '' : ' by ${p.nkaRecordedByName}'}',
              )
            : (
                AppColors.textSecondary,
                Icons.help_outline,
                'Allergies not recorded',
                'Ask and record before prescribing.',
              );
        return Semantics(
          container: true,
          label: '$title. $detail',
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: all.isNotEmpty ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: all.isNotEmpty ? Border.all(color: color.withValues(alpha: 0.5)) : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.headline(color: all.isNotEmpty ? color : AppColors.textPrimary)),
                      Text(detail, style: AppTypography.subheadline(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                if (p.isActive && all.isEmpty && p.nkaRecordedAt == null) ...[
                  TextButton(
                    onPressed: () => _run(
                      context,
                      () => MedicationService().setNoKnownAllergies(p.id),
                      'No known allergies recorded',
                    ),
                    child: const Text('None'),
                  ),
                  TextButton(
                    onPressed: () => showAddAllergy(context, patient: p),
                    child: const Text('Add'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _Tab { active, previous, history }

/// Medicines on this admission, stopped ones with their history, and drug
/// history before admission (with allergies). Doctors start, change and
/// stop; doctors and nurses record history and allergies.
class PatientMedicationsSection extends StatefulWidget {
  const PatientMedicationsSection({super.key, required this.patient, required this.canPrescribe});
  final Patient patient;
  final bool canPrescribe;

  @override
  State<PatientMedicationsSection> createState() => _PatientMedicationsSectionState();
}

class _PatientMedicationsSectionState extends State<PatientMedicationsSection> {
  final _service = MedicationService();
  late final Stream<List<PatientMedication>> _meds = _service.watchMedications(widget.patient.id);
  late final Stream<List<MedicationEvent>> _events = _service.watchEvents(widget.patient.id);
  late final Stream<List<PatientAllergy>> _allergies = _service.watchAllergies(widget.patient.id);
  late final Stream<List<PatientInfusion>> _infusions = DrugService().watchInfusions(widget.patient.id);
  _Tab _tab = _Tab.active;
  double? _kg;

  @override
  void initState() {
    super.initState();
    _kg = dosingWeightKg(birthGrams: widget.patient.birthWeightG);
    _loadWeight();
  }

  Future<void> _loadWeight() async {
    try {
      final g = (await TrackingService().snapshot([widget.patient.id])).latestWeight[widget.patient.id]?.grams;
      if (mounted && g != null) setState(() => _kg = dosingWeightKg(latestGrams: g));
    } catch (_) {
      // Keep the birth weight (or none) for the dose check.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PatientMedication>>(
      stream: _meds,
      builder: (context, ms) => StreamBuilder<List<PatientAllergy>>(
        stream: _allergies,
        builder: (context, as) => StreamBuilder<List<PatientInfusion>>(
          stream: _infusions,
          builder: (context, ins) => StreamBuilder<List<MedicationEvent>>(
            stream: _events,
            builder: (context, es) => _body(
              ms.data ?? const [],
              as.data ?? const [],
              [
                for (final i in ins.data ?? const <PatientInfusion>[])
                  if (i.isRunning) i,
              ],
              es.data ?? const [],
              ms.hasError,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    List<PatientMedication> meds,
    List<PatientAllergy> allergies,
    List<PatientInfusion> infusions,
    List<MedicationEvent> events,
    bool error,
  ) {
    final active = meds.where((m) => m.isActive).toList();
    final previous = meds.where((m) => m.context == MedContext.inpatient && !m.isActive).toList().reversed.toList();
    final history = meds.where((m) => m.context != MedContext.inpatient && m.stoppedAt == null).toList();
    final counts = {
      _Tab.active: active.length + infusions.length,
      _Tab.previous: previous.length,
      _Tab.history: history.length + allergies.length,
    };
    return InsetGroup(
      header: 'Medications',
      footer: switch (_tab) {
        _Tab.active =>
          widget.canPrescribe ? 'Tap a medicine to change the dose or stop it.' : 'Doctors start and change medicines.',
        _Tab.previous => 'Stopped this admission, newest first. Tap for its history.',
        _Tab.history => 'Before this admission. Doctors and nurses can add to it.',
      },
      dividerIndent: 16,
      children: [
        InsetSegmentedRow<_Tab>(
          label: 'Show',
          value: _tab,
          options: {
            for (final t in _Tab.values)
              t:
                  '${switch (t) {
                    _Tab.active => 'Active',
                    _Tab.previous => 'Previous',
                    _Tab.history => 'History',
                  }}${counts[t] == 0 ? '' : ' ${counts[t]}'}',
          },
          onChanged: (t) => setState(() => _tab = t),
        ),
        if (error) const SettingsRow(icon: Icons.cloud_off_outlined, title: "Couldn't load medicines"),
        ...switch (_tab) {
          _Tab.active => _activeRows(active, infusions, allergies),
          _Tab.previous => _previousRows(previous, events),
          _Tab.history => _historyRows(history, allergies),
        },
      ],
    );
  }

  List<Widget> _activeRows(
    List<PatientMedication> active,
    List<PatientInfusion> infusions,
    List<PatientAllergy> allergies,
  ) {
    final p = widget.patient;
    return [
      for (final m in active)
        SettingsRow(
          key: ValueKey(m.id),
          icon: Icons.medication_outlined,
          iconColor: AppColors.primary,
          title: m.line,
          subtitle: [
            if (m.startedOn != null) 'since ${formatDay(m.startedOn!)}',
            if (m.createdByName != null) m.createdByName!,
            if (m.indication != null) m.indication!,
          ].join(' · '),
          showChevron: widget.canPrescribe && p.isActive,
          onTap: widget.canPrescribe && p.isActive ? () => _activeActions(m) : null,
        ),
      for (final i in infusions)
        SettingsRow(
          key: ValueKey('inf-${i.id}'),
          icon: Icons.water_drop_outlined,
          iconColor: AppColors.stable,
          title: i.line,
          subtitle: 'Infusion — change it under Infusions',
        ),
      if (active.isEmpty && infusions.isEmpty) const SettingsRow(title: 'No medicines on this admission'),
      if (widget.canPrescribe && p.isActive)
        SettingsRow(
          icon: Icons.add,
          title: 'Start a Medicine',
          showChevron: true,
          onTap: () => showAddMedication(
            context,
            patient: p,
            medContext: MedContext.inpatient,
            allergies: allergies,
            weightKg: _kg,
          ),
        ),
    ];
  }

  Future<void> _activeActions(PatientMedication m) async {
    final choice = await showOptionSheet<String>(
      context,
      title: m.line,
      options: const {'change': 'Change Dose', 'stop': 'Stop'},
    );
    if (!mounted) return;
    if (choice == 'change') {
      await showChangeMedication(context, med: m, weightKg: _kg);
    } else if (choice == 'stop') {
      final reason = await askReason(context, title: 'Stop ${m.drugName}?', action: 'Stop', quick: _stopReasons);
      if (reason != null && mounted) {
        await _run(context, () => _service.stop(m.id, reason: reason), '${m.drugName} stopped');
      }
    }
  }

  List<Widget> _previousRows(List<PatientMedication> previous, List<MedicationEvent> events) => [
    if (previous.isEmpty) const SettingsRow(title: 'Nothing stopped on this admission'),
    for (final m in previous)
      SettingsRow(
        key: ValueKey(m.id),
        icon: Icons.history,
        title: m.line,
        subtitle: [
          '${m.startedOn == null ? '' : formatDay(m.startedOn!)} – ${formatDay(m.stoppedAt!)}',
          if (m.stopReason != null) m.stopReason!,
          if (m.stoppedByName != null) 'stopped by ${m.stoppedByName}',
        ].join(' · '),
        showChevron: true,
        onTap: () => _showEvents(m, events.where((e) => e.medicationId == m.id).toList()),
      ),
  ];

  void _showEvents(PatientMedication m, List<MedicationEvent> events) => showAppSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(m.drugName, style: AppTypography.title3(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            InsetGroup(
              dividerIndent: 16,
              children: [
                for (final e in events)
                  SettingsRow(
                    title: switch (e.kind) {
                      'start' => 'Started',
                      'change' => 'Changed',
                      _ => 'Stopped',
                    },
                    subtitle: '${e.summary}\n${formatDueTime(e.at)}${e.byName == null ? '' : ' · ${e.byName}'}',
                  ),
                if (events.isEmpty) const SettingsRow(title: 'No history recorded'),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _historyRows(List<PatientMedication> history, List<PatientAllergy> allergies) {
    final p = widget.patient;
    return [
      for (final a in allergies)
        SettingsRow(
          key: ValueKey(a.id),
          icon: Icons.warning_rounded,
          iconColor: AppColors.danger,
          title: 'Allergy: ${a.line}',
          subtitle: [
            a.kind.label,
            if (a.infoSource != null) 'from ${a.infoSource}',
            if (a.createdByName != null) a.createdByName!,
          ].join(' · '),
          showChevron: widget.canPrescribe && p.isActive,
          onTap: widget.canPrescribe && p.isActive
              ? () async {
                  final reason = await askReason(
                    context,
                    title: 'Remove allergy to ${a.substance}?',
                    action: 'Remove',
                    quick: _removeReasons,
                    required: true,
                  );
                  if (reason != null && reason.isNotEmpty && mounted) {
                    await _run(context, () => _service.removeAllergy(a.id, reason), 'Allergy removed');
                  }
                }
              : null,
        ),
      for (final m in history)
        SettingsRow(
          key: ValueKey(m.id),
          icon: m.context == MedContext.home ? Icons.home_outlined : Icons.history_edu_outlined,
          title: m.line,
          subtitle: [m.context.label, if (m.infoSource != null) 'from ${m.infoSource}'].join(' · '),
          showChevron: p.isActive,
          onTap: p.isActive
              ? () async {
                  final reason = await askReason(
                    context,
                    title: 'Remove ${m.drugName} from drug history?',
                    action: 'Remove',
                    quick: const ['Entered in error'],
                  );
                  if (reason != null && mounted) {
                    await _run(context, () => _service.stop(m.id, reason: reason), 'Removed from drug history');
                  }
                }
              : null,
        ),
      if (history.isEmpty && allergies.isEmpty) const SettingsRow(title: 'No drug history recorded'),
      if (p.isActive) ...[
        SettingsRow(
          icon: Icons.add,
          title: 'Add Drug History',
          showChevron: true,
          onTap: () => showAddMedication(context, patient: p, medContext: MedContext.home, allergies: allergies),
        ),
        SettingsRow(
          icon: Icons.add_alert_outlined,
          iconColor: AppColors.danger,
          title: 'Record an Allergy',
          showChevron: true,
          onTap: () => showAddAllergy(context, patient: p),
        ),
      ],
    ];
  }
}
