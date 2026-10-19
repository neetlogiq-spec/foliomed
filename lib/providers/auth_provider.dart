import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  AppUser? _currentUser;
  bool _isLoading = false;
  Object? _error;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isDoctor => _currentUser?.role == UserRole.doctor;
  bool get isNurse => _currentUser?.role == UserRole.nurse;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _error = null;
    _setLoading(true);
    try {
      final user = await _authService.signInWithGoogle();
      _currentUser = user;
      _setLoading(false);
      return user != null;
    } catch (e) {
      debugPrint('AUTH ERROR: $e (${e.runtimeType})');
      _error = e;
      _setLoading(false);
      return false;
    }
  }

  /// Sign in with Apple — iOS-only. Required by App Review whenever
  /// Google sign-in is offered.
  Future<bool> signInWithApple() async {
    _error = null;
    _setLoading(true);
    try {
      final user = await _authService.signInWithApple();
      _currentUser = user;
      _setLoading(false);
      return user != null;
    } catch (e) {
      debugPrint('AUTH ERROR: $e (${e.runtimeType})');
      _error = e;
      _setLoading(false);
      return false;
    }
  }

  /// One-time doctor/nurse choice after first sign-in.
  Future<bool> confirmRole(UserRole role) async {
    _error = null;
    try {
      _currentUser = await _authService.confirmRole(role.name);
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      debugPrint('AUTH ERROR: $e (${e.runtimeType})');
      _error = e;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> loadCurrentUser() async {
    _setLoading(true);
    try {
      _currentUser = await _authService.getCurrentUser();
    } catch (e) {
      debugPrint('AUTH ERROR: $e (${e.runtimeType})');
      _error = e;
    }
    _setLoading(false);
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? avatarEmoji,
    String? specialty,
  }) async {
    try {
      await _authService.updateProfile(
        name: name,
        avatarUrl: avatarUrl,
        avatarEmoji: avatarEmoji,
        specialty: specialty,
      );
    } catch (_) {}
    final current = _currentUser;
    if (current != null) {
      _currentUser = AppUser(
        uid: current.uid,
        name: name ?? current.name,
        email: current.email,
        role: current.role,
        wardId: current.wardId,
        wardIds: current.wardIds,
        avatarUrl: avatarUrl ?? current.avatarUrl,
        avatarEmoji: avatarEmoji ?? current.avatarEmoji,
        specialty: specialty ?? current.specialty,
        createdAt: current.createdAt,
        roleConfirmed: current.roleConfirmed,
      );
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }


}
