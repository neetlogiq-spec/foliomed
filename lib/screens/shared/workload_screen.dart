import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../clinical/workload.dart';
import '../../models/ward.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

enum _Range {
  day('24 hours', Duration(hours: 24)),
  week('7 days', Duration(days: 7)),
  month('30 days', Duration(days: 30));

  const _Range(this.label, this.span);
  final String label;
  final Duration span;
}

/// Ward owner / admin: tasks per shift and response times, for planning
/// staffing. Counts per person are A–Z, not a league table.
class WorkloadScreen extends StatefulWidget {
  const WorkloadScreen({super.key, required this.ward, this.shiftStarts});

  final Ward ward;

  /// Overrides the ward's (just edited on the ward page).
  final List<int>? shiftStarts;

  @override
  State<WorkloadScreen> createState() => _WorkloadScreenState();
}

class _WorkloadScreenState extends State<WorkloadScreen> {
  _Range _range = _Range.week;
  List<int> get _starts => widget.shiftStarts ?? widget.ward.shiftStarts;
  late Future<List<WorkloadEvent>> _events = _load();

  Future<List<WorkloadEvent>> _load() {
    final now = DateTime.now();
    return WardService().workload(widget.ward.id, now.subtract(_range.span), now);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          setState(() => _events = _load());
          await _events.catchError((Object _) => <WorkloadEvent>[]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LargeTitleAppBar(title: 'Workload', eyebrow: widget.ward.name, showBackButton: true),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList.list(children: [
                CupertinoSlidingSegmentedControl<_Range>(
                  groupValue: _range,
                  onValueChanged: (r) {
                    if (r == null) return;
                    Haptics.selection();
                    setState(() {
                      _range = r;
                      _events = _load();
                    });
                  },
                  children: {
                    for (final r in _Range.values)
                      r: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(r.label,
                            style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
                      ),
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<WorkloadEvent>>(
                  future: _events,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return EmptyPlaceholder(
                        icon: Icons.cloud_off_outlined,
                        title: "Couldn't load the report",
                        subtitle: friendlyError(snap.error!),
                        buttonLabel: 'Try again',
                        onButtonTap: () => setState(() => _events = _load()),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                          padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator.adaptive()));
                    }
                    return _report(snap.data!);
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _report(List<WorkloadEvent> events) {
    if (events.isEmpty) {
      return const EmptyPlaceholder(
        icon: Icons.insights_outlined,
        title: 'Nothing in this period',
        subtitle: 'Jobs, urgent notes, reminders and handovers will show up here.',
      );
    }
    final all = WorkloadStats(events, end: DateTime.now());
    final shifts = byShift(events, _starts);
    String? d(Duration? x) => x == null ? null : durationLabel(x);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InsetGroup(
        header: 'Last ${_range.label}',
        dividerIndent: 16,
        children: [
          SettingsRow(
            title: 'Jobs',
            value: '${all.jobsCreated} added · ${all.jobsDone} done',
            subtitle: all.jobTurnaround == null ? null : 'Typical time to done: ${d(all.jobTurnaround)}',
          ),
          SettingsRow(
            title: 'Urgent notes',
            value: '${all.urgentNotes}',
            subtitle: [
              if (all.confirmMedian != null) 'Typically confirmed in ${d(all.confirmMedian)}',
              if (all.confirmSlowest != null) 'slowest ${d(all.confirmSlowest)}',
              if (all.unconfirmed > 0) '${all.unconfirmed} still unconfirmed',
            ].join(' · '),
          ),
          SettingsRow(
            title: 'Reminders',
            value: '${all.remindersDue} due',
            subtitle: all.remindersLate == 0 ? null : '${all.remindersLate} done over ${kReminderLateAfter.inMinutes} min late',
          ),
          SettingsRow(
            title: 'Handovers',
            value: '${all.handovers}',
            subtitle: all.handovers == 0
                ? null
                : '${all.handoverPatients} patients handed over · ${all.handoverMissed} missed',
          ),
        ],
      ),
      const SizedBox(height: 24),
      InsetGroup(
        header: 'By shift',
        footer: 'Shifts start at ${_starts.map(clockLabel).join(', ')} '
            '(the ward owner changes them on the ward’s page). “Left open” counts jobs and reminders '
            'from that shift still not done when it ended.',
        dividerIndent: 16,
        children: [
          for (final (shift, s) in shifts)
            SettingsRow(
              title: '${DateFormat('EEE d MMM').format(shift.start)} · ${shift.label}',
              subtitle: [
                '${s.jobsCreated} jobs (${s.jobsDone} done)',
                if (s.urgentNotes > 0)
                  '${s.urgentNotes} urgent${s.confirmMedian == null ? '' : ', confirmed in ~${d(s.confirmMedian)}'}',
                if (s.remindersDue > 0) '${s.remindersDue} reminders${s.remindersLate == 0 ? '' : ' (${s.remindersLate} late)'}',
                if (s.leftOpen > 0) '${s.leftOpen} left open',
                if (s.handovers > 0) 'handover: ${s.handoverMissed} missed',
              ].join(' · '),
              showChevron: false,
            ),
        ],
      ),
      const SizedBox(height: 24),
      InsetGroup(
        header: 'By person (A–Z)',
        footer: 'Counts for planning, not a ranking. Jobs and reminders count for whoever marked them done.',
        dividerIndent: 16,
        children: [
          for (final p in all.people)
            SettingsRow(
              title: p.name,
              subtitle: [
                if (p.jobs > 0) '${p.jobs} jobs',
                if (p.confirmed > 0) '${p.confirmed} urgent confirmed',
                if (p.reminders > 0) '${p.reminders} reminders',
                if (p.handovers > 0) '${p.handovers} handovers given',
              ].join(' · '),
              showChevron: false,
            ),
          if (all.people.isEmpty) const SettingsRow(title: 'No names recorded yet'),
        ],
      ),
    ]);
  }
}
