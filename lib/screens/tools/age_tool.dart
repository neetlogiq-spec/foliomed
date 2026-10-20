import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/neonatal_formulas.dart';
import '../../utils/formatting.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// Postmenstrual age today and, for preterm babies past term, age
/// corrected to 40 weeks.
class AgeTool extends StatefulWidget {
  const AgeTool({super.key});

  @override
  State<AgeTool> createState() => _AgeToolState();
}

class _AgeToolState extends State<AgeTool> {
  Patient? _baby;
  final _weeks = TextEditingController();
  final _days = TextEditingController(text: '0');
  DateTime? _born;

  @override
  void dispose() {
    _weeks.dispose();
    _days.dispose();
    super.dispose();
  }

  void _fromBaby(Patient p) => setState(() {
        _baby = p;
        writeNumber(_weeks, p.gestationWeeks);
        writeNumber(_days, p.gestationDays ?? 0);
        _born = p.bornAt?.toLocal();
      });

  Future<void> _pickBirthDate() async {
    var chosen = _born ?? DateTime.now();
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(onPressed: () => Navigator.pop(ctx, chosen), child: const Text('Done')),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: chosen,
                maximumDate: DateTime.now(),
                minimumDate: DateTime.now().subtract(const Duration(days: 3 * 365)),
                onDateTimeChanged: (d) => chosen = d,
              ),
            ),
          ]),
        ),
      ),
    );
    if (picked != null) setState(() => _born = picked);
  }

  String _span(int days) {
    if (days < 7) return '$days day${days == 1 ? '' : 's'}';
    final w = days ~/ 7, d = days % 7;
    return '$w week${w == 1 ? '' : 's'}${d == 0 ? '' : ' $d day${d == 1 ? '' : 's'}'}';
  }

  @override
  Widget build(BuildContext context) {
    final w = readNumber(_weeks)?.round();
    final d = (double.tryParse(_days.text) ?? 0).round().clamp(0, 6);
    final r = w == null || _born == null || w < 22 || w > 44
        ? null
        : correctedAge(gestationAtBirth: WeeksDays.of(w, d), born: _born!, on: DateTime.now());

    return ToolPage(
      title: 'Corrected Age',
      method: 'Postmenstrual age = gestation at birth + days since birth.\n'
          'Corrected age = days since birth − (40 weeks − gestation at birth), for babies born before 37 weeks once past 40 weeks.',
      source: 'Standard definitions (AAP Committee on Fetus and Newborn, 2004).',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(header: 'At birth', dividerIndent: 16, children: [
          NumberRow(label: 'Gestation', controller: _weeks, unit: 'weeks', onChanged: () => setState(() {})),
          NumberRow(label: '+ days', controller: _days, unit: 'days', onChanged: () => setState(() {})),
          SettingsRow(title: 'Date of birth', value: _born == null ? 'Choose' : formatDay(_born!), onTap: _pickBirthDate),
        ]),
        const SizedBox(height: 16),
        ResultCard(
          lines: r == null
              ? null
              : [
                  ('Postmenstrual age today', '${r.pma.weeks}+${r.pma.days} weeks'),
                  ('Age since birth', _span(r.chronologicalDays)),
                  if (r.correctedDays != null) ('Corrected age', _span(r.correctedDays!)),
                  if (r.correctedDays == null && w! < 37) ('Corrected age', 'from 40 weeks PMA'),
                ],
          emptyHint: 'Enter gestation at birth (22–44 weeks) and date of birth.',
        ),
      ],
    );
  }
}
