/// Supabase connection settings, injected at build time:
///
///   flutter run --dart-define-from-file=env.json
///
/// `env.json` is gitignored; copy `env.example.json` and fill it in.
/// The anon key is a public client key (safe to ship in the app) — the
/// database is protected by row-level security, not by hiding this key.
/// Never put the service-role key here.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zfnucugpbpyrymyyrary.supabase.co',
  );

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep link Supabase redirects to after OAuth / password-reset emails.
  static const String authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'com.foliomed.app://login-callback',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
