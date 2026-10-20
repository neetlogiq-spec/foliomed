import 'package:android_intent_plus/android_intent.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';

/// Some Android brands stop apps in the background unless the user allows
/// "auto-start" / "background activity" for them. This knows where that
/// switch lives on the common brands and how to describe it.
class PowerSettingsGuide {
  const PowerSettingsGuide({
    required this.brand,
    required this.steps,
    this.screens = const [],
  });

  /// As shown to the user, e.g. "Xiaomi".
  final String brand;

  /// What to do once the settings screen opens.
  final String steps;

  /// Settings activities to try, in order (package, activity class).
  final List<(String, String)> screens;
}

const _guides = <String, PowerSettingsGuide>{
  'xiaomi': PowerSettingsGuide(
    brand: 'Xiaomi',
    steps: 'Find FolioMed in Autostart and switch it on. Then in Battery saver, set FolioMed to "No restrictions".',
    screens: [('com.miui.securitycenter', 'com.miui.permcenter.autostart.AutoStartManagementActivity')],
  ),
  'oppo': PowerSettingsGuide(
    brand: 'OPPO',
    steps: 'Allow FolioMed to start automatically, then set Battery to "Allow background activity".',
    screens: [
      ('com.coloros.safecenter', 'com.coloros.safecenter.permission.startup.StartupAppListActivity'),
      ('com.oppo.safe', 'com.oppo.safe.permission.startup.StartupAppListActivity'),
    ],
  ),
  'realme': PowerSettingsGuide(
    brand: 'realme',
    steps: 'Allow FolioMed to start automatically, then set Battery to "Allow background activity".',
    screens: [('com.coloros.safecenter', 'com.coloros.safecenter.permission.startup.StartupAppListActivity')],
  ),
  'vivo': PowerSettingsGuide(
    brand: 'vivo',
    steps: 'Turn on background start-up for FolioMed, and allow high background power use.',
    screens: [
      ('com.vivo.permissionmanager', 'com.vivo.permissionmanager.activity.BgStartUpManagerActivity'),
      ('com.iqoo.secure', 'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity'),
    ],
  ),
  'oneplus': PowerSettingsGuide(
    brand: 'OnePlus',
    steps: 'Allow FolioMed to auto-launch, then set its battery use to "Don’t optimise".',
    screens: [('com.oneplus.security', 'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity')],
  ),
  'samsung': PowerSettingsGuide(
    brand: 'Samsung',
    steps: 'Under Background usage limits, make sure FolioMed is not in "Sleeping apps" or "Deep sleeping apps".',
    screens: [('com.samsung.android.lool', 'com.samsung.android.sm.ui.battery.BatteryActivity')],
  ),
  'huawei': PowerSettingsGuide(
    brand: 'Huawei',
    steps: 'In App launch, turn off "Manage automatically" for FolioMed and allow it to run in the background.',
    screens: [('com.huawei.systemmanager', 'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity')],
  ),
  'honor': PowerSettingsGuide(
    brand: 'Honor',
    steps: 'In App launch, turn off "Manage automatically" for FolioMed and allow it to run in the background.',
    screens: [('com.huawei.systemmanager', 'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity')],
  ),
  'asus': PowerSettingsGuide(
    brand: 'ASUS',
    steps: 'Allow FolioMed under Auto-start manager.',
    screens: [('com.asus.mobilemanager', 'com.asus.mobilemanager.autostart.AutoStartActivity')],
  ),
};

/// Guide for a device manufacturer string (case-insensitive, partial —
/// "Xiaomi", "Redmi" and "POCO" all map to Xiaomi), or null when the
/// brand doesn't need an extra step.
PowerSettingsGuide? powerGuideFor(String manufacturer) {
  final m = manufacturer.toLowerCase();
  if (m.contains('redmi') || m.contains('poco')) return _guides['xiaomi'];
  for (final e in _guides.entries) {
    if (m.contains(e.key)) return e.value;
  }
  return null;
}

/// Opens the brand's auto-start screen, falling back to FolioMed's own
/// app settings when none of the known screens exist on this build.
Future<void> openPowerSettings(PowerSettingsGuide guide) async {
  for (final (pkg, cls) in guide.screens) {
    try {
      await AndroidIntent(action: 'android.intent.action.MAIN', package: pkg, componentName: cls).launch();
      return;
    } catch (e) {
      debugPrint('Power settings screen not available: $pkg/$cls');
    }
  }
  await AppSettings.openAppSettings();
}
