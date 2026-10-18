import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextScaleProvider extends ChangeNotifier {
  static const _prefKey = 'text_scale';

  /// Range: 1.0 (100%) → 1.5 (150%). Default 1.0.
  double _scale = 1.0;
  double get scale => _scale;

  static const double minScale = 1.0;
  static const double maxScale = 1.5;
  static const double step = 0.1;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_prefKey);
    if (v != null && v >= minScale && v <= maxScale) {
      _scale = v;
      notifyListeners();
    }
  }

  Future<void> setScale(double value) async {
    final clamped = value.clamp(minScale, maxScale);
    if ((_scale - clamped).abs() < 0.001) return;
    _scale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKey, _scale);
  }
}
