import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../widgets/note_card.dart';
import '../../widgets/notifications_panel.dart';
import '../../utils/share_helper.dart';
import '../../widgets/support_sheet.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/foliomed_brand.dart';
import 'acknowledge_sheet.dart';
import '../../widgets/app_sheet.dart';
import '../../utils/layout.dart';

class NurseHomeScreen extends StatefulWidget {
  const NurseHomeScreen({super.key});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  String _filter = 'All';
  bool _todayOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wardIds =
          context.read<AuthProvider>().currentUser?.wardIds ?? const [];
      context.read<NoteProvider>().subscribeForWards(wardIds);
      context.read<PatientProvider>().subscribeForWards(wardIds);
    });
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
            _header(user?.name ?? 'Nurse'),
            Expanded(
              child: SingleChildScrollView(
                padding: withBottomBarInset(context, const EdgeInsets.all(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _alertBanner(),
                    _statsRow(),
                    const SizedBox(height: 24),
                    _pendingHeader(),
                    const SizedBox(height: 10),
                    _pendingList(),
                    const SizedBox(height: 24),
                    _allNotesHeader(),
                    const SizedBox(height: 10),
                    _allNotesList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String name) {
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

  Widget _alertBanner() {
    return Consumer<NoteProvider>(
      builder: (context, np, _) {
        final count = np.urgentNotes.length;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.danger, AppColors.warning],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You have $count urgent notes requiring attention',
                  style: appText(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                onPressed: () => setState(() => _filter = 'Urgent'),
                child: const Text('View Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statsRow() {
    return Consumer<NoteProvider>(
      builder: (context, np, _) {
        final uid = context.read<AuthProvider>().currentUser?.uid;
        final ackToday = np.notes.where((n) {
          return n.isAcknowledged &&
              n.acknowledgedBy == uid &&
              n.acknowledgedAt != null &&
              isToday(n.acknowledgedAt!);
        }).length;
        return Row(
          children: [
            Expanded(
              child: _statCard(
                label: 'Pending',
                value: '${np.unacknowledgedCount}',
                icon: Icons.notifications_active_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                label: 'Acknowledged Today',
                value: '$ackToday',
                icon: Icons.check_circle_outline,
                color: AppColors.accent,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
    );
  }

  Widget _pendingHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Pending Actions',
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterSheet,
        ),
      ],
    );
  }

  void _showFilterSheet() {
    showAppSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in ['All', 'Urgent', 'Normal', 'Low'])
                ListTile(
                  leading: Icon(
                    _filter == f ? Icons.check_circle : Icons.circle_outlined,
                    color: _filter == f
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  title: Text(f),
                  onTap: () {
                    setState(() => _filter = f);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _pendingList() {
    return Consumer<NoteProvider>(
      builder: (context, np, _) {
        Iterable<Note> pending = np.notes.where((n) => !n.isAcknowledged);
        if (_filter != 'All') {
          pending = pending.where((n) => n.priority == _filter);
        }
        final list = pending.toList();
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.accent,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'All caught up!',
                  style: appText(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final n in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NoteCard(
                  note: n,
                  onAcknowledge: () => showAcknowledgeSheet(context, n),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _allNotesHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'All Ward Notes',
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilterChip(
          selected: _todayOnly,
          label: const Text('Today'),
          onSelected: (v) => setState(() => _todayOnly = v),
        ),
      ],
    );
  }

  Widget _allNotesList() {
    return Consumer<NoteProvider>(
      builder: (context, np, _) {
        var notes = np.notes;
        if (_todayOnly) {
          notes = notes.where((n) => isToday(n.createdAt)).toList();
        }
        if (notes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'No notes yet',
              textAlign: TextAlign.center,
              style: appText(color: AppColors.textSecondary),
            ),
          );
        }
        return Column(
          children: [
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NoteCard(
                  note: n,
                  onAcknowledge: n.isAcknowledged
                      ? null
                      : () => showAcknowledgeSheet(context, n),
                ),
              ),
          ],
        );
      },
    );
  }
}
