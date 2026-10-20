import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../screens/patients/patient_board.dart';
import '../screens/patients/patient_screen.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// A patient in a list, read like a ward board: bed on the left, who they
/// are and what's wrong, and status marks on the right.
class PatientRow extends StatelessWidget {
  const PatientRow({super.key, required this.patient, this.signals = PatientSignals.none});

  final Patient patient;
  final PatientSignals signals;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final s = signals;
    final hours = p.hoursSinceBirth();
    final facts = [
      if (hours != null && hours < 24 * 7) '$hours h' else p.ageLabel,
      if (p.gender.isNotEmpty) p.gender,
      if (s.latestWeightG != null) '${(s.latestWeightG! / 1000).toStringAsFixed(2)} kg'
      else if (p.birthWeightG != null) '${(p.birthWeightG! / 1000).toStringAsFixed(2)} kg',
      if (p.isDischarged && p.dischargedAt != null) 'home ${DateFormat('d MMM').format(p.dischargedAt!)}',
    ].join(' · ');
    final marks = <(IconData, Color, String)>[
      if (s.urgentNotes > 0) (Icons.priority_high, AppColors.danger, '${s.urgentNotes} urgent note'),
      if (s.overdueReminders > 0) (Icons.alarm, AppColors.danger, '${s.overdueReminders} overdue reminder'),
      if (s.phototherapy) (Icons.light_mode, AppColors.warning, 'Under phototherapy'),
    ];

    return Semantics(
      button: true,
      label: [
        if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}',
        p.name,
        facts,
        if (p.diagnosis.isNotEmpty) p.diagnosis,
        for (final m in marks) m.$3,
        if (s.openJobs > 0) '${s.openJobs} open job${s.openJobs == 1 ? '' : 's'}',
      ].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientScreen(patientId: p.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
          child: Row(
            children: [
              SizedBox(
                width: 58,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(color: AppColors.textPrimary, weight: FontWeight.w600)),
                    Text(facts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote(color: AppColors.textSecondary)),
                    if (p.diagnosis.isNotEmpty)
                      Text(p.diagnosis,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.footnote(color: AppColors.textSecondary)),
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
