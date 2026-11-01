import 'package:flutter/material.dart';

import '../../clinical/growth.dart';
import '../../models/patient.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../widgets/inset_group.dart';
import '../growth/growth_screen.dart';
import 'tool_page.dart';

/// WHO z-scores and centiles for one set of measurements (nothing saved).
class GrowthTool extends StatefulWidget {
  const GrowthTool({super.key});

  @override
  State<GrowthTool> createState() => _GrowthToolState();
}

class _GrowthToolState extends State<GrowthTool> {
  Patient? _baby;
  bool _male = true;
  DateTime? _born;
  final _ga = TextEditingController();
  final _kg = TextEditingController();
  final _cm = TextEditingController();
  final _head = TextEditingController();

  @override
  void dispose() {
    for (final c in [_ga, _kg, _cm, _head]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  void _fromBaby(Patient p) => setState(() {
    _baby = p;
    _male = sexOf(p) ?? _male;
    _born = birthDateOf(p)?.$1;
    writeNumber(_ga, p.gestationWeeks);
  });

  Future<void> _pickBorn() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _born ?? now,
      firstDate: DateTime(now.year - 19),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (d != null) setState(() => _born = d);
  }

  @override
  Widget build(BuildContext context) {
    final born = _born;
    final age = born == null ? null : plotAge(born: born, on: DateTime.now(), gestationWeeks: readNumber(_ga)?.round());
    final kg = readNumber(_kg), cm = readNumber(_cm), head = readNumber(_head);
    final results = <(GrowthIndicator, double)>[
      if (kg != null) (GrowthIndicator.weight, kg),
      if (cm != null) (GrowthIndicator.length, cm),
      if (head != null) (GrowthIndicator.head, head),
      if (kg != null && cm != null) (GrowthIndicator.bmi, bmiOf(kg, cm)),
    ];
    return ToolPage(
      title: 'Growth (WHO)',
      method:
          'z = ((value ÷ M)^L − 1) ÷ (L × S), with L, M, S for the sex and age in months (interpolated). '
          'Weight and BMI beyond ±3 SD use WHO’s restricted method. Centile from the normal distribution. '
          'Born before 37 weeks: corrected age until 24 months.',
      source:
          'WHO Child Growth Standards 2006 (0–5 years: weight, length/height, head circumference) and WHO '
          'Growth Reference 2007 (5–19 years: height, BMI). Under 2 years length is measured lying down.',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(
          header: 'Child',
          dividerIndent: 16,
          children: [
            InsetSegmentedRow<bool>(
              label: 'Sex',
              value: _male,
              options: const {true: 'Boy', false: 'Girl'},
              onChanged: (v) => setState(() => _male = v),
            ),
            SettingsRow(
              title: 'Date of birth',
              value: born == null ? 'Choose' : formatDay(born),
              showChevron: true,
              onTap: _pickBorn,
            ),
            NumberRow(label: 'Born at', controller: _ga, unit: 'weeks', placeholder: 'Term', onChanged: _changed),
          ],
        ),
        const SizedBox(height: 20),
        InsetGroup(
          header: 'Measured today',
          dividerIndent: 16,
          children: [
            NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: _changed),
            NumberRow(label: 'Length / height', controller: _cm, unit: 'cm', onChanged: _changed),
            NumberRow(label: 'Head', controller: _head, unit: 'cm', onChanged: _changed),
          ],
        ),
        const SizedBox(height: 16),
        if (age == null)
          const ResultCard(lines: null, emptyHint: 'Choose the date of birth, then enter a measurement.')
        else ...[
          Text(
            'Age ${age.months.toStringAsFixed(1)} months${age.corrected ? ' (corrected)' : ''}',
            style: AppTypography.footnote(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (results.isEmpty) const ResultCard(lines: null, emptyHint: 'Enter a measurement.'),
          for (final (ind, value) in results) ...[
            Builder(
              builder: (context) {
                final z = WhoGrowth.zScore(ind, _male, age.months, value);
                final reading = z == null ? null : growthReading(ind, z, age.months);
                return ResultCard(
                  lines: [
                    (
                      '${ind.title} · ${value.toStringAsFixed(ind == GrowthIndicator.weight ? 2 : 1)} ${ind.unit}',
                      z == null ? 'Outside the WHO tables' : 'z ${z >= 0 ? '+' : ''}${z.toStringAsFixed(2)}',
                    ),
                    if (z != null) ('Centile', centileText(z)),
                    if (reading != null) ('Reading', reading),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}
