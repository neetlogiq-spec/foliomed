import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/monitor_vitals.dart';
import '../../utils/app_theme.dart';

class BPCard extends StatelessWidget {
  final Map<VitalType, double> vitals;
  final Map<VitalType, VitalThreshold> thresholds;

  const BPCard({super.key, required this.vitals, required this.thresholds});

  @override
  Widget build(BuildContext context) {
    final sbp = vitals[VitalType.sbp] ?? 0;
    final dbp = vitals[VitalType.dbp] ?? 0;
    final map = vitals[VitalType.map] ?? 0;

    String sev = 'stable';
    String msg = 'All within range';
    for (final vt in [VitalType.sbp, VitalType.dbp, VitalType.map]) {
      final thr = thresholds[vt];
      if (thr == null) continue;
      final val = vitals[vt] ?? 0;
      final s = thr.severity(val);
      if (s == 'critical') {
        sev = 'critical';
        final meta = vitalMeta[vt]!;
        msg = '${meta.label} critically ${val < (thr.critLow ?? 0) ? "low" : "high"}: ${val.round()} mmHg';
        break;
      }
      if (s == 'warning' && sev != 'critical') {
        sev = 'warning';
        final meta = vitalMeta[vt]!;
        msg = '${meta.label} ${val < (thr.warnLow ?? 0) ? "low" : "high"}: ${val.round()} mmHg';
      }
    }

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
              const Icon(Icons.swap_vert, size: 14),
              const SizedBox(width: 6),
              Text(
                'Blood Pressure',
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${sbp.round()}',
                style: GoogleFonts.dmSans(
                  color: sev != 'stable' ? sevColor : AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '/',
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
              ),
              Text(
                '${dbp.round()}',
                style: GoogleFonts.dmSans(
                  color: sev != 'stable' ? sevColor : AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('MAP', style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('${map.round()}', style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text('mmHg', style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: sevBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sev == 'stable' ? msg : '↓ $msg',
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
