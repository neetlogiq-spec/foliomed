import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ward_job.dart';
import '../providers/account_provider.dart';
import '../providers/job_board.dart';
import '../screens/jobs/job_actions.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';

/// One job: a round tick on the left (tap to complete or reopen), title,
/// and a line saying who it's for and by when. Tapping the row opens the
/// job's actions.
class JobRow extends StatelessWidget {
  const JobRow({super.key, required this.job, this.showPatient = true, this.fromPatient = false});

  final WardJob job;
  final bool showPatient;

  /// Already on the patient's page: no "Open Patient" action.
  final bool fromPatient;

  @override
  Widget build(BuildContext context) {
    final j = job;
    final now = DateTime.now();
    final myUid = context.select<AccountProvider, String?>((a) => a.currentUser?.uid);
    final overdue = j.isOverdueAt(now);
    final who = j.isDone
        ? 'Done${j.doneByName == null ? '' : ' by ${j.doneByName}'} · ${formatClock(j.doneAt!.toLocal())}'
        : j.isUnassigned
            ? 'Anyone'
            : (j.assignedTo == myUid ? 'You' : (j.assignedName ?? 'Someone'));
    final details = [
      if (showPatient && j.patientName.isNotEmpty) j.patientName,
      if (!j.isDone && j.dueBy != null) '${overdue ? 'Overdue · was due' : 'By'} ${_when(j.dueBy!.toLocal(), now)}',
      who,
    ].join(' · ');

    return Semantics(
      button: true,
      label: '${j.title}. $details${j.urgent && !j.isDone ? '. Urgent' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showJobActions(context, j, fromPatient: fromPatient),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
            child: Row(
              children: [
                _Tick(
                  done: j.isDone,
                  urgent: j.urgent && !j.isDone,
                  onTap: () => context.read<JobBoard>().setDone(j, !j.isDone),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              j.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                color: j.isDone ? AppColors.textSecondary : AppColors.textPrimary,
                              ).copyWith(decoration: j.isDone ? TextDecoration.lineThrough : null),
                            ),
                          ),
                          if (j.urgent && !j.isDone) ...[
                            const SizedBox(width: 6),
                            const _UrgentPill(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote(
                            color: overdue ? AppColors.danger : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _when(DateTime due, DateTime now) {
    final sameDay = due.year == now.year && due.month == now.month && due.day == now.day;
    return sameDay ? formatClock(due) : formatDueTime(due);
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.done, required this.urgent, required this.onTap});

  final bool done;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = urgent ? AppColors.danger : AppColors.tertiaryLabel;
    return SizedBox(
      width: 48,
      height: 48,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 160),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.stable : Colors.transparent,
              border: Border.all(color: done ? AppColors.stable : ring, width: 1.6),
            ),
            child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
        ),
      ),
    );
  }
}

class _UrgentPill extends StatelessWidget {
  const _UrgentPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('Urgent',
            style: AppTypography.caption1(color: AppColors.danger, weight: FontWeight.w600)),
      );
}
