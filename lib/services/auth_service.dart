import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/app_user.dart';
import 'supabase_service.dart';

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
     defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.linux);

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client}) : _client = client ?? supabase;

  GoTrueClient get _auth => _client.auth;

  SupabaseQueryBuilder get _profiles => _client.from(Tables.profiles);

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  User? get authUser => _auth.currentUser;

  GoogleSignIn get _google => GoogleSignIn(
        clientId: (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) &&
                SupabaseConfig.googleIosClientId.isNotEmpty
            ? SupabaseConfig.googleIosClientId
            : null,
        serverClientId: SupabaseConfig.googleWebClientId,
      );

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

  Future<AppUser?> signIn(String email, String password) async {
    final res = await _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final uid = res.user?.id;
    if (uid == null) return null;
    return _fetchProfileWithRetry(uid);
  }

  /// Creates the auth account. `name`, `role` and `ward_id` travel as user
  /// metadata; the `handle_new_user` trigger turns them into a profile row.
  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? wardId,
  }) async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: kIsWeb ? null : SupabaseConfig.authRedirectUrl,
      data: {
        'name': name,
        'role': role,
        'ward_id': wardId ?? '',
      },
    );
    final user = res.user;
    if (user == null) return null;
    if (res.session == null) {
      // Email confirmation is enabled in Supabase Auth settings.
      throw const AuthException(
        'Check your inbox to confirm your email, then sign in.',
        code: 'email_not_confirmed',
      );
    }
    return _fetchProfileWithRetry(user.id);
  }

  Future<AppUser?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: full-page redirect; the session is restored on return and the
      // splash screen routes the user from there.
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        // Return to wherever the app is served (e.g. /app/), not the site root.
        redirectTo: '${Uri.base.origin}${Uri.base.path}',
      );
      return null;
    }
    final googleUser = await _google.signIn();
    if (googleUser == null) return null; // cancelled
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw const AuthException(
        'Google did not return an ID token. Check GOOGLE_WEB_CLIENT_ID.',
        code: 'google_no_id_token',
      );
    }
    final res = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
    final uid = res.user?.id;
    if (uid == null) return null;
    return _fetchProfileWithRetry(uid);
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

  /// Sends a password-reset email via Supabase Auth. Delivery goes through
  /// the custom SMTP configured in the Supabase dashboard (Resend).
  /// Supabase never reveals whether the address is registered.
  Future<void> sendPasswordReset(String email) async {
    await _auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: kIsWeb ? null : SupabaseConfig.authRedirectUrl,
    );
  }

  /// Re-checks the password for a sensitive action (account deletion).
  Future<void> reauthenticate(String password) async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthException('No email on this account.');
    }
    await _auth.signInWithPassword(email: email, password: password);
  }

  /// Permanently deletes the signed-in account and everything it owns
  /// (cascades in Postgres via `delete_my_account`).
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    await signOut();
  }

  Future<void> signOut() async {
    if (!_isDesktop && !kIsWeb) {
      try {
        await _google.signOut();
      } catch (e) {
        debugPrint('Google sign-out skipped: $e');
      }
    }
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
