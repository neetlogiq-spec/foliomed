import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'a11y/reduce_transparency_stub.dart'
    if (dart.library.js_interop) 'a11y/reduce_transparency_web.dart';

/// OS accessibility settings Flutter's [MediaQuery] doesn't expose.
///
/// "Reduce Transparency" (iOS/macOS Settings → Accessibility, and the
/// `prefers-reduced-transparency` media query on the web): translucent
/// chrome must fall back to a solid surface when it's on.
class AccessibilitySettings {
  AccessibilitySettings._();

  static const MethodChannel _channel =
      MethodChannel('com.foliomed.app/accessibility');

  /// Listen to this to rebuild when the setting changes.
  static final ValueNotifier<bool> reduceTransparency = ValueNotifier(false);

  static bool get _isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Call once at startup (after `WidgetsFlutterBinding.ensureInitialized`).
  static Future<void> init() async {
    if (kIsWeb) {
      reduceTransparency.value = webPrefersReducedTransparency();
      return;
    }
    if (!_isApple) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'reduceTransparencyChanged') {
        reduceTransparency.value = call.arguments == true;
      }
    });
    await refresh();
  }

  /// Re-reads the setting (e.g. when the app returns to the foreground).
  static Future<void> refresh() async {
    if (kIsWeb) {
      reduceTransparency.value = webPrefersReducedTransparency();
      return;
    }
    if (!_isApple) return;
    try {
      final value = await _channel.invokeMethod<bool>('reduceTransparency');
      reduceTransparency.value = value ?? false;
    } on MissingPluginException {
      // Native side not registered (e.g. widget tests) — keep the default.
    } on PlatformException catch (e) {
      debugPrint('AccessibilitySettings: $e');
    }
  }
}
