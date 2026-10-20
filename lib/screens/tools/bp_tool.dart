import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/bp_centiles.dart';
import '../../tools/neonatal_formulas.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// Where a baby's blood pressure sits against the Dionne 2012 centiles.
class BpTool extends StatefulWidget {
  const BpTool({super.key});

  @override
  State<BpTool> createState() => _BpToolState();
}

class _BpToolState extends State<BpTool> {
  Patient? _baby;
  final _pma = TextEditingController();
  final _sbp = TextEditingController();
  final _dbp = TextEditingController();
  final _map = TextEditingController();

  @override
  void dispose() {
    for (final c in [_pma, _sbp, _dbp, _map]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fromBaby(Patient p) => setState(() {
        _baby = p;
        if (p.gestationWeeks != null && p.bornAt != null) {
          final r = correctedAge(
              gestationAtBirth: WeeksDays.of(p.gestationWeeks!, p.gestationDays ?? 0),
              born: p.bornAt!.toLocal(),
              on: DateTime.now());
          writeNumber(_pma, double.parse((r.pma.totalDays / 7).toStringAsFixed(1)));
        }
      });

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pma = readNumber(_pma);
    final row = pma == null ? null : bpRowFor(pma);
    (String, String)? line(String label, TextEditingController c, (int, int, int) centiles) {
      final v = readNumber(c)?.round();
      if (v == null) return null;
      return (label, '$v · ${bpBand(v, centiles).label.toLowerCase()}');
    }

    final measured = row == null
        ? <(String, String)>[]
        : [
            line('Systolic', _sbp, row.sbp),
            line('Mean', _map, row.map),
            line('Diastolic', _dbp, row.dbp),
          ].whereType<(String, String)>().toList();

    return ToolPage(
      title: 'Blood Pressure',
      method: 'Centiles for the nearest postmenstrual age in the table (26–44 weeks, in 2-week steps). '
          'At or above the 95th centile on repeated readings suggests hypertension; at or above the 99th needs '
          'prompt review.',
      source: 'Dionne JM, Abitbol CL, Flynn JT. Pediatr Nephrol 2012;27:17–32 (values for infants after 2 weeks '
          'of age). In the first days of life many units use mean BP ≥ gestation in weeks as a rough lower limit.',
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(header: 'Baby', dividerIndent: 16, children: [
          NumberRow(label: 'Postmenstrual age', controller: _pma, unit: 'weeks', onChanged: _changed),
        ]),
        const SizedBox(height: 16),
        if (row != null) _CentileTable(row: row),
        if (pma != null && row == null)
          Text('The table covers 26–44 weeks postmenstrual age.',
              style: AppTypography.footnote(color: AppColors.danger)),
        const SizedBox(height: 20),
        InsetGroup(header: 'Measured (optional)', dividerIndent: 16, children: [
          NumberRow(label: 'Systolic', controller: _sbp, unit: 'mmHg', onChanged: _changed),
          NumberRow(label: 'Mean', controller: _map, unit: 'mmHg', onChanged: _changed),
          NumberRow(label: 'Diastolic', controller: _dbp, unit: 'mmHg', onChanged: _changed),
        ]),
        if (measured.isNotEmpty) ...[
          const SizedBox(height: 16),
          ResultCard(lines: measured),
        ],
      ],
    );
  }
}

class _CentileTable extends StatelessWidget {
  const _CentileTable({required this.row});
  final BpRow row;

  @override
  Widget build(BuildContext context) {
    TableRow r(String label, (int, int, int) c, {bool head = false}) => TableRow(children: [
          for (final t in [label, '${c.$1}', '${c.$2}', '${c.$3}'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(t,
                  textAlign: t == label ? TextAlign.start : TextAlign.end,
                  style: AppTypography.subheadline(
                    color: t == label ? AppColors.textSecondary : AppColors.textPrimary,
                    weight: t == label ? null : FontWeight.w600,
                  ).copyWith(fontFeatures: AppTypography.tabular)),
            ),
        ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${row.pmaWeeks} weeks · centiles (mmHg)', style: AppTypography.footnote(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Table(columnWidths: const {0: FlexColumnWidth(1.4)}, children: [
          TableRow(children: [
            for (final t in ['', '50th', '95th', '99th'])
              Text(t, textAlign: TextAlign.end, style: AppTypography.caption1(color: AppColors.textSecondary)),
          ]),
          r('Systolic', row.sbp),
          r('Mean', row.map),
          r('Diastolic', row.dbp),
        ]),
      ]),
    );
  }
}
