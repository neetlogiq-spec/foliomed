import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../services/push_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/friendly_error.dart';
import 'background_setup_screen.dart';
import 'onboarding_screen.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../utils/oauth_error.dart';
import 'package:flutter/cupertino.dart';
import '../../widgets/foliomed_brand.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.signIn;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberDevice = true;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 8),
        content: Text(message),
      ),
    );
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_device') ?? true;
    final saved = prefs.getString('saved_email');
    if (!mounted) return;
    setState(() {
      _rememberDevice = remember;
      if (remember && saved != null && saved.isNotEmpty) {
        _emailController.text = saved;
      }
    });
  }

  Future<void> _persistRememberDevice(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberDevice) {
      await prefs.setBool('remember_device', true);
      await prefs.setString('saved_email', email);
    } else {
      await prefs.setBool('remember_device', false);
      await prefs.remove('saved_email');
    }
  }

  Future<void> _markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingDoneKey, true);
    await prefs.remove('onboarding_complete'); // legacy
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool ok;
    if (_mode == _Mode.signIn) {
      ok = await authProvider.signIn(email, password);
    } else {
      final name = _nameController.text.trim();
      ok = await authProvider.register(
        name: name,
        email: email,
        password: password,
        role: 'doctor',
      );
    }

    if (!mounted) return;
    if (ok && authProvider.currentUser != null) {
      await _persistRememberDevice(email);
      await _markOnboardingDone();
      PushService.register();
      if (!mounted) return;
      await _routePostAuth();
    } else if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 10),
          content: Text(
            friendlyError(authProvider.error!),
            maxLines: 10,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    }
  }

  Future<void> _routePostAuth() async {
    if (BackgroundSetupScreen.shouldSkip()) {
      Navigator.of(context).pushReplacementNamed('/doctor/home');
      return;
    }
    final done = await BackgroundSetupScreen.isDone();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(done ? '/doctor/home' : '/background-setup');
  }

  Future<void> _signInGoogle() async {
    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.signInWithGoogle();
    if (!mounted) return;
    if (ok && authProvider.currentUser != null) {
      await _markOnboardingDone();
      PushService.register();
      final user = authProvider.currentUser!;
      final needsName =
          user.name.trim().isEmpty ||
          user.name.trim() == user.email.split('@').first;
      if (!mounted) return;
      if (needsName) {
        await _promptForName(authProvider);
      }
      if (!mounted) return;
      await _routePostAuth();
    } else if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 10),
          content: Text(
            friendlyError(authProvider.error!),
            maxLines: 10,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    }
  }

  Future<void> _signInApple() async {
    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.signInWithApple();
    if (!mounted) return;
    if (ok && authProvider.currentUser != null) {
      await _markOnboardingDone();
      PushService.register();
      final user = authProvider.currentUser!;
      final needsName = user.name.trim().isEmpty;
      if (!mounted) return;
      if (needsName) {
        await _promptForName(authProvider);
      }
      if (!mounted) return;
      await _routePostAuth();
    } else if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 10),
          content: Text(
            friendlyError(authProvider.error!),
            maxLines: 10,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    }
  }

  Future<void> _promptForName(AuthProvider auth) async {
    final controller = TextEditingController(
      text: auth.currentUser?.name ?? '',
    );
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
              'Please use your real name — it makes tracking who posted or acknowledged a note much easier for your ward team.',
              style: appText(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your full name',
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

  Future<void> _forgotPassword() async {
    final ec = TextEditingController(text: _emailController.text.trim());
    final result = await showAdaptiveDialog<String>(
      context: context,
      builder: (_) => AppAlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: ec,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ec.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    final email = result.trim();

    // Supabase never reveals whether an address is registered, so we just
    // send it and show a neutral "check your inbox" message either way.
    final ok = await context.read<AuthProvider>().sendPasswordReset(email);
    if (!mounted) return;
    if (ok) {
      await _showResetInfoDialog(
        context,
        title: 'Check your inbox',
        body:
            "If a FolioMed account exists for $email, a reset link is on its way.\n\n"
            "• It usually arrives within a minute.\n"
            "• Check your Spam / Junk folder if you don't see it.\n"
            "• The link is valid for 1 hour — tap 'Forgot?' again for a fresh one.\n\n"
            "If you signed up with Google, go back and tap 'Continue with Google' — there's no password to reset.",
      );
    } else {
      final err = (context.read<AuthProvider>().error ?? '').toString();
      final errLower = err.toLowerCase();
      final isNotFound =
          errLower.contains('not found') ||
          errLower.contains('no account') ||
          errLower.contains('user-not-found');

      if (isNotFound) {
        // Most likely a Google-only account — no password to reset.
        await _showResetInfoDialog(
          context,
          title: 'No password account found',
          body:
              "We couldn't find a FolioMed password account for $email.\n\n"
              "• If you signed up with Google, go back and tap "
              "'Continue with Google' — there's no password to reset.\n\n"
              "• Double-check the spelling of the email.\n\n"
              "• If you've never signed up, switch to 'Sign Up' and create an account.",
        );
      } else {
        // Network error or something else unexpected.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 6),
            content: Text(
              err.isEmpty
                  ? "Couldn't send the reset email. Check your internet and try again."
                  : "Reset failed — ${friendlyError(err)}",
            ),
          ),
        );
      }
    }
  }

  Future<void> _showResetInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showAdaptiveDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    final authProvider = context.watch<AuthProvider>();

    final reduced = AppMotion.reduced(context);
    final isSignUp = _mode == _Mode.signUp;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: FolioMedBrand(size: 44)),
                        const SizedBox(height: 10),
                        Text(
                          'Ward, connected',
                          textAlign: TextAlign.center,
                          style: AppTypography.subheadline(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _modeToggle(),
                        const SizedBox(height: 24),
                        // The name field slides in for sign-up — explains the
                        // mode change instead of rebuilding the whole form.
                        AnimatedSize(
                          duration: reduced ? Duration.zero : AppMotion.quick,
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: isSignUp
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TextFormField(
                                    controller: _nameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    decoration: const InputDecoration(
                                      labelText: 'Full name',
                                      hintText: 'Use your real name',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (v) =>
                                        _mode == _Mode.signUp &&
                                            (v == null || v.trim().isEmpty)
                                        ? 'Please enter your name'
                                        : null,
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Enter your email';
                            final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!re.hasMatch(v)) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: [
                            isSignUp
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(() {
                                _obscurePassword = !_obscurePassword;
                              }),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: MergeSemantics(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() {
                                    _rememberDevice = !_rememberDevice;
                                  }),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 44,
                                    ),
                                    child: Row(
                                      children: [
                                        Switch.adaptive(
                                          value: _rememberDevice,
                                          onChanged: (v) => setState(() {
                                            _rememberDevice = v;
                                          }),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Remember this device',
                                            style: AppTypography.subheadline(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isSignUp)
                              TextButton(
                                onPressed: _forgotPassword,
                                child: const Text('Forgot?'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _submit,
                          child: Text(isSignUp ? 'Create Account' : 'Sign In'),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or',
                                style: AppTypography.footnote(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (!kIsWeb && Platform.isIOS) ...[
                          _appleButton(authProvider),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : _signInGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: Text(
                            isSignUp
                                ? 'Sign up with Google'
                                : 'Continue with Google',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (authProvider.isLoading)
            Semantics(
              label: 'Signing in',
              liveRegion: true,
              child: Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "Sign in with Apple" per Apple's button guidelines: black in light
  /// mode, white in dark mode, Apple logo + standard title.
  Widget _appleButton(AuthProvider authProvider) {
    final dark = AppColors.isDark;
    return ElevatedButton.icon(
      onPressed: authProvider.isLoading ? null : _signInApple,
      style: ElevatedButton.styleFrom(
        backgroundColor: dark ? Colors.white : Colors.black,
        foregroundColor: dark ? Colors.black : Colors.white,
      ),
      icon: const Icon(Icons.apple, size: 22),
      label: const Text('Sign in with Apple'),
    );
  }

  /// Native sliding segmented control: the thumb springs between the two
  /// modes, and it is the control iOS users already know for this choice.
  Widget _modeToggle() {
    return CupertinoSlidingSegmentedControl<_Mode>(
      groupValue: _mode,
      onValueChanged: (mode) {
        if (mode != null) setState(() => _mode = mode);
      },
      children: {
        _Mode.signIn: _segment('Sign In'),
        _Mode.signUp: _segment('Sign Up'),
      },
    );
  }

  Widget _segment(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: AppTypography.subheadline(
          color: AppColors.textPrimary,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}
