import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../models/ward_job.dart';
import '../screens/jobs/add_job_sheet.dart';
import '../services/job_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'job_row.dart';

/// Jobs on one patient: open ones, then those done in the last 24 hours.
class PatientJobsSection extends StatefulWidget {
  const PatientJobsSection({super.key, required this.patient});
  final Patient patient;

  @override
  State<PatientJobsSection> createState() => _PatientJobsSectionState();
}

class _PatientJobsSectionState extends State<PatientJobsSection> {
  late final Stream<List<WardJob>> _stream = JobService().forPatient(widget.patient.id);

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return StreamBuilder<List<WardJob>>(
      stream: _stream,
      builder: (context, snap) {
        final now = DateTime.now();
        final jobs = [
          for (final j in snap.data ?? const <WardJob>[])
            if (!j.isDone || now.difference(j.doneAt!) < const Duration(hours: 24)) j,
        ]..sort((a, b) => WardJob.byPriority(a, b, now));
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text('Jobs', style: AppTypography.headline(color: AppColors.textPrimary))),
                      if (p.isActive)
                        TextButton.icon(
                          onPressed: () => showAddJob(context, patient: p),
                          icon: const Icon(Icons.add_task, size: 18),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                ),
                if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text("Couldn't load jobs.", style: AppTypography.footnote(color: AppColors.danger)),
                  )
                else if (jobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      p.isActive ? 'Nothing to do for this patient. Add a job for the team.' : 'No recent jobs.',
                      style: AppTypography.footnote(color: AppColors.textSecondary),
                    ),
                  )
                else
                  for (final j in jobs) JobRow(key: ValueKey(j.id), job: j, showPatient: false, fromPatient: true),
              ],
            ),
          ),
        );
      },
    );
  }
}
