import 'package:flutter/material.dart';
import '../../utils/haptics.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/rate_prompt.dart';
import '../../widgets/note_card.dart';
import '../../widgets/support_action.dart';
import '../admin/admin_home_screen.dart';
import '../admin/admin_staff_screen.dart';
import '../doctor/add_note_screen.dart';
import '../doctor/doctor_home_screen.dart';
import '../doctor/patients_list_screen.dart';
import '../monitor/monitor_dashboard_screen.dart';
import '../nurse/nurse_home_screen.dart';
import '../nurse/nurse_patients_screen.dart';
import 'profile_screen.dart';
import 'tutorial_screen.dart';
import 'wards_screen.dart';
import '../../providers/theme_provider.dart';

class MainScaffold extends StatefulWidget {
  final UserRole role;

  const MainScaffold({super.key, required this.role});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _index = 0;

  // Coachmark keys — used by the first-run interactive walkthrough that
  // highlights each bottom-nav destination in turn after the slide
  // tutorial finishes. Stored in fields so the same key instance is
  // reused across rebuilds (Showcase is sensitive to that).
  final GlobalKey _wardsKey = GlobalKey();
  final GlobalKey _patientsKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();
  final GlobalKey _monitorKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();

  static const String _interactiveTutorialKey =
      'interactive_tutorial_done_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!await TutorialScreen.isDone()) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TutorialScreen(),
            fullscreenDialog: true,
          ),
        );
      }
      if (!mounted) return;
      // After the slide tutorial, run the interactive coachmark walk —
      // exactly once per install (keyed in SharedPreferences).
      await _maybeStartInteractiveTutorial();
      // Daily chai popup removed at user's request — Support button
      // now lives in every main-screen AppBar instead, so users still
      // have a one-tap way to support the project without an
      // interruption every day.
      // Quietly try a weekly Play in-app review nudge. Google rate-
      // limits the actual dialog server-side; we just ask.
      RatePrompt.maybeShowWeekly();
    });
  }

  Future<void> _maybeStartInteractiveTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_interactiveTutorialKey) ?? false) return;
    if (!mounted) return;
    final keys = <GlobalKey>[
      _wardsKey,
      _patientsKey,
      if (widget.role == UserRole.doctor) _notesKey,
      _profileKey,
    ];
    // Defer one frame to make sure the bottom nav has laid out and the
    // ShowCase Overlay is mounted, otherwise startShowCase silently no-ops.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShowCaseWidget.of(context).startShowCase(keys);
    });
    await prefs.setBool(_interactiveTutorialKey, true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App is backgrounded — drop listeners to stop billing reads.
      context.read<NoteProvider>().pauseStreams();
      context.read<PatientProvider>().pauseStream();
    } else if (state == AppLifecycleState.resumed) {
      final wardIds = context.read<AuthProvider>().currentUser?.wardIds ??
          const <String>[];
      context.read<NoteProvider>().subscribeForWards(wardIds);
      context.read<PatientProvider>().subscribeForWards(wardIds);
    }
  }

  List<Widget> get _screensForRole {
    switch (widget.role) {
      case UserRole.doctor:
        return const [
          DoctorHomeScreen(),
          WardsScreen(),
          PatientsListScreen(),
          _DoctorNotesList(),
          MonitorDashboardScreen(),
          ProfileScreen(),
        ];
      case UserRole.nurse:
        return const [
          NurseHomeScreen(),
          WardsScreen(),
          NursePatientsScreen(),
          ProfileScreen(),
        ];
      case UserRole.admin:
        return const [
          AdminHomeScreen(),
          WardsScreen(),
          AdminStaffScreen(),
          ProfileScreen(),
        ];
    }
  }

  // Coachmark wrapper. We want the entire icon (including any badge
  // positioned around it) to be the "target" so the spotlight has the
  // right shape. Description copy is intentionally short — coachmarks
  // shouldn't read like documentation.
  Widget _showcase({
    required GlobalKey key,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Showcase(
      key: key,
      title: title,
      description: description,
      titleTextStyle: appText(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
      descTextStyle: appText(
        color: AppColors.textSecondary,
        fontSize: 13,
        height: 1.45,
      ),
      tooltipBackgroundColor: AppColors.card,
      targetShapeBorder: const CircleBorder(),
      targetPadding: const EdgeInsets.all(6),
      child: child,
    );
  }

  List<BottomNavigationBarItem> get _itemsForRole {
    switch (widget.role) {
      case UserRole.doctor:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _wardsKey,
              title: 'Wards',
              description:
                  'Create or join a ward here. Each ward has a 5-digit '
                  'code you share with your team.',
              child: const Icon(Icons.corporate_fare_outlined),
            ),
            activeIcon: const Icon(Icons.corporate_fare),
            label: 'Wards',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _patientsKey,
              title: 'Patients',
              description:
                  'Every patient on your wards. Pull-search across wards '
                  'and add new ones from here.',
              child: const Icon(Icons.people_outline),
            ),
            activeIcon: const Icon(Icons.people),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _notesKey,
              title: 'Notes',
              description:
                  'The live ward feed. Post a note here and the whole '
                  'team gets a push instantly.',
              child: Consumer<NoteProvider>(
                builder: (context, np, _) =>
                    _notesIcon(np.unacknowledgedCount),
              ),
            ),
            activeIcon: Consumer<NoteProvider>(
              builder: (context, np, _) =>
                  _notesIcon(np.unacknowledgedCount, active: true),
            ),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _monitorKey,
              title: 'Monitor',
              description:
                  'Live patient monitoring — vitals, alerts, and bedside '
                  'camera. Requires FolioMed Pro.',
              child: const Icon(Icons.monitor_heart_outlined),
            ),
            activeIcon: const Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _profileKey,
              title: 'Profile',
              description:
                  'Settings, dark mode, text size, FAQs and a way to '
                  'send me feedback.',
              child: const Icon(Icons.person_outline),
            ),
            activeIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ];
      case UserRole.nurse:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _wardsKey,
              title: 'Wards',
              description:
                  'Create or join a ward here. Each ward has a 5-digit '
                  'code you share with your team.',
              child: const Icon(Icons.corporate_fare_outlined),
            ),
            activeIcon: const Icon(Icons.corporate_fare),
            label: 'Wards',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _patientsKey,
              title: 'Patients',
              description:
                  'Every patient on your wards. Pull-search across wards '
                  'and tap any one to see their notes.',
              child: const Icon(Icons.people_outline),
            ),
            activeIcon: const Icon(Icons.people),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _profileKey,
              title: 'Profile',
              description:
                  'Settings, dark mode, text size, FAQs and a way to '
                  'send me feedback.',
              child: const Icon(Icons.person_outline),
            ),
            activeIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ];
      case UserRole.admin:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _wardsKey,
              title: 'Wards',
              description: 'Inspect every ward in the system.',
              child: const Icon(Icons.corporate_fare),
            ),
            label: 'Wards',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _patientsKey,
              title: 'Staff',
              description: 'Every signed-up FolioMed user.',
              child: const Icon(Icons.group_outlined),
            ),
            activeIcon: const Icon(Icons.group),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _profileKey,
              title: 'Profile',
              description: 'Settings, FAQs, send feedback.',
              child: const Icon(Icons.person_outline),
            ),
            activeIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ];
    }
  }

  Widget _notesIcon(int count, {bool active = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.notes : Icons.notes_outlined),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    // Wrap everything in ShowCaseWidget so any Showcase descendant can
    // be triggered by ShowCaseWidget.of(context).startShowCase(...).
    // Coachmarks are themed for the app palette and dismiss themselves
    // on tap or when the user taps outside.
    return ShowCaseWidget(
      onFinish: () {/* one-shot; nothing to do */},
      enableAutoScroll: false,
      blurValue: 1.5,
      builder: (context) => _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screensForRole,
      ),
      // iOS-style tab bar: chrome material with a hairline top edge,
      // 10pt labels, tint on the selected item and a selection haptic.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.isDark ? AppColors.darkCard : const Color(0xFFF9F9F9),
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconSize: 26,
          selectedItemColor:
              AppColors.isDark ? AppColors.darkPrimary : AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: appText(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: appText(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          currentIndex: _index,
          items: _itemsForRole,
          onTap: (i) {
            if (i != _index) Haptics.selection();
            setState(() => _index = i);
          },
        ),
      ),
    );
  }
}

