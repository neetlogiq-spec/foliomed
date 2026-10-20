import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/electrolytes.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

enum _Topic {
  sodium('Na'),
  potassium('K'),
  calcium('Ca'),
  magnesium('Mg'),
  phosphate('PO₄'),
  gap('Gap');

  const _Topic(this.short);
  final String short;
}

/// Electrolyte arithmetic: deficits, doses to volumes, anion gap and
/// osmolality. Doses come from the unit protocol; the tool does the maths.
class ElectrolytesTool extends StatefulWidget {
  const ElectrolytesTool({super.key});

  @override
  State<ElectrolytesTool> createState() => _ElectrolytesToolState();
}

class _ElectrolytesToolState extends State<ElectrolytesTool> {
  Patient? _baby;
  _Topic _topic = _Topic.sodium;
  final _kg = TextEditingController();
  final _c = <String, TextEditingController>{};

  TextEditingController _f(String key, [String initial = '']) =>
      _c.putIfAbsent(key, () => TextEditingController(text: initial));
  double? _n(String key, [String initial = '']) => readNumber(_f(key, initial));

  @override
  void dispose() {
    _kg.dispose();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  NumberRow _row(String label, String key, String unit, {String initial = '', String? hint}) =>
      NumberRow(label: label, controller: _f(key, initial), unit: unit, placeholder: hint, onChanged: _changed);

  @override
  Widget build(BuildContext context) {
    final kg = readNumber(_kg);
    return ToolPage(
      title: 'Electrolytes',
      method: switch (_topic) {
        _Topic.sodium => 'Deficit (mmol) = (target − current Na) × body water × weight.\n'
            'Free water deficit (L) = body water × weight × (Na ÷ 140 − 1).\n'
            'Corrected Na = Na + 1.6 × (glucose − 100) ÷ 100 (mg/dL).',
        _Topic.gap => 'Anion gap = Na − (Cl + HCO₃) (+ K if entered).\n'
            'Osmolality = 2 × Na + glucose ÷ 18 + BUN ÷ 2.8; BUN = urea ÷ 2.14 (mg/dL).',
        _ => 'Volume (mL) = dose per kg × weight ÷ strength of the stock.',
      },
      source: 'Standard arithmetic. Doses, targets and rates of correction must come from your unit’s protocol — '
          'correct sodium slowly, and give potassium and calcium only with monitoring.',
      children: [
        BabyRow(
          patient: _baby,
          onPicked: (p) => setState(() {
            _baby = p;
            if (p.birthWeightG != null) writeNumber(_kg, p.birthWeightG! / 1000);
          }),
        ),
        const SizedBox(height: 16),
        InsetGroup(dividerIndent: 16, children: [
          NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: _changed),
        ]),
        const SizedBox(height: 16),
        CupertinoSlidingSegmentedControl<_Topic>(
          groupValue: _topic,
          onValueChanged: (v) {
            if (v == null) return;
            Haptics.selection();
            setState(() => _topic = v);
          },
          children: {
            for (final t in _Topic.values)
              t: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(t.short, style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
              ),
          },
        ),
        const SizedBox(height: 20),
        ...switch (_topic) {
          _Topic.sodium => _sodium(kg),
          _Topic.potassium => _dose(kg,
              header: 'Potassium',
              doseKey: 'k_dose',
              doseUnit: 'mmol/kg',
              stockKey: 'k_stock',
              stockUnit: 'mmol/mL',
              stockDefault: '${kKcl15MmolPerMl.toInt()}',
              stockHint: 'KCl 15% = 2 mmol/mL'),
          _Topic.calcium => _calcium(kg),
          _Topic.magnesium => _dose(kg,
              header: 'Magnesium sulphate',
              doseKey: 'mg_dose',
              doseUnit: 'mg/kg',
              stockKey: 'mg_stock',
              stockUnit: 'mg/mL',
              stockDefault: '${kMagnesiumSulphate50MgPerMl.toInt()}',
              stockHint: 'MgSO₄ 50% = 500 mg/mL'),
          _Topic.phosphate => _dose(kg,
              header: 'Phosphate',
              doseKey: 'p_dose',
              doseUnit: 'mmol/kg',
              stockKey: 'p_stock',
              stockUnit: 'mmol/mL',
              stockHint: 'Check your product label'),
          _Topic.gap => _gap(),
        },
      ],
    );
  }

