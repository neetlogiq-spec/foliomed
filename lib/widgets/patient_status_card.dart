import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../clinical/early_warning.dart';
import '../clinical/patient_status.dart';
import '../models/newborn_tracking.dart';
import '../models/observation.dart';
import '../models/patient.dart';
import '../models/ward.dart';
import '../providers/job_board.dart';
import '../providers/reminder_provider.dart';
import '../providers/ward_feed.dart';
import '../screens/patients/patient_board.dart';
import '../services/observation_service.dart';
import '../services/patient_service.dart';
import '../services/tracking_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_sheet.dart';
import 'inset_group.dart';
import 'status_dot.dart';

/// Patient page: the status dot, why it's that colour, and the status
/// staff set by hand (tap to set, review or clear). Live.
class PatientStatusCard extends StatefulWidget {
  const PatientStatusCard({super.key, required this.patient, required this.wardKind});

  final Patient patient;

  /// Null while the ward is loading (treated as Other).
  final WardKind? wardKind;

  @override
  State<PatientStatusCard> createState() => _PatientStatusCardState();
}

class _PatientStatusCardState extends State<PatientStatusCard> {
  final _tracking = TrackingService();
  late final bool _newborn = widget.patient.bornAt != null;
  late final Stream<List<BilirubinReading>> _readings =
      _newborn ? _tracking.readings(widget.patient.id) : Stream.value(const []);
  late final Stream<List<PhototherapySession>> _sessions =
      _newborn ? _tracking.phototherapy(widget.patient.id) : Stream.value(const []);
  late final Stream<List<WeightEntry>> _weights =
      _newborn ? _tracking.weights(widget.patient.id) : Stream.value(const []);
  late final Stream<List<Observation>> _observations =
      earlyWarningFor(widget.patient, DateTime.now()) != null
          ? ObservationService().watch(widget.patient.id)
          : Stream.value(const []);

  Patient get p => widget.patient;
  WardKind get kind => widget.wardKind ?? WardKind.other;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tasks = patientSignals(
          now: now,
          reminders: context.watch<ReminderProvider>().open.where((r) => r.patientId == p.id),
          jobs: context.watch<JobBoard>().open().where((j) => j.patientId == p.id),
          notes: context.watch<WardFeed>().feed.where((n) => n.patientId == p.id),
        )[p.id] ??
        PatientSignals.none;
    return StreamBuilder<List<BilirubinReading>>(
      stream: _readings,
      builder: (context, rs) => StreamBuilder<List<PhototherapySession>>(
        stream: _sessions,
        builder: (context, ss) => StreamBuilder<List<WeightEntry>>(
          stream: _weights,
          builder: (context, ws) => StreamBuilder<List<Observation>>(
            stream: _observations,
            builder: (context, os) {
              final readings = rs.data ?? const [];
              final obs = os.data ?? const [];
              final weights = ws.data ?? const [];
              final status = patientStatus(StatusInputs(
                patient: p,
                wardKind: kind,
                now: now,
                urgentNotes: tasks.urgentNotes,
                overdueReminders: tasks.overdueReminders,
                urgentJobs: tasks.urgentJobs,
                latestBilirubin: readings.isEmpty ? null : readings.last,
                phototherapyRunning: (ss.data ?? const []).any((s) => s.isRunning),
                latestWeightG: weights.isEmpty ? null : weights.last.grams,
                latestObservation: obs.isEmpty ? null : obs.last,
              ));
              return _card(status);
            },
          ),
        ),
      ),
    );
  }

  Widget _card(PatientStatusResult status) {
    final acuity = Acuity.fromName(p.acuity);
    final tags = [for (final t in p.supportTags) SupportTag.fromName(t)?.label ?? t];
    final setLine = acuity == null
        ? (kind.staffLed ? 'No status set — tap to set one' : 'Tap to set a status by hand')
        : [
            'Marked ${acuity.label}',
            if (p.acuitySetByName?.isNotEmpty ?? false) 'by ${p.acuitySetByName}',
            if (p.acuitySetAt != null) formatDueTime(p.acuitySetAt!),
          ].join(' · ');
    final shown = status.reasons.where((r) => r.topic != StatusTopic.staff && r.topic != StatusTopic.review);
    return InsetGroup(
      header: 'Status · ${kind.label}',
      footer: 'Red: act now · amber: watch · green: settled. A prompt to look — not a diagnosis.',
      children: [
        SettingsRow(
          leading: Center(child: StatusDot(status: status, size: 16)),
          title: status.label,
          subtitle: [
            setLine,
            if ((p.acuityReason ?? '').isNotEmpty) p.acuityReason!,
            if (tags.isNotEmpty) 'Support: ${tags.join(', ')}',
          ].join('\n'),
          trailing: status.needsReview && p.isActive
              ? Text('Review', style: AppTypography.body(color: AppColors.warning))
              : null,
          onTap: p.isActive ? _edit : null,
        ),
        for (final r in shown)
          SettingsRow(
            leading: Center(child: StatusDot(status: PatientStatusResult(r.level, const []), size: 10)),
            title: r.text,
            showChevron: false,
          ),
        if (status.needsReview)
          SettingsRow(
            icon: Icons.history,
            iconColor: AppColors.warning,
            title: 'Status not reviewed in ${kind.reviewEvery.inHours} h',
            subtitle: 'Tap the status above and save it again to confirm it.',
            showChevron: false,
          ),
      ],
    );
  }

  Future<void> _edit() async {
    final result = await showAppSheet<_StatusDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StatusSheet(patient: p, showSupport: kind == WardKind.picu || p.supportTags.isNotEmpty),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PatientService().setStatus(p.id,
          acuity: result.acuity?.name, reason: result.reason, supportTags: result.tags);
      Haptics.success();
      messenger.showSnackBar(SnackBar(
          content: Text(result.acuity == null ? 'Status cleared' : 'Status saved — ${result.acuity!.label}')));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }
}

