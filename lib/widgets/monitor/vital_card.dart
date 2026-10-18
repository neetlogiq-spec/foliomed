import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/monitor_vitals.dart';
import '../../utils/app_theme.dart';

class VitalCard extends StatelessWidget {
  final VitalType type;
  final double value;
  final VitalThreshold threshold;

  const VitalCard({
    super.key,
    required this.type,
    required this.value,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final meta = vitalMeta[type]!;
    final sev = threshold.severity(value);
    final sevColor = sev == 'critical'
        ? AppColors.critical
        : sev == 'warning'
            ? AppColors.warningColor
            : AppColors.stable;
    final sevBg = sev == 'critical'
        ? AppColors.criticalBackground
        : sev == 'warning'
            ? AppColors.warningBackground
            : AppColors.stableBackground;

    String statusText;
    if (sev == 'stable') {
      statusText = 'Normal';
    } else {
      final isLow = (threshold.critLow != null && value < threshold.critLow!) ||
                     (threshold.warnLow != null && value < threshold.warnLow!);
      final dir = isLow ? '↓' : '↑';
      final limitLabel = sev == 'critical' ? 'Critical' : 'Warning';
      final limitVal = isLow
          ? (sev == 'critical' ? threshold.critLow : threshold.warnLow)
          : (sev == 'critical' ? threshold.critHigh : threshold.warnHigh);
      statusText = '$dir $limitLabel (${isLow ? '<' : '>'} ${limitVal?.round()})';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sev != 'stable' ? sevColor.withValues(alpha: 0.4) : AppColors.divider,
          width: sev != 'stable' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, size: 14, color: sevColor),
              const SizedBox(width: 6),
              Text(
                meta.label,
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${value.round()}',
            style: GoogleFonts.dmSans(
              color: sev != 'stable' ? sevColor : AppColors.textPrimary,
              fontSize: 38,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            meta.unit,
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: sevBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.dmSans(
                color: sevColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
