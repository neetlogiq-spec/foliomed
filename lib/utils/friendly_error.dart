import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

/// Turns an exception into one short sentence a clinician can act on.
/// Every error shown in the UI goes through here, so database and network
/// jargon never reaches the screen.
String friendlyError(Object e) {
  if (e is PostgrestException) return _database(e);
  if (e is AuthException) return _signIn(e);
  final text = e.toString().toLowerCase();
  if (_offline.any(text.contains)) {
    return 'FolioMed can’t reach the server. Check your connection and try again.';
  }
  if (text.contains('payload too large') || text.contains('maximum allowed size')) {
    return 'That photo is too large to upload.';
  }
  if (e is FormatException && e.message.isNotEmpty && e.message.length < 120) return e.message;
  if (text.contains('cancel')) return 'Cancelled.';
  if (e is String && e.trim().isNotEmpty && e.length < 120) return e;
  return 'That didn’t work. Please try again.';
}

const _offline = [
  'socketexception',
  'clientexception',
  'failed host lookup',
  'connection refused',
  'connection closed',
  'network is unreachable',
  'timed out',
  'timeoutexception',
];

String _database(PostgrestException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('last admin')) return 'FolioMed needs at least one admin, so this role can’t be removed.';
  if (msg.contains('admin only') || msg.contains('only an admin')) return 'Only an admin can do that.';
  switch (e.code) {
    case '42501':
      return 'You don’t have access to that — you may no longer be a member of this ward.';
    case '23505':
      return 'That already exists.';
    case '23503':
    case 'P0002':
    case 'PGRST116':
      return 'That item is no longer available.';
    case '23514':
      return 'One of the values is outside the allowed range.';
    case '22023':
    case 'P0001':
      // Our own functions raise readable reasons ("set the date and time
      // of birth first"); pass those through, capitalised.
      final m = e.message.trim();
      return m.isEmpty ? 'That isn’t allowed.' : '${m[0].toUpperCase()}${m.substring(1)}.';
  }
  if (e.code != null && e.code!.startsWith('PGRST3')) return 'You’ve been signed out. Sign in to carry on.';
  return 'That couldn’t be saved. Please try again.';
}

String _signIn(AuthException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('rate') || e.statusCode == '429') return 'Too many attempts — wait a minute and try again.';
  if (msg.contains('expired') || msg.contains('jwt')) return 'You’ve been signed out. Sign in to carry on.';
  if (msg.contains('provider') && msg.contains('not enabled')) return 'That sign-in option isn’t switched on yet.';
  if (msg.contains('cancel')) return 'Sign-in was cancelled.';
  return 'Signing in didn’t work. Please try again.';
}
