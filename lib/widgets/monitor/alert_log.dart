import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/monitor_alert.dart';
import '../../utils/app_theme.dart';

class AlertLog extends StatelessWidget {
  final List<MonitorAlert> alerts;

  const AlertLog({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Alert log', style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              Text('${alerts.length} total', style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No alerts yet', style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 13)),
              ),
            )
          else
            ...alerts.take(10).map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.severity == 'critical' ? AppColors.critical : AppColors.warningColor,
                    ),
                  ),
                  Expanded(
                    child: Text(a.message, style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(a.time, allowFromNow: true),
                    style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
