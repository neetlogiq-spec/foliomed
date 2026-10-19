import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_typography.dart';

import '../models/app_user.dart';
import '../utils/app_theme.dart';
import '../providers/theme_provider.dart';

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool small;

  const RoleBadge({super.key, required this.role, this.small = false});

  Color get _color {
    switch (role) {
      case UserRole.doctor:
        return AppColors.doctorColor;
      case UserRole.nurse:
        return AppColors.nurseColor;
      case UserRole.admin:
        return AppColors.adminColor;
    }
  }

  String get _label {
    switch (role) {
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.nurse:
        return 'Nurse';
      case UserRole.admin:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    // Role colour lives in the dot; the label stays in label colour so it
    // passes contrast (several role tints are under 4.5:1 as text).
    return Semantics(
      label: 'Role: $_label',
      excludeSemantics: true,
      child: Container(
        padding: small
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.quaternaryFill,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              _label,
              style: (small ? AppTypography.caption2 : AppTypography.caption1)(
                color: AppColors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
