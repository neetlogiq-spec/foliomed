import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/drugs/drug_list.dart';
import '../../tools/drugs/drug_model.dart';
import '../../tools/resus.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import '../growth/growth_screen.dart';
import 'drugs/drug_widgets.dart';
import 'emergency_drugs_tool.dart';
import 'tool_page.dart';

/// (drug key, which of its uses) for the card, in resuscitation order.
const _cardDrugs = [
  ('adrenaline', 'Cardiac arrest'),
  ('adrenaline', 'Resuscitation'),
  ('saline', null),
  ('glucose10', null),
  ('atropine', null),
  ('adenosine', null),
  ('amiodarone', 'Arrest — VF / pulseless VT'),
  ('calcium_chloride', null),
  ('sodium_bicarbonate', null),
  ('midazolam', 'Seizures'),
];

/// Everything for a child's resuscitation on one screen, from age (and
/// weight when known): weight estimate, normal signs, tubes, shocks and
/// the first drugs.
class ResusTool extends StatefulWidget {
  const ResusTool({super.key});

  @override
  State<ResusTool> createState() => _ResusToolState();
}

class _ResusToolState extends State<ResusTool> {
  Patient? _baby;
  final _years = TextEditingController();
  final _months = TextEditingController();
  final _kg = TextEditingController();

  @override
  void dispose() {
    for (final c in [_years, _months, _kg]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  void _fromBaby(Patient p) => setState(() {
    _baby = p;
    final born = birthDateOf(p)?.$1;
    if (born != null) {
      final m = DateTime.now().difference(born).inDays / 30.4375;
      writeNumber(_years, (m / 12).floor());
      writeNumber(_months, (m % 12).floor());
    }
    if (p.birthWeightG != null && born != null && DateTime.now().difference(born).inDays < 28) {
      writeNumber(_kg, p.birthWeightG! / 1000);
    }
  });

  double? get _ageMonths {
    final y = double.tryParse(_years.text.trim()), m = double.tryParse(_months.text.trim());
    if (y == null && m == null) return null;
    return (y ?? 0) * 12 + (m ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final age = _ageMonths;
    final estimated = age == null ? null : estimatedWeightKg(age);
    final actual = readNumber(_kg);
    final kg = actual ?? estimated;
    final neonate = age != null && age < 1;
    final care = neonate ? CareSetting.nicu : CareSetting.picu;
    return ToolPage(
      title: 'Resuscitation Card',
      method:
          'Estimated weight (APLS): 0–12 months 0.5 × months + 4; 1–5 years 2 × years + 8; 6–12 years 3 × years + 7.\n'
          'Tubes from 1 year: cuffed age/4 + 3.5, uncuffed age/4 + 4 (mm); oral depth age/2 + 12 cm.\n'
          'Hypotension (PALS): under 60 (newborn), 70 (to 1 year), 70 + 2 × age (1–10 years), 90 (over 10).\n'
          'Shocks: VF/pulseless VT 2 then 4 J/kg; synchronised cardioversion 0.5–1 then 2 J/kg.',
      source:
          'APLS (Advanced Paediatric Life Support) formulas and normal ranges; AHA PALS 2020; drug doses from '
          'FolioMed’s drug list (see Emergency Drugs). Use the actual weight whenever you have it.',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(
          dividerIndent: 16,
          footer: 'Weight, if known, replaces the estimate.',
          children: [
            NumberRow(label: 'Age', controller: _years, unit: 'years', onChanged: _changed),
            NumberRow(label: 'and', controller: _months, unit: 'months', onChanged: _changed),
            NumberRow(label: 'Weight', controller: _kg, unit: 'kg', placeholder: 'Estimate', onChanged: _changed),
          ],
        ),
        const SizedBox(height: 16),
        if (age == null)
          const ResultCard(lines: null, emptyHint: 'Enter the age.')
        else ...[
          _Card(
            title: 'Weight',
            lines: [
              (
                kg == null ? 'Weigh the child' : '${trimNum(kg, 1)} kg',
                actual != null ? 'measured' : (estimated == null ? 'no estimate over 12 years' : 'estimated from age'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final v = normalVitals(age);
              return _Card(
                title: 'Normal at rest · ${v.ageBand}',
                lines: [
                  ('Breathing ${v.rr.$1}–${v.rr.$2}/min', 'Heart ${v.hr.$1}–${v.hr.$2}/min'),
                  ('Systolic ${v.sbp.$1}–${v.sbp.$2} mmHg', 'Low if under ${hypotensionSbp(age)} mmHg'),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (tubeSizes(age) case final t?)
            _Card(
              title: 'Airway',
              lines: [
                (
                  'Tube ${trimNum(t.cuffed)} cuffed / ${trimNum(t.uncuffed)} uncuffed',
                  'Oral depth ${trimNum(t.oralCm)} cm',
                ),
                ('Suction ${t.suctionFr} Fr', kg == null ? 'LMA by weight' : 'LMA size ${lmaSize(kg)}'),
              ],
            )
          else
            _Card(
              title: 'Airway',
              lines: [('Newborn: size the tube by weight', kg == null ? '' : 'LMA size ${lmaSize(kg)}')],
            ),
          if (kg != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final e = shockEnergies(kg);
                return _Card(
                  title: 'Shocks',
                  lines: [
                    ('VF / pulseless VT', '${e.vf1} J, then ${e.vf2} J'),
                    ('Cardioversion (synchronised)', '${e.cv1} J, then ${e.cv2} J'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _DrugCard(kg: kg, care: care),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).push(CupertinoPageRoute(builder: (_) => EmergencyDrugsTool(initialCare: care))),
            icon: const Icon(Icons.emergency_outlined),
            label: const Text('All Emergency Drugs'),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.lines});
  final String title;
  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600),
        ),
        for (final (a, b) in lines)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(a, style: AppTypography.headline(color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    b,
                    textAlign: TextAlign.end,
                    style: AppTypography.subheadline(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _DrugCard extends StatelessWidget {
  const _DrugCard({required this.kg, required this.care});
  final double kg;
  final CareSetting care;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    for (final (key, label) in _cardDrugs) {
      final d = drugByKey(key);
      if (d == null) continue;
      for (final use in d.bolusesFor(care)) {
        if (label != null && use.label != label) continue;
        if (label == null && rows.any((r) => r.$1.startsWith(d.name))) continue;
        final dose = bolusDose(use, d, kg);
        final u = use.unit.label;
        final amount = '${rangeText(dose.low, dose.high, doseText)} $u';
        final vol = use.unit == Amount.mL
            ? ''
            : ' = ${rangeText(dose.volumeLow, dose.volumeHigh, (v) => doseText(roundDraw(v)))} mL of ${dose.strength.label}';
        rows.add(('${d.name} · ${use.label}${use.route.contains('Endo') ? ' (ET)' : ''}', '$amount$vol'));
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIRST DRUGS · ${care.label}',
            style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600),
          ),
          for (final (name, dose) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.subheadline(color: AppColors.textSecondary)),
                  Text(dose, style: AppTypography.headline(color: AppColors.textPrimary)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Dilutions, repeats and limits: tap All Emergency Drugs. Check with a second person.',
            style: AppTypography.footnote(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
