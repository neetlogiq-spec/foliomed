import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../models/ward_job.dart';
import '../../providers/account_provider.dart';
import '../../providers/job_board.dart';
import '../../providers/patient_roster.dart';
import '../../providers/unit_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/scope_filter.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/job_row.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/scope_button.dart';
import 'add_job_sheet.dart';

enum JobsView { mine, ward, done }

/// Today's jobs across your wards: yours, everyone's (grouped by patient),
/// and what's been done since midnight.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, this.initial = JobsView.ward});
  final JobsView initial;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  late JobsView _view = widget.initial;

  @override
  Widget build(BuildContext context) {
    final board = context.watch<JobBoard>();
    final uid = context.watch<AccountProvider>().currentUser?.uid ?? '';
    final patients = context.watch<PatientRoster>().patients;
    final f = ScopeFilter(context.watch<UnitProvider>().scope, patients);
    final inScope = board.jobs.where(f.job).toList();
    final mine = inScope.where((j) => !j.isDone && j.isFor(uid)).toList();
    final open = inScope.where((j) => !j.isDone).toList();
    final done = inScope.where((j) => j.isDone).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(
            title: 'Jobs',
            showBackButton: true,
            actions: [
              ChromeIconButton(icon: Icons.add, tooltip: 'New job', onPressed: () => showAddJob(context)),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(children: [
              const Align(alignment: Alignment.centerLeft, child: ScopeButton()),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<JobsView>(
                groupValue: _view,
                onValueChanged: (v) {
                  if (v == null) return;
                  Haptics.selection();
                  setState(() => _view = v);
                },
                children: {
                  JobsView.mine: _segment('Mine', mine.length),
                  JobsView.ward: _segment('Ward', open.length),
                  JobsView.done: _segment('Done', done.length),
                },
              ),
              const SizedBox(height: 16),
              if (board.lastError != null && board.jobs.isEmpty)
                InsetGroup(children: [
                  SettingsRow(title: "Couldn't load jobs", subtitle: friendlyError(board.lastError!)),
                ])
              else
                ..._body(switch (_view) { JobsView.mine => mine, JobsView.ward => open, JobsView.done => done },
                    patients),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(count == 0 ? label : '$label  $count',
            style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
      );

  List<Widget> _body(List<WardJob> jobs, List<Patient> patients) {
    if (jobs.isEmpty) {
      final (icon, title, subtitle) = switch (_view) {
        JobsView.mine => (Icons.task_alt, 'Nothing on your list', 'Jobs assigned to you, or that you take on, show here.'),
        JobsView.ward => (Icons.checklist, 'No open jobs', 'Add one with + — for example “Repeat TSB at 6 pm”.'),
        JobsView.done => (Icons.history, 'Nothing done yet today', 'Ticked-off jobs stay here until midnight.'),
      };
      return [
        Container(
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
          child: EmptyPlaceholder(icon: icon, title: title, subtitle: subtitle),
        ),
      ];
    }
    if (_view != JobsView.ward) {
      return [
        InsetGroup(dividerIndent: 52, children: [for (final j in jobs) JobRow(key: ValueKey(j.id), job: j)]),
      ];
    }
    // Everyone's open jobs, one group per patient (patients with urgent or
    // overdue jobs first, as the list is already in priority order).
    final byPatient = <String, List<WardJob>>{};
    for (final j in jobs) {
      byPatient.putIfAbsent(j.patientId, () => []).add(j);
    }
    final beds = {for (final p in patients) p.id: p.bedNumber};
    return [
      for (final entry in byPatient.entries) ...[
        InsetGroup(
          header: [
            entry.value.first.patientName,
            if ((beds[entry.key] ?? '').isNotEmpty) 'Bed ${beds[entry.key]}',
          ].join(' · '),
          dividerIndent: 52,
          children: [
            for (final j in entry.value) JobRow(key: ValueKey(j.id), job: j, showPatient: false),
          ],
        ),
        const SizedBox(height: 20),
      ],
    ];
  }
}
