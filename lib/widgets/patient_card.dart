import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_typography.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../utils/app_theme.dart';
import 'pressable.dart';
import '../providers/theme_provider.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onTap;

  const PatientCard({super.key, required this.patient, this.onTap});

  static const List<Color> _avatarColors = [
    Color(0xFF1565C0),
    Color(0xFF00838F),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF2E7D32),
  ];

  Color get _avatarColor =>
      _avatarColors[patient.name.hashCode.abs() % _avatarColors.length];

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _avatarColor.withOpacity(0.12),
              child: Text(
                patient.initials,
                style: TextStyle(
                  color: _avatarColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patient.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        // Background contrast alone separates it — no border.
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Bed ${patient.bedNumber}',
                          style: appText(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patient.diagnosis,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  // Hairline groups the metadata into its own zone.
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 0.5, thickness: 0.5),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(patient.admittedAt),
                        style: appText(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      _statusChip(patient.isActive),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filled dot + label (the iOS accessory pattern). The dot carries the
  /// colour; the label stays in label colour so it passes contrast.
  Widget _statusChip(bool active) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    final label = active ? 'Active' : 'Discharged';
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.footnote(
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
