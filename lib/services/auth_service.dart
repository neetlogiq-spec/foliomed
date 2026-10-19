import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/app_user.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client}) : _client = client ?? supabase;

  GoTrueClient get _auth => _client.auth;

  SupabaseQueryBuilder get _profiles => _client.from(Tables.profiles);

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  User? get authUser => _auth.currentUser;

  /// How long to wait for the OAuth browser round-trip to finish.
  static const Duration _oauthTimeout = Duration(minutes: 5);

  /// After the app returns to the foreground without a session, the user
  /// most likely closed the browser — give the deep link this long to land.
  static const Duration _oauthResumeGrace = Duration(seconds: 3);

  Future<AppUser?> _fetchProfile(String uid) async {
    final row = await _profiles.select().eq('id', uid).maybeSingle();
    return row == null ? null : AppUser.fromRow(row);
  }

  /// The profile row is created by a database trigger right after sign-up.
  /// A brand-new OAuth user can race that trigger, so retry briefly.
  Future<AppUser?> _fetchProfileWithRetry(String uid) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final user = await _fetchProfile(uid);
      if (user != null) return user;
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
    return null;
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  /// Google sign-in through Supabase's hosted OAuth flow (the Google
  /// provider is configured in the Supabase dashboard).
  ///
  /// Web: full-page redirect — the session is restored when the browser
  /// comes back and the splash screen routes from there, so this returns
  /// null. Mobile/desktop: opens the system browser, then waits for the
  /// `com.foliomed.app://login-callback` deep link to deliver the session.
  /// Returns null if the user abandons the browser.
  Future<AppUser?> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        // Return to wherever the app is served (e.g. /app/), not the site root.
        redirectTo: '${Uri.base.origin}${Uri.base.path}',
      );
      return null;
    }

    final signedIn = Completer<Session?>();
    final authSub = _auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn &&
          state.session != null &&
          !signedIn.isCompleted) {
        signedIn.complete(state.session);
      }
    });
    final resumeWatcher = _ResumeWatcher(() {
      Future<void>.delayed(_oauthResumeGrace, () {
        if (!signedIn.isCompleted) signedIn.complete(null); // abandoned
      });
    });
    try {
      final launched = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) return null;
      final session = await signedIn.future
          .timeout(_oauthTimeout, onTimeout: () => null);
      if (session == null) return null;
      return await _fetchProfileWithRetry(session.user.id);
    } finally {
      resumeWatcher.dispose();
      await authSub.cancel();
    }
  }

  /// Sign in with Apple — iOS/macOS only. Apple App Review rejects apps
  /// that offer Google sign-in without Apple sign-in.
  Future<AppUser?> signInWithApple() async {
    if (kIsWeb) {
      throw UnsupportedError('Sign in with Apple is not available on web.');
    }
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError('Sign in with Apple requires iOS or macOS.');
    }
    // Nonce flow: Apple receives the SHA-256 hash (baked into the ID
    // token); Supabase receives the raw nonce, re-hashes and compares.
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple did not return an identity token.',
          code: 'apple_no_id_token');
    }
    final res = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    final uid = res.user?.id;
    if (uid == null) return null;

    // Apple only sends the name on the FIRST grant — store it if we got it.
    final composed = [credential.givenName ?? '', credential.familyName ?? '']
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();
    final profile = await _fetchProfileWithRetry(uid);
    if (profile != null && composed.isNotEmpty && profile.name != composed) {
      await _profiles.update({'name': composed}).eq('id', uid);
      return _fetchProfile(uid);
    }
    return profile;
  }

  /// Cryptographically-random nonce for Apple Sign-In (see [signInWithApple]).
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// SHA-256 hash of [input], lowercase hex — the form Apple expects.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// One-time doctor/nurse choice after first sign-in (`confirm_my_role`).
  /// "admin" can never be self-assigned — the database rejects it.
  Future<AppUser?> confirmRole(String role) async {
    await _client.rpc('confirm_my_role', params: {'p_role': role});
    return getCurrentUser();
  }

  /// Admin-only: grant or change another user's role (`set_user_role`).
  Future<void> setUserRole(String userId, String role) async {
    await _client.rpc('set_user_role', params: {
      'p_user': userId,
      'p_role': role,
    });
  }

  /// Permanently deletes the signed-in account and everything it owns
  /// (cascades in Postgres via `delete_my_account`).
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    await signOut();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? avatarEmoji,
    String? specialty,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (specialty != null) 'specialty': specialty,
    };
    if (updates.isEmpty) return;
    await _profiles.update(updates).eq('id', user.id);
  }

  Stream<AppUser?> userStream(String uid) {
    return _profiles
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : AppUser.fromRow(rows.first));
  }
}

/// Calls [onResumed] whenever the app comes back to the foreground.
class _ResumeWatcher with WidgetsBindingObserver {
  final VoidCallback onResumed;

  _ResumeWatcher(this.onResumed) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