class _StatusDraft {
  const _StatusDraft(this.acuity, this.reason, this.tags);
  final Acuity? acuity;
  final String reason;
  final List<String> tags;
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.patient, required this.showSupport});
  final Patient patient;
  final bool showSupport;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late Acuity _acuity = Acuity.fromName(widget.patient.acuity) ?? Acuity.stable;
  late final _reason = TextEditingController(text: widget.patient.acuityReason ?? '');
  late final Set<String> _tags = {...widget.patient.supportTags};

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hadStatus = widget.patient.acuity != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                Expanded(
                  child: Text('Status',
                      textAlign: TextAlign.center, style: AppTypography.headline(color: AppColors.textPrimary)),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(
                      context, _StatusDraft(_acuity, _reason.text.trim(), _tags.toList()..sort())),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
              CupertinoSlidingSegmentedControl<Acuity>(
                groupValue: _acuity,
                onValueChanged: (a) {
                  if (a == null) return;
                  Haptics.selection();
                  setState(() => _acuity = a);
                },
                children: {
                  for (final a in Acuity.values)
                    a: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        StatusDot(status: PatientStatusResult(a.level, const []), size: 9),
                        const SizedBox(width: 6),
                        Text(a.label,
                            style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
                      ]),
                    ),
                },
              ),
              const SizedBox(height: 16),
              InsetGroup(
                footer: 'Saving the same status again counts as a review. Every change is logged on the timeline.',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _reason,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Reason (optional), e.g. on HFNC, desaturating',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.showSupport) ...[
                const SizedBox(height: 16),
                InsetGroup(
                  header: 'Support',
                  dividerIndent: 16,
                  children: [
                    for (final t in SupportTag.values)
                      SettingsRow(
                        title: t.label,
                        trailing: Icon(
                          _tags.contains(t.name) ? Icons.check_circle : Icons.circle_outlined,
                          color: _tags.contains(t.name) ? AppColors.primary : AppColors.textSecondary,
                        ),
                        showChevron: false,
                        onTap: () => setState(() => _tags.contains(t.name) ? _tags.remove(t.name) : _tags.add(t.name)),
                      ),
                  ],
                ),
              ],
              if (hadStatus) ...[
                const SizedBox(height: 16),
                InsetGroup(children: [
                  SettingsRow(
                    title: 'Clear status',
                    destructive: true,
                    onTap: () => Navigator.pop(context, const _StatusDraft(null, '', [])),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
