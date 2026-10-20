import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/account_provider.dart';
import '../providers/ward_feed.dart';
import '../providers/patient_roster.dart';
import '../providers/reminder_provider.dart';
import '../providers/appearance_provider.dart';
import '../providers/unit_provider.dart';
import '../screens/admin/admin_overview_screen.dart';
import '../screens/admin/admin_people_screen.dart';
import '../screens/shared/patients_screen.dart';
import '../screens/account/account_screen.dart';
import '../screens/shared/today_screen.dart';
import '../screens/shared/wards_screen.dart';
import '../services/accessibility_settings.dart';
import '../services/reminder_notifications.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/haptics.dart';
import '../widgets/reminder_widgets.dart';

/// One tab: what it shows and how it's labelled.
class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.page, {this.badge});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  /// Live count shown on the icon (e.g. pending notes), or null.
  final int Function(BuildContext)? badge;
}

/// The signed-in app: four tabs under a frosted tab bar. Keeps live data
/// in step with the user's wards and pauses streams in the background.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.role});

  final UserRole role;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _selected = 0;
  List<String> _wardIds = const [];

  late final List<_Tab> _tabs = widget.role == UserRole.admin
      ? const [
          _Tab('Overview', Icons.space_dashboard_outlined, Icons.space_dashboard, AdminHomeScreen()),
          _Tab('Wards', Icons.corporate_fare_outlined, Icons.corporate_fare, WardsScreen()),
          _Tab('People', Icons.badge_outlined, Icons.badge, AdminPeopleScreen()),
          _Tab('Profile', Icons.account_circle_outlined, Icons.account_circle, AccountScreen()),
        ]
      : [
          _Tab('Today', Icons.today_outlined, Icons.today,
              TodayScreen(onOpenPatients: () => _select(1)),
              badge: (c) => c.watch<WardFeed>().pendingCount),
          const _Tab('Patients', Icons.people_outline, Icons.people, PatientsScreen()),
          const _Tab('Wards', Icons.corporate_fare_outlined, Icons.corporate_fare, WardsScreen()),
          const _Tab('Profile', Icons.account_circle_outlined, Icons.account_circle, AccountScreen()),
        ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final reminders = context.read<ReminderProvider>();
    reminders.onDue = (r) async {
      if (mounted) await showReminderDuePrompt(context, r);
    };
    ReminderNotifications.instance.onTap = (_) {
      if (mounted) reminders.checkDue();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReminderNotifications.instance.onTap = null;
    super.dispose();
  }

  void _select(int i) {
    if (i == _selected) return;
    Haptics.selection();
    setState(() => _selected = i);
  }

  /// Ward-scoped providers follow the user's ward list.
  void _syncWards(List<String> wardIds) {
    if (identical(wardIds, _wardIds) || _sameIds(wardIds, _wardIds)) return;
    _wardIds = wardIds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReminderProvider>().subscribe(wardIds);
      context.read<UnitProvider>().subscribe(wardIds);
    });
  }

  static bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Nobody is looking: stop paying for live reads.
        context.read<WardFeed>().pause();
        context.read<PatientRoster>().pause();
      case AppLifecycleState.resumed:
        AccessibilitySettings.refresh();
        final ids = context.read<AccountProvider>().currentUser?.wardIds ?? const <String>[];
        context.read<WardFeed>().watchWards(ids);
        context.read<PatientRoster>().watchWards(ids);
        context.read<ReminderProvider>().checkDue();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    _syncWards(context.select<AccountProvider, List<String>>(
        (a) => a.currentUser?.wardIds ?? const <String>[]));
    return Scaffold(
      // Pages scroll beneath the translucent bar (see withBottomBarInset).
      extendBody: true,
      body: IndexedStack(index: _selected, children: [for (final t in _tabs) t.page]),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: AccessibilitySettings.reduceTransparency,
        builder: (context, reduceTransparency, _) => _FrostedTabBar(
          tabs: _tabs,
          selected: _selected,
          onSelect: _select,
          solid: reduceTransparency || MediaQuery.highContrastOf(context),
        ),
      ),
    );
  }
}

class _FrostedTabBar extends StatelessWidget {
  const _FrostedTabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.solid,
  });

  final List<_Tab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Opaque when the user asks for less transparency or more contrast.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.isDark ? AppColors.darkPrimary : AppColors.primary;
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? (AppColors.isDark ? AppColors.darkCard : Colors.white) : AppColors.chrome,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              for (final (i, t) in tabs.indexed)
                Expanded(
                  child: _TabButton(
                    tab: t,
                    selected: i == selected,
                    tint: tint,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (solid) return bar;
    return ClipRect(
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: bar),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.selected, required this.tint, required this.onTap});

  final _Tab tab;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tint : AppColors.textSecondary;
    final count = tab.badge?.call(context) ?? 0;
    return Semantics(
      button: true,
      selected: selected,
      label: count > 0 ? '${tab.label}, $count pending' : tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              backgroundColor: AppColors.danger,
              offset: const Offset(10, -4),
              child: Icon(selected ? tab.selectedIcon : tab.icon, color: color, size: 26),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: AppTypography.caption2(color: color, weight: selected ? FontWeight.w600 : FontWeight.w500)
                  .copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
