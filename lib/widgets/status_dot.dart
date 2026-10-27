import 'package:flutter/material.dart';

import '../clinical/patient_status.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

Color statusColor(StatusLevel level) => switch (level) {
      StatusLevel.act => AppColors.danger,
      StatusLevel.watch => AppColors.warning,
      StatusLevel.ok => AppColors.stable,
      StatusLevel.unknown => AppColors.tertiaryLabel,
    };

/// The patient's status dot. Shape as well as colour, for colour-blind
/// readers: red is filled, amber is filled inside a ring, green is a
/// ring, grey (no status) is a thin ring. Faded when the hand-set status
/// is due for review.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 11});

  final PatientStatusResult status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status.level);
    final ring = size * 0.18;
    final dot = switch (status.level) {
      StatusLevel.act => BoxDecoration(color: c, shape: BoxShape.circle),
      StatusLevel.watch => BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.card, width: ring),
          boxShadow: [BoxShadow(color: c, spreadRadius: ring)],
        ),
      StatusLevel.ok => BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: ring * 1.4)),
      StatusLevel.unknown => BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: ring * 0.8)),
    };
    return Opacity(
      opacity: status.needsReview ? 0.45 : 1,
      child: SizedBox.square(dimension: size, child: DecoratedBox(decoration: dot)),
    );
  }
}

/// One-line key for the dots, under the Patients filters.
class StatusLegend extends StatelessWidget {
  const StatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(StatusLevel level, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          StatusDot(status: PatientStatusResult(level, const []), size: 9),
          const SizedBox(width: 5),
          Text(label, style: AppTypography.caption1(color: AppColors.textSecondary)),
        ]);
    return Semantics(
      label: 'Status dots: red needs action, amber watch, green settled, grey no status set',
      excludeSemantics: true,
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        item(StatusLevel.act, 'Needs action'),
        item(StatusLevel.watch, 'Watch'),
        item(StatusLevel.ok, 'Settled'),
        item(StatusLevel.unknown, 'No status'),
      ]),
    );
  }
}
