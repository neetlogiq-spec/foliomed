import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/note_card.dart';
import '../../widgets/notifications_panel.dart';
import '../../utils/share_helper.dart';
import '../../widgets/support_sheet.dart';
import '../../widgets/theme_toggle_button.dart';
import '../shared/filtered_notes_screen.dart';
import 'add_note_screen.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';
import 'patients_list_screen.dart';
import '../../utils/layout.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/pressable.dart';
import '../../widgets/empty_state.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  List<String> _subscribedWardIds = const [];

  /// The note list's entrance plays once, when data first arrives.
  bool _notesEntered = false;

  void _addPatient() {
    final wardIds = context.read<AuthProvider>().currentUser?.wardIds ?? [];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPatientScreen(
          initialWardId: wardIds.isNotEmpty ? wardIds.first : null,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wardIds =
        context.watch<AuthProvider>().currentUser?.wardIds ?? const [];
    if (!_sameList(wardIds, _subscribedWardIds)) {
      _subscribedWardIds = List.of(wardIds);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NoteProvider>().subscribeForWards(_subscribedWardIds);
        context.read<PatientProvider>().subscribeForWards(_subscribedWardIds);
      });
    }
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator.adaptive(
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          final wardIds =
              context.read<AuthProvider>().currentUser?.wardIds ?? const [];
          context.read<NoteProvider>().subscribeForWards(wardIds);
          context.read<PatientProvider>().subscribeForWards(wardIds);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LargeTitleAppBar(
              eyebrow: timeOfDayGreeting(),
              title: user?.name ?? 'Doctor',
              actions: _headerActions(context),
            ),
            SliverPadding(
              padding: withBottomBarInset(
                context,
                const EdgeInsets.fromLTRB(16, 8, 16, 96),
              ),
              sliver: SliverList.list(
                children: [
                  _buildStats(),
                  const SizedBox(height: 28),
                  SectionHeader(
                    'Active Patients',
                    actionLabel: 'See All',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PatientsListScreen(),
                      ),
                    ),
                  ),
                  _buildPatientsRow(),
                  const SizedBox(height: 28),
                  // Flat section on the grouped background — no
                  // container-in-a-container.
                  SectionHeader(
                    'Recent Notes',
                    trailing: IconButton(
                      tooltip: 'New note',
                      icon: Icon(
                        Icons.add_circle,
                        color: AppColors.isDark
                            ? AppColors.darkPrimary
                            : AppColors.primary,
                      ),
                      onPressed: () => showAddNoteBottomSheet(context),
                    ),
                  ),
                  _buildNotesList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'doctor_home_add_patient',
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.primary,
            elevation: 2,
            icon: const Icon(Icons.person_add_outlined),
            label: Text(
              'Add Patient',
              style: appText(fontWeight: FontWeight.w600),
            ),
            onPressed: _addPatient,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'doctor_home_fab',
            backgroundColor: AppColors.isDark
                ? AppColors.darkPrimary
                : AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: const Icon(Icons.add),
            label: const Text('New Note'),
            onPressed: () => showAddNoteBottomSheet(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _headerActions(BuildContext context) {
    final notifCount = context.watch<NotificationProvider>().items.length;
    return [
      ChromeIconButton(
        icon: Icons.notifications_outlined,
        tooltip: 'Notifications',
        badgeCount: notifCount,
        onPressed: () => showNotificationsPanel(context),
      ),
      const ThemeToggleButton(),
      ChromeIconButton(
        icon: Icons.share_outlined,
        tooltip: 'Share FolioMed',
        onPressed: () => ShareHelper.shareApp(),
      ),
      ChromeIconButton(
        icon: Icons.local_cafe_outlined,
        tooltip: 'Support the developer',
        color: AppColors.warning,
        onPressed: () => showSupportSheet(context),
      ),
    ];
  }

  Widget _buildStats() {
    return Consumer2<PatientProvider, NoteProvider>(
      builder: (context, patientProvider, noteProvider, _) {
        final today = DateTime.now();
        final todaysNotes = noteProvider.notes.where((n) {
          return n.createdAt.year == today.year &&
              n.createdAt.month == today.month &&
              n.createdAt.day == today.day;
        }).length;
        return Row(
          children: [
            _statCard(
              label: 'Patients',
              value: '${patientProvider.patientCount}',
              icon: Icons.people_outline,
              color: AppColors.doctorColor,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PatientsListScreen()),
              ),
            ),
            const SizedBox(width: 10),
            _statCard(
              label: 'Notes Today',
              value: '$todaysNotes',
              icon: Icons.notes_outlined,
              color: AppColors.accent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FilteredNotesScreen(
                    filter: NoteFilterType.today,
                    title: "Today's Notes",
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _statCard(
              label: 'Urgent',
              value: '${noteProvider.urgentNotes.length}',
              icon: Icons.priority_high,
              color: AppColors.danger,
              emphasised: noteProvider.urgentNotes.isNotEmpty,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FilteredNotesScreen(
                    filter: NoteFilterType.urgent,
                    title: 'Urgent Notes',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool emphasised = false,
  }) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            // Urgent with items: a coloured edge, not a glow.
            border: emphasised ? Border.all(color: color, width: 1.5) : null,
            boxShadow: AppColors.cardShadow,
          ),
          child: Semantics(
            label: '$label: $value',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: AppTypography.title1(
                    color: AppColors.textPrimary,
                  ).copyWith(fontFeatures: AppTypography.tabular),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsRow() {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        if (provider.patients.isEmpty) {
          return _EmptyCard(
            child: EmptyState(
              icon: Icons.people_outline,
              title: 'No patients yet',
              subtitle: 'Admit a patient to start their notes.',
              buttonLabel: 'Add Patient',
              onButtonTap: _addPatient,
            ),
          );
        }
        return SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: provider.patients.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _patientMiniCard(provider.patients[i]),
          ),
        );
      },
    );
  }

  Widget _patientMiniCard(Patient p) {
    return Pressable(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientDetailScreen(patientId: p.id),
          ),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.doctorColor.withOpacity(0.1),
              child: Text(
                p.initials,
                style: const TextStyle(
                  color: AppColors.doctorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Bed ${p.bedNumber}',
              style: appText(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              p.diagnosis,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(color: AppColors.textPrimary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    return Consumer<NoteProvider>(
      builder: (context, provider, _) {
        final recent = provider.notes.take(10).toList();
        if (recent.isEmpty) {
          return _EmptyCard(
            child: EmptyState(
              icon: Icons.notes_outlined,
              title: 'No notes yet',
              subtitle: 'Notes your ward team posts appear here in real time.',
              buttonLabel: 'New Note',
              onButtonTap: () => showAddNoteBottomSheet(context),
            ),
          );
        }
        final animate = !_notesEntered;
        if (animate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _notesEntered = true;
          });
        }
        return Column(
          children: [
            for (final (i, n) in recent.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: staggeredEntrance(
                  context,
                  index: i,
                  animate: animate,
                  child: NoteCard(
                    note: n,
                    onAcknowledge: () {
                      final name =
                          context.read<AuthProvider>().currentUser?.name ??
                          'Staff';
                      context.read<NoteProvider>().acknowledgeNote(n.id, name);
                    },
                    onUnacknowledge: () =>
                        context.read<NoteProvider>().unacknowledgeNote(n.id),
                    onDelete: () => _confirmDelete(context, n.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, String noteId) async {
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AppAlertDialog(
        title: const Text('Delete note?'),
        content: const Text(
          'This will permanently delete the note and every reply on it — fully erased from our database. There is no backup and no way to recover it once you tap Delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<NoteProvider>().deleteNote(noteId);
    }
  }
}

/// Card surface for an inline empty state inside a section.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: child,
    );
  }
}
