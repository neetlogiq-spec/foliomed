import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../models/app_user.dart';
import '../../models/row_parsing.dart';
import '../../providers/account_provider.dart';
import '../../providers/appearance_provider.dart';
import '../../services/account_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/tip_card.dart';
import '../help/help_center_screen.dart';
import '../start/alert_setup_screen.dart';
import 'edit_account_sheet.dart';

const _supportEmail = 'kashyap2k007@gmail.com';
const _siteUrl = 'https://www.foliomed.app/';
const _privacyUrl = 'https://www.foliomed.app/privacy.html';

/// The signed-in person's page, laid out like iOS Settings.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AccountProvider>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          const LargeTitleAppBar(title: 'Profile'),
          if (me == null)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator.adaptive()))
          else
            SliverPadding(
              padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 24)),
              sliver: SliverList.list(
                children: [
                  _IdentityCard(me: me),
                  const SizedBox(height: 24),
                  _RoleGroup(me: me),
                  const SizedBox(height: 24),
                  const _AppearanceGroup(),
                  const SizedBox(height: 24),
                  if (AlertSetupScreen.applies) ...[
                    InsetGroup(children: [
                      SettingsRow(
                        icon: Icons.notifications_active_outlined,
                        iconColor: AppColors.danger,
                        title: 'Alert Setup',
                        subtitle: 'Get alerts even when FolioMed is closed',
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const AlertSetupScreen())),
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],
                  _HelpGroup(me: me),
                  const SizedBox(height: 24),
                  const _AboutGroup(),
                  const SizedBox(height: 24),
                  _LeaveGroup(me: me),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final emoji = me.avatarEmoji;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => showEditAccount(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: me.roleColor.withValues(alpha: 0.16),
                child: emoji != null && emoji.isNotEmpty
                    ? Text(emoji, style: const TextStyle(fontSize: 30))
                    : Text(initialsOf(me.name),
                        style: AppTypography.title3(color: me.roleColor, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name.isEmpty ? 'Add your name' : me.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title3(color: AppColors.textPrimary)),
                    Text(
                      [me.roleLabel, if ((me.specialty ?? '').isNotEmpty) me.specialty!].join(' · '),
                      style: AppTypography.subheadline(color: me.roleColor),
                    ),
                    Text(me.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text('Edit', style: AppTypography.body(color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleGroup extends StatelessWidget {
  const _RoleGroup({required this.me});
  final AppUser me;

  Future<void> _switch(BuildContext context) async {
    final other = me.role == UserRole.doctor ? UserRole.nurse : UserRole.doctor;
    final yes = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text('Switch to ${other.label.toLowerCase()}?'),
        content: Text(other == UserRole.nurse
            ? 'You’ll confirm notes from the confirmation sheet and won’t see the compose button.'
            : 'You’ll get the compose button and can confirm notes in one tap.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Switch to ${other.label}')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final account = context.read<AccountProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (await account.confirmRole(other)) {
      if (context.mounted) Routes.restart(context);
    } else {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text(friendlyError(account.error ?? 'error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = me.role == UserRole.admin;
    return InsetGroup(
      footer: admin ? 'Admin access is managed by another admin from People.' : null,
      children: [
        SettingsRow(
          icon: Icons.badge_outlined,
          iconColor: me.roleColor,
          title: 'Role',
          value: me.roleLabel,
          onTap: admin ? null : () => _switch(context),
          showChevron: !admin,
        ),
      ],
    );
  }
}

class _AppearanceGroup extends StatelessWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppearanceProvider>();
    final pct = (a.extraTextScale * 100).round();
    return InsetGroup(
      header: 'Appearance',
      footer: 'Text size adds to the size set on your phone.',
      dividerIndent: 16,
      children: [
        InsetSegmentedRow<Appearance>(
          label: 'Theme',
          value: a.appearance,
          options: {for (final x in Appearance.values) x: x.label},
          onChanged: a.setAppearance,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(child: Text('Text size', style: AppTypography.body(color: AppColors.textPrimary))),
              Text(pct == 100 ? 'Standard' : '+${pct - 100}%',
                  style: AppTypography.body(color: AppColors.textSecondary)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Row(
            children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('A', style: TextStyle(fontSize: 13))),
              Expanded(
                child: Slider.adaptive(
                  value: a.extraTextScale,
                  min: AppearanceProvider.minExtra,
                  max: AppearanceProvider.maxExtra,
                  divisions: ((AppearanceProvider.maxExtra - AppearanceProvider.minExtra) /
                          AppearanceProvider.extraStep)
                      .round(),
                  onChanged: a.setExtraTextScale,
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('A', style: TextStyle(fontSize: 21))),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpGroup extends StatelessWidget {
  const _HelpGroup({required this.me});
  final AppUser me;

  Future<void> _feedback(BuildContext context) async {
    final info = await PackageInfo.fromPlatform().catchError((_) => PackageInfo(
        appName: 'FolioMed', packageName: '', version: '?', buildNumber: '?'));
    final platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    final uri = Uri(scheme: 'mailto', path: _supportEmail, queryParameters: {
      'subject': 'FolioMed feedback',
      'body': '\n\n— Sent from FolioMed ${info.version} (${info.buildNumber}) on $platform',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      await showAdaptiveDialog<void>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: const Text('No mail app found'),
          content: const SelectableText('Write to us at $_supportEmail'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InsetGroup(
      header: 'Help & feedback',
      children: [
        SettingsRow(
          icon: Icons.help_outline,
          title: 'Help',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
        ),
        SettingsRow(
          icon: Icons.lightbulb_outline,
          iconColor: AppColors.warning,
          title: 'Show tips again',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            await TipStore.reset();
            messenger.showSnackBar(const SnackBar(content: Text('Tips will show again as you go.')));
          },
        ),
        SettingsRow(
          icon: Icons.mail_outline,
          iconColor: AppColors.accent,
          title: 'Send feedback',
          subtitle: 'Ideas, problems, anything',
          onTap: () => _feedback(context),
        ),
        SettingsRow(
          icon: Icons.star_outline,
          iconColor: AppColors.warning,
          title: 'Rate FolioMed',
          onTap: () async {
            final review = InAppReview.instance;
            try {
              if (await review.isAvailable()) {
                await review.requestReview();
              } else {
                await review.openStoreListing();
              }
            } catch (_) {
              await launchUrl(Uri.parse(_siteUrl), mode: LaunchMode.externalApplication);
            }
          },
        ),
        SettingsRow(
          icon: Icons.ios_share,
          title: 'Tell a colleague',
          onTap: () => Share.share(
            'I use FolioMed for ward notes and newborn follow-ups — ${_siteUrl}app/'
            '${me.name.isEmpty ? '' : '\n\n— ${me.name}'}',
            subject: 'FolioMed for your ward',
          ),
        ),
      ],
    );
  }
}

class _AboutGroup extends StatelessWidget {
  const _AboutGroup();

  @override
  Widget build(BuildContext context) {
    final since = parseTimestampOrNull(supabase.auth.currentUser?.createdAt);
    Future<void> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    final external = Icon(Icons.open_in_new, size: 17, color: AppColors.textSecondary);
    return InsetGroup(
      header: 'About',
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, s) => SettingsRow(
            icon: Icons.info_outline,
            iconColor: AppColors.textSecondary,
            title: 'Version',
            value: s.hasData ? '${s.data!.version} (${s.data!.buildNumber})' : '–',
          ),
        ),
        if (since != null)
          SettingsRow(
            icon: Icons.event_available_outlined,
            iconColor: AppColors.textSecondary,
            title: 'Member since',
            value: DateFormat('MMMM y').format(since.toLocal()),
          ),
        SettingsRow(icon: Icons.privacy_tip_outlined, iconColor: AppColors.accent, title: 'Privacy Policy', trailing: external, onTap: () => open(_privacyUrl)),
        SettingsRow(icon: Icons.public, title: 'foliomed.app', trailing: external, onTap: () => open(_siteUrl)),
      ],
    );
  }
}

class _LeaveGroup extends StatelessWidget {
  const _LeaveGroup({required this.me});
  final AppUser me;

  Future<void> _signOut(BuildContext context) async {
    final yes = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Sign out of FolioMed?'),
        content: const Text('Alerts stop on this phone until you sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await context.read<AccountProvider>().signOut();
    if (context.mounted) Routes.toSignIn(context);
  }

  Future<void> _delete(BuildContext context) async {
    List<String> owned = const [];
    try {
      final rows = await supabase.from(Tables.wards).select('name').eq('creator_id', me.uid);
      owned = [for (final r in rows) r['name'] as String? ?? 'A ward'];
    } catch (e) {
      debugPrint('Owned wards lookup failed: $e');
    }
    if (!context.mounted) return;
    final confirmed = await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DeleteAccountSheet(ownedWards: owned),
    );
    if (confirmed != true || !context.mounted) return;
    final account = context.read<AccountProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AccountService().deleteAccount();
      Haptics.destructive();
      await account.signOut();
      if (context.mounted) Routes.toSignIn(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text('Account not deleted — ${friendlyError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InsetGroup(
      children: [
        SettingsRow(title: 'Sign Out', destructive: true, onTap: () => _signOut(context)),
        SettingsRow(title: 'Delete Account', destructive: true, onTap: () => _delete(context)),
      ],
    );
  }
}

/// Spells out what deleting removes; the button stays disabled until the
/// person types "delete".
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.ownedWards});
  final List<String> ownedWards;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _typed.text.trim().toLowerCase() == 'delete';
    final owned = widget.ownedWards;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Delete your account', style: AppTypography.title2(color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Text(
                'Your profile is erased and you leave every ward. This can’t be undone.',
                style: AppTypography.body(color: AppColors.textSecondary),
              ),
              if (owned.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Text(
                    'You own ${owned.length == 1 ? 'this ward' : 'these wards'}. '
                    '${owned.length == 1 ? 'It' : 'They'} will be deleted too — with every patient, note and reminder, for everyone in ${owned.length == 1 ? 'it' : 'them'}:\n'
                    '${owned.map((w) => '• $w').join('\n')}',
                    style: AppTypography.subheadline(color: AppColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: _typed,
                placeholder: 'Type “delete” to confirm',
                autocorrect: false,
                padding: const EdgeInsets.all(14),
                style: AppTypography.body(color: AppColors.textPrimary),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: ready ? () => Navigator.pop(context, true) : null,
                  child: Text('Delete Account', style: AppTypography.headline(color: Colors.white)),
                ),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep my account')),
            ],
          ),
        ),
      ),
    );
  }
}
