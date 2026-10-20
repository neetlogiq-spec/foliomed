import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/app_user.dart';
import '../../providers/account_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';

/// First sign-in only: doctor or nurse. Admin access is given by an
/// existing admin, never chosen here.
class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  UserRole? _picked;
  bool _saving = false;

  Future<void> _continue() async {
    final role = _picked;
    if (role == null) return;
    setState(() => _saving = true);
    final account = context.read<AccountProvider>();
    final ok = await account.confirmRole(role);
    if (!mounted) return;
    if (ok) {
      Haptics.success();
      Routes.restart(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(friendlyError(account.error ?? 'Your choice wasn’t saved')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('How do you work\non the ward?',
                            style: AppTypography.largeTitle(color: AppColors.textPrimary).copyWith(height: 1.1)),
                        const SizedBox(height: 10),
                        Text('This sets what FolioMed puts first for you.',
                            style: AppTypography.body(color: AppColors.textSecondary)),
                        const SizedBox(height: 28),
                        _RoleOption(
                          role: UserRole.doctor,
                          icon: Icons.medical_information_outlined,
                          summary: 'Write notes, admit patients and plan investigations.',
                          selected: _picked == UserRole.doctor,
                          onTap: () => setState(() => _picked = UserRole.doctor),
                        ),
                        const SizedBox(height: 12),
                        _RoleOption(
                          role: UserRole.nurse,
                          icon: Icons.volunteer_activism_outlined,
                          summary: 'Confirm notes as you act on them and record what was done.',
                          selected: _picked == UserRole.nurse,
                          onTap: () => setState(() => _picked = UserRole.nurse),
                        ),
                        const SizedBox(height: 18),
                        Text('You can switch later in Profile.',
                            style: AppTypography.footnote(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _picked == null || _saving ? null : _continue,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                        : Text('Continue', style: AppTypography.headline(color: AppColors.onPrimary)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.icon,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final IconData icon;
  final String summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: AnimatedContainer(
            duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: selected ? role.color : AppColors.divider, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(icon, size: 34, color: role.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.label, style: AppTypography.headline(color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(summary, style: AppTypography.subheadline(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? role.color : AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
