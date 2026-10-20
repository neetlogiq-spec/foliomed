import '../../models/row_parsing.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/share_helper.dart';
import '../start/alert_setup_screen.dart';
import '../../app/routes.dart';
import '../help/help_center_screen.dart';
import '../../widgets/tip_card.dart';

import '../../models/app_user.dart';
import '../../providers/account_provider.dart';
import '../../providers/text_scale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/friendly_error.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../widgets/app_sheet.dart';
import '../../utils/layout.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/inset_group.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final auth = context.watch<AccountProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    // iOS Settings pattern: large title + grouped sections.
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          const LargeTitleAppBar(title: 'Profile'),
          SliverPadding(
            padding: withBottomBarInset(
              context,
              const EdgeInsets.fromLTRB(16, 8, 16, 16),
            ),
            sliver: SliverList.list(
              children: [
                _headerCard(context, user, auth),
                const SizedBox(height: 24),
                _accountGroup(context, auth),
                const SizedBox(height: 24),
                _preferencesGroup(context),
                const SizedBox(height: 24),
                _helpGroup(context),
                const SizedBox(height: 24),
                _feedbackGroup(context),
                const SizedBox(height: 24),
                _aboutGroup(context),
                const SizedBox(height: 24),
                _signOutGroup(context, auth),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _headerCard(BuildContext context, AppUser user, AccountProvider auth) {
    final hasEmoji = user.avatarEmoji != null && user.avatarEmoji!.isNotEmpty;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => _showEditProfile(context, auth),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Change avatar',
                child: GestureDetector(
                  onTap: () => _showEmojiPicker(context, auth),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: user.roleColor.withValues(alpha: 0.15),
                    child: hasEmoji
                        ? Text(user.avatarEmoji!,
                            style: const TextStyle(fontSize: 32))
                        : Text(
                            getInitials(user.name),
                            style: AppTypography.title2(
                                color: user.roleColor, weight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title3(
                            color: AppColors.textPrimary)),
                    Text(
                      [
                        user.roleLabel,
                        if (user.specialty != null && user.specialty!.isNotEmpty)
                          user.specialty!,
                      ].join(' · '),
                      style: AppTypography.subheadline(color: user.roleColor),
                    ),
                    Text(user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  static const List<String> _emojiOptions = [
    '👨‍⚕️',
    '👩‍⚕️',
    '🧑‍⚕️',
    '🩺',
    '💉',
    '🧬',
    '🧪',
    '❤️',
    '🩷',
    '💙',
    '💚',
    '🔥',
    '⭐',
    '✨',
    '😀',
    '😎',
    '🤓',
    '🧐',
    '🤗',
    '🙂',
    '😇',
    '🐱',
    '🐶',
    '🦊',
    '🐼',
    '🦁',
    '🐯',
    '🐻',
    '🚀',
    '⚡',
    '🎯',
    '🏆',
    '🌟',
    '🌈',
    '☕',
  ];

  void _showEmojiPicker(BuildContext context, AccountProvider auth) {
    showAppSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Pick an avatar',
                style: appText(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 7,
              children: [
                for (final e in _emojiOptions)
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Future.microtask(
                        () => auth.updateProfile(avatarEmoji: e),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Future.microtask(() => auth.updateProfile(avatarEmoji: ''));
                },
                child: const Text('Remove emoji · use initials'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountGroup(BuildContext context, AccountProvider auth) {
    final isAdmin = auth.currentUser?.role == UserRole.admin;
    return InsetGroup(
      header: 'Account',
      children: [
        SettingsRow(
          icon: Icons.person_outline,
          title: 'Name & specialty',
          onTap: () => _showEditProfile(context, auth),
        ),
        SettingsRow(
          icon: Icons.emoji_emotions_outlined,
          iconColor: AppColors.warning,
          title: 'Avatar',
          onTap: () => _showEmojiPicker(context, auth),
        ),
        SettingsRow(
          icon: Icons.badge_outlined,
          iconColor: AppColors.accent,
          title: 'Role',
          subtitle: isAdmin ? 'Admin roles are managed from Staff' : null,
          value: auth.currentUser?.roleLabel ?? '',
          showChevron: !isAdmin,
          onTap: isAdmin ? null : () => _chooseRole(context, auth),
        ),
      ],
    );
  }

  Widget _preferencesGroup(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final ts = context.watch<TextScaleProvider>();
    return InsetGroup(
      header: 'Preferences',
      children: [
        SettingsRow(
          icon: tp.isDark ? Icons.dark_mode : Icons.light_mode,
          iconColor: const Color(0xFF5856D6),
          title: 'Dark mode',
          trailing: Switch.adaptive(value: tp.isDark, onChanged: (_) => tp.toggle()),
          onTap: tp.toggle,
          showChevron: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.format_size,
                        size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('Text size',
                        style: AppTypography.body(color: AppColors.textPrimary)),
                  ),
                  Text('${(ts.scale * 100).round()}%',
                      style: AppTypography.body(color: AppColors.textSecondary)),
                  if (ts.scale != 1.0)
                    TextButton(
                      onPressed: () => ts.setScale(1.0),
                      child: const Text('Reset'),
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 44),
                  const Text('A', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider.adaptive(
                      value: ts.scale,
                      min: TextScaleProvider.minScale,
                      max: TextScaleProvider.maxScale,
                      divisions: ((TextScaleProvider.maxScale -
                                  TextScaleProvider.minScale) /
                              TextScaleProvider.step)
                          .round(),
                      onChanged: ts.setScale,
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
        if (AlertSetupScreen.applies)
          SettingsRow(
            icon: Icons.notifications_active_outlined,
            iconColor: AppColors.danger,
            title: 'Alert Setup',
            subtitle: 'Get alerts even when FolioMed is closed',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlertSetupScreen()),
            ),
          ),
      ],
    );
  }

  Widget _helpGroup(BuildContext context) {
    return InsetGroup(
      header: 'Help',
      children: [
        SettingsRow(
          icon: Icons.help_outline,
          title: 'Help',
          subtitle: 'How-tos and answers',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
        ),
        SettingsRow(
          icon: Icons.lightbulb_outline,
          iconColor: AppColors.warning,
          title: 'Show tips again',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            await TipStore.reset();
            messenger.showSnackBar(
                const SnackBar(content: Text('Tips will appear again as you use FolioMed.')));
          },
        ),
      ],
    );
  }

  Widget _aboutGroup(BuildContext context) {
    final authUser = supabase.auth.currentUser;
    final lastSignIn = parseTimestampOrNull(authUser?.lastSignInAt);
    final created = parseTimestampOrNull(authUser?.createdAt);
    return InsetGroup(
      header: 'About',
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) => SettingsRow(
            icon: Icons.info_outline,
            iconColor: AppColors.textSecondary,
            title: 'Version',
            value: snap.hasData
                ? '${snap.data!.version} (${snap.data!.buildNumber})'
                : '—',
          ),
        ),
        SettingsRow(
          icon: Icons.login_outlined,
          iconColor: AppColors.textSecondary,
          title: 'Last sign-in',
          value: lastSignIn == null
              ? '—'
              : DateFormat('d MMM y, HH:mm').format(lastSignIn),
        ),
        SettingsRow(
          icon: Icons.calendar_today_outlined,
          iconColor: AppColors.textSecondary,
          title: 'Member since',
          value: created == null ? '—' : DateFormat('d MMM y').format(created),
        ),
        SettingsRow(
          icon: Icons.public,
          title: 'Website',
          trailing: Icon(Icons.open_in_new,
              size: 18, color: AppColors.textSecondary),
          onTap: () => _openExternal(context, 'https://www.foliomed.app/'),
        ),
        SettingsRow(
          icon: Icons.privacy_tip_outlined,
          iconColor: AppColors.accent,
          title: 'Privacy policy',
          trailing: Icon(Icons.open_in_new,
              size: 18, color: AppColors.textSecondary),
          onTap: () =>
              _openExternal(context, 'https://www.foliomed.app/privacy.html'),
        ),
      ],
    );
  }

  /// Opens an external URL in the user's default browser. Falls back to
  /// a snackbar if no handler is registered.
  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't open $url")));
    }
  }

  // ───────────────────────── Feedback & support ─────────────────────────

  static const String _supportEmail = 'kashyap2k007@gmail.com';
  static const String _androidPackage = 'com.foliomed.app';
  // Replace with the real App Store ID after first iOS submission —
  // App Store Connect → App Information → "Apple ID" (numeric).
  // Until then, the search-page URL is the second fallback.
  static const String _iosAppStoreId = '0000000000';

  Widget _feedbackGroup(BuildContext context) {
    return InsetGroup(
      header: 'Feedback',
      children: [
        SettingsRow(
          icon: Icons.lightbulb_outline,
          iconColor: AppColors.warning,
          title: 'Suggest a feature',
          onTap: () => _emailDeveloper(
            context,
            subject: 'FolioMed · Feature suggestion',
            body: "Here's an idea for FolioMed:\n\n",
            label: 'Feature suggestion',
          ),
        ),
        SettingsRow(
          icon: Icons.chat_bubble_outline,
          iconColor: AppColors.accent,
          title: 'Give feedback',
          onTap: () => _emailDeveloper(
            context,
            subject: 'FolioMed · Feedback',
            body: 'My feedback on FolioMed:\n\n',
            label: 'Feedback',
          ),
        ),
        SettingsRow(
          icon: Icons.bug_report_outlined,
          iconColor: AppColors.danger,
          title: 'Report a bug',
          onTap: () => _reportBug(context),
        ),
        SettingsRow(
          icon: Icons.star_outline,
          iconColor: AppColors.warning,
          title: 'Rate FolioMed',
          onTap: () => _openPlayStoreRating(context),
        ),
        SettingsRow(
          icon: Icons.ios_share,
          title: 'Share FolioMed',
          onTap: () => ShareHelper.shareApp(),
        ),
      ],
    );
  }

  /// Opens the user's email app with a pre-filled mailto: link to the
  /// developer. Falls back to copying the address if no mail handler
  /// is registered on the device.
  Future<void> _emailDeveloper(
    BuildContext context, {
    required String subject,
    required String body,
    required String label,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: _encodeQueryParameters({'subject': subject, 'body': body}),
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showCopyEmailFallback(context, label);
    }
  }

  /// Bug-report intent: same as feedback but the body already has version
  /// + platform info filled in so the user doesn't have to.
  Future<void> _reportBug(BuildContext context) async {
    final auth = context.read<AccountProvider>();
    String version = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} · build ${info.buildNumber}';
    } catch (_) {}
    final email = auth.currentUser?.email ?? '(not signed in)';
    final body =
        '''
What happened:


What you expected:


Steps to reproduce:
1.
2.
3.

— diagnostics —
App version: $version
Platform: ${_platformLabel()}
Account: $email
''';
    if (!context.mounted) return;
    await _emailDeveloper(
      context,
      subject: 'FolioMed · Bug report',
      body: body,
      label: 'Bug report',
    );
  }

  String _platformLabel() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Tries Google Play's in-app review dialog first (no app switch — the
  /// rating prompt overlays the app). Falls back to opening the Play
  /// Store listing if in-app review isn't available (web, Android device
  /// without Play Services, or quota exhausted by Google).
  Future<void> _openPlayStoreRating(BuildContext context) async {
    final review = InAppReview.instance;

    if (!kIsWeb) {
      try {
        if (await review.isAvailable()) {
          await review.requestReview();
          return; // Done — Play handled the dialog inside the app.
        }
      } catch (_) {
        // fall through to the store listing
      }
    }

    // Fallback: open the platform-appropriate store listing.
    // On iOS: itms-apps://itunes.apple.com (deep-link to App Store).
    // On Android: market:// (deep-link) with HTTPS fallback.
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final List<Uri> attempts;
    if (isIOS) {
      // App Store ID isn't known until first submission — once you have
      // it, paste it here as `_iosAppStoreId`. Until then, the search
      // URL works as a fallback.
      attempts = [
        Uri.parse('https://apps.apple.com/app/id$_iosAppStoreId'),
        Uri.parse('https://apps.apple.com/search?term=foliomed'),
      ];
    } else {
      attempts = [
        Uri.parse('market://details?id=$_androidPackage'),
        Uri.parse(
          'https://play.google.com/store/apps/details?id=$_androidPackage',
        ),
      ];
    }
    bool launched = false;
    for (final uri in attempts) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) break;
      } catch (_) {}
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open the store — search for 'FolioMed' there.",
          ),
        ),
      );
    }
  }

  /// Shown when no mail app is configured. Copies the address to the
  /// clipboard and tells the user about it.
  void _showCopyEmailFallback(BuildContext context, String label) {
    showAdaptiveDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        title: Text('Send $label by email'),
        content: const SelectableText(
          'No email app is set up on this device. '
          'Copy this address and email it from anywhere:\n\n'
          '$_supportEmail',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// mailto: query strings need their own encoding — Uri's default
  /// encoder can produce '+' for spaces, which some mail clients don't
  /// decode back into spaces.
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
  }

  Widget _signOutGroup(BuildContext context, AccountProvider auth) {
    return InsetGroup(
      footer: 'Deleting your account removes your profile and every ward you own, with its patients and notes.',
      children: [
        SettingsRow(
          icon: Icons.logout,
          title: 'Sign out',
          destructive: true,
          onTap: () => _confirmSignOut(context, auth),
        ),
        SettingsRow(
          icon: Icons.delete_forever_outlined,
          title: 'Delete account',
          destructive: true,
          onTap: () => _confirmDeleteAccount(context, auth),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AccountProvider auth,
  ) async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return;

    // Load wards this user created so we can warn them specifically.
    List<String> ownedWardNames = [];
    try {
      final rows = await supabase
          .from(Tables.wards)
          .select('name')
          .eq('creator_id', authUser.id);
      ownedWardNames = rows
          .map((r) => r['name'] as String? ?? 'Unnamed ward')
          .toList();
    } catch (e) {
      debugPrint('Owned-ward lookup failed: $e');
    }

    if (!context.mounted) return;

    // Build the ward warning text dynamically.
    final wardWarning = ownedWardNames.isEmpty
        ? ''
        : '\n⚠️ You are the creator of ${ownedWardNames.length} ward${ownedWardNames.length > 1 ? 's' : ''}. '
              'Deleting your account will permanently delete ${ownedWardNames.length > 1 ? 'them' : 'it'} and '
              'ALL their patients, notes and replies — even for other team members still using them:\n'
              '${ownedWardNames.map((n) => '  • $n').join('\n')}\n';

    final typed = await showAdaptiveDialog<String>(
      context: context,
      builder: (_) {
        final tc = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setState) => AppAlertDialog(
            title: const Text('Delete your account?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently:\n'
                    '• Delete your profile forever\n'
                    '• Remove you from all wards\n'
                    '• Sign you out on every device\n'
                    '$wardWarning\n'
                    'There is no undo. Type DELETE to confirm:',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tc,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'DELETE'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: tc.text.trim() == 'DELETE'
                    ? () => Navigator.pop(ctx, tc.text.trim())
                    : null,
                child: const Text('Delete forever'),
              ),
            ],
          ),
        );
      },
    );

    if (typed != 'DELETE' || !context.mounted) return;
    await _doDeleteAccount(context, auth);
  }

  /// Deletes the account via the `delete_my_account` Postgres function,
  /// which cascades to owned wards (patients, notes, replies) and removes
  /// the user from every ward they joined.
  Future<void> _doDeleteAccount(BuildContext context, AccountProvider auth) async {
    try {
      await AuthService().deleteAccount();
      await auth.signOut();
      if (context.mounted) {
        Routes.toSignIn(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Could not delete account — ${friendlyError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, AccountProvider auth) async {
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AppAlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await auth.signOut();
      if (context.mounted) {
        Routes.toSignIn(context);
      }
    }
  }

  void _showEditProfile(BuildContext context, AccountProvider auth) {
    final nameController = TextEditingController(text: auth.currentUser?.name);
    final specialtyController = TextEditingController(
      text: auth.currentUser?.specialty ?? '',
    );
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit profile',
                style: appText(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specialtyController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Specialty (optional)',
                  hintText: 'e.g. Cardiologist, ICU, Paediatrics',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final newName = nameController.text.trim();
                  final newSpecialty = specialtyController.text.trim();
                  Navigator.pop(context);
                  Future.microtask(
                    () => auth.updateProfile(
                      name: newName,
                      specialty: newSpecialty,
                    ),
                  );
                },
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Self-service doctor ↔ nurse switch (admin is never self-assigned).
  Future<void> _chooseRole(BuildContext context, AccountProvider auth) async {
    final role = await showAdaptiveDialog<UserRole>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Your role'),
        content: const Text('This decides your home screen and what you can do.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, UserRole.doctor),
            child: const Text('Doctor'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, UserRole.nurse),
            child: const Text('Nurse'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (role == null || role == auth.currentUser?.role) return;
    final ok = await auth.confirmRole(role);
    if (!context.mounted) return;
    if (ok) {
      // Home screen and tabs depend on the role — restart at the gate.
      Routes.restart(context);
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(friendlyError(auth.error!)),
        ),
      );
    }
  }

}
