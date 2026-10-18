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
import '../../widgets/foliomed_brand.dart';
import '../shared/filtered_notes_screen.dart';
import 'add_note_screen.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';
import 'patients_list_screen.dart';
import '../../utils/layout.dart';
import '../../widgets/app_alert_dialog.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  List<String> _subscribedWardIds = const [];

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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user?.name ?? 'Doctor'),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.appBarBg,
                      AppColors.surface,
                    ],
                    stops: const [0.0, 0.18],
                  ),
                ),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    final wardIds = context
                            .read<AuthProvider>()
                            .currentUser
                            ?.wardIds ??
                        const [];
                    context
                        .read<NoteProvider>()
                        .subscribeForWards(wardIds);
                    context
                        .read<PatientProvider>()
                        .subscribeForWards(wardIds);
                    await Future.delayed(
                        const Duration(milliseconds: 300));
                  },
                  child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: withBottomBarInset(context, const EdgeInsets.all(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStats(),
                    const SizedBox(height: 24),
                    _sectionHeader(
                      'Active Patients',
                      actionLabel: 'See All',
                      onAction: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PatientsListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPatientsRow(),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.appBarBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            'Recent Notes',
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: AppColors.primary,
                              ),
                              onPressed: () =>
                                  showAddNoteBottomSheet(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildNotesList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
                ),
                ),
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
            label: Text('Add Patient',
                style: appText(fontWeight: FontWeight.w600)),
            onPressed: () {
              final wardIds =
                  context.read<AuthProvider>().currentUser?.wardIds ?? [];
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddPatientScreen(
                    initialWardId: wardIds.isNotEmpty ? wardIds.first : null),
              ));
            },
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'doctor_home_fab',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('New Note'),
            onPressed: () => showAddNoteBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        final notifCount = notifProvider.items.length;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.appBarBg,
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const FolioMedBrand(size: 36),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => showNotificationsPanel(context),
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  if (notifCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$notifCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const ThemeToggleButton(),
              IconButton(
                tooltip: 'Share FolioMed',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => ShareHelper.shareApp(),
              ),
              IconButton(
                tooltip: 'Support the developer',
                icon: const Icon(
                  Icons.local_cafe_outlined,
                  color: Color(0xFFE57F00),
                ),
                onPressed: () => showSupportSheet(context),
              ),
            ],
          ),
        );
      },
    );
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
                MaterialPageRoute(
                  builder: (_) => const PatientsListScreen(),
                ),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: emphasised ? color : AppColors.divider,
            width: emphasised ? 1.5 : 1,
          ),
          boxShadow: emphasised
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(AppColors.iconChipOpacity),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: appText(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: appText(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) trailing,
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  Widget _buildPatientsRow() {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        if (provider.patients.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              'No patients yet',
              style: appText(color: AppColors.textSecondary),
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientDetailScreen(patientId: p.id),
          ),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
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
              style: appText(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.diagnosis,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
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
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No notes yet',
                  style: appText(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final n in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NoteCard(
                  note: n,
                  onAcknowledge: () {
                    final name =
                        context.read<AuthProvider>().currentUser?.name ??
                            'Staff';
                    context
                        .read<NoteProvider>()
                        .acknowledgeNote(n.id, name);
                  },
                  onUnacknowledge: () => context
                      .read<NoteProvider>()
                      .unacknowledgeNote(n.id),
                  onDelete: () => _confirmDelete(context, n.id),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
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