  List<Widget> _sodium(double? kg) {
    final cur = _n('na'), target = _n('na_target', '135'), water = _n('water', '0.7');
    final deficit = kg == null || cur == null || target == null || water == null
        ? null
        : sodiumDeficitMmol(currentNa: cur, targetNa: target, kg: kg, water: water);
    final freeWater = kg == null || cur == null || water == null ? null : freeWaterDeficitL(na: cur, kg: kg, water: water);
    final glucose = _n('glucose');
    return [
      InsetGroup(header: 'Sodium', footer: 'Body water: about 0.7–0.8 in newborns, 0.6 in children.', dividerIndent: 16, children: [
        _row('Sodium', 'na', 'mmol/L'),
        _row('Target', 'na_target', 'mmol/L', initial: '135'),
        _row('Body water', 'water', '× weight', initial: '0.7'),
        _row('Glucose (optional)', 'glucose', 'mg/dL'),
      ]),
      const SizedBox(height: 16),
      ResultCard(
        lines: cur == null
            ? null
            : [
                if (deficit != null && deficit > 0) ...[
                  ('Sodium deficit', '${fmt(deficit, 0)} mmol'),
                  ('As 3% saline', '${fmt(deficit / kNaCl3PercentMmolPerMl, 0)} mL'),
                  ('As 0.9% saline', '${fmt(deficit / kNaCl09PercentMmolPerMl, 0)} mL'),
                ],
                if (freeWater != null && freeWater > 0) ('Free water deficit', '${fmt(freeWater * 1000, 0)} mL'),
                if (glucose != null) ('Corrected for glucose', '${fmt(correctedSodium(na: cur, glucoseMgDl: glucose), 1)} mmol/L'),
                if ((deficit ?? 0) == 0 && (freeWater ?? 0) == 0 && glucose == null) ('Sodium', 'Within 135–140: no deficit'),
              ],
        emptyHint: 'Enter weight and sodium.',
      ),
    ];
  }

  List<Widget> _calcium(double? kg) {
    final mlPerKg = _n('ca_ml', '2');
    final ml = kg == null || mlPerKg == null ? null : mlPerKg * kg;
    return [
      InsetGroup(
        header: 'Calcium gluconate 10%',
        footer: 'Commonly 1–2 mL/kg, slowly over at least 10 minutes with heart-rate monitoring, through a good line.',
        dividerIndent: 16,
        children: [_row('Dose', 'ca_ml', 'mL/kg', initial: '2')],
      ),
      const SizedBox(height: 16),
      ResultCard(
        lines: ml == null
            ? null
            : [
                ('Give', '${fmt(ml)} mL'),
                ('Calcium gluconate', '${fmt(ml * kCalciumGluconate10MgPerMl, 0)} mg'),
                ('Elemental calcium', '${fmt(ml * kCalciumGluconate10ElementalMgPerMl, 0)} mg'),
              ],
        emptyHint: 'Enter the weight.',
      ),
    ];
  }

  List<Widget> _dose(double? kg,
      {required String header,
      required String doseKey,
      required String doseUnit,
      required String stockKey,
      required String stockUnit,
      String stockDefault = '',
      required String stockHint}) {
    final dose = _n(doseKey), stock = _n(stockKey, stockDefault), hours = _n('${doseKey}_h');
    final ml = kg == null || dose == null || stock == null ? null : doseVolumeMl(dosePerKg: dose, kg: kg, stockPerMl: stock);
    return [
      InsetGroup(header: header, footer: 'Stock: $stockHint.', dividerIndent: 16, children: [
        _row('Dose', doseKey, doseUnit, hint: 'from protocol'),
        _row('Stock', stockKey, stockUnit, initial: stockDefault),
        _row('Over (optional)', '${doseKey}_h', 'hours'),
      ]),
      const SizedBox(height: 16),
      ResultCard(
        lines: ml == null
            ? null
            : [
                ('Volume of stock', '${fmt(ml, 2)} mL'),
                ('Total', '${fmt(dose! * kg!, 2)} ${doseUnit.replaceAll('/kg', '')}'),
                if (hours != null) ('Rate', '${fmt(dose / hours, 3)} $doseUnit/h'),
              ],
        emptyHint: 'Enter weight, dose and stock strength.',
      ),
    ];
  }

  List<Widget> _gap() {
    final na = _n('g_na'), cl = _n('g_cl'), hco3 = _n('g_hco3'), k = _n('g_k');
    final glucose = _n('g_glu'), urea = _n('g_urea');
    return [
      InsetGroup(header: 'Blood results', dividerIndent: 16, children: [
        _row('Sodium', 'g_na', 'mmol/L'),
        _row('Chloride', 'g_cl', 'mmol/L'),
        _row('Bicarbonate', 'g_hco3', 'mmol/L'),
        _row('Potassium (optional)', 'g_k', 'mmol/L'),
        _row('Glucose', 'g_glu', 'mg/dL'),
        _row('Urea', 'g_urea', 'mg/dL'),
      ]),
      const SizedBox(height: 16),
      ResultCard(
        lines: na == null
            ? null
            : [
                if (cl != null && hco3 != null) ('Anion gap', '${fmt(anionGap(na: na, cl: cl, hco3: hco3, k: k), 0)} mmol/L'),
                if (glucose != null && urea != null)
                  ('Osmolality', '${fmt(serumOsmolality(na: na, glucoseMgDl: glucose, bunMgDl: bunFromUrea(urea)), 0)} mOsm/kg'),
              ],
        emptyHint: 'Enter sodium with chloride and bicarbonate (gap) or glucose and urea (osmolality).',
      ),
    ];
  }
}
