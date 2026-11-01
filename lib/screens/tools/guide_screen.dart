import 'package:flutter/material.dart';

import '../../guides/guide_model.dart';
import '../../models/patient.dart';
import '../../services/tracking_service.dart';
import '../../tools/drugs/drug_list.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import 'drugs/drug_widgets.dart';
import 'tool_page.dart';

/// One emergency guide: red flags, then numbered steps with doses worked
/// out for the weight.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.guide});
  final Guide guide;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  Patient? _baby;
  final _kg = TextEditingController();

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _fromBaby(Patient p) async {
    setState(() {
      _baby = p;
      writeNumber(_kg, dosingWeightKg(birthGrams: p.birthWeightG));
    });
    try {
      final g = (await TrackingService().snapshot([p.id])).latestWeight[p.id]?.grams;
      if (mounted && g != null && _baby?.id == p.id) setState(() => writeNumber(_kg, dosingWeightKg(latestGrams: g)));
    } catch (_) {
      // Keep the birth weight.
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final kg = readNumber(_kg);
    return ToolPage(
      title: g.title,
      method: 'Doses are per kg × weight, limited to the maximum shown. Timings are from the start of the emergency.',
      source: '${g.source} Decision support only — follow your unit protocol and senior advice.',
      children: [
        if (g.redFlags.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RED FLAGS',
                  style: AppTypography.caption1(color: AppColors.danger, weight: FontWeight.w700),
                ),
                for (final f in g.redFlags)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• $f', style: AppTypography.subheadline(color: AppColors.textPrimary)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (g.needsWeight || g.steps.any((s) => s.doses.isNotEmpty)) ...[
          BabyRow(patient: _baby, onPicked: _fromBaby),
          const SizedBox(height: 12),
          InsetGroup(
            children: [NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: () => setState(() {}))],
          ),
          const SizedBox(height: 16),
        ],
        for (final (i, s) in g.steps.indexed) ...[
          _StepCard(number: i + 1, step: s, kg: kg),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.step, required this.kg});
  final int number;
  final GuideStep step;
  final double? kg;

  @override
  Widget build(BuildContext context) {
    final s = step;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.primary,
                child: Text(
                  '$number',
                  style: AppTypography.footnote(color: AppColors.onPrimary, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.title, style: AppTypography.headline(color: AppColors.textPrimary)),
              ),
              if (s.when != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    s.when!,
                    style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          for (final p in s.points)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('• $p', style: AppTypography.subheadline(color: AppColors.textPrimary)),
            ),
          for (final d in s.doses) _DoseLine(dose: d, kg: kg),
          if (s.caution != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(s.caution!, style: AppTypography.footnote(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DoseLine extends StatelessWidget {
  const _DoseLine({required this.dose, required this.kg});
  final GuideDose dose;
  final double? kg;

  @override
  Widget build(BuildContext context) {
    final w = kg;
    final worked = w == null ? null : dose.forWeight(w);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.label,
                  style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600),
                ),
                Text(
                  [dose.perKg, ?dose.how].join(' · '),
                  style: AppTypography.footnote(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (worked != null) ...[
            const SizedBox(width: 10),
            Text(
              '${rangeText(worked.$1, worked.$2, doseText)} ${dose.unit}${worked.$3 ? ' (max)' : ''}',
              style: AppTypography.headline(color: AppColors.textPrimary).copyWith(fontFeatures: AppTypography.tabular),
            ),
          ],
        ],
      ),
    );
  }
}
