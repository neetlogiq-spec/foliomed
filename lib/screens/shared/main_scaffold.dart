import 'dart:ui' as ui;

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
import '../admin/admin_home_screen.dart';
import '../admin/admin_staff_screen.dart';
import 'patients_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';
import 'tutorial_screen.dart';
import 'wards_screen.dart';
import '../../providers/theme_provider.dart';
import '../../services/accessibility_settings.dart';
import '../../providers/reminder_provider.dart';
import '../../services/reminder_notifications.dart';
import '../../widgets/reminder_widgets.dart';

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
  final GlobalKey _profileKey = GlobalKey();

  static const String _interactiveTutorialKey = 'interactive_tutorial_done_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final reminders = context.read<ReminderProvider>();
    reminders.onDue = (r) async {
      if (mounted) await showReminderDuePrompt(context, r);
    };
    ReminderNotifications.instance.onTap = (id) {
      if (mounted) reminders.checkDue();
    };
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
    ReminderNotifications.instance.onTap = null;
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
      AccessibilitySettings.refresh();
      final wardIds =
          context.read<AuthProvider>().currentUser?.wardIds ?? const <String>[];
      context.read<NoteProvider>().subscribeForWards(wardIds);
      context.read<PatientProvider>().subscribeForWards(wardIds);
      context.read<ReminderProvider>().checkDue();
    }
  }

  /// Doctors and nurses share one IA: Today · Patients · Wards · Profile.
  List<Widget> get _screensForRole {
    switch (widget.role) {
      case UserRole.doctor:
      case UserRole.nurse:
        return [
          TodayScreen(onOpenPatients: () => setState(() => _index = 1)),
          const PatientsScreen(),
          const WardsScreen(),
          const ProfileScreen(),
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
    final profile = BottomNavigationBarItem(
      icon: _showcase(
        key: _profileKey,
        title: 'Profile',
        description: 'Your details, dark mode, text size, help and feedback.',
        child: const Icon(Icons.person_outline),
      ),
      activeIcon: const Icon(Icons.person),
      label: 'Profile',
    );
    final wards = BottomNavigationBarItem(
      icon: _showcase(
        key: _wardsKey,
        title: 'Wards',
        description: widget.role == UserRole.admin
            ? 'Inspect every ward in the system.'
            : 'Create or join a ward. Each ward has a 5-digit code you '
                'share with your team.',
        child: const Icon(Icons.corporate_fare_outlined),
      ),
      activeIcon: const Icon(Icons.corporate_fare),
      label: 'Wards',
    );
    switch (widget.role) {
      case UserRole.doctor:
      case UserRole.nurse:
        return [
          BottomNavigationBarItem(
            icon: Consumer<NoteProvider>(
              builder: (context, np, _) =>
                  _badged(Icons.today_outlined, np.unacknowledgedCount),
            ),
            activeIcon: Consumer<NoteProvider>(
              builder: (context, np, _) =>
                  _badged(Icons.today, np.unacknowledgedCount),
            ),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: _showcase(
              key: _patientsKey,
              title: 'Patients',
              description: 'Everyone on your wards. Search by name, bed, '
                  'diagnosis or ID, and tap a patient for their timeline.',
              child: const Icon(Icons.people_outline),
            ),
            activeIcon: const Icon(Icons.people),
            label: 'Patients',
          ),
          wards,
          profile,
        ];
      case UserRole.admin:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          wards,
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
          profile,
        ];
    }
  }

  /// Tab icon with a count badge (pending notes on Today).
  Widget _badged(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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
      onFinish: () {
        /* one-shot; nothing to do */
      },
      enableAutoScroll: false,
      blurValue: 1.5,
      builder: (context) => _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AccessibilitySettings.reduceTransparency,
      builder: (context, reduceTransparency, _) {
        // Solid chrome when the user asks for less transparency or more
        // contrast — translucency must never cost legibility.
        final solidChrome =
            reduceTransparency || MediaQuery.highContrastOf(context);
        return _buildScaffold(context, solidChrome);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, bool solidChrome) {
    // Keep reminders (and their notifications) in step with the wards.
    final wardIds = context.select<AuthProvider, List<String>>(
        (a) => a.currentUser?.wardIds ?? const <String>[]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReminderProvider>().subscribe(wardIds);
    });
    return Scaffold(
      // Content scrolls under the translucent tab bar; tab screens add the
      // bar's height to their own scroll padding (withBottomBarInset).
      extendBody: true,
      body: IndexedStack(index: _index, children: _screensForRole),
      // iOS-style tab bar: a frosted material (blur + saturation) with a
      // hairline top edge, 10pt labels and a selection haptic. High
      // contrast mode gets a solid bar instead of translucency.
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          enabled: !solidChrome,
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: solidChrome
                  ? (AppColors.isDark ? AppColors.darkCard : Colors.white)
                  : AppColors.chrome,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconSize: 26,
              selectedItemColor: AppColors.isDark
                  ? AppColors.darkPrimary
                  : AppColors.primary,
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
        ),
      ),
    );
  }
}
