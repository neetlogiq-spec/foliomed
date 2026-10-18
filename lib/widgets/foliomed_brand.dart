import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_theme.dart';
import '../providers/theme_provider.dart';

class FolioMedBrand extends StatelessWidget {
  final double size;

  const FolioMedBrand({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          child: Center(
            child: Text(
              'W',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: size * 0.6,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'FOLIOMED',
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            letterSpacing: size * 0.08,
          ),
        ),
      ],
    );
  }
}
