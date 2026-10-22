import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/bp_aap2017.dart';
import '../../tools/bp_centiles.dart';
import '../../tools/bp_zubrow.dart';
import '../../tools/neonatal_formulas.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

enum _Mode {
  day1('Day 1'),
  infant('Newborn'),
  child('1–17 Years');

  const _Mode(this.label);
  final String label;
}

/// Where a blood pressure sits for the age: Zubrow 1995 on day one and by
/// post-conceptional age, Dionne 2012 after 2 weeks, AAP 2017 for 1–17 years.
class BpTool extends StatefulWidget {
  const BpTool({super.key});

  @override
  State<BpTool> createState() => _BpToolState();
}

class _BpToolState extends State<BpTool> {
  _Mode _mode = _Mode.infant;
  Patient? _baby;
  bool _male = true;
  final _ga = TextEditingController();
  final _pma = TextEditingController();
  final _years = TextEditingController();
  final _height = TextEditingController();
  final _sbp = TextEditingController();
  final _dbp = TextEditingController();
  final _map = TextEditingController();

  @override
  void dispose() {
    for (final c in [_ga, _pma, _years, _height, _sbp, _dbp, _map]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fromBaby(Patient p) => setState(() {
        _baby = p;
        _male = p.gender != 'Female';
        final now = DateTime.now();
        final ga = p.gestationWeeks;
        if (ga != null) writeNumber(_ga, ga.toDouble());
        if (ga != null && p.bornAt != null) {
          final r = correctedAge(
              gestationAtBirth: WeeksDays.of(ga, p.gestationDays ?? 0), born: p.bornAt!.toLocal(), on: now);
          writeNumber(_pma, double.parse((r.pma.totalDays / 7).toStringAsFixed(1)));
        }
        final years = p.bornAt != null
            ? (now.difference(p.bornAt!).inDays / 365.25).floor()
            : (p.ageUnit == AgeUnit.years ? p.age : 0);
        if (years >= kAapBpFromYears) writeNumber(_years, years.toDouble());
        final hours = p.hoursSinceBirth(now);
        _mode = years >= kAapBpFromYears
            ? _Mode.child
            : (hours != null && hours < 24 ? _Mode.day1 : _Mode.infant);
      });

  void _changed() => setState(() {});

  int? _read(TextEditingController c) => readNumber(c)?.round();

  @override
  Widget build(BuildContext context) {
    final (method, source) = switch (_mode) {
      _Mode.day1 => (
          'Normal range on the first day of life for the gestation at birth, in completed weeks (22–42). '
              'Below the lower limit suggests hypotension in context (perfusion, urine output, lactate).',
          'Zubrow AB, Hulman S, Kushner H, Falkner B. J Perinatol 1995;15:470–9, as tabulated by EPIQ (2022), '
              'Table 1. Limits are the study\'s 95% confidence limits; mean BP was calculated from systolic and diastolic.'
        ),
      _Mode.infant => (
          'Zubrow normal range for the post-conceptional age in completed weeks (24–46), and Dionne centiles '
              'for the nearest postmenstrual age in the table (26–44 weeks, 2-week steps) for babies over 2 weeks old. '
              'At or above the 95th centile on repeated readings suggests hypertension; at or above the 99th needs prompt review.',
          'Zubrow AB et al. J Perinatol 1995;15:470–9 (EPIQ 2022, Table 2). Dionne JM, Abitbol CL, Flynn JT. '
              'Pediatr Nephrol 2012;27:17–32, Table 2.'
        ),
      _Mode.child => (
          'Percentiles for sex, age in completed years and the height column nearest the measured height. '
              'Under 13 years: elevated ≥90th, stage 1 ≥95th, stage 2 ≥95th + 12 mmHg (or 120/80, 130/80, 140/90 '
              'if lower). From 13 years: 120/<80, 130/80 and 140/90. Confirm a high reading with repeat measurements.',
          'Flynn JT et al. Clinical Practice Guideline for Screening and Management of High Blood Pressure in Children '
              'and Adolescents. Pediatrics 2017;140(3):e20171904, Tables 3–5.'
        ),
    };
    return ToolPage(
      title: 'Blood Pressure',
      method: method,
      source: source,
      children: [
        BabyRow(patient: _baby, onPicked: _fromBaby),
        const SizedBox(height: 20),
        InsetGroup(dividerIndent: 16, children: [
          InsetSegmentedRow<_Mode>(
            label: 'Age group',
            value: _mode,
            options: {for (final m in _Mode.values) m: m.label},
            onChanged: (m) => setState(() => _mode = m),
          ),
        ]),
        const SizedBox(height: 16),
        ...switch (_mode) {
          _Mode.day1 => _day1(),
          _Mode.infant => _infant(),
          _Mode.child => _child(),
        },
      ],
    );
  }

  Widget _measured({bool withMean = true}) => InsetGroup(header: 'Measured (optional)', dividerIndent: 16, children: [
        NumberRow(label: 'Systolic', controller: _sbp, unit: 'mmHg', onChanged: _changed),
        if (withMean) NumberRow(label: 'Mean', controller: _map, unit: 'mmHg', onChanged: _changed),
        NumberRow(label: 'Diastolic', controller: _dbp, unit: 'mmHg', onChanged: _changed),
      ]);

  Widget _outOfRange(String text) =>
      Text(text, style: AppTypography.footnote(color: AppColors.danger));

  List<(String, String)> _zubrowLines(ZubrowRow z) => [
        for (final (label, c, range) in [('Systolic', _sbp, z.sbp), ('Mean', _map, z.map), ('Diastolic', _dbp, z.dbp)])
          if (_read(c) case final v?) (label, '$v · ${zubrowBand(v, range).label.toLowerCase()}'),
      ];

  List<Widget> _day1() {
    final ga = readNumber(_ga);
    final row = ga == null ? null : zubrowRowFor(kZubrowDay1, ga);
    final lines = row == null ? const <(String, String)>[] : _zubrowLines(row);
    return [
      InsetGroup(header: 'Baby', dividerIndent: 16, children: [
        NumberRow(label: 'Gestation at birth', controller: _ga, unit: 'weeks', onChanged: _changed),
      ]),
      const SizedBox(height: 16),
      if (row != null) _ZubrowCard(title: '${row.weeks} weeks at birth · day 1 (mmHg)', row: row),
      if (ga != null && row == null) _outOfRange('The day-one table covers 22–42 weeks at birth.'),
      const SizedBox(height: 20),
      _measured(),
      if (lines.isNotEmpty) ...[const SizedBox(height: 16), ResultCard(lines: lines)],
    ];
  }

  List<Widget> _infant() {
    final pma = readNumber(_pma);
    final z = pma == null ? null : zubrowRowFor(kZubrowByPca, pma);
    final d = pma == null ? null : bpRowFor(pma);
    final lines = <(String, String)>[
      for (final (label, c, zr, dr) in [
        ('Systolic', _sbp, z?.sbp, d?.sbp),
        ('Mean', _map, z?.map, d?.map),
        ('Diastolic', _dbp, z?.dbp, d?.dbp),
      ])
        if (_read(c) case final v?)
          if (zr != null && zubrowBand(v, zr) == ZubrowBand.low)
            (label, '$v · below the Zubrow lower limit')
          else if (dr != null)
            (label, '$v · ${bpBand(v, dr).label.toLowerCase()}')
          else if (zr != null)
            (label, '$v · ${zubrowBand(v, zr).label.toLowerCase()}'),
    ];
    return [
      InsetGroup(header: 'Baby', dividerIndent: 16, children: [
        NumberRow(label: 'Postmenstrual age', controller: _pma, unit: 'weeks', onChanged: _changed),
      ]),
      const SizedBox(height: 16),
      if (z != null) ...[
        _ZubrowCard(title: 'Zubrow · ${z.weeks} weeks post-conceptional (mmHg)', row: z),
        const SizedBox(height: 12),
      ],
      if (d != null) _DionneCard(row: d),
      if (pma != null && z == null && d == null) _outOfRange('These tables cover 24–46 weeks postmenstrual age.'),
      const SizedBox(height: 20),
      _measured(),
      if (lines.isNotEmpty) ...[const SizedBox(height: 16), ResultCard(lines: lines)],
    ];
  }

  List<Widget> _child() {
    final years = readNumber(_years)?.floor();
    final height = readNumber(_height);
    final l = years == null || height == null ? null : aapBpLevels(male: _male, years: years, heightCm: height);
    final sbp = _read(_sbp), dbp = _read(_dbp);
    final category = l == null ? null : aapBpCategory(l, sbp: sbp, dbp: dbp);
    return [
      InsetGroup(header: 'Child', dividerIndent: 16, children: [
        InsetSegmentedRow<bool>(
          label: 'Sex',
          value: _male,
          options: const {true: 'Boy', false: 'Girl'},
          onChanged: (v) => setState(() => _male = v),
        ),
        NumberRow(label: 'Age', controller: _years, unit: 'years', onChanged: _changed),
        NumberRow(label: 'Height', controller: _height, unit: 'cm', onChanged: _changed),
      ]),
      const SizedBox(height: 16),
      if (l != null) _AapCard(levels: l),
      if (years != null && l == null && height != null) _outOfRange('The AAP tables cover 1–17 years.'),
      const SizedBox(height: 20),
      _measured(withMean: false),
      if (category != null) ...[
        const SizedBox(height: 16),
        ResultCard(lines: [
          ('Category', category.label),
          if (sbp != null) ('Systolic', '$sbp mmHg'),
          if (dbp != null) ('Diastolic', '$dbp mmHg'),
          if (l!.years >= kAapAdultCutoffsFromYears) ('Cut-offs', 'Adult values (13 years and over)'),
        ]),
      ],
    ];
  }
}

class _ZubrowCard extends StatelessWidget {
  const _ZubrowCard({required this.title, required this.row});
  final String title;
  final ZubrowRow row;

  @override
  Widget build(BuildContext context) => _CentileTable(
        title: title,
        headers: const ['Lower', 'Mean', 'Upper'],
        rows: [
          ('Systolic', [row.sbp.$1, row.sbp.$2, row.sbp.$3]),
          ('Mean', [row.map.$1, row.map.$2, row.map.$3]),
          ('Diastolic', [row.dbp.$1, row.dbp.$2, row.dbp.$3]),
        ],
      );
}

class _DionneCard extends StatelessWidget {
  const _DionneCard({required this.row});
  final BpRow row;

  @override
  Widget build(BuildContext context) => _CentileTable(
        title: 'Dionne · ${row.pmaWeeks} weeks, after 2 weeks of age (mmHg)',
        headers: const ['50th', '95th', '99th'],
        rows: [
          ('Systolic', [row.sbp.$1, row.sbp.$2, row.sbp.$3]),
          ('Mean', [row.map.$1, row.map.$2, row.map.$3]),
          ('Diastolic', [row.dbp.$1, row.dbp.$2, row.dbp.$3]),
        ],
      );
}

class _AapCard extends StatelessWidget {
  const _AapCard({required this.levels});
  final AapBpLevels levels;

  @override
  Widget build(BuildContext context) {
    final l = levels;
    return _CentileTable(
      title: '${l.years} y · ${l.heightCentile}th height centile column (${l.columnHeightCm} cm) · mmHg',
      headers: const ['50th', '90th', '95th', '+12'],
      rows: [
        ('Systolic', [l.sbp.$1, l.sbp.$2, l.sbp.$3, l.sbpStage2]),
        ('Diastolic', [l.dbp.$1, l.dbp.$2, l.dbp.$3, l.dbpStage2]),
      ],
    );
  }
}

class _CentileTable extends StatelessWidget {
  const _CentileTable({required this.title, required this.headers, required this.rows});
  final String title;
  final List<String> headers;
  final List<(String, List<int>)> rows;

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {bool label = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(t,
              textAlign: label ? TextAlign.start : TextAlign.end,
              style: AppTypography.subheadline(
                color: label ? AppColors.textSecondary : AppColors.textPrimary,
                weight: label ? null : FontWeight.w600,
              ).copyWith(fontFeatures: AppTypography.tabular)),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTypography.footnote(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Table(columnWidths: const {0: FlexColumnWidth(1.4)}, children: [
          TableRow(children: [
            for (final t in ['', ...headers])
              Text(t, textAlign: TextAlign.end, style: AppTypography.caption1(color: AppColors.textSecondary)),
          ]),
          for (final (label, values) in rows)
            TableRow(children: [cell(label, label: true), for (final v in values) cell('$v')]),
        ]),
      ]),
    );
  }
}
