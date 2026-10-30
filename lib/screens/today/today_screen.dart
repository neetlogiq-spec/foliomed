import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/note.dart';
import '../../models/ward_job.dart';
import '../../providers/account_provider.dart';
import '../../providers/alert_inbox.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/job_board.dart';
import '../../providers/patient_roster.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../utils/scope_filter.dart';
import '../../widgets/alert_inbox_sheet.dart';
import '../../widgets/handover_banner.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/job_row.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/reminder_widgets.dart';
import '../../widgets/scope_button.dart';
import '../jobs/add_job_sheet.dart';
import '../jobs/jobs_screen.dart';
import '../notes/compose_note_sheet.dart';
import '../notes/confirm_note_sheet.dart';
import '../notes/note_thread_sheet.dart';
import '../notes/ward_notes_screen.dart';
import '../patients/patient_form_screen.dart';
import '../patients/patient_screen.dart';
import 'up_next.dart';

/// The shift at a glance. Up Next is one list of what needs you now
/// (overdue reminders, urgent notes, your jobs); At a Glance counts lead
/// to the full lists; Latest Notes shows the last few lines written.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.onOpenPatients});

  /// Switches to the Patients tab.
  final VoidCallback onOpenPatients;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const _upNextPreview = 6;
  static const _latestNotes = 5;

  bool _showAllUpNext = false;
  List<String> _wardIds = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ids = context.watch<AccountProvider>().currentUser?.wards ?? const <String>[];
    if (ids.length != _wardIds.length || !ids.every(_wardIds.contains)) {
      _wardIds = List.of(ids);
      WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
    }
  }

  void _subscribe() {
    if (!mounted) return;
    context.read<WardFeed>().watchWards(_wardIds);
    context.read<PatientRoster>().watchWards(_wardIds);
  }

  void _admit() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PatientFormScreen(initialWardId: _wardIds.isEmpty ? null : _wardIds.first),
    ));
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    final user = context.watch<AccountProvider>().currentUser;
    final now = DateTime.now();
    final first = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final f = ScopeFilter(context.watch<UnitProvider>().scope, context.watch<PatientRoster>().patients);
    final feed = context.watch<WardFeed>();
    final reminders = context.watch<ReminderProvider>().open.where(f.reminder).toList();
    final jobs = context.watch<JobBoard>().open().where(f.job).toList();
    final notes = feed.feed.where(f.note).toList();
    final items = upNext(now: now, uid: user?.uid ?? '', reminders: reminders, notes: notes, jobs: jobs);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator.adaptive(
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        onRefresh: () async {
          _subscribe();
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LargeTitleAppBar(
              eyebrow: [
                DateFormat('EEEE d MMMM').format(now),
                if (first.isNotEmpty) '${timeOfDayGreeting(now)}, $first',
              ].join(' · '),
              title: 'Today',
              actions: [
                ChromeIconButton(
                  icon: Icons.notifications_outlined,
                  tooltip: 'Notifications',
                  badgeCount: context.watch<AlertInbox>().unread,
                  onPressed: () => showAlertInbox(context),
                ),
                _AddMenu(
                  canPost: user?.role == UserRole.doctor,
                  onNote: () => showComposeNote(context),
                  onJob: () => showAddJob(context),
                  onAdmit: _admit,
                ),
              ],
            ),
            SliverPadding(
              padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 32)),
              sliver: SliverList.list(children: [
                const Align(alignment: Alignment.centerLeft, child: ScopeButton()),
                const SizedBox(height: 12),
                HandoverBanner(wardIds: _wardIds),
                _upNextSection(items),
                const SizedBox(height: 28),
                _glance(f, feed, jobs, user?.uid ?? ''),
                const SizedBox(height: 28),
                _latestNotesSection(notes),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Up Next ────────────────────────────────────────────────────────────

  Widget _upNextSection(List<UpNext> items) {
    if (items.isEmpty) return const _AllClear();
    final shown = _showAllUpNext ? items : items.take(_upNextPreview).toList();
    final hidden = items.length - shown.length;
    return InsetGroup(
      header: 'Up Next',
      dividerIndent: 52,
      children: [
        for (final i in shown)
          switch (i) {
            UpNextReminder() => _ReminderItem(key: ValueKey('r${i.reminder.id}'), item: i),
            UpNextNote() => _UrgentNoteItem(key: ValueKey('n${i.note.id}'), note: i.note),
            UpNextJob() => JobRow(key: ValueKey('j${i.job.id}'), job: i.job),
          },
        if (hidden > 0)
          SettingsRow(
            title: 'Show $hidden More',
            showChevron: false,
            onTap: () {
              Haptics.selection();
              setState(() => _showAllUpNext = true);
            },
          ),
      ],
    );
  }

  // ── At a Glance ────────────────────────────────────────────────────────

  Widget _glance(ScopeFilter f, WardFeed feed, List<WardJob> jobs, String uid) {
    final admitted = context.watch<PatientRoster>().patients.where(f.patient).length;
    final toConfirm = f.scope.isAll ? feed.pendingCount : feed.feed.where((n) => !n.isConfirmed && f.note(n)).length;
    final mine = jobs.where((j) => j.isFor(uid)).length;
    return InsetGroup(
      header: 'At a Glance',
      children: [
        SettingsRow(
          icon: Icons.bed_outlined,
          iconColor: AppColors.doctorColor,
          title: 'Admitted',
          value: '$admitted',
          onTap: widget.onOpenPatients,
        ),
        SettingsRow(
          icon: Icons.mark_chat_unread_outlined,
          iconColor: AppColors.warning,
          title: 'Notes to Confirm',
          value: '$toConfirm',
          onTap: () => _push(const WardNotesScreen(initial: NotesView.pending)),
        ),
        SettingsRow(
          icon: Icons.checklist,
          iconColor: AppColors.stable,
          title: 'Open Jobs',
          subtitle: mine == 0 ? null : '$mine for you',
          value: '${jobs.length}',
          onTap: () => _push(JobsScreen(initial: mine > 0 ? JobsView.mine : JobsView.ward)),
        ),
      ],
    );
  }

  // ── Latest Notes ──────────────────────────────────────────────────────

  Widget _latestNotesSection(List<Note> notes) {
    final latest = notes.take(_latestNotes).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 2),
          child: Row(
            children: [
              Expanded(
                child: Text('LATEST NOTES',
                    style: AppTypography.footnote(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => _push(const WardNotesScreen(initial: NotesView.all)),
                child: const Text('Show All'),
              ),
            ],
          ),
        ),
        if (latest.isEmpty)
          InsetGroup(children: const [
            SettingsRow(title: 'No notes yet', subtitle: 'Notes your team writes appear here as they’re posted.'),
          ])
        else
          InsetGroup(
            dividerIndent: 16,
            children: [for (final n in latest) _NoteGlance(key: ValueKey('l${n.id}'), note: n)],
          ),
      ],
    );
  }
}

