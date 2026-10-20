import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/neonatal_formulas.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// Total fluids by day of life, the pump rate, the GIR it gives, and how
/// to mix the dextrose strength you want from two stocks.
class FluidsTool extends StatefulWidget {
  const FluidsTool({super.key});

  @override
  State<FluidsTool> createState() => _FluidsToolState();
}

class _FluidsToolState extends State<FluidsTool> {
  Patient? _baby;
  final _kg = TextEditingController();
  final _day = TextEditingController();
  final _perKg = TextEditingController();
  final _dextrose = TextEditingController(text: '10');
  bool _under1500 = false;
  bool _perKgEdited = false;

  final _mixTarget = TextEditingController(text: '12.5');
  final _mixVolume = TextEditingController(text: '50');
  final _weak = TextEditingController(text: '10');
  final _strong = TextEditingController(text: '25');

  @override
  void dispose() {
    for (final c in [_kg, _day, _perKg, _dextrose, _mixTarget, _mixVolume, _weak, _strong]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fromBaby(Patient p) {
    setState(() {
      _baby = p;
      if (p.birthWeightG != null) {
        writeNumber(_kg, p.birthWeightG! / 1000);
        _under1500 = p.birthWeightG! < 1500;
      }
      if (p.bornAt != null) writeNumber(_day, dayOfLife(p.bornAt!, DateTime.now()));
      _perKgEdited = false;
      _suggest();
    });
  }

  /// Fills mL/kg/day from the table unless someone typed their own.
  void _suggest() {
    final day = readNumber(_day);
    if (_perKgEdited || day == null) return;
    writeNumber(_perKg, totalFluidPerKgDay(dayOfLife: day.round(), under1500g: _under1500));
  }

  void _changed() => setState(_suggest);

  @override
  Widget build(BuildContext context) {
    final kg = readNumber(_kg), perKg = readNumber(_perKg), dex = readNumber(_dextrose);
    final v = kg == null || perKg == null ? null : fluidVolumes(perKg, kg);
    final mix = mixDextrose(
      targetPercent: readNumber(_mixTarget) ?? 0,
      totalMl: readNumber(_mixVolume) ?? 0,
      weakPercent: readNumber(_weak) ?? 0,
      strongPercent: readNumber(_strong) ?? 0,
    );

    return ToolPage(
      title: 'Fluids & Glucose',
      method: 'Total fluid: starts at 60 mL/kg/day (80 if under 1500 g) on day 1 and rises 15 a day to 150.\n'
          'Rate = mL/kg/day × weight ÷ 24.\n'
          'GIR (mg/kg/min) = dextrose % × mL/kg/day ÷ 144.\n'
          'Mixing: strong stock mL = total × (target − weak) ÷ (strong − weak).',
      source: 'Day-of-life table as used in many Indian NICUs (e.g. AIIMS protocols); units vary, so type your own mL/kg/day '
          'to override. GIR is standard arithmetic.',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(header: 'Baby', dividerIndent: 16, children: [
          NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: _changed),
          NumberRow(label: 'Day of life', controller: _day, unit: 'day', onChanged: _changed),
          InsetSegmentedRow<bool>(
            label: 'Birth weight',
            value: _under1500,
            options: const {false: '≥ 1500 g', true: '< 1500 g'},
            onChanged: (v) => setState(() {
              _under1500 = v;
              _suggest();
            }),
          ),
        ]),
        const SizedBox(height: 20),
        InsetGroup(header: 'Fluids', dividerIndent: 16, children: [
          NumberRow(
            label: 'Total fluid',
            controller: _perKg,
            unit: 'mL/kg/day',
            onChanged: () => setState(() => _perKgEdited = true),
          ),
          NumberRow(label: 'Dextrose', controller: _dextrose, unit: '%', onChanged: _changed),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: v == null
              ? null
              : [
                  ('Pump rate', '${fmt(v.perHour)} mL/h'),
                  ('Per day', '${fmt(v.perDay, 0)} mL'),
                  if (dex != null) ('GIR', '${fmt(gir(dextrosePercent: dex, mlPerKgDay: perKg!))} mg/kg/min'),
                ],
          emptyHint: 'Enter weight and total fluid (or day of life).',
        ),
        const SizedBox(height: 28),
        InsetGroup(header: 'Mix a dextrose strength', dividerIndent: 16, children: [
          NumberRow(label: 'Wanted', controller: _mixTarget, unit: '%', onChanged: _changed),
          NumberRow(label: 'Total volume', controller: _mixVolume, unit: 'mL', onChanged: _changed),
          NumberRow(label: 'Weaker stock', controller: _weak, unit: '%', onChanged: _changed),
          NumberRow(label: 'Stronger stock', controller: _strong, unit: '%', onChanged: _changed),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: mix == null
              ? null
              : [
                  ('Stronger stock', '${fmt(mix.strongMl)} mL'),
                  ('Weaker stock', '${fmt(mix.weakMl)} mL'),
                ],
          emptyHint: 'The wanted strength must lie between the two stocks.',
        ),
      ],
    );
  }
}
