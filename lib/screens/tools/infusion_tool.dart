import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/neonatal_formulas.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

enum _Solve { rate, dose }

/// Pump rate from a dose (or the dose a rate gives) for a drug made up in a
/// syringe. No drug list: you enter the drug amount, volume and dose.
class InfusionTool extends StatefulWidget {
  const InfusionTool({super.key});

  @override
  State<InfusionTool> createState() => _InfusionToolState();
}

class _InfusionToolState extends State<InfusionTool> {
  Patient? _baby;
  final _kg = TextEditingController();
  final _mg = TextEditingController();
  final _ml = TextEditingController(text: '50');
  final _dose = TextEditingController();
  final _rate = TextEditingController();
  DoseUnit _unit = DoseUnit.mcgPerKgMin;
  _Solve _solve = _Solve.rate;

  @override
  void dispose() {
    for (final c in [_kg, _mg, _ml, _dose, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fromBaby(Patient p) => setState(() {
        _baby = p;
        if (p.birthWeightG != null) writeNumber(_kg, p.birthWeightG! / 1000);
      });

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final kg = readNumber(_kg), mg = readNumber(_mg), ml = readNumber(_ml);
    final ready = kg != null && mg != null && ml != null;
    List<(String, String)>? result;
    if (ready && _solve == _Solve.rate && readNumber(_dose) != null) {
      final rate = infusionRateMlPerHour(dose: readNumber(_dose)!, unit: _unit, kg: kg, drugMg: mg, volumeMl: ml);
      result = [('Pump rate', '${fmt(rate, 2)} mL/h'), ('Concentration', '${fmt(mg * 1000 / ml, 1)} mcg/mL')];
    } else if (ready && _solve == _Solve.dose && readNumber(_rate) != null) {
      final dose = doseFromRate(mlPerHour: readNumber(_rate)!, unit: _unit, kg: kg, drugMg: mg, volumeMl: ml);
      result = [('Dose delivered', '${fmt(dose, 2)} ${_unit.label}'), ('Concentration', '${fmt(mg * 1000 / ml, 1)} mcg/mL')];
    }

    return ToolPage(
      title: 'Infusion Rate',
      method: 'Concentration (mcg/mL) = drug (mg) × 1000 ÷ volume (mL).\n'
          'Rate (mL/h) = dose in mcg/kg/h × weight ÷ concentration.\n'
          '(mcg/kg/min × 60 = mcg/kg/h; mg/kg/h × 1000 = mcg/kg/h.)',
      source: 'Standard arithmetic. FolioMed has no drug list on purpose: take the drug, dilution and dose from your unit '
          'formulary, and double-check with a second person.',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(header: 'Syringe', dividerIndent: 16, children: [
          NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: _changed),
          NumberRow(label: 'Drug', controller: _mg, unit: 'mg', onChanged: _changed),
          NumberRow(label: 'Made up to', controller: _ml, unit: 'mL', onChanged: _changed),
        ]),
        const SizedBox(height: 20),
        InsetGroup(dividerIndent: 16, children: [
          InsetSegmentedRow<_Solve>(
            label: 'Work out',
            value: _solve,
            options: const {_Solve.rate: 'Rate', _Solve.dose: 'Dose'},
            onChanged: (v) => setState(() => _solve = v),
          ),
          InsetSegmentedRow<DoseUnit>(
            label: 'Dose unit',
            value: _unit,
            options: {for (final u in DoseUnit.values) u: u.label},
            onChanged: (v) => setState(() => _unit = v),
          ),
          if (_solve == _Solve.rate)
            NumberRow(label: 'Dose', controller: _dose, unit: _unit.label, onChanged: _changed)
          else
            NumberRow(label: 'Pump rate', controller: _rate, unit: 'mL/h', onChanged: _changed),
        ]),
        const SizedBox(height: 16),
        ResultCard(lines: result, emptyHint: 'Enter weight, drug amount, volume and the dose (or rate).'),
      ],
    );
  }
}