/// One "+" with a menu anchored to it: note (doctors), job, patient.
class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.canPost, required this.onNote, required this.onJob, required this.onAdmit});
  final bool canPost;
  final VoidCallback onNote, onJob, onAdmit;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-150, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.card),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card))),
      ),
      menuChildren: [
        if (canPost)
          MenuItemButton(leadingIcon: const Icon(Icons.edit_square), onPressed: onNote, child: const Text('New Note')),
        MenuItemButton(leadingIcon: const Icon(Icons.add_task), onPressed: onJob, child: const Text('New Job')),
        MenuItemButton(leadingIcon: const Icon(Icons.person_add_alt), onPressed: onAdmit, child: const Text('Admit Patient')),
      ],
      builder: (context, controller, _) => ChromeIconButton(
        icon: Icons.add,
        tooltip: 'Add',
        onPressed: () {
          Haptics.selection();
          controller.isOpen ? controller.close() : controller.open();
        },
      ),
    );
  }
}

/// Up Next is empty.
class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        children: [
          Icon(Icons.task_alt, size: 34, color: AppColors.stable),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You’re all caught up', style: AppTypography.headline(color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Nothing overdue, nothing urgent, no jobs waiting for you.',
                    style: AppTypography.footnote(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Leading glyph used by Up Next rows, matching JobRow's 48-pt column.
class _Glyph extends StatelessWidget {
  const _Glyph(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      );
}

class _ReminderItem extends StatelessWidget {
  const _ReminderItem({super.key, required this.item});
  final UpNextReminder item;

  @override
  Widget build(BuildContext context) {
    final r = item.reminder;
    final overdue = item.overdue;
    final rp = context.read<ReminderProvider>();
    final color = overdue ? AppColors.danger : AppColors.warning;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientScreen(patientId: r.patientId))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          children: [
            _Glyph(overdue ? Icons.alarm : Icons.schedule, color),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title, style: AppTypography.body(color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${r.patientName.isEmpty ? 'Patient' : r.patientName} · '
                    '${overdue ? 'was due' : 'due'} ${formatClock(r.dueAt.toLocal())}',
                    style: AppTypography.footnote(color: overdue ? AppColors.danger : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ask again in an hour',
              icon: const Icon(Icons.snooze),
              color: AppColors.textSecondary,
              onPressed: () => rp.snooze(r),
            ),
            IconButton(
              tooltip: r.isNewbornStep ? 'Answer' : 'Done',
              icon: const Icon(Icons.check_circle_outline),
              color: AppColors.stable,
              onPressed: () => r.isNewbornStep ? showReminderDuePrompt(context, r) : rp.markDone(r),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentNoteItem extends StatelessWidget {
  const _UrgentNoteItem({super.key, required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showConfirmNote(context, note),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
        child: Row(
          children: [
            _Glyph(Icons.priority_high, AppColors.danger),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.text, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Urgent · ${note.patientName} · ${note.authorName}',
                      style: AppTypography.footnote(color: AppColors.danger)),
                ],
              ),
            ),
            Text('Confirm', style: AppTypography.subheadline(color: AppColors.primary, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A recent note in one or two lines; tap to read and reply.
class _NoteGlance extends StatelessWidget {
  const _NoteGlance({super.key, required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final n = note;
    return InkWell(
      onTap: () => showNoteThread(context, n),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(n.patientName.isEmpty ? 'Ward' : n.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
                ),
                Text(formatClock(n.createdAt.toLocal()), style: AppTypography.footnote(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 2),
            Text(n.text, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTypography.subheadline(color: AppColors.textSecondary)),
            if (!n.isConfirmed) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: n.isUrgent ? AppColors.danger : AppColors.warning, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('Waiting for confirmation', style: AppTypography.caption1(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
