import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/account_service.dart';
import '../services/push_registration.dart';

/// The signed-in person: sign-in and sign-out, their profile, and their
/// one-time role choice. Screens read [currentUser]; failures land in
/// [error] for the UI to explain.
class AccountProvider extends ChangeNotifier {
  AccountProvider({AccountService? service}) : _service = service ?? AccountService();

  final AccountService _service;

  AppUser? _user;
  bool _busy = false;
  Object? _error;

  AppUser? get currentUser => _user;
  bool get isLoading => _busy;
  Object? get error => _error;

  /// Runs an account step with the busy flag and error capture.
  Future<bool> _step(Future<AppUser?> Function() op, {bool showBusy = true}) async {
    _error = null;
    if (showBusy) {
      _busy = true;
      notifyListeners();
    }
    try {
      _user = await op();
      return _user != null;
    } catch (e) {
      debugPrint('Account: $e');
      _error = e;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() => _step(_service.signInWithGoogle);

  /// iOS only (App Store rule: offered whenever Google is).
  Future<bool> signInWithApple() => _step(_service.signInWithApple);

  Future<void> loadCurrentUser() => _step(_service.getCurrentUser);

  /// Doctor or nurse, chosen once after first sign-in.
  Future<bool> confirmRole(UserRole role) =>
      _step(() => _service.confirmRole(role.name), showBusy: false);

  /// Saves profile changes; returns false (with [error]) if they didn't save.
  Future<bool> updateProfile({String? name, String? avatarUrl, String? avatarEmoji, String? specialty}) async {
    _error = null;
    try {
      await _service.updateProfile(
          name: name, avatarUrl: avatarUrl, avatarEmoji: avatarEmoji, specialty: specialty);
      _user = _user?.copyWith(
          name: name, avatarUrl: avatarUrl, avatarEmoji: avatarEmoji, specialty: specialty);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await PushRegistration.instance.unregister();
    await _service.signOut();
    _user = null;
    notifyListeners();
  }
}
