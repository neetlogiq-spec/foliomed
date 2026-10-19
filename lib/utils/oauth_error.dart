/// Reads an OAuth error that Supabase appends to the return URL
/// (`?error=…&error_description=…`, or in the `#` fragment) and turns it
/// into a short message for the user. Returns null when there is none.
String? oauthErrorMessage(Uri uri) {
  final params = <String, String>{
    ...uri.queryParameters,
    ..._fragmentParams(uri.fragment),
  };
  final error = params['error'];
  if (error == null || error.isEmpty) return null;
  final code = params['error_code'] ?? '';
  final description = (params['error_description'] ?? '').toLowerCase();
  if (error == 'access_denied' || code == 'access_denied') {
    return 'Google sign-in was cancelled.';
  }
  if (description.contains('exchange external code')) {
    return "Google sign-in couldn't be completed. Please try again — "
        'if it keeps failing, use email sign-in for now.';
  }
  return "Sign-in didn't complete. Please try again.";
}

/// Fragment-style params, e.g. `#error=…` or `#/login?error=…`.
Map<String, String> _fragmentParams(String fragment) {
  final q = fragment.indexOf('?');
  final raw = q >= 0 ? fragment.substring(q + 1) : fragment;
  if (!raw.contains('=')) return const {};
  try {
    return Uri.splitQueryString(raw);
  } on FormatException {
    return const {};
  }
}
