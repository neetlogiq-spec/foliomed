import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../clinical/patient_status.dart';
import '../models/patient.dart';
import '../screens/patients/patient_board.dart';
import '../screens/patients/patient_screen.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'status_dot.dart';

/// A patient in a list, read like a ward board: bed on the left, who they
/// are and what's wrong, and status marks on the right.
class PatientRow extends StatelessWidget {
  const PatientRow({super.key, required this.patient, this.signals = PatientSignals.none, this.onReturn});

  final Patient patient;
  final PatientSignals signals;

  /// Called when the patient page closes (the board refreshes its data).
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final s = signals;
    final status = s.status;
    final hours = p.hoursSinceBirth();
    final facts = [
      if (hours != null && hours < 24 * 7) '$hours h' else p.ageLabel,
      if (p.gender.isNotEmpty) p.gender,
      if (s.latestWeightG != null) '${(s.latestWeightG! / 1000).toStringAsFixed(2)} kg'
      else if (p.birthWeightG != null) '${(p.birthWeightG! / 1000).toStringAsFixed(2)} kg',
      if (p.consultant?.isNotEmpty ?? false) p.consultant!,
      if (p.isDischarged && p.dischargedAt != null) 'home ${DateFormat('d MMM').format(p.dischargedAt!)}',
    ].join(' · ');
    final marks = <(IconData, Color, String)>[
      if (s.urgentNotes > 0) (Icons.priority_high, AppColors.danger, '${s.urgentNotes} urgent note'),
      if (s.overdueReminders > 0) (Icons.alarm, AppColors.danger, '${s.overdueReminders} overdue reminder'),
      if (s.phototherapy) (Icons.light_mode, AppColors.warning, 'Under phototherapy'),
      for (final (topic, icon) in [
        (StatusTopic.bilirubin, Icons.show_chart),
        (StatusTopic.weight, Icons.monitor_weight_outlined),
        (StatusTopic.observations, Icons.monitor_heart_outlined),
      ])
        if (status?.reasons.where((r) => r.topic == topic && r.level.index >= StatusLevel.watch.index).firstOrNull
            case final r?)
          (icon, statusColor(r.level), r.text),
    ];

    return Semantics(
      button: true,
      label: [
        if (status != null)
          '${status.label}${status.needsReview ? ', review status' : ''}'
              '${status.reasons.isEmpty ? '' : ': ${status.reasons.where((r) => r.level.index >= StatusLevel.watch.index).map((r) => r.text).join(', ')}'}',
        if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}',
        p.name,
        if (s.followed) 'Following',
        if (p.tags.isNotEmpty) 'Tags: ${p.tags.join(', ')}',
        facts,
        if (p.diagnosis.isNotEmpty) p.diagnosis,
        for (final m in marks) m.$3,
        if (s.openJobs > 0) '${s.openJobs} open job${s.openJobs == 1 ? '' : 's'}',
      ].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientScreen(patientId: p.id)));
          onReturn?.call();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: Row(children: [
                  SizedBox(
                    width: 16,
                    child: status == null
                        ? null
                        : Align(alignment: Alignment.centerRight, child: StatusDot(status: status, size: 10)),
                  ),
                  Expanded(
                    child: Text(
                      p.bedNumber.isEmpty ? '–' : p.bedNumber,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title3(
                        color: p.bedNumber.isEmpty ? AppColors.tertiaryLabel : AppColors.textPrimary,
                      ).copyWith(fontFeatures: AppTypography.tabular),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(color: AppColors.textPrimary, weight: FontWeight.w600)),
                      ),
                      if (s.followed)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                        ),
                    ]),
                    Text(facts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote(color: AppColors.textSecondary)),
                    if (p.diagnosis.isNotEmpty)
                      Text(p.diagnosis,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.footnote(color: AppColors.textSecondary)),
                    if (p.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Wrap(spacing: 4, runSpacing: 3, children: [
                          for (final t in p.tags.take(4)) TagChip(t),
                          if (p.tags.length > 4) TagChip('+${p.tags.length - 4}'),
                        ]),
                      ),
                  ],
                ),
              ),
              for (final (icon, color, _) in marks)
                Padding(padding: const EdgeInsets.only(left: 6), child: Icon(icon, size: 19, color: color)),
              if (s.openJobs > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.checklist, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text('${s.openJobs}', style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.tertiaryLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small clinical-tag chip ("NPO", "Isolation").
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label, style: AppTypography.caption2(color: AppColors.primary, weight: FontWeight.w600)),
      );
}
