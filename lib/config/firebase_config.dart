import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase is used only for push (FCM). Values come from env.json at
/// build time (see docs/PUSH_SETUP.md); without them push is simply off
/// and the app falls back to on-device reminder notifications.
class FirebaseConfig {
  FirebaseConfig._();

  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  /// Options for this platform, or null when push isn't configured / supported.
  static FirebaseOptions? get options {
    if (kIsWeb || _projectId.isEmpty || _senderId.isEmpty) return null;
    if (Platform.isAndroid && _androidApiKey.isNotEmpty && _androidAppId.isNotEmpty) {
      return const FirebaseOptions(
        apiKey: _androidApiKey,
        appId: _androidAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
      );
    }
    if (Platform.isIOS && _iosApiKey.isNotEmpty && _iosAppId.isNotEmpty) {
      return const FirebaseOptions(
        apiKey: _iosApiKey,
        appId: _iosAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        iosBundleId: 'com.foliomed.app',
      );
    }
    return null;
  }
}
