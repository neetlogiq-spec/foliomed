/// Translates raw Firebase / Firestore / FlutterFire / network exceptions
/// into short, plain-English messages the user can act on. Anything that
/// hits the UI must go through this helper so we never leak "firestore",
/// "firebase", "cloud_firestore" wording into the front end.
String friendlyError(Object e) {
  final raw = e.toString();
  final lower = raw.toLowerCase();

  // ── Keychain (macOS) ──
  if (lower.contains('keychain') || lower.contains('keychainerror') || lower.contains('-34018')) {
    return 'macOS Keychain error. Please quit the app completely (Cmd+Q) and relaunch — a one-time keychain reset will run on next start.';
  }

  // ── Permission / auth ──
  if (lower.contains('permission-denied') ||
      lower.contains('insufficient permissions')) {
    return "You don't have permission to do that.";
  }
  if (lower.contains('unauthenticated')) {
    return 'Please sign in again.';
  }
  if (lower.contains('user-not-found')) {
    return 'No account exists with that email.';
  }
  if (lower.contains('wrong-password')) {
    return 'That password is incorrect.';
  }
  // Firebase Email Enumeration Protection merges wrong-password +
  // user-not-found into a single generic code to prevent account probing.
  if (lower.contains('invalid-credential') ||
      lower.contains('invalid-login-credentials')) {
    return 'Email or password is incorrect. Please check and try again.';
  }
  if (lower.contains('invalid-email')) {
    return 'That email address looks invalid.';
  }
  if (lower.contains('email-already-in-use')) {
    return 'That email is already registered.';
  }
  if (lower.contains('weak-password')) {
    return 'Password is too weak — pick something longer.';
  }
  if (lower.contains('requires-recent-login')) {
    return 'Please sign out and back in, then try again.';
  }
  if (lower.contains('admin-restricted-operation')) {
    return 'This sign-in method is not enabled.';
  }
  if (lower.contains('account-exists-with-different-credential')) {
    return 'This email is already linked to another sign-in method.';
  }

  // ── Network / availability ──
  if (lower.contains('network-request-failed') ||
      lower.contains('failed-precondition') ||
      lower.contains('unavailable') ||
      lower.contains('socketexception') ||
      lower.contains('timed out')) {
    return "We can't reach the server right now. Check your internet and try again.";
  }
  if (lower.contains('cancelled')) {
    return 'Action cancelled.';
  }

  // ── Quotas ──
  if (lower.contains('resource-exhausted') ||
      lower.contains('quota')) {
    return 'The service is busy right now. Try again in a minute.';
  }

  // ── Validation ──
  if (lower.contains('invalid-argument') ||
      lower.contains('not-found')) {
    return 'That item could not be found.';
  }

  // ── Anything else: scrub vendor wording, keep a short message ──
  String cleaned = raw
      .replaceAll(RegExp(r'\[firebase[^\]]*\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[cloud_firestore[^\]]*\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'firebase', caseSensitive: false), '')
      .replaceAll(RegExp(r'firestore', caseSensitive: false), '')
      .replaceAll('Exception:', '')
      .replaceAll('Error:', '')
      .trim();
  if (cleaned.isEmpty) {
    return 'Something went wrong. Please try again.';
  }
  return cleaned;
}
