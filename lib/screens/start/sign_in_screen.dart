import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../providers/account_provider.dart';
import '../../services/push_registration.dart';
import '../../services/live_note_alerts.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/oauth_error.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/foliomed_brand.dart';
import 'welcome_screen.dart';

/// Sign in with an account you already have (Apple on iPhone, Google
/// everywhere). New accounts are created on first sign-in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static bool get _offerApple => !kIsWeb && Platform.isIOS;

  @override
  void initState() {
    super.initState();
    // On the web, a failed Google round-trip comes back as URL parameters.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final problem = oauthErrorMessage(Uri.base);
        if (problem != null && mounted) _tell(problem);
      });
    }
  }

  void _tell(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 8),
        content: Text(message),
      ));

  Future<void> _go(Future<bool> Function(AccountProvider) signIn) async {
    final account = context.read<AccountProvider>();
    final ok = await signIn(account);
    if (!mounted) return;
    if (!ok || account.currentUser == null) {
      // The web leaves the page for Google; nothing to report yet.
      if (kIsWeb && account.error == null) return;
      if (account.error != null) _tell(friendlyError(account.error!));
      return;
    }
    await WelcomeScreen.markSeen();
    LiveNoteAlerts.register();
    PushRegistration.instance.register();
    final me = account.currentUser!;
    final placeholderName = me.name.trim().isEmpty || me.name.trim() == me.email.split('@').first;
    if (placeholderName && mounted) await _askName(account);
    if (mounted) Routes.restart(context);
  }

  Future<void> _askName(AccountProvider account) async {
    final name = await showAppSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _NameSheet(initial: account.currentUser?.name ?? ''),
    );
    if (name != null && name.isNotEmpty) await account.updateProfile(name: name);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AccountProvider>().isLoading;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // What FolioMed is, and why signing in is safe.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FolioMedMark(size: 56),
                        const SizedBox(height: 20),
                        Text('FolioMed', style: AppTypography.largeTitle(color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        Text('Ward notes, jobs and newborn care, shared live with your team.',
                            style: AppTypography.title3(color: AppColors.textSecondary, weight: FontWeight.w400)),
                        const SizedBox(height: 32),
                        const _Promise(
                          icon: Icons.key_off_outlined,
                          title: 'No new password',
                          text: 'Sign in with the Google or Apple account you already use.',
                        ),
                        const _Promise(
                          icon: Icons.lock_outline,
                          title: 'Only your wards',
                          text: 'Patients and notes are visible only to people in the same ward.',
                        ),
                        const _Promise(
                          icon: Icons.volunteer_activism_outlined,
                          title: 'Free for the whole team',
                          text: 'No subscriptions, no ads.',
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions sit at the bottom, within thumb reach.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_offerApple) ...[
                        _ProviderButton(
                          label: 'Continue with Apple',
                          icon: Icons.apple,
                          background: dark ? Colors.white : Colors.black,
                          foreground: dark ? Colors.black : Colors.white,
                          onPressed: busy ? null : () => _go((a) => a.signInWithApple()),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _ProviderButton(
                        label: 'Sign in with Google',
                        icon: Icons.g_mobiledata_rounded,
                        background: AppColors.card,
                        foreground: AppColors.textPrimary,
                        outlined: true,
                        onPressed: busy ? null : () => _go((a) => a.signInWithGoogle()),
                      ),
                      SizedBox(
                        height: 36,
                        child: busy ? const Center(child: CupertinoActivityIndicator()) : null,
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () => launchUrl(Uri.parse('https://www.foliomed.app/privacy.html'),
                              mode: LaunchMode.externalApplication),
                          child: Text('How FolioMed handles your data',
                              style: AppTypography.footnote(color: AppColors.primary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One reassurance on the sign-in page.
class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 28, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTypography.headline(color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(text, style: AppTypography.subheadline(color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      );
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: outlined ? BorderSide(color: AppColors.divider) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.control)),
        ),
        icon: Icon(icon, size: 26),
        label: Text(label, style: AppTypography.headline(color: foreground)),
      ),
    );
  }
}

/// "Your name on notes" — asked once when the account has no real name.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _name.text.trim().length >= 2;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your name on notes', style: AppTypography.title2(color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Teammates see it next to everything you post or confirm.',
                  style: AppTypography.subheadline(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              CupertinoTextField(
                controller: _name,
                autofocus: true,
                placeholder: 'e.g. Dr Meera Iyer',
                textCapitalization: TextCapitalization.words,
                padding: const EdgeInsets.all(14),
                style: AppTypography.body(color: AppColors.textPrimary),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) => ok ? Navigator.pop(context, v.trim()) : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: ok ? () => Navigator.pop(context, _name.text.trim()) : null,
                  child: Text('Done', style: AppTypography.headline(color: AppColors.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
