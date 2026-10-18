import 'package:android_intent_plus/android_intent.dart';
import 'package:app_settings/app_settings.dart';

/// Manufacturer-specific "autostart / background-allowed" management
/// pages. Each OEM hides this in a different system app — without
/// whitelisting FolioMed there, Android will kill the process and FCM
/// pushes will never reach the device.
class OemAutostart {
  /// Returns a friendly label + instructions for the given manufacturer.
  /// Manufacturer string should be lower-cased.
  static OemGuide guideFor(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (_xiaomi.any(m.contains)) return _xiaomiGuide;
    if (_oppo.any(m.contains)) return _oppoGuide;
    if (_vivo.any(m.contains)) return _vivoGuide;
    if (_oneplus.any(m.contains)) return _oneplusGuide;
    if (_samsung.any(m.contains)) return _samsungGuide;
    if (_huawei.any(m.contains)) return _huaweiGuide;
    if (_asus.any(m.contains)) return _asusGuide;
    return _genericGuide;
  }

  /// Tries to open the OEM-specific autostart screen. Falls back to the
  /// generic Android battery-optimization settings.
  static Future<void> openAutostartScreen(String manufacturer) async {
    final m = manufacturer.toLowerCase();
    final attempts = <_OemIntent>[];
    if (_xiaomi.any(m.contains)) attempts.addAll(_xiaomiIntents);
    if (_oppo.any(m.contains)) attempts.addAll(_oppoIntents);
    if (_vivo.any(m.contains)) attempts.addAll(_vivoIntents);
    if (_oneplus.any(m.contains)) attempts.addAll(_oneplusIntents);
    if (_samsung.any(m.contains)) attempts.addAll(_samsungIntents);
    if (_huawei.any(m.contains)) attempts.addAll(_huaweiIntents);
    if (_asus.any(m.contains)) attempts.addAll(_asusIntents);

    for (final intent in attempts) {
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: intent.pkg,
          componentName: intent.cls,
        ).launch();
        return;
      } catch (_) {/* try next */}
    }

    await AppSettings.openAppSettings(
      type: AppSettingsType.batteryOptimization,
    );
  }
}

class OemGuide {
  final String label;
  final List<String> steps;
  const OemGuide(this.label, this.steps);
}

class _OemIntent {
  final String pkg;
  final String cls;
  const _OemIntent(this.pkg, this.cls);
}

// ─────── Brand keyword groups ───────
const _xiaomi = ['xiaomi', 'redmi', 'poco'];
const _oppo = ['oppo', 'realme'];
const _vivo = ['vivo', 'iqoo'];
const _oneplus = ['oneplus', 'oneplus '];
const _samsung = ['samsung'];
const _huawei = ['huawei', 'honor'];
const _asus = ['asus'];

// ─────── OEM-specific intents ───────
const _xiaomiIntents = [
  _OemIntent('com.miui.securitycenter',
      'com.miui.permcenter.autostart.AutoStartManagementActivity'),
];
const _oppoIntents = [
  _OemIntent('com.coloros.safecenter',
      'com.coloros.safecenter.permission.startup.StartupAppListActivity'),
  _OemIntent('com.oppo.safe',
      'com.oppo.safe.permission.startup.StartupAppListActivity'),
];
const _vivoIntents = [
  _OemIntent('com.iqoo.secure',
      'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity'),
  _OemIntent('com.vivo.permissionmanager',
      'com.vivo.permissionmanager.activity.BgStartUpManagerActivity'),
];
const _oneplusIntents = [
  _OemIntent('com.oneplus.security',
      'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity'),
];
const _samsungIntents = [
  _OemIntent('com.samsung.android.lool',
      'com.samsung.android.sm.ui.battery.BatteryActivity'),
];
const _huaweiIntents = [
  _OemIntent('com.huawei.systemmanager',
      'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity'),
  _OemIntent('com.huawei.systemmanager',
      'com.huawei.systemmanager.optimize.process.ProtectActivity'),
];
const _asusIntents = [
  _OemIntent('com.asus.mobilemanager',
      'com.asus.mobilemanager.entry.FunctionActivity'),
];

// ─────── Per-OEM step-by-step text ───────
const _xiaomiGuide = OemGuide(
  'Xiaomi / Redmi / POCO (MIUI)',
  [
    'Tap "Open settings" below.',
    'Find FolioMed in the Autostart list and turn it ON.',
    'Go back to Settings → Apps → Manage apps → FolioMed.',
    'Battery saver: pick "No restrictions".',
    'Other permissions: enable "Show on lock screen" and "Display pop-up while running in background".',
  ],
);

const _oppoGuide = OemGuide(
  'OPPO / Realme (ColorOS)',
  [
    'Tap "Open settings" below.',
    'In the Startup Manager, switch FolioMed ON.',
    'Then go to Settings → Battery → App Battery Management → FolioMed → Allow background activity.',
    'Settings → Privacy permissions → Floating windows → enable FolioMed.',
  ],
);

const _vivoGuide = OemGuide(
  'Vivo / iQOO (Funtouch / OriginOS)',
  [
    'Tap "Open settings" below.',
    'In Background app refresh, switch FolioMed ON.',
    'iManager → Battery → Background power consumption → allow FolioMed.',
    'Settings → More settings → Permission management → Autostart → FolioMed ON.',
  ],
);

const _oneplusGuide = OemGuide(
  'OnePlus (OxygenOS)',
  [
    'Tap "Open settings" below.',
    'Add FolioMed to the autostart whitelist.',
    'Then Settings → Battery → Battery optimization → FolioMed → Don\'t optimize.',
    'Settings → Apps → FolioMed → Battery → Allow background activity.',
  ],
);

const _samsungGuide = OemGuide(
  'Samsung (One UI)',
  [
    'Tap "Open settings" below.',
    'Settings → Apps → FolioMed → Battery.',
    'Pick "Unrestricted".',
    'Device care → Battery → Background usage limits → Never sleeping apps → Add FolioMed.',
  ],
);

const _huaweiGuide = OemGuide(
  'Huawei / Honor (EMUI / Magic UI)',
  [
    'Tap "Open settings" below.',
    'In Startup management, switch FolioMed OFF the auto-toggle, then turn ON Auto-launch, Secondary launch, and Run in background.',
    'Settings → Battery → App launch → FolioMed → set all three switches manually.',
  ],
);

const _asusGuide = OemGuide(
  'ASUS (ZenUI)',
  [
    'Tap "Open settings" below.',
    'In Mobile Manager → Auto-start manager, allow FolioMed.',
    'Settings → Battery → PowerMaster → Auto-start manager → FolioMed ON.',
  ],
);

const _genericGuide = OemGuide(
  'Stock Android',
  [
    'Tap "Open settings" below.',
    'Pick "Don\'t optimize" so Android lets FolioMed run in the background.',
    'Settings → Apps → FolioMed → enable "Allow background activity" if you see it.',
  ],
);