class _DoctorNotesList extends StatelessWidget {
  const _DoctorNotesList();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Ward Notes'),
        actions: const [SupportAppBarAction()],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, np, _) {
          if (np.notes.isEmpty) {
            return Center(
              child: Text(
                'No notes yet',
                style: appText(color: AppColors.textSecondary),
              ),
            );
          }
          final showLimitNotice = np.notes.length >= 150;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: np.notes.length + (showLimitNotice ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (showLimitNotice && i == np.notes.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Showing the last 150 notes',
                      style: appText(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              final note = np.notes[i];
              return NoteCard(
                note: note,
                onAcknowledge: note.isAcknowledged
                    ? null
                    : () {
                        final name = context
                                .read<AuthProvider>()
                                .currentUser
                                ?.name ??
                            'Staff';
                        context
                            .read<NoteProvider>()
                            .acknowledgeNote(note.id, name);
                      },
                onUnacknowledge: () => context
                    .read<NoteProvider>()
                    .unacknowledgeNote(note.id),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete note?'),
                      content: const Text(
                        'This will permanently delete the note and every reply on it — fully erased from our database. There is no backup and no way to recover it once you tap Delete.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context
                        .read<NoteProvider>()
                        .deleteNote(note.id);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_list_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
        onPressed: () => showAddNoteBottomSheet(context),
      ),
    );
  }
}


