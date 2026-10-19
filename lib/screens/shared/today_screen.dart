import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import '../../models/note.dart';
import '../../models/patient_reminder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/app_utils.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/note_list_items.dart';
import '../../widgets/notifications_panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reminder_widgets.dart';
import '../doctor/add_note_screen.dart';
import '../doctor/add_patient_screen.dart';
import '../doctor/patient_detail_screen.dart';

enum _Feed { pending, all, urgent }

/// Home for doctors and nurses: what needs doing now (due reminders,
/// pending and urgent notes), then the live ward feed — collapsible to
/// one line per note.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.onOpenPatients});

  /// Switches to the Patients tab.
  final VoidCallback onOpenPatients;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const _compactKey = 'home_notes_compact_v1';
  static const _pageSize = 20;

  _Feed _feed = _Feed.pending;
  bool _compact = true;
  int _shown = _pageSize;
  List<String> _subscribedWardIds = const [];

  @override
  void initState() {
    super.initState();
    _loadCompact();
  }

  Future<void> _loadCompact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_compactKey);
      if (v != null && mounted) setState(() => _compact = v);
    } catch (_) {
      // Preference is a convenience; default stays.
    }
  }

  Future<void> _setCompact(bool v) async {
    Haptics.selection();
    setState(() => _compact = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_compactKey, v);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wardIds =
        context.watch<AuthProvider>().currentUser?.wardIds ?? const <String>[];
    if (!_sameList(wardIds, _subscribedWardIds)) {
      _subscribedWardIds = List.of(wardIds);
      WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
    }
  }

  void _subscribe() {
    if (!mounted) return;
    context.read<NoteProvider>().subscribeForWards(_subscribedWardIds);
    context.read<PatientProvider>().subscribeForWards(_subscribedWardIds);
  }

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  void _addPatient() {
    final wardIds = context.read<AuthProvider>().currentUser?.wardIds ?? [];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddPatientScreen(
        initialWardId: wardIds.isNotEmpty ? wardIds.first : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final isDoctor = user?.role == UserRole.doctor;
    final now = DateTime.now();
    final firstName = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator.adaptive(
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        onRefresh: () async {
          _subscribe();
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LargeTitleAppBar(
              eyebrow:
                  '${DateFormat('EEEE d MMMM').format(now)} · ${timeOfDayGreeting(now)}',
              title: firstName.isEmpty ? 'Today' : firstName,
              actions: [
                ChromeIconButton(
                  icon: Icons.notifications_outlined,
                  tooltip: 'Notifications',
                  badgeCount: context.watch<NotificationProvider>().items.length,
                  onPressed: () => showNotificationsPanel(context),
                ),
                ChromeIconButton(
                  icon: Icons.person_add_alt,
                  tooltip: 'Add patient',
                  onPressed: _addPatient,
                ),
                // Compose lives in the navigation bar (iOS Mail/Notes), not a
                // floating action button.
                if (isDoctor)
                  ChromeIconButton(
                    icon: Icons.edit_square,
                    tooltip: 'New note',
                    onPressed: () => showAddNoteBottomSheet(context),
                  ),
              ],
            ),
            SliverPadding(
              padding: withBottomBarInset(
                context,
                const EdgeInsets.fromLTRB(16, 4, 16, 96),
              ),
              sliver: SliverList.list(
                children: [
                  _summary(),
                  const SizedBox(height: 24),
                  const _RemindersBlock(),
                  _feedHeader(),
                  const SizedBox(height: 10),
                  _feedList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Summary tiles ───────────────────────────

  Widget _summary() {
    final patients = context.watch<PatientProvider>().patientCount;
    final notes = context.watch<NoteProvider>();
    final urgentOpen =
        notes.urgentNotes.where((n) => !n.isAcknowledged).length;
    return Row(
      children: [
        _Tile(
          label: 'Admitted',
          value: patients,
          icon: Icons.bed_outlined,
          color: AppColors.doctorColor,
          onTap: widget.onOpenPatients,
        ),
        const SizedBox(width: 10),
        _Tile(
          label: 'Pending',
          value: notes.unacknowledgedCount,
          icon: Icons.pending_actions_outlined,
          color: AppColors.warning,
          selected: _feed == _Feed.pending,
          onTap: () => setState(() => _feed = _Feed.pending),
        ),
        const SizedBox(width: 10),
        _Tile(
          label: 'Urgent',
          value: urgentOpen,
          icon: Icons.priority_high,
          color: AppColors.danger,
          emphasised: urgentOpen > 0,
          selected: _feed == _Feed.urgent,
          onTap: () => setState(() => _feed = _Feed.urgent),
        ),
      ],
    );
  }

  // ─────────────────────────── Notes feed ───────────────────────────

  Widget _feedHeader() {
    return Row(
      children: [
        Expanded(
          child: Text('Ward notes',
              style: AppTypography.title3(color: AppColors.textPrimary)),
        ),
        IconButton(
          tooltip: _compact ? 'Expand notes' : 'Collapse notes',
          icon: Icon(_compact ? Icons.unfold_more : Icons.unfold_less),
          color: AppColors.textSecondary,
          onPressed: () => _setCompact(!_compact),
        ),
      ],
    );
  }

  Widget _feedList() {
    final np = context.watch<NoteProvider>();
    final List<Note> all = switch (_feed) {
      _Feed.pending => np.notes.where((n) => !n.isAcknowledged).toList(),
      _Feed.urgent => np.urgentNotes,
      _Feed.all => np.notes,
    };
    final visible = all.take(_shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoSlidingSegmentedControl<_Feed>(
          groupValue: _feed,
          onValueChanged: (f) {
            if (f == null) return;
            Haptics.selection();
            setState(() {
              _feed = f;
              _shown = _pageSize;
            });
          },
          children: {
            _Feed.pending: _segment('Pending'),
            _Feed.all: _segment('All'),
            _Feed.urgent: _segment('Urgent'),
          },
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          _emptyFeed()
        else
          for (final n in visible)
            Padding(
              padding: EdgeInsets.only(bottom: _compact ? 8 : 10),
              child: _compact
                  ? CollapsibleNote(key: ValueKey('c${n.id}'), note: n)
                  : WiredNoteCard(key: ValueKey('f${n.id}'), note: n),
            ),
        if (all.length > visible.length)
          TextButton(
            onPressed: () => setState(() => _shown += _pageSize),
            child: Text('Show ${all.length - visible.length} more'),
          ),
      ],
    );
  }

  Widget _segment(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(label,
            style: AppTypography.subheadline(
                color: AppColors.textPrimary, weight: FontWeight.w600)),
      );

  Widget _emptyFeed() {
    final (icon, title, subtitle) = switch (_feed) {
      _Feed.pending => (
          Icons.check_circle_outline,
          'All caught up',
          'Every note on your wards has been acknowledged.'
        ),
      _Feed.urgent => (
          Icons.verified_outlined,
          'Nothing urgent',
          'Urgent notes appear here first.'
        ),
      _Feed.all => (
          Icons.notes_outlined,
          'No notes yet',
          'Notes your ward team posts appear here in real time.'
        ),
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: EmptyState(icon: icon, title: title, subtitle: subtitle),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.emphasised = false,
    this.selected = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool emphasised;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: emphasised
                ? Border.all(color: color, width: 1.5)
                : selected
                    ? Border.all(color: AppColors.divider, width: 1)
                    : null,
          ),
          child: Semantics(
            button: onTap != null,
            label: '$label: $value',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const Spacer(),
                    Text(
                      '$value',
                      style: AppTypography.title2(color: AppColors.textPrimary)
                          .copyWith(fontFeatures: AppTypography.tabular),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote(
                      color: AppColors.textSecondary, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Due and upcoming (next 24 h) reminders across the user's wards.
class _RemindersBlock extends StatelessWidget {
  const _RemindersBlock();

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReminderProvider>();
    final now = DateTime.now();
    final due = rp.open.where((r) => r.isOverdueAt(now)).toList();
    final soon = rp.open
        .where((r) =>
            !r.isOverdueAt(now) &&
            r.dueAt.isBefore(now.add(const Duration(hours: 24))))
        .toList();
    if (due.isEmpty && soon.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reminders',
              style: AppTypography.title3(color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, r) in [...due, ...soon].indexed) ...[
                  if (i > 0)
                    const Divider(height: 0.5, thickness: 0.5, indent: 16),
                  _ReminderRow(reminder: r, overdue: r.isOverdueAt(now)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder, required this.overdue});

  final PatientReminder reminder;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final rp = context.read<ReminderProvider>();
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PatientDetailScreen(patientId: r.patientId),
      )),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              overdue ? Icons.alarm : Icons.schedule,
              color: overdue ? AppColors.danger : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: AppTypography.subheadline(
                          color: AppColors.textPrimary,
                          weight: FontWeight.w600)),
                  Text(
                    '${r.patientName.isEmpty ? 'Patient' : r.patientName} · '
                    '${overdue ? 'was due' : 'due'} ${formatDueTime(r.dueAt)}',
                    style: AppTypography.footnote(
                        color:
                            overdue ? AppColors.danger : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (overdue) ...[
              IconButton(
                tooltip: 'Not yet — ask in 1 hour',
                icon: const Icon(Icons.snooze),
                color: AppColors.textSecondary,
                onPressed: () => rp.snooze(r),
              ),
              IconButton(
                tooltip: 'Mark done',
                icon: const Icon(Icons.check_circle_outline),
                color: AppColors.accent,
                onPressed: () => r.isNewbornStep
                    ? showReminderDuePrompt(context, r)
                    : rp.markDone(r),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
