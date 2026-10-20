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

/// Sign-in, the profile row, role changes and account deletion, on
/// Supabase Auth. Only Google and Apple — FolioMed stores no passwords.
class AccountService {
  AccountService({SupabaseClient? client}) : _db = client ?? supabase;

  final SupabaseClient _db;
  GoTrueClient get _auth => _db.auth;
  SupabaseQueryBuilder get _profiles => _db.from(Tables.profiles);

  /// Upper bound for the browser round-trip on mobile.
  static const _browserLimit = Duration(minutes: 5);

  /// If the app returns to the foreground with no session, the person
  /// probably closed the browser; allow this long for a late deep link.
  static const _lateLinkGrace = Duration(seconds: 3);

  Future<AppUser?> _profile(String uid) async {
    final row = await _profiles.select().eq('id', uid).maybeSingle();
    return row == null ? null : AppUser.fromRow(row);
  }

  /// A new account's profile row is written by a trigger moments after
  /// sign-up, so a first sign-in may need to wait for it.
  Future<AppUser?> _profileOnceReady(String uid) async {
    const waits = [0, 300, 600, 900, 1200];
    for (final ms in waits) {
      if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
      final p = await _profile(uid);
      if (p != null) return p;
    }
    return null;
  }

  Future<AppUser?> getCurrentUser() async {
    final uid = _auth.currentUser?.id;
    return uid == null ? null : _profile(uid);
  }

  /// Google, through Supabase's hosted OAuth. On the web the page
  /// redirects away (returns null; the session is picked up on return).
  /// On phones the system browser opens and the session arrives through
  /// the `com.foliomed.app://login-callback` deep link.
  Future<AppUser?> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithOAuth(OAuthProvider.google, redirectTo: '${Uri.base.origin}${Uri.base.path}');
      return null;
    }
    final session = await _awaitBrowserSignIn(() => _auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: SupabaseConfig.authRedirectUrl,
          authScreenLaunchMode: LaunchMode.externalApplication,
        ));
    return session == null ? null : _profileOnceReady(session.user.id);
  }

  /// Opens the browser via [open] and resolves with the new session, or
  /// null if the person gives up (comes back without signing in).
  Future<Session?> _awaitBrowserSignIn(Future<bool> Function() open) async {
    final done = Completer<Session?>();
    void finish(Session? s) {
      if (!done.isCompleted) done.complete(s);
    }

    final sub = _auth.onAuthStateChange.listen((change) {
      if (change.event == AuthChangeEvent.signedIn) finish(change.session);
    });
    final watcher = _ForegroundWatcher(() => Future.delayed(_lateLinkGrace, () => finish(null)));
    try {
      if (!await open()) return null;
      return await done.future.timeout(_browserLimit, onTimeout: () => null);
    } finally {
      watcher.dispose();
      await sub.cancel();
    }
  }

  /// Apple, on iPhone only (App Store rule: required alongside Google).
  /// Apple signs a hash of a one-time secret; Supabase checks it against
  /// the secret itself.
  Future<AppUser?> signInWithApple() async {
    if (kIsWeb || !Platform.isIOS) {
      throw UnsupportedError('Sign in with Apple is only offered on iPhone.');
    }
    final secret = _oneTimeSecret();
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: sha256.convert(utf8.encode(secret)).toString(),
    );
    final token = apple.identityToken;
    if (token == null) {
      throw const AuthException('Apple sign-in returned no token.', code: 'apple_no_id_token');
    }
    final res = await _auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: token, nonce: secret);
    final uid = res.user?.id;
    if (uid == null) return null;
    final me = await _profileOnceReady(uid);
    // Apple shares the person's name only on their very first sign-in.
    final given = '${apple.givenName ?? ''} ${apple.familyName ?? ''}'.trim();
    if (me != null && given.isNotEmpty && me.name != given) {
      await _profiles.update({'name': given}).eq('id', uid);
      return me.copyWith(name: given);
    }
    return me;
  }

  /// 32 random bytes, URL-safe base64 — the sign-in nonce.
  static String _oneTimeSecret() {
    final rng = Random.secure();
    return base64Url.encode([for (var i = 0; i < 32; i++) rng.nextInt(256)]).replaceAll('=', '');
  }

  /// Doctor or nurse, once (`confirm_my_role`; admin is refused).
  Future<AppUser?> confirmRole(String role) async {
    await _db.rpc('confirm_my_role', params: {'p_role': role});
    return getCurrentUser();
  }

  /// Admins only (`set_user_role`); the database keeps one admin.
  Future<void> setUserRole(String userId, String role) =>
      _db.rpc('set_user_role', params: {'p_user': userId, 'p_role': role});

  Future<void> updateProfile({String? name, String? avatarUrl, String? avatarEmoji, String? specialty}) async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;
    final changes = {
      'name': ?name,
      'avatar_url': ?avatarUrl,
      'avatar_emoji': ?avatarEmoji,
      'specialty': ?specialty,
    };
    if (changes.isNotEmpty) await _profiles.update(changes).eq('id', uid);
  }

  /// Erases the account and everything it owns (`delete_my_account`).
  Future<void> deleteAccount() async {
    await _db.rpc('delete_my_account');
    await signOut();
  }

  Future<void> signOut() => _auth.signOut();
}

/// Runs [onForeground] each time the app returns to the foreground.
class _ForegroundWatcher with WidgetsBindingObserver {
  _ForegroundWatcher(this.onForeground) {
    WidgetsBinding.instance.addObserver(this);
  }

  final VoidCallback onForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onForeground();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
