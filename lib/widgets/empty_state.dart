import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// "Nothing here yet" — a symbol, a one-line title, a hint about what to
/// do, and optionally the button that does it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.tertiaryLabel),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTypography.title3(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.subheadline(color: AppColors.textSecondary)),
          if (buttonLabel != null && onButtonTap != null) ...[
            const SizedBox(height: 18),
            FilledButton.tonal(onPressed: onButtonTap, child: Text(buttonLabel!)),
          ],
        ],
      ),
    );
  }
}
