import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';
import 'supabase_service.dart';

/// Registers this device for server push (FCM) and keeps the token fresh.
///
/// Push is "live" only when both sides are ready: Firebase is configured in
/// the build AND the server has switched `push_enabled` on. Until then
/// [isLive] stays false and reminders keep using local notifications.
class PushRegistration {
  PushRegistration._();
  static final PushRegistration instance = PushRegistration._();

  bool _firebaseReady = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  /// True when server push will deliver alerts to this device.
  final ValueNotifier<bool> isLive = ValueNotifier(false);

  Future<void> initFirebase() async {
    final options = FirebaseConfig.options;
    if (options == null || _firebaseReady) return;
    try {
      await Firebase.initializeApp(options: options);
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase init failed (push off): $e');
    }
  }

  /// Call after sign-in. Safe to call repeatedly.
  Future<void> register() async {
    if (!_firebaseReady || supabase.auth.currentUser == null) return;
    try {
      final serverOn = await supabase.rpc('push_enabled') == true;
      if (!serverOn) {
        isLive.value = false;
        return;
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        isLive.value = false;
        return;
      }
      if (Platform.isIOS && await messaging.getAPNSToken() == null) {
        // APNs hands out its token a moment after launch; try again shortly.
        await Future<void>.delayed(const Duration(seconds: 3));
        if (await messaging.getAPNSToken() == null) return;
      }
      final token = await messaging.getToken();
      if (token == null) return;
      await _save(token);
      _refreshSub ??= messaging.onTokenRefresh.listen(_save);
      isLive.value = true;
    } catch (e) {
      debugPrint('Push registration failed: $e');
      isLive.value = false;
    }
  }

  Future<void> _save(String token) async {
    _token = token;
    await supabase.rpc('register_push_token', params: {
      'p_token': token,
      'p_platform': Platform.isIOS ? 'ios' : 'android',
    });
  }

  /// Call before sign-out so the next person on this phone doesn't get
  /// the previous user's alerts.
  Future<void> unregister() async {
    final token = _token;
    isLive.value = false;
    if (token == null) return;
    try {
      await supabase.rpc('unregister_push_token', params: {'p_token': token});
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
  }
}
