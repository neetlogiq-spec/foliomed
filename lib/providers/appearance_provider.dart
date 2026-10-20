import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';

enum Appearance {
  automatic('Automatic'),
  light('Light'),
  dark('Dark');

  const Appearance(this.label);
  final String label;
}

/// Light / dark / follow the phone, plus an extra text-size step on top of
/// the phone's own text size (never instead of it).
class AppearanceProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppearanceProvider() {
    WidgetsBinding.instance.addObserver(this);
    _syncColors();
  }

  static const _appearanceKey = 'appearance_v1';
  static const _textKey = 'extra_text_scale_v1';

  /// Extra text size on top of the system setting: 100% – 140%.
  static const double minExtra = 1.0;
  static const double maxExtra = 1.4;
  static const double extraStep = 0.1;

  Appearance _appearance = Appearance.automatic;
  double _extra = 1.0;

  Appearance get appearance => _appearance;
  double get extraTextScale => _extra;

  ThemeMode get themeMode => switch (_appearance) {
        Appearance.automatic => ThemeMode.system,
        Appearance.light => ThemeMode.light,
        Appearance.dark => ThemeMode.dark,
      };

  bool get isDark => switch (_appearance) {
        Appearance.automatic =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
        Appearance.light => false,
        Appearance.dark => true,
      };

  // Static colour getters read this flag.
  void _syncColors() => AppColors.isDark = isDark;

  @override
  void didChangePlatformBrightness() {
    if (_appearance != Appearance.automatic) return;
    _syncColors();
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_appearanceKey);
      _appearance = Appearance.values.firstWhere((a) => a.name == saved, orElse: () => Appearance.automatic);
      final extra = prefs.getDouble(_textKey);
      if (extra != null) _extra = extra.clamp(minExtra, maxExtra);
    } catch (_) {}
    _syncColors();
    notifyListeners();
  }

  Future<void> setAppearance(Appearance a) async {
    _appearance = a;
    _syncColors();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_appearanceKey, a.name);
    } catch (_) {}
  }

  Future<void> setExtraTextScale(double v) async {
    final next = v.clamp(minExtra, maxExtra).toDouble();
    if ((next - _extra).abs() < 0.001) return;
    _extra = next;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setDouble(_textKey, _extra);
    } catch (_) {}
  }

  /// The phone's text scaler with FolioMed's extra step applied.
  TextScaler scalerOver(TextScaler system) =>
      _extra == 1.0 ? system : TextScaler.linear(system.scale(1) * _extra);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
