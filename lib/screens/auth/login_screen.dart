import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../app/routes.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/push_service.dart';
import '../../services/push_registration.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/oauth_error.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/foliomed_brand.dart';
import '../start/welcome_screen.dart';

/// Sign-in: Google or Apple only — no passwords to create, forget or leak.
/// The same screen covers new and returning users; a new account is
/// created on first sign-in and then asked for its role once.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _privacyUrl = 'https://www.foliomed.app/privacy.html';

  bool get _appleAvailable =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOAuthError());
    }
  }

  /// Web: Supabase returns OAuth failures as URL parameters
  /// (e.g. `?error=server_error&error_description=…`). Surface them.
  void _showOAuthError() {
    final message = oauthErrorMessage(Uri.base);
    if (message == null || !mounted) return;
    debugPrint('OAuth error on return: ${Uri.base}');
    _showError(message);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 8),
        content: Text(message),
      ),
    );
  }

  Future<void> _markOnboardingDone() => WelcomeScreen.markSeen();

  Future<void> _afterSignIn(AuthProvider auth, {required bool ok}) async {
    if (!mounted) return;
    if (!ok || auth.currentUser == null) {
      if (auth.error != null) _showError(friendlyError(auth.error!));
      return;
    }
    await _markOnboardingDone();
    PushService.register();
    PushRegistration.instance.register();
    final user = auth.currentUser!;
    final needsName = user.name.trim().isEmpty ||
        user.name.trim() == user.email.split('@').first;
    if (needsName && mounted) await _promptForName(auth);
    if (!mounted) return;
    // The splash gate routes by role (and asks a new user for it once).
    Routes.restart(context);
  }

  Future<void> _signInGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithGoogle();
    // Web redirects away; native returns here once the deep link lands.
    if (kIsWeb && !ok) return;
    await _afterSignIn(auth, ok: ok);
  }

  Future<void> _signInApple() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithApple();
    await _afterSignIn(auth, ok: ok);
  }

  Future<void> _promptForName(AuthProvider auth) async {
    final controller = TextEditingController(text: auth.currentUser?.name ?? '');
    await showAdaptiveDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppAlertDialog(
        title: const Text('What should we call you?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your ward team sees this name on every note you post or '
              'acknowledge, so please use your real name.',
              style: AppTypography.footnote(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full name',
                hintText: 'e.g. Ravi Kumar',
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await auth.updateProfile(name: name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final busy = auth.isLoading;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: FolioMedLockup(size: 44)),
                      const SizedBox(height: 40),
                      Text(
                        'Every handover,\nin one place.',
                        textAlign: TextAlign.center,
                        style: AppTypography.title1(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Notes, acknowledgements and patient updates your '
                        'ward team can see the moment they happen.',
                        textAlign: TextAlign.center,
                        style: AppTypography.callout(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (_appleAvailable) ...[
                        _AppleButton(onPressed: busy ? null : _signInApple),
                        const SizedBox(height: 12),
                      ],
                      _GoogleButton(onPressed: busy ? null : _signInGoogle),
                      const SizedBox(height: 28),
                      Text.rich(
                        TextSpan(
                          text: 'New here? Signing in creates your account. '
                              'By continuing you agree to our ',
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: Semantics(
                                link: true,
                                child: GestureDetector(
                                  onTap: () => launchUrl(
                                    Uri.parse(_privacyUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: Text(
                                    'Privacy Policy',
                                    style: AppTypography.footnote(
                                      color: AppColors.isDark
                                          ? AppColors.darkPrimary
                                          : AppColors.primary,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: AppTypography.footnote(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (busy)
            Semantics(
              label: 'Signing in',
              liveRegion: true,
              child: ColoredBox(
                color: Colors.black.withOpacity(0.2),
                child: const Center(child: CircularProgressIndicator.adaptive()),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Sign in with Apple" per Apple's guidelines: black on light, white on
/// dark, Apple logo + standard title, full width, 50pt tall.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: dark ? Colors.white : Colors.black,
        foregroundColor: dark ? Colors.black : Colors.white,
      ),
      icon: const Icon(Icons.apple, size: 22),
      label: const Text('Sign in with Apple'),
    );
  }
}

/// Google's guidance: neutral surface, Google mark, "Continue with Google".
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.divider),
      ),
      icon: const Icon(Icons.g_mobiledata, size: 30),
      label: const Text('Continue with Google'),
    );
  }
}
