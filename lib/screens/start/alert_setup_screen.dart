import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/routes.dart';
import '../../services/device_power_settings.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

/// Android only: a live checklist of what the phone needs so ward alerts
/// arrive when FolioMed is closed — notifications, unrestricted battery,
/// and (on brands that need it) auto-start. Statuses refresh whenever the
/// user comes back from Settings.
class AlertSetupScreen extends StatefulWidget {
  const AlertSetupScreen({super.key, this.firstRun = false});

  /// From the launch flow (shows Done / Not now) vs. from Profile.
  final bool firstRun;

  static const _doneKey = 'alert_setup_done_v1';

  /// Only Android phones need this.
  static bool get applies => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the launch flow should show it.
  static Future<bool> needed() async {
    if (!applies) return false;
    try {
      return !((await SharedPreferences.getInstance()).getBool(_doneKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markDone() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_doneKey, true);
    } catch (_) {}
  }

  @override
  State<AlertSetupScreen> createState() => _AlertSetupScreenState();
}

class _AlertSetupScreenState extends State<AlertSetupScreen> with WidgetsBindingObserver {
  PermissionStatus? _notifications;
  PermissionStatus? _battery;
  PowerSettingsGuide? _guide;
  bool _guideOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _loadBrand();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _loadBrand() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (mounted) setState(() => _guide = powerGuideFor(info.manufacturer));
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final n = await Permission.notification.status;
    final b = await Permission.ignoreBatteryOptimizations.status;
    if (mounted) {
      setState(() {
        _notifications = n;
        _battery = b;
      });
    }
  }

  Future<void> _fixNotifications() async {
    final s = _notifications;
    if (s != null && (s.isPermanentlyDenied || s.isRestricted)) {
      await openAppSettings();
    } else {
      await Permission.notification.request();
    }
    await _refresh();
  }

  Future<void> _fixBattery() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _refresh();
  }

  Future<void> _openBrandSettings() async {
    final g = _guide;
    if (g == null) return;
    setState(() => _guideOpened = true);
    await openPowerSettings(g);
  }

  Future<void> _finish() async {
    Haptics.success();
    await AlertSetupScreen.markDone();
    if (!mounted) return;
    if (widget.firstRun) {
      Routes.restart(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  bool get _allSet =>
      (_notifications?.isGranted ?? false) &&
      (_battery?.isGranted ?? false) &&
      (_guide == null || _guideOpened);

  Widget _status(bool? ok, {required String onLabel, required VoidCallback fix, String fixLabel = 'Turn On'}) {
    if (ok == null) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2));
    if (ok) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, color: AppColors.accent, size: 20),
        const SizedBox(width: 4),
        Text(onLabel, style: AppTypography.subheadline(color: AppColors.textSecondary)),
      ]);
    }
    return FilledButton.tonal(
      onPressed: fix,
      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      child: Text(fixLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _guide;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(title: 'Alert Setup', showBackButton: !widget.firstRun),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Urgent notes and due reminders should reach you even when FolioMed '
                    'is closed. Android needs a couple of switches for that.',
                    style: AppTypography.body(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 20),
                InsetGroup(
                  footer: 'Battery: FolioMed only wakes for alerts, so this has little effect on battery life.',
                  children: [
                    SettingsRow(
                      icon: Icons.notifications_active,
                      iconColor: AppColors.danger,
                      title: 'Notifications',
                      subtitle: 'To show alerts on your lock screen',
                      trailing: _status(_notifications?.isGranted,
                          onLabel: 'On', fix: _fixNotifications),
                      showChevron: false,
                    ),
                    SettingsRow(
                      icon: Icons.battery_charging_full,
                      iconColor: AppColors.accent,
                      title: 'Unrestricted battery',
                      subtitle: 'So Android doesn’t delay alerts to save power',
                      trailing: _status(_battery?.isGranted,
                          onLabel: 'Allowed', fix: _fixBattery, fixLabel: 'Allow'),
                      showChevron: false,
                    ),
                  ],
                ),
                if (g != null) ...[
                  const SizedBox(height: 24),
                  InsetGroup(
                    header: 'On ${g.brand} phones',
                    footer: g.steps,
                    children: [
                      SettingsRow(
                        icon: Icons.power_settings_new,
                        iconColor: AppColors.secondary,
                        title: 'Allow auto-start',
                        subtitle: _guideOpened ? 'Opened — check FolioMed is switched on' : null,
                        trailing: _guideOpened
                            ? Icon(Icons.check_circle, color: AppColors.accent, size: 20)
                            : Text('Open', style: AppTypography.body(color: AppColors.primary)),
                        onTap: _openBrandSettings,
                        showChevron: false,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _finish,
                    child: Text(_allSet || !widget.firstRun ? 'Done' : 'Continue Anyway',
                        style: AppTypography.headline(color: AppColors.onPrimary)),
                  ),
                ),
                if (widget.firstRun && !_allSet) ...[
                  const SizedBox(height: 8),
                  Text(
                    'You can finish this later in Profile → Alert Setup.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
