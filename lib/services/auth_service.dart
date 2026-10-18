import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../utils/app_constants.dart';
import 'metrics_service.dart';

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
     defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.linux);

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get firebaseUser => _auth.currentUser;

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<AppUser?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null) return null;
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? wardId,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return null;

    await user.updateDisplayName(name);

    final now = DateTime.now();
    final data = {
      'name': name,
      'email': email.trim(),
      'role': role,
      'wardId': wardId ?? '',
      'wardIds': wardId != null && wardId.isNotEmpty ? [wardId] : <String>[],
      'avatarUrl': null,
      'createdAt': Timestamp.fromDate(now),
    };
    await _users.doc(user.uid).set(data);
    MetricsService.bump('user', summary: 'New account: $name');

    final doc = await _users.doc(user.uid).get();
    return AppUser.fromFirestore(doc);
  }

  Future<AppUser?> signInWithGoogle() async {
    try {
      UserCredential cred;
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        cred = await _auth.signInWithPopup(googleProvider);
      } else {
        final googleUser = await GoogleSignIn(
          clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
        ).signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        cred = await _auth.signInWithCredential(credential);
      }
      final user = cred.user;
      if (user == null) return null;

      final doc = await _users.doc(user.uid).get();
      if (!doc.exists) {
        final now = DateTime.now();
        final displayName =
            user.displayName ?? (user.email ?? 'User').split('@').first;
        await _users.doc(user.uid).set({
          'name': displayName,
          'email': user.email ?? '',
          'role': 'doctor',
          'wardId': '',
          'wardIds': <String>[],
          'avatarUrl': user.photoURL,
          'createdAt': Timestamp.fromDate(now),
        });
        // First-time Google sign-in is also a new account → bump userCount
        // so the public dashboard tally stays honest.
        MetricsService.bump('user',
            summary: 'New Google account: $displayName');
      }
      final fresh = await _users.doc(user.uid).get();
      return AppUser.fromFirestore(fresh);
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with Apple — iOS-only. Apple App Review rejects apps that
  /// offer third-party social sign-in (Google, in our case) but not
  /// Apple Sign-In, so this exists purely to satisfy that requirement
  /// on iOS. Android raises a runtime error if called there.
  Future<AppUser?> signInWithApple() async {
    if (kIsWeb) {
      throw UnsupportedError('Sign in with Apple is not available on web.');
    }
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError('Sign in with Apple requires iOS or macOS.');
    }
    // Firebase verifies Apple Sign-In with a nonce to block replay attacks:
    //  1. generate a random rawNonce
    //  2. send its SHA-256 hash to Apple (baked into the returned idToken)
    //  3. hand the RAW nonce to Firebase, which re-hashes it and compares.
    // Skipping this makes Firebase reject the credential with
    // `invalid-credential` — which the UI then mislabels as a wrong
    // email/password. The nonce flow is mandatory, not optional.
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final oauth = OAuthProvider('apple.com').credential(
      idToken: credential.identityToken,
      rawNonce: rawNonce,
      // Apple only sends email on the FIRST grant, so a display name is
      // synthesised below if it comes back null on later sign-ins.
    );
    final cred = await _auth.signInWithCredential(oauth);
    final user = cred.user;
    if (user == null) return null;

    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) {
      final now = DateTime.now();
      final composed = [
        credential.givenName ?? '',
        credential.familyName ?? '',
      ].where((s) => s.isNotEmpty).join(' ').trim();
      final displayName = composed.isNotEmpty
          ? composed
          : (user.displayName ??
              (user.email ?? 'Apple user').split('@').first);
      await _users.doc(user.uid).set({
        'name': displayName,
        'email': user.email ?? credential.email ?? '',
        'role': 'doctor',
        'wardId': '',
        'wardIds': <String>[],
        'avatarUrl': user.photoURL,
        'createdAt': Timestamp.fromDate(now),
      });
      MetricsService.bump('user',
          summary: 'New Apple account: $displayName');
    }
    final fresh = await _users.doc(user.uid).get();
    return AppUser.fromFirestore(fresh);
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

  /// Sends a branded password-reset email via our Cloud Function + Resend.
  ///
  /// Firebase's built-in delivery (noreply@foliomed.firebaseapp.com)
  /// is silently dropped by many providers, so we generate the reset link
  /// with the Admin SDK and hand delivery to Resend.
  ///
  /// The Cloud Function always returns 200 regardless of whether the address
  /// is registered — we intentionally never reveal that to callers either.
  Future<void> sendPasswordReset(String email) async {
    const url =
        'https://us-central1-foliomed.cloudfunctions.net/sendPasswordResetEmail';
    await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: '{"email":"${email.trim().toLowerCase()}"}',
    );
    // We don't check the response body — the function always returns ok:true.
    // The caller shows a neutral "check your inbox" message.
  }

  Future<void> signOut() async {
    if (!_isDesktop) {
      try {
        await GoogleSignIn(
          clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
        ).signOut();
      } catch (_) {}
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
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (avatarEmoji != null) updates['avatarEmoji'] = avatarEmoji;
    if (specialty != null) updates['specialty'] = specialty;
    if (updates.isEmpty) return;
    await _users.doc(user.uid).update(updates);
    if (name != null) {
      await user.updateDisplayName(name);
    }
  }

  Stream<AppUser?> userStream(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromFirestore(doc) : null,
        );
  }
}
