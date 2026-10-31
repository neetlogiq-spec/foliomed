import 'package:flutter/material.dart';

import '../clinical/bilirubin.dart';
import '../clinical/handover.dart';
import '../clinical/patient_status.dart';
import '../models/newborn_tracking.dart';
import '../screens/patients/patient_screen.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'status_dot.dart';

/// One patient in I-PASS order: Illness severity (dot + reasons), Patient
/// summary, Action list, Situation awareness ("If … → …"). Tapping opens
/// the patient. [footer] holds the receive controls in a live handover.
class HandoverCard extends StatelessWidget {
  const HandoverCard({super.key, required this.item, required this.now, this.footer});

  final HandoverItem item;
  final DateTime now;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = item.patient;
    final st = item.status;
    final a = item.assessment;
    final wc = item.weightChange;
    final actions = item.actions(now);

    Widget part(String letter, String text, {Color? color, bool strong = false}) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: Text(letter,
                    style: AppTypography.footnote(color: AppColors.textSecondary, weight: FontWeight.w700)),
              ),
              Expanded(
                child: Text(text,
                    style: (strong ? AppTypography.subheadline : AppTypography.footnote)(
                        color: color ?? AppColors.textSecondary)),
              ),
            ],
          ),
        );
    Widget line(IconData icon, String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 3, left: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: color ?? AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: AppTypography.footnote(color: color ?? AppColors.textSecondary))),
            ],
          ),
        );

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientScreen(patientId: p.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (st != null) ...[StatusDot(status: st, size: 11), const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    [if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}', p.name].join(' · '),
                    style: AppTypography.headline(color: AppColors.textPrimary),
                  ),
                ),
              ]),
              Text(
                [p.ageLabel, if (item.unitName != null) item.unitName!, if (p.patientCode.isNotEmpty) p.patientCode]
                    .join(' · '),
                style: AppTypography.footnote(color: AppColors.textSecondary),
              ),
              if (item.severityLine != null)
                part('I', item.severityLine!,
                    color: st == null || st.level.index < StatusLevel.watch.index ? null : statusColor(st.level)),
              if (item.summary != null) part('P', item.summary!, color: AppColors.textPrimary, strong: true),
              if (item.phototherapy != null)
                line(Icons.light_mode,
                    '${item.phototherapy!.kind.label} phototherapy · ${item.phototherapy!.durationAt(now).inHours} h',
                    color: AppColors.warning),
              if (item.bilirubin != null)
                line(Icons.show_chart,
                    'Last ${item.bilirubin!.transcutaneous ? 'TcB' : 'TSB'} '
                    '${item.bilirubin!.value} ${item.bilirubin!.isUmol ? 'µmol/L' : 'mg/dL'}'
                    '${a == null ? '' : ' · ${a.guideline}: ${a.action.label}'}',
                    color: a != null && a.action.index >= BiliAction.considerPhototherapy.index
                        ? AppColors.danger
                        : null),
              if (wc != null)
                line(Icons.monitor_weight_outlined, 'Weight ${wc.label} from birth',
                    color: wc.flag == WeightFlag.ok ? null : AppColors.warning),
              if (actions.isEmpty)
                part('A', 'No open jobs or reminders')
              else
                for (final (i, x) in actions.indexed)
                  part(i == 0 ? 'A' : '', x,
                      color: x.startsWith('OVERDUE') || x.startsWith('URGENT') ? AppColors.danger : null),
              for (final c in item.contingencies) part('S', c.line, color: AppColors.textPrimary),
              if (footer != null) ...[const SizedBox(height: 10), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
