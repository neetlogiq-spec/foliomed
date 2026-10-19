import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

/// Translates raw Supabase / network exceptions into short, plain-English
/// messages the user can act on. Anything that hits the UI must go
/// through this helper so vendor wording never leaks into the front end.
String friendlyError(Object e) {
  final supabaseMessage = _supabaseMessage(e);
  if (supabaseMessage != null) return supabaseMessage;

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
  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid-credential') ||
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
      .replaceAll(RegExp(r'(Postgrest|Auth|Storage)Exception\([^)]*\)?'), '')
      .replaceAll(RegExp(r'supabase', caseSensitive: false), '')
      .replaceAll('Exception:', '')
      .replaceAll('Error:', '')
      .trim();
  if (cleaned.isEmpty) {
    return 'Something went wrong. Please try again.';
  }
  return cleaned;
}

/// Supabase errors carry structured codes — map the common ones first.
String? _supabaseMessage(Object e) {
  if (e is AuthException) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Email or password is incorrect. Please check and try again.';
      case 'user_already_exists':
      case 'email_exists':
        return 'That email is already registered. Switch to Sign In.';
      case 'weak_password':
        return 'Password is too weak — pick something longer.';
      case 'email_not_confirmed':
        return 'Please confirm your email first — check your inbox.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'validation_failed':
        return 'That email address looks invalid.';
      case 'provider_disabled':
        return 'This sign-in method is not enabled.';
    }
    return e.message.isEmpty ? null : e.message;
  }
  if (e is PostgrestException) {
    final message = e.message.toLowerCase();
    if (message.contains('last admin')) {
      return "You're the only admin — make someone else an admin first.";
    }
    if (message.contains('only an admin') || message.contains('admin only')) {
      return 'Only a ward admin can change roles.';
    }
    switch (e.code) {
      case '42501': // insufficient_privilege / row-level security
        return "You don't have permission to do that.";
      case '23505': // unique_violation
        return 'That already exists.';
      case '23503': // foreign_key_violation
        return 'That item no longer exists.';
      case 'PGRST116': // .single() found no rows
        return 'That item could not be found.';
    }
    return 'Something went wrong saving that. Please try again.';
  }
  return null;
}
