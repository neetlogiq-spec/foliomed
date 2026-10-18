import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;
import '../../models/row_parsing.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/share_helper.dart';
import '../../widgets/support_sheet.dart';
import '../auth/background_setup_screen.dart';
import 'help_screen.dart';
import 'tutorial_screen.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/text_scale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/friendly_error.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../monitor/edge_setup_screen.dart';
import '../monitor/foliomed_edge_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _headerCard(context, user, auth),
                  const SizedBox(height: 20),
                  _sectionLabel('Account'),
                  const SizedBox(height: 8),
                  _accountCard(context, auth),
                  const SizedBox(height: 20),
                  _sectionLabel('Preferences'),
                  const SizedBox(height: 8),
                  _preferencesCard(context),
                  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
                      defaultTargetPlatform == TargetPlatform.windows ||
                      defaultTargetPlatform == TargetPlatform.linux)) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('FolioMed Edge'),
                    const SizedBox(height: 8),
                    _edgeCard(context),
                  ],
                  const SizedBox(height: 20),
                  _sectionLabel('About'),
                  const SizedBox(height: 8),
                  _aboutCard(context),
                  const SizedBox(height: 20),
                  _sectionLabel('Feedback & support'),
                  const SizedBox(height: 8),
                  _feedbackCard(context),
                  const SizedBox(height: 20),
                  _sectionLabel('Danger zone'),
                  const SizedBox(height: 8),
                  _dangerCard(context, auth),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, AppUser user, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => _showEmojiPicker(context, auth),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: user.roleColor.withOpacity(0.15),
                  child: user.avatarEmoji != null &&
                          user.avatarEmoji!.isNotEmpty
                      ? Text(
                          user.avatarEmoji!,
                          style: const TextStyle(fontSize: 40),
                        )
                      : Text(
                          getInitials(user.name),
                          style: TextStyle(
                            color: user.roleColor,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Icon(
                    Icons.edit,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.name,
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (user.specialty != null && user.specialty!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user.specialty!,
              style: GoogleFonts.dmSans(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.alternate_email,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const List<String> _emojiOptions = [
    '👨‍⚕️', '👩‍⚕️', '🧑‍⚕️', '🩺', '💉', '🧬', '🧪',
    '❤️', '🩷', '💙', '💚', '🔥', '⭐', '✨',
    '😀', '😎', '🤓', '🧐', '🤗', '🙂', '😇',
    '🐱', '🐶', '🦊', '🐼', '🦁', '🐯', '🐻',
    '🚀', '⚡', '🎯', '🏆', '🌟', '🌈', '☕',
  ];

  void _showEmojiPicker(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
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
                style: GoogleFonts.dmSans(
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
                      child: Text(
                        e,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Future.microtask(
                    () => auth.updateProfile(avatarEmoji: ''),
                  );
                },
                child: const Text('Remove emoji · use initials'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardWrapper({required List<Widget> children}) {
    final tiles = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      tiles.add(children[i]);
      if (i < children.length - 1) tiles.add(const Divider(height: 1));
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: tiles),
    );
  }

  Widget _accountCard(BuildContext context, AuthProvider auth) {
    return _cardWrapper(
      children: [
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit profile'),
          subtitle: const Text('Update your name'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showEditProfile(context, auth),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showChangePassword(context),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Share FolioMed'),
          subtitle: const Text('Invite your team to download the app'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => ShareHelper.shareApp(),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(
            Icons.local_cafe_outlined,
            color: Color(0xFFE57F00),
          ),
          title: const Text('Support FolioMed'),
          subtitle: const Text('Buy me a chai · keep the servers running'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showSupportSheet(context),
        ),
        if (!BackgroundSetupScreen.shouldSkip()) ...[
          const Divider(height: 1, indent: 60),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notification setup'),
            subtitle: const Text(
              'Re-run the background reliability wizard',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BackgroundSetupScreen(),
              ),
            ),
          ),
        ],
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('View tutorial'),
          subtitle: const Text('Walk through every button and feature'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TutorialScreen(),
              fullscreenDialog: true,
            ),
          ),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(Icons.quiz_outlined),
          title: const Text('Help & FAQs'),
          subtitle: const Text(
            'Quick answers to the most common questions',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HelpScreen()),
          ),
        ),
      ],
    );
  }

  Widget _preferencesCard(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final ts = context.watch<TextScaleProvider>();
    return _cardWrapper(
      children: [
        SwitchListTile(
          secondary: Icon(
            tp.isDark ? Icons.dark_mode : Icons.light_mode,
          ),
          title: const Text('Dark mode'),
          subtitle: Text(tp.isDark ? 'On' : 'Off'),
          value: tp.isDark,
          onChanged: (_) => tp.toggle(),
        ),
        const Divider(height: 1, indent: 60),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.format_size,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Text size',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(ts.scale * 100).round()}% of default',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (ts.scale != 1.0)
                TextButton(
                  onPressed: () => ts.setScale(1.0),
                  child: const Text('Reset'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: ts.scale,
                  min: TextScaleProvider.minScale,
                  max: TextScaleProvider.maxScale,
                  divisions: ((TextScaleProvider.maxScale -
                              TextScaleProvider.minScale) /
                          TextScaleProvider.step)
                      .round(),
                  label: '${(ts.scale * 100).round()}%',
                  onChanged: ts.setScale,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
        const Divider(height: 1, indent: 60),
        // Stateful daily-support toggle — the previous FutureBuilder
        // version never re-rendered because the future was cached after
        // the first read, and `markNeedsBuild()` doesn't re-invoke a
        // already-resolved FutureBuilder. A small dedicated widget owns
        // the value in state and updates instantly on tap.
        const _SupportPromptToggle(),
        // Note: weekly rating reminder is always-on by default and not
        // user-toggleable. Google Play rate-limits the dialog itself,
        // so it appears at most a few times a year regardless.
      ],
    );
  }

  Widget _edgeCard(BuildContext context) {
    return _cardWrapper(children: [
      ListTile(
        leading: const Icon(Icons.settings_input_antenna, color: AppColors.primary),
        title: Text('Manage Cameras',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        subtitle: Text('View, edit, or add CCTV cameras',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FolioMedEdgeScreen())),
      ),
      const Divider(height: 1, indent: 56),
      ListTile(
        leading: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
        title: Text('Set Up a New Camera',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        subtitle: Text('Step-by-step connection wizard',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const EdgeSetupScreen())),
      ),
      const Divider(height: 1, indent: 56),
      ListTile(
        leading: const Icon(Icons.info_outline, color: AppColors.primary),
        title: Text('What is FolioMed Edge?',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        subtitle: Text(
            'Connects CCTV cameras → auto-reads vitals → no manual charting',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
      ),
    ]);
  }

  Widget _aboutCard(BuildContext context) {
    final authUser = supabase.auth.currentUser;
    final lastSignIn = parseTimestampOrNull(authUser?.lastSignInAt);
    final created = parseTimestampOrNull(authUser?.createdAt);
    return _cardWrapper(children: [
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final v = snap.hasData
              ? '${snap.data!.version} · build ${snap.data!.buildNumber}'
              : '—';
          return ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('App version'),
            subtitle: Text(v),
          );
        },
      ),
      const Divider(height: 1, indent: 60),
      ListTile(
        leading: const Icon(Icons.login_outlined),
        title: const Text('Last sign-in'),
        subtitle: Text(
          lastSignIn == null
              ? 'unknown'
              : DateFormat('d MMM y · HH:mm').format(lastSignIn),
        ),
      ),
      const Divider(height: 1, indent: 60),
      ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: const Text('Account created'),
        subtitle: Text(
          created == null
              ? 'unknown'
              : DateFormat('d MMM y').format(created),
        ),
      ),
      const Divider(height: 1, indent: 60),
      ListTile(
        leading: const Icon(Icons.person_pin_circle_outlined),
        title: const Text('About the maker'),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => _openExternal(context, 'https://www.foliomed.app/'),
      ),
    ]);
  }

  /// Opens an external URL in the user's default browser. Falls back to
  /// a snackbar if no handler is registered.
  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't open $url")),
      );
    }
  }

  // ───────────────────────── Feedback & support ─────────────────────────

  static const String _supportEmail = 'kashyap2k007@gmail.com';
  static const String _androidPackage = 'com.foliomed.app';
  // Replace with the real App Store ID after first iOS submission —
  // App Store Connect → App Information → "Apple ID" (numeric).
  // Until then, the search-page URL is the second fallback.
  static const String _iosAppStoreId = '0000000000';

  Widget _feedbackCard(BuildContext context) {
    return _cardWrapper(
      children: [
        ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: const Text('Suggest a feature'),
          subtitle: const Text(
            'Idea for the app? Tell me — I read every email.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _emailDeveloper(
            context,
            subject: 'FolioMed · Feature suggestion',
            body: "Here's an idea for FolioMed:\n\n",
            label: 'Feature suggestion',
          ),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('Give feedback'),
          subtitle: const Text(
            'What works, what doesn\'t, what feels awkward',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _emailDeveloper(
            context,
            subject: 'FolioMed · Feedback',
            body: 'My feedback on FolioMed:\n\n',
            label: 'Feedback',
          ),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(Icons.star_outline, color: Color(0xFFE57F00)),
          title: const Text('Rate on Play Store'),
          subtitle: const Text(
            'A 5-star rating helps the next ward find FolioMed',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPlayStoreRating(context),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(
            Icons.bug_report_outlined,
            color: AppColors.danger,
          ),
          title: const Text(
            'Report a bug',
            style: TextStyle(color: AppColors.danger),
          ),
          subtitle: const Text(
            'Something broke or behaved weird? Send the details',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _reportBug(context),
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
      query: _encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showCopyEmailFallback(context, label);
    }
  }

  /// Bug-report intent: same as feedback but the body already has version
  /// + platform info filled in so the user doesn't have to.
  Future<void> _reportBug(BuildContext context) async {
    String version = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} · build ${info.buildNumber}';
    } catch (_) {}
    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? '(not signed in)';
    final body = '''
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
        Uri.parse(
          'https://apps.apple.com/app/id$_iosAppStoreId',
        ),
        Uri.parse('https://apps.apple.com/search?term=foliomed'),
      ];
    } else {
      attempts = [
        Uri.parse('market://details?id=$_androidPackage'),
        Uri.parse(
            'https://play.google.com/store/apps/details?id=$_androidPackage'),
      ];
    }
    bool launched = false;
    for (final uri in attempts) {
      try {
        launched = await launchUrl(uri,
            mode: LaunchMode.externalApplication);
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  Widget _dangerCard(BuildContext context, AuthProvider auth) {
    return _cardWrapper(
      children: [
        ListTile(
          leading: const Icon(Icons.logout, color: AppColors.danger),
          title: const Text(
            'Sign out',
            style: TextStyle(color: AppColors.danger),
          ),
          onTap: () => _confirmSignOut(context, auth),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(
            Icons.delete_forever_outlined,
            color: AppColors.danger,
          ),
          title: const Text(
            'Delete account',
            style: TextStyle(color: AppColors.danger),
          ),
          subtitle: const Text(
            'Removes your account and profile data permanently',
          ),
          onTap: () => _confirmDeleteAccount(context, auth),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AuthProvider auth,
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

    final typed = await showDialog<String>(
      context: context,
      builder: (_) {
        final tc = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
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
  Future<void> _doDeleteAccount(
    BuildContext context,
    AuthProvider auth,
  ) async {
    try {
      await AuthService().deleteAccount();
      await auth.signOut();
      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
                'Could not delete account — ${friendlyError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (_) => false,
        );
      }
    }
  }

  void _showEditProfile(BuildContext context, AuthProvider auth) {
    final nameController =
        TextEditingController(text: auth.currentUser?.name);
    final specialtyController =
        TextEditingController(text: auth.currentUser?.specialty ?? '');
    showModalBottomSheet(
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit profile',
                style: GoogleFonts.dmSans(
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
                  Future.microtask(() => auth.updateProfile(
                        name: newName,
                        specialty: newSpecialty,
                      ));
                },
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              final user = supabase.auth.currentUser;
              if (user == null || user.email == null) return;
              try {
                // Verify the current password before changing it.
                await AuthService().reauthenticate(currentController.text);
                await supabase.auth.updateUser(
                  UserAttributes(password: newController.text),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text(friendlyError(e)),
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────── Stateful toggle ────────────────────────────
// Lives outside ProfileScreen because its state has to survive across
// the parent rebuilds caused by AuthProvider / TextScaleProvider.

class _SupportPromptToggle extends StatefulWidget {
  const _SupportPromptToggle();

  @override
  State<_SupportPromptToggle> createState() => _SupportPromptToggleState();
}

class _SupportPromptToggleState extends State<_SupportPromptToggle> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    SupportPrompt.isEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<void> _toggle(bool v) async {
    // Update UI optimistically so the switch animates immediately.
    setState(() => _enabled = v);
    try {
      await SupportPrompt.setEnabled(v);
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() => _enabled = !v);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final enabled = _enabled ?? true;
    return SwitchListTile(
      secondary: const Icon(
        Icons.local_cafe_outlined,
        color: Color(0xFFE57F00),
      ),
      title: const Text('Daily support reminder'),
      subtitle: Text(
        enabled
            ? 'Once a day, a friendly chai prompt'
            : 'Off — you can still tap the chai icon any time',
      ),
      value: enabled,
      onChanged: _toggle,
    );
  }
}

