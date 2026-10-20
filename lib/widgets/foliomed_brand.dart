import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// The FolioMed mark: a rounded square in the brand colour holding a
/// page-with-pulse glyph (a patient's folio).
class FolioMedMark extends StatelessWidget {
  const FolioMedMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FolioMed',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color.lerp(AppColors.primary, Colors.black, 0.25)!],
          ),
          // Continuous-corner feel: ~22.5% radius, like an app icon.
          borderRadius: BorderRadius.circular(size * 0.225),
        ),
        child: Icon(Icons.description_outlined, color: Colors.white, size: size * 0.58),
      ),
    );
  }
}

/// Mark + "FolioMed" wordmark, for sign-in and about screens.
class FolioMedLockup extends StatelessWidget {
  const FolioMedLockup({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FolioMedMark(size: size),
        SizedBox(width: size * 0.3),
        Text(
          'FolioMed',
          style: AppTypography.title2(color: AppColors.textPrimary, weight: FontWeight.w700)
              .copyWith(fontSize: size * 0.72, letterSpacing: -0.4),
        ),
      ],
    );
  }
}
