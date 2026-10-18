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

  Future<bool> signIn(String email, String password) async {
    _error = null;
    _setLoading(true);
    try {
      final user = await _authService.signIn(email, password);
      _currentUser = user;
      _setLoading(false);
      return user != null;
    } catch (e) {
      debugPrint('AUTH ERROR FULL: $e');
      debugPrint('AUTH ERROR TYPE: ${e.runtimeType}');
      _error = e;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? wardId,
  }) async {
    _error = null;
    _setLoading(true);
    try {
      final user = await _authService.registerUser(
        name: name,
        email: email,
        password: password,
        role: role,
        wardId: wardId,
      );
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

  Future<bool> sendPasswordReset(String email) async {
    _error = null;
    try {
      await _authService.sendPasswordReset(email);
      return true;
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
      );
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) return 'No account with that email';
    if (msg.contains('wrong-password')) return 'Wrong password';
    // Firebase Email Enumeration Protection collapses wrong-password +
    // user-not-found into this single code to prevent account probing.
    if (msg.contains('invalid-credential') ||
        msg.contains('invalid-login-credentials')) {
      return 'Email or password is incorrect';
    }
    if (msg.contains('invalid-email')) return 'Invalid email';
    if (msg.contains('email-already-in-use')) {
      return 'That email is already registered. Switch to Sign In.';
    }
    if (msg.contains('weak-password')) return 'Password too weak';
    if (msg.contains('network-request-failed')) return 'Network error';
    return msg.replaceFirst('[firebase_auth/', '').replaceFirst(']', ': ');
  }
}
