import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/electrolytes.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// Dextrose bolus for low blood glucose, and the infusion rate for a GIR.
class HypoglycaemiaTool extends StatefulWidget {
  const HypoglycaemiaTool({super.key});

  @override
  State<HypoglycaemiaTool> createState() => _HypoglycaemiaToolState();
}

class _HypoglycaemiaToolState extends State<HypoglycaemiaTool> {
  Patient? _baby;
  final _kg = TextEditingController();
  final _bolus = TextEditingController(text: '2');
  final _bolusPct = TextEditingController(text: '10');
  final _gir = TextEditingController(text: '6');
  final _infPct = TextEditingController(text: '10');

  @override
  void dispose() {
    for (final c in [_kg, _bolus, _bolusPct, _gir, _infPct]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final kg = readNumber(_kg), bolus = readNumber(_bolus), pct = readNumber(_bolusPct);
    final gir = readNumber(_gir), infPct = readNumber(_infPct);
    final b = kg == null || bolus == null || pct == null
        ? null
        : dextroseBolus(kg: kg, mlPerKg: bolus, dextrosePercent: pct);
    final rate = kg == null || gir == null || infPct == null
        ? null
        : rateForGir(girMgKgMin: gir, kg: kg, dextrosePercent: infPct);
    return ToolPage(
      title: 'Low Blood Glucose',
      method: 'Bolus mL = mL/kg × weight. Glucose given (mg/kg) = mL/kg × dextrose % × 10.\n'
          'Infusion rate (mL/h) = GIR × weight × 6 ÷ dextrose %.',
      source: 'Defaults follow AAP Committee on Fetus and Newborn, Pediatrics 2011 (200 mg/kg = 2 mL/kg of 10% '
          'dextrose, then an infusion of about 5–8 mg/kg/min). Use your unit’s protocol for when to treat, and '
          'recheck glucose 30–60 minutes after.',
      children: [
        BabyRow(
          patient: _baby,
          onPicked: (p) => setState(() {
            _baby = p;
            if (p.birthWeightG != null) writeNumber(_kg, p.birthWeightG! / 1000);
          }),
        ),
        const SizedBox(height: 20),
        InsetGroup(header: 'Bolus', dividerIndent: 16, children: [
          NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: _changed),
          NumberRow(label: 'Volume', controller: _bolus, unit: 'mL/kg', onChanged: _changed),
          NumberRow(label: 'Dextrose', controller: _bolusPct, unit: '%', onChanged: _changed),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: b == null ? null : [('Give', '${fmt(b.ml)} mL'), ('Glucose', '${fmt(b.mgPerKg, 0)} mg/kg')],
          emptyHint: 'Enter the weight.',
        ),
        const SizedBox(height: 28),
        InsetGroup(header: 'Then an infusion', dividerIndent: 16, children: [
          NumberRow(label: 'Target GIR', controller: _gir, unit: 'mg/kg/min', onChanged: _changed),
          NumberRow(label: 'Dextrose', controller: _infPct, unit: '%', onChanged: _changed),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: rate == null
              ? null
              : [('Pump rate', '${fmt(rate)} mL/h'), ('Per day', '${fmt(rate * 24 / kg!, 0)} mL/kg/day')],
          emptyHint: 'Enter the weight above.',
        ),
      ],
    );
  }
}
