import 'package:app_settings/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_theme.dart';
import '../../utils/oem_autostart.dart';
import '../../providers/theme_provider.dart';

class BackgroundSetupScreen extends StatefulWidget {
  const BackgroundSetupScreen({super.key});

  static const String prefKey = 'bg_wizard_done';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
  }

  /// Returns true on platforms where this wizard shouldn't show.
  static bool shouldSkip() {
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.android;
  }

  @override
  State<BackgroundSetupScreen> createState() => _BackgroundSetupScreenState();
}

class _BackgroundSetupScreenState extends State<BackgroundSetupScreen> {
  int _step = 0;
  String _manufacturer = '';
  bool _notifGranted = false;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (mounted) {
        setState(() => _manufacturer = info.manufacturer);
      }
    } catch (_) {}
    final perm = await Permission.notification.status;
    if (mounted) setState(() => _notifGranted = perm.isGranted);
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() => _notifGranted = status.isGranted);
    if (!status.isGranted) {
      _nudgeNotificationBlocked();
    }
  }

  void _nudgeNotificationBlocked() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('FolioMed needs notifications'),
        content: const Text(
          'Without notifications you will miss urgent alerts. Open settings and turn on notifications for FolioMed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBatteryOptimization() async {
    await AppSettings.openAppSettings(
      type: AppSettingsType.batteryOptimization,
    );
  }

  Future<void> _openOemAutostart() async {
    await OemAutostart.openAutostartScreen(_manufacturer);
  }

  Future<void> _finish({bool skippedBattery = false}) async {
    await BackgroundSetupScreen.markDone();
    if (skippedBattery) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bg_wizard_skipped_battery', true);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/doctor/home');
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    final guide = OemAutostart.guideFor(_manufacturer);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Set up alerts'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _stepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _stepBody(guide),
              ),
            ),
            _stepFooter(guide),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBody(OemGuide guide) {
    switch (_step) {
      case 0:
        return _intro();
      case 1:
        return _notifStep();
      case 2:
        return _batteryStep(guide);
    }
    return const SizedBox.shrink();
  }

  Widget _intro() {
    return _stepCard(
      icon: Icons.notifications_active_outlined,
      iconColor: AppColors.danger,
      title: 'Don\'t miss a single alert',
      body:
          "FolioMed delivers urgent ward updates the moment they happen. Android aggressively kills background apps to save battery — that means missed notifications, late acks, and missed care.\n\nThis quick 2-step setup makes sure your phone always wakes FolioMed when a teammate posts an alert. Takes 30 seconds.",
      bullets: const [
        ('Allow notifications', 'Required'),
        ('Disable battery optimisation', 'Strongly recommended'),
        ('Allow background autostart', 'OEM-specific'),
      ],
    );
  }

  Widget _notifStep() {
    return _stepCard(
      icon: _notifGranted
          ? Icons.check_circle_outline
          : Icons.notifications_outlined,
      iconColor:
          _notifGranted ? AppColors.accent : AppColors.primary,
      title: _notifGranted
          ? 'Notifications enabled'
          : 'Allow notifications',
      body: _notifGranted
          ? 'Perfect. FolioMed can now alert you the moment a note lands.'
          : 'FolioMed needs permission to send you notifications. This is non-negotiable — without it, you cannot be alerted to urgent patient updates from your team.',
      bullets: const [],
      action: _notifGranted
          ? null
          : ('Allow notifications', _requestNotification),
    );
  }

  Widget _batteryStep(OemGuide guide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepCard(
          icon: Icons.battery_full_outlined,
          iconColor: AppColors.warning,
          title: 'Keep FolioMed running in the background',
          body:
              'Android (especially on ${guide.label}) aggressively shuts apps down to save battery. Without these settings, you may miss urgent alerts when the app is closed.',
          bullets: const [],
        ),
        const SizedBox(height: 16),
        _instructionsCard(
          title: 'Step A · Disable battery optimisation',
          subtitle:
              'Tells Android to stop killing FolioMed when the screen is off.',
          actionLabel: 'Open battery settings',
          onAction: _openBatteryOptimization,
        ),
        const SizedBox(height: 12),
        _instructionsCard(
          title: 'Step B · Allow autostart for ${guide.label}',
          subtitle: 'Some Android skins (yours) need a separate toggle.',
          actionLabel: 'Open ${guide.label} settings',
          onAction: _openOemAutostart,
          steps: guide.steps,
        ),
      ],
    );
  }

  Widget _stepCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    List<(String, String)> bullets = const [],
    (String, VoidCallback)? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: appText(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: appText(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: b.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: b.$2,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: action.$2,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(action.$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _instructionsCard({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    List<String>? steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: appText(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (steps != null && steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${i + 1}. ${steps[i]}',
                  style: appText(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepFooter(OemGuide guide) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.appBarBg,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (_step == 2)
            Expanded(
              child: TextButton(
                onPressed: () => _finish(skippedBattery: true),
                child: const Text('Skip for now'),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (_step == 0) {
                setState(() => _step = 1);
              } else if (_step == 1) {
                if (!_notifGranted) {
                  _requestNotification();
                  return;
                }
                setState(() => _step = 2);
              } else {
                _finish();
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
            ),
            child: Text(
              _step == 0
                  ? 'Get started'
                  : _step == 1
                      ? (_notifGranted ? 'Continue' : 'Allow notifications')
                      : 'Done',
            ),
          ),
        ],
      ),
    );
  }
}
