import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/neonatal_formulas.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// Double-volume exchange (hyperbilirubinaemia) and partial exchange
/// (polycythaemia) volumes.
class ExchangeTool extends StatefulWidget {
  const ExchangeTool({super.key});

  @override
  State<ExchangeTool> createState() => _ExchangeToolState();
}

class _ExchangeToolState extends State<ExchangeTool> {
  Patient? _baby;
  final _kg = TextEditingController();
  final _hct = TextEditingController();
  final _targetHct = TextEditingController(text: '55');
  bool _preterm = false;

  @override
  void dispose() {
    for (final c in [_kg, _hct, _targetHct]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fromBaby(Patient p) => setState(() {
        _baby = p;
        if (p.birthWeightG != null) writeNumber(_kg, p.birthWeightG! / 1000);
        if (p.gestationWeeks != null) _preterm = p.gestationWeeks! < 37;
      });

  @override
  Widget build(BuildContext context) {
    final kg = readNumber(_kg), hct = readNumber(_hct), target = readNumber(_targetHct) ?? 55;
    final bv = bloodVolumePerKg(preterm: _preterm);
    return ToolPage(
      title: 'Exchange Transfusion',
      method: 'Blood volume ≈ $bv mL/kg (${_preterm ? 'preterm' : 'term'}).\n'
          'Double-volume exchange = 2 × blood volume × weight.\n'
          'Partial exchange volume = blood volume × weight × (observed Hct − target Hct) ÷ observed Hct.',
      source: 'Blood volume ~85 mL/kg at term and ~100 mL/kg preterm (textbook ranges 80–90 and 90–105). '
          'Use the weight your unit uses (birth or current) and your protocol for aliquot size and rate.',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(header: 'Baby', dividerIndent: 16, children: [
          NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: () => setState(() {})),
          InsetSegmentedRow<bool>(
            label: 'Born',
            value: _preterm,
            options: const {false: 'Term', true: 'Preterm'},
            onChanged: (v) => setState(() => _preterm = v),
          ),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: kg == null
              ? null
              : [
                  ('Double-volume exchange', '${fmt(doubleVolumeExchangeMl(kg: kg, preterm: _preterm), 0)} mL'),
                  ('Estimated blood volume', '${fmt(bv * kg, 0)} mL'),
                ],
          emptyHint: 'Enter the weight.',
        ),
        const SizedBox(height: 28),
        InsetGroup(header: 'Partial exchange (polycythaemia)', dividerIndent: 16, children: [
          NumberRow(label: 'Observed Hct', controller: _hct, unit: '%', onChanged: () => setState(() {})),
          NumberRow(label: 'Target Hct', controller: _targetHct, unit: '%', onChanged: () => setState(() {})),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: kg == null || hct == null
              ? null
              : hct <= target
                  ? [('Volume to exchange', 'None'), ('Hct', 'at or below target')]
                  : [
                      (
                        'Volume to exchange',
                        '${fmt(partialExchangeMl(kg: kg, preterm: _preterm, observedHct: hct, targetHct: target), 0)} mL'
                      ),
                    ],
          emptyHint: 'Enter weight and observed haematocrit.',
        ),
      ],
    );
  }
}
