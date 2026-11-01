import 'package:flutter/material.dart';

import '../../clinical/growth.dart';
import '../../models/newborn_tracking.dart';
import '../../models/patient.dart';
import '../../services/measurement_service.dart';
import '../../services/tracking_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/growth_chart.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../tools/tool_page.dart';

/// Date of birth for growth: the birth time, else estimated from the age
/// given at admission. The bool says whether it is an estimate.
(DateTime, bool)? birthDateOf(Patient p) {
  if (p.bornAt != null) return (p.bornAt!, false);
  final days = switch (p.ageUnit) {
    AgeUnit.days => p.age.toDouble(),
    AgeUnit.months => p.age * kDaysPerMonth,
    AgeUnit.years => p.age * 365.25,
  };
  if (p.age <= 0 && p.ageUnit == AgeUnit.years) return null;
  return (p.admittedAt.subtract(Duration(hours: (days * 24).round())), true);
}

bool? sexOf(Patient p) => switch (p.gender.toLowerCase()) {
  'male' => true,
  'female' => false,
  _ => null,
};

/// One child's WHO growth charts from their recorded weights, lengths and
/// head circumferences.
class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key, required this.patient});
  final Patient patient;

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  late final Stream<List<WeightEntry>> _weights = TrackingService().weights(widget.patient.id);
  late final Stream<List<Measurement>> _measures = MeasurementService().watch(widget.patient.id);
  GrowthIndicator _ind = GrowthIndicator.weight;
  late bool? _male = sexOf(widget.patient);

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final dob = birthDateOf(p);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<List<WeightEntry>>(
        stream: _weights,
        builder: (context, ws) => StreamBuilder<List<Measurement>>(
          stream: _measures,
          builder: (context, ms) => CustomScrollView(
            slivers: [
              LargeTitleAppBar(title: 'Growth', eyebrow: p.name, showBackButton: true),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList.list(
                  children: [
                    if (dob == null)
                      Text(
                        'Add the date of birth or age to plot growth.',
                        style: AppTypography.body(color: AppColors.textSecondary),
                      )
                    else
                      ..._body(dob.$1, dob.$2, ws.data ?? const [], ms.data ?? const []),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(DateTime born, bool estimated, List<WeightEntry> weights, List<Measurement> measures) {
    final p = widget.patient;
    final male = _male;
    final rows = <(DateTime, double)>[];
    switch (_ind) {
      case GrowthIndicator.weight:
        rows.addAll([for (final w in weights) (w.measuredAt, w.grams / 1000)]);
      case GrowthIndicator.length:
        rows.addAll([
          for (final m in measures)
            if (m.lengthCm != null) (m.measuredAt, m.lengthCm!),
        ]);
      case GrowthIndicator.head:
        rows.addAll([
          for (final m in measures)
            if (m.headCm != null) (m.measuredAt, m.headCm!),
        ]);
      case GrowthIndicator.bmi:
        for (final m in measures.where((m) => m.lengthCm != null)) {
          final near = weights.where((w) => w.measuredAt.difference(m.measuredAt).inDays.abs() <= 7).toList()
            ..sort(
              (a, b) =>
                  a.measuredAt.difference(m.measuredAt).abs().compareTo(b.measuredAt.difference(m.measuredAt).abs()),
            );
          if (near.isNotEmpty) rows.add((m.measuredAt, bmiOf(near.first.grams / 1000, m.lengthCm!)));
        }
    }
    final ages = [for (final r in rows) plotAge(born: born, on: r.$1, gestationWeeks: p.gestationWeeks)];
    final corrected = ages.any((a) => a.corrected);
    final points = [for (final (i, r) in rows.indexed) GrowthPoint(ages[i].months, r.$2)];
    return [
      InsetGroup(
        dividerIndent: 16,
        children: [
          if (sexOf(p) == null)
            InsetSegmentedRow<bool>(
              label: 'Chart',
              value: male,
              options: const {true: 'Boy', false: 'Girl'},
              onChanged: (v) => setState(() => _male = v),
            ),
          InsetSegmentedRow<GrowthIndicator>(
            label: 'Measure',
            value: _ind,
            options: {for (final i in GrowthIndicator.values) i: i.short},
            onChanged: (v) => setState(() => _ind = v),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (male == null)
        Text('Choose boy or girl charts.', style: AppTypography.body(color: AppColors.textSecondary))
      else ...[
        Container(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
          child: GrowthChart(indicator: _ind, male: male, points: points),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            '${_ind.title} (${_ind.unit}), WHO ${_ind == GrowthIndicator.bmi ? 'Growth Reference 2007' : 'Child Growth Standards'}. '
            'Lines at −3, −2, 0, +2 and +3 SD.'
            '${corrected ? ' Plotted at corrected age (born before 37 weeks).' : ''}'
            '${estimated ? ' Age estimated from the age at admission.' : ''}',
            style: AppTypography.footnote(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 20),
        InsetGroup(
          header: 'Measurements',
          dividerIndent: 16,
          children: [
            if (rows.isEmpty) SettingsRow(title: 'No ${_ind.short.toLowerCase()} recorded yet'),
            for (final (i, r) in rows.indexed.toList().reversed)
              Builder(
                builder: (context) {
                  final z = WhoGrowth.zScore(_ind, male, ages[i].months, r.$2);
                  final reading = z == null ? null : growthReading(_ind, z, ages[i].months);
                  return SettingsRow(
                    icon: reading == null ? null : Icons.flag_outlined,
                    iconColor: reading == null ? null : AppColors.warning,
                    title: '${r.$2.toStringAsFixed(_ind == GrowthIndicator.weight ? 2 : 1)} ${_ind.unit}',
                    subtitle: [
                      formatDay(r.$1),
                      if (z != null)
                        'z ${z >= 0 ? '+' : ''}${z.toStringAsFixed(2)} · ${centileText(z)}'
                      else
                        'outside the WHO tables',
                      ?reading,
                    ].join(' · '),
                  );
                },
              ),
            if (p.isActive)
              SettingsRow(
                icon: Icons.add,
                title: 'Add Measurement',
                showChevron: true,
                onTap: () => showAppSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _AddMeasurement(patient: p),
                ),
              ),
          ],
        ),
      ],
    ];
  }
}

class _AddMeasurement extends StatefulWidget {
  const _AddMeasurement({required this.patient});
  final Patient patient;

  @override
  State<_AddMeasurement> createState() => _AddMeasurementState();
}

class _AddMeasurementState extends State<_AddMeasurement> {
  final _kg = TextEditingController();
  final _cm = TextEditingController();
  final _head = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_kg, _cm, _head]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final kg = readNumber(_kg), cm = readNumber(_cm), head = readNumber(_head);
    if (kg == null && cm == null && head == null) return;
    final p = widget.patient;
    final now = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      if (kg != null) {
        await TrackingService().addWeight(
          patientId: p.id,
          wardId: p.wardId,
          measuredAt: now,
          grams: (kg * 1000).round(),
        );
      }
      if (cm != null || head != null) {
        await MeasurementService().add(patientId: p.id, wardId: p.wardId, measuredAt: now, lengthCm: cm, headCm: head);
      }
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Measurement saved')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Measurement', style: AppTypography.title3(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          InsetGroup(
            dividerIndent: 16,
            footer: 'Measured now. Under 2 years, measure length lying down.',
            children: [
              NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: () => setState(() {})),
              NumberRow(label: 'Length / height', controller: _cm, unit: 'cm', onChanged: () => setState(() {})),
              NumberRow(label: 'Head', controller: _head, unit: 'cm', onChanged: () => setState(() {})),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
    ),
  );
}
