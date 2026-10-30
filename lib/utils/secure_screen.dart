import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording while clinical photos are on
/// screen. Android only (FLAG_SECURE in MainActivity); iOS and web can't
/// block them, so the UI relies on the consent wording there.
class SecureScreen {
  SecureScreen._();
  static const _channel = MethodChannel('com.foliomed.app/secure');
  static int _holders = 0;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Nested callers are counted; the flag clears when the last one leaves.
  static Future<void> enter() async {
    _holders++;
    if (_holders == 1) await _set(true);
  }

  static Future<void> leave() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _set(false);
  }

  static Future<void> _set(bool on) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } on MissingPluginException {
      // Older build without the channel: nothing to do.
    } on PlatformException {
      // Never let this break the screen.
    }
  }
}
