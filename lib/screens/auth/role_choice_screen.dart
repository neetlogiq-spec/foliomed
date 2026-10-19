import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/pressable.dart';

/// Asked once, right after a new account's first sign-in. Doctor or nurse
/// only — admin access is granted by an existing admin, never self-chosen.
class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  UserRole? _saving;

  Future<void> _choose(UserRole role) async {
    setState(() => _saving = role);
    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmRole(role);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      return;
    }
    setState(() => _saving = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.danger,
      content: Text(friendlyError(auth.error ?? 'Could not save your role')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final name = context.watch<AuthProvider>().currentUser?.name ?? '';
    final first = name.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    first.isEmpty ? 'Welcome' : 'Welcome, $first',
                    style: AppTypography.largeTitle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How do you work on the ward? You can change this later '
                    'in Profile.',
                    style: AppTypography.callout(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  _RoleOption(
                    icon: Icons.medical_services_outlined,
                    color: AppColors.doctorColor,
                    title: 'Doctor',
                    detail: 'Admit patients, write notes and orders, follow '
                        'what your team acknowledges.',
                    busy: _saving == UserRole.doctor,
                    enabled: _saving == null,
                    onTap: () => _choose(UserRole.doctor),
                  ),
                  const SizedBox(height: 12),
                  _RoleOption(
                    icon: Icons.health_and_safety_outlined,
                    color: AppColors.nurseColor,
                    title: 'Nurse',
                    detail: 'See every update for your patients and '
                        'acknowledge orders as you act on them.',
                    busy: _saving == UserRole.nurse,
                    enabled: _saving == null,
                    onTap: () => _choose(UserRole.nurse),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ward admins are added by an existing admin.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $detail',
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(AppColors.iconChipOpacity),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.headline(color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(detail,
                        style: AppTypography.subheadline(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : Icon(Icons.chevron_right, color: AppColors.tertiaryLabel),
            ],
          ),
        ),
      ),
    );
  }
}
