import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/large_title_app_bar.dart';

/// Invite staff. Accounts are created by signing in with Google or Apple —
/// there are no passwords to hand out — so inviting means sharing a ward's
/// join code. Roles are then set from the Staff screen.
Future<void> showAddStaffBottomSheet(
  BuildContext context, {
  String? wardId,
  bool showWardSelector = false,
}) {
  return showAppSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => InviteStaffSheet(wardId: wardId),
  );
}

class InviteStaffSheet extends StatelessWidget {
  const InviteStaffSheet({super.key, this.wardId});

  /// A specific ward, or null to list every ward the admin belongs to.
  final String? wardId;

  static const _appUrl = 'https://www.foliomed.app/app/';

  String _message(String code) =>
      'Join my ward on FolioMed.\n\n'
      '1. Open $_appUrl (or install the app)\n'
      '2. Sign in with Google or Apple\n'
      '3. Wards → Join Ward → enter code $code';

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final codes = wardId != null ? [wardId!] : (user?.wardIds ?? const []);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.tertiaryLabel,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Invite staff',
                style: AppTypography.title2(color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Colleagues sign in with Google or Apple, then join with the '
              'ward code. Once they appear in Staff, you can set their role.',
              style: AppTypography.subheadline(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (codes.isEmpty)
              Text(
                'Create or join a ward first — its code is what you share.',
                style: AppTypography.subheadline(color: AppColors.textPrimary),
              )
            else ...[
              const GroupedSectionHeader('Ward codes'),
              for (final code in codes) _CodeRow(code: code, message: _message(code)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.code, required this.message});

  final String code;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              semanticsLabel: 'Ward code ${code.split('').join(' ')}',
              style: appMonoText(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ).copyWith(fontFeatures: AppTypography.tabular),
            ),
          ),
          IconButton(
            tooltip: 'Copy code',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ward code $code copied')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Share invite',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Share.share(message, subject: 'Join my ward on FolioMed'),
          ),
        ],
      ),
    );
  }
}
