import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

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

    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: GoogleFonts.dmSans(
          color: _color,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
