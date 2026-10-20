import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/neonatal_formulas.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// Umbilical catheter lengths and endotracheal tube size and depth.
class LinesTool extends StatefulWidget {
  const LinesTool({super.key});

  @override
  State<LinesTool> createState() => _LinesToolState();
}

class _LinesToolState extends State<LinesTool> {
  Patient? _baby;
  final _kg = TextEditingController();
  final _weeks = TextEditingController();

  @override
  void dispose() {
    _kg.dispose();
    _weeks.dispose();
    super.dispose();
  }

  void _fromBaby(Patient p) => setState(() {
        _baby = p;
        if (p.birthWeightG != null) writeNumber(_kg, p.birthWeightG! / 1000);
        writeNumber(_weeks, p.gestationWeeks);
      });

  @override
  Widget build(BuildContext context) {
    final kg = readNumber(_kg);
    final weeks = readNumber(_weeks)?.round();
    final byGa = weeks == null ? null : ettDepthByGestationCm(weeks);
    return ToolPage(
      title: 'Lines & Tubes',
      method: 'High UAC (cm) = 3 × weight + 9.\n'
          'UVC (cm) = UAC ÷ 2 + 1.\n'
          'ETT size: under 1 kg 2.5 mm, 1–2 kg 3.0 mm, over 2 kg 3.5 mm.\n'
          'ETT depth at the lip: weight (kg) + 6 cm, or by gestation (23–24 wk 5.5 cm … 41–43 wk 9.0 cm).',
      source: 'Shukla & Ferrara, Am J Dis Child 1986 (UAC/UVC); NRP (tube size); Tochen, J Pediatr 1979 (depth by '
          'weight); Kempley et al., Resuscitation 2008 (depth by gestation). Lengths are starting points — always '
          'confirm position on X-ray.',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(header: 'Baby', dividerIndent: 16, children: [
          NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: () => setState(() {})),
          NumberRow(label: 'Gestation', controller: _weeks, unit: 'weeks', onChanged: () => setState(() {})),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: kg == null
              ? null
              : [
                  ('UVC insertion', '${fmt(uvcCm(kg))} cm'),
                  ('High UAC insertion', '${fmt(uacHighCm(kg))} cm'),
                ],
          emptyHint: 'Enter the weight for catheter lengths.',
        ),
        const SizedBox(height: 16),
        ResultCard(
          lines: kg == null && byGa == null
              ? null
              : [
                  if (kg != null) ('ETT size', '${fmt(ettSizeMm(kg))} mm'),
                  if (kg != null) ('Depth at lip, by weight', '${fmt(ettDepthByWeightCm(kg))} cm'),
                  if (byGa != null) ('Depth at lip, by gestation', '${fmt(byGa)} cm'),
                ],
          emptyHint: 'Enter weight or gestation for the tube.',
        ),
      ],
    );
  }
}
