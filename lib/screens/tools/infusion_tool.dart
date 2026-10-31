import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../services/drug_service.dart';
import '../../tools/drugs/drug_list.dart';
import '../../tools/drugs/drug_model.dart';
import '../../tools/drugs/ward_drugs.dart';
import '../../tools/neonatal_formulas.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/inset_group.dart';
import 'drugs/drug_scope.dart';
import 'drugs/drug_widgets.dart';
import 'tool_page.dart';

enum _Solve { rate, dose }

final _strengths = {0.5: '½×', 1.0: '1×', 2.0: '2×', 3.0: '3×', 4.0: '4×'};
final _volumes = {10.0: '10 mL', 20.0: '20 mL', 50.0: '50 mL', 0.0: 'Other'};

/// Pump rate from a dose (or the dose a rate gives). Pick a drug from the
/// list for its vial, usual range and standard syringe — with strengths,
/// syringe sizes and a rate table — or enter your own drug. Can start the
/// infusion on a patient's record.
class InfusionTool extends StatefulWidget {
  const InfusionTool({super.key, this.drugKey, this.care, this.weightKg, this.patient});
  final String? drugKey;
  final CareSetting? care;
  final double? weightKg;
  final Patient? patient;

  @override
  State<InfusionTool> createState() => _InfusionToolState();
}

class _InfusionToolState extends State<InfusionTool> {
  Patient? _baby;
  String? _drugKey;
  CareSetting? _care;
  double _strength = 1;
  double _volume = 50;
  final _kg = TextEditingController();
  final _otherMl = TextEditingController();
  final _dose = TextEditingController();
  final _rate = TextEditingController();
  // Own drug.
  final _ownName = TextEditingController();
  final _mg = TextEditingController();
  final _ownMl = TextEditingController(text: '50');
  DoseUnit _unit = DoseUnit.mcgPerKgMin;
  _Solve _solve = _Solve.rate;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _baby = widget.patient;
    _drugKey = widget.drugKey;
    _care = widget.care;
    writeNumber(_kg, widget.weightKg);
    if (_kg.text.isEmpty && _baby?.birthWeightG != null) writeNumber(_kg, _baby!.birthWeightG! / 1000);
  }

  @override
  void dispose() {
    for (final c in [_kg, _otherMl, _dose, _rate, _ownName, _mg, _ownMl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  void _fromBaby(Patient p) => setState(() {
    _baby = p;
    if (p.birthWeightG != null) writeNumber(_kg, p.birthWeightG! / 1000);
  });

  Future<void> _pickDrug(CareSetting care) async {
    final options = {for (final d in drugsFor(care, infusions: true)) d.key: d.name, '': 'Enter my own drug'};
    final key = await showOptionSheet<String>(context, title: 'Drug', options: options, selected: _drugKey ?? '');
    if (key == null) return;
    setState(() {
      _drugKey = key.isEmpty ? null : key;
      _dose.clear();
      _rate.clear();
    });
  }

  /// A stand-in drug so "your own" uses the same arithmetic (mg in the
  /// syringe; dose unit as chosen).
  Drug _ownDrug() => Drug(
    key: 'own',
    name: _ownName.text.trim().isEmpty ? 'Infusion' : _ownName.text.trim(),
    category: '',
    vial: const Strength(1, Amount.mg),
    source: '',
    infusion: InfusionSpec(
      unit: switch (_unit) {
        DoseUnit.mcgPerKgMin => mcgKgMin,
        DoseUnit.mcgPerKgHour => mcgKgH,
        DoseUnit.mgPerKgHour => mgKgH,
      },
      ranges: const {},
      mixAt1MlH: const {},
      diluent: '',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DrugScopeBuilder(
      preferWardId: _baby?.wardId,
      builder: (context, scope, pickWard) {
        final care = _care ?? scope.care ?? CareSetting.nicu;
        final listed = _drugKey == null ? null : drugByKey(_drugKey!);
        final wd = listed == null || !listed.hasInfusionFor(care) ? null : scope.drug(listed);
        return ToolPage(
          title: 'Infusion Rate',
          method:
              'Concentration = drug in the syringe ÷ syringe volume.\n'
              'Rate (mL/h) = dose × weight (× 60 for per-minute doses) ÷ concentration, in matching units.\n'
              'The 1× syringe is made so 1 mL/h gives the dose shown; 2× is twice as strong (half the rate).',
          source:
              'Standard arithmetic; usual ranges and standard syringes from FolioMed’s drug list or your ward’s '
              'own settings. Double-check with a second person before starting.',
          children: [
            BabyRow(patient: _baby, onPicked: _fromBaby),
            const SizedBox(height: 20),
            InsetGroup(
              header: 'Drug',
              dividerIndent: 16,
              children: [
                SettingsRow(
                  icon: Icons.medication_outlined,
                  title: wd?.drug.name ?? 'My own drug',
                  subtitle: wd == null ? 'Tap to pick from the list' : '${wd.drug.vial.label} · tap to change',
                  showChevron: true,
                  onTap: () => _pickDrug(care),
                ),
                InsetSegmentedRow<CareSetting>(
                  label: 'For',
                  value: care,
                  options: {for (final c in CareSetting.values) c: c.label},
                  onChanged: (c) => setState(() {
                    _care = c;
                    if (listed != null && !listed.hasInfusionFor(c)) _drugKey = null;
                  }),
                ),
                NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: _changed),
              ],
            ),
            if (wd != null && scope.ward != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  DrugCheckChip(drug: wd),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                      onPressed: () => showDrugDetails(context, drug: wd, scope: scope),
                      child: Text('${scope.ward!.name} · details'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (wd != null) ..._listedDrug(wd, care) else ..._ownDrugInputs(),
          ],
        );
      },
    );
  }

  // ── A drug from the list ──

  double get _syringeMl => _volume == 0 ? (readNumber(_otherMl) ?? 0) : _volume;

  List<Widget> _listedDrug(WardDrug wd, CareSetting care) {
    final d = wd.drug, inf = d.infusion!;
    final range = inf.ranges[care]!;
    final kg = readNumber(_kg);
    final base = wd.mixFor(care)!;
    final m = kg == null || _syringeMl <= 0
        ? null
        : mixture(drug: d, kg: kg, volumeMl: _syringeMl, doseAt1MlH: base * _strength);
    return [
      InsetGroup(
        header: 'Syringe',
        dividerIndent: 16,
        children: [
          InsetSegmentedRow<double>(
            label: 'Strength (1× = 1 mL/h gives ${doseText(base)} ${inf.unit.label})',
            value: _strength,
            options: _strengths,
            onChanged: (v) => setState(() => _strength = v),
          ),
          InsetSegmentedRow<double>(
            label: 'Syringe',
            value: _volume,
            options: _volumes,
            onChanged: (v) => setState(() => _volume = v),
          ),
          if (_volume == 0) NumberRow(label: 'Volume', controller: _otherMl, unit: 'mL', onChanged: _changed),
        ],
      ),
      const SizedBox(height: 16),
      if (m == null)
        const ResultCard(lines: null, emptyHint: 'Enter the weight for the syringe and rates.')
      else ...[
        _PrepCard(drug: d, mixture: m, unitLabel: inf.unit.label, diluent: inf.diluent, note: inf.note),
        const SizedBox(height: 16),
        _RateTable(drug: d, kg: kg!, mixture: m, range: range, unitLabel: inf.unit.label),
      ],
      const SizedBox(height: 20),
      ..._workOut(
        unitLabel: inf.unit.label,
        range: range,
        compute: m == null ? null : (dose) => rateFor(drug: d, dose: dose, kg: kg!, concentration: m.concentration),
        reverse: m == null ? null : (rate) => doseFor(drug: d, rateMlH: rate, kg: kg!, concentration: m.concentration),
        start: m == null
            ? null
            : (dose, rate) => _start(
                drugKey: d.key,
                name: d.name,
                dose: dose,
                unit: inf.unit.label,
                rate: rate,
                concentration: m.concentration,
                concUnit: '${m.amountUnit.label}/mL',
                syringe: '${doseText(m.totalAmount)} ${m.amountUnit.label} in ${trimNum(m.volumeMl)} mL',
                kg: kg,
              ),
      ),
    ];
  }

  // ── Your own drug ──

  List<Widget> _ownDrugInputs() {
    final kg = readNumber(_kg), mg = readNumber(_mg), ml = readNumber(_ownMl);
    final own = _ownDrug();
    final conc = mg == null || ml == null ? null : mg / ml;
    return [
      InsetGroup(
        header: 'Syringe',
        dividerIndent: 16,
        children: [
          InsetTextRow(label: 'Name', controller: _ownName, placeholder: 'Optional', onChanged: (_) => _changed()),
          NumberRow(label: 'Amount', controller: _mg, unit: 'mg', onChanged: _changed),
          NumberRow(label: 'Made up to', controller: _ownMl, unit: 'mL', onChanged: _changed),
          InsetSegmentedRow<DoseUnit>(
            label: 'Dose unit',
            value: _unit,
            options: {for (final u in DoseUnit.values) u: u.label},
            onChanged: (v) => setState(() => _unit = v),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ..._workOut(
        unitLabel: _unit.label,
        range: null,
        compute: kg == null || conc == null
            ? null
            : (dose) => rateFor(drug: own, dose: dose, kg: kg, concentration: conc),
        reverse: kg == null || conc == null
            ? null
            : (rate) => doseFor(drug: own, rateMlH: rate, kg: kg, concentration: conc),
        start: kg == null || conc == null || _ownName.text.trim().isEmpty
            ? null
            : (dose, rate) => _start(
                drugKey: null,
                name: _ownName.text.trim(),
                dose: dose,
                unit: _unit.label,
                rate: rate,
                concentration: conc,
                concUnit: 'mg/mL',
                syringe: '${trimNum(mg!)} mg in ${trimNum(ml!)} mL',
                kg: kg,
              ),
      ),
    ];
  }

  // ── Rate ⇄ dose, and starting it on the patient ──

  List<Widget> _workOut({
    required String unitLabel,
    required (double, double)? range,
    required double Function(double dose)? compute,
    required double Function(double rate)? reverse,
    required Future<void> Function(double dose, double rate)? start,
  }) {
    double? dose, rate;
    if (_solve == _Solve.rate && compute != null && readNumber(_dose) != null) {
      dose = readNumber(_dose)!;
      rate = compute(dose);
    } else if (_solve == _Solve.dose && reverse != null && readNumber(_rate) != null) {
      rate = readNumber(_rate)!;
      dose = reverse(rate);
    }
    final lines = <(String, String)>[
      if (dose != null && rate != null) ...[
        _solve == _Solve.rate
            ? ('Pump rate', '${trimNum(roundRate(rate), 1)} mL/h')
            : ('Dose', '${doseText(dose)} $unitLabel'),
        if (_solve == _Solve.rate && (rate - roundRate(rate)).abs() > 0.001) ('Exact', '${trimNum(rate, 3)} mL/h'),
        if (rate < 0.1) ('Check', 'Below 0.1 mL/h — use a weaker syringe'),
        if (range != null && (dose < range.$1 - 1e-9 || dose > range.$2 + 1e-9))
          ('Check', 'Outside the usual ${rangeText(range.$1, range.$2, doseText)} $unitLabel'),
      ],
    ];
    final who = _baby;
    return [
      InsetGroup(
        dividerIndent: 16,
        children: [
          InsetSegmentedRow<_Solve>(
            label: 'Work out',
            value: _solve,
            options: const {_Solve.rate: 'Rate', _Solve.dose: 'Dose'},
            onChanged: (v) => setState(() => _solve = v),
          ),
          if (_solve == _Solve.rate)
            NumberRow(
              label: 'Dose',
              controller: _dose,
              unit: unitLabel,
              placeholder: range == null ? null : rangeText(range.$1, range.$2, doseText),
              onChanged: _changed,
            )
          else
            NumberRow(label: 'Pump rate', controller: _rate, unit: 'mL/h', onChanged: _changed),
        ],
      ),
      const SizedBox(height: 16),
      ResultCard(
        lines: lines.isEmpty ? null : lines,
        emptyHint: 'Enter the weight, the syringe and the dose (or rate).',
      ),
      if (who != null && who.isActive && start != null && dose != null && rate != null) ...[
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _starting ? null : () => start(dose!, roundRate(rate!)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('Start on ${who.name}'),
        ),
      ],
    ];
  }

  Future<void> _start({
    required String? drugKey,
    required String name,
    required double dose,
    required String unit,
    required double rate,
    required double concentration,
    required String concUnit,
    required String syringe,
    required double? kg,
  }) async {
    final p = _baby!;
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text('Start $name on ${p.name}?'),
        content: Text(
          '${doseText(dose)} $unit at ${trimNum(rate, 1)} mL/h\n$syringe\n\n'
          'Checked by a second person?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    try {
      await DrugService().start(
        patientId: p.id,
        drugKey: drugKey,
        drugName: name,
        dose: dose,
        doseUnit: unit,
        rateMlH: rate,
        concentration: concentration,
        concUnit: concUnit,
        syringe: syringe,
        weightKg: kg,
      );
      Haptics.success();
      messenger.showSnackBar(SnackBar(content: Text('$name started on ${p.name} — on the timeline')));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(content: Text("Couldn't start — ${friendlyError(e)}")));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

/// How to make the syringe.
class _PrepCard extends StatelessWidget {
  const _PrepCard({
    required this.drug,
    required this.mixture,
    required this.unitLabel,
    required this.diluent,
    this.note,
  });
  final Drug drug;
  final Mixture mixture;
  final String unitLabel;
  final String diluent;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final m = mixture;
    final warn = <String>[
      if (m.drawMl > m.volumeMl) 'More drug than the syringe holds — use a lower strength or a bigger syringe.',
      if (m.drawMl < 0.1 && m.drawMl <= m.volumeMl) 'Under 0.1 mL to draw — hard to measure; use a stronger mixture.',
    ];
    Widget line(String t, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(t, style: style ?? AppTypography.body(color: AppColors.textPrimary)),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAKE UP',
            style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600),
          ),
          if (m.stockRecipe != null) line('First: ${m.stockRecipe}.'),
          line(
            'Draw ${doseText(roundDraw(m.drawMl))} mL of ${drug.name} ${m.drawFrom.label} '
            '(${doseText(m.totalAmount)} ${m.amountUnit.label}).',
          ),
          line('Make up to ${trimNum(m.volumeMl)} mL with $diluent.'),
          line(
            '= ${doseText(m.concentration)} ${m.amountUnit.label}/mL · 1 mL/h gives ${doseText(m.doseAt1MlH)} $unitLabel',
            style: AppTypography.headline(color: AppColors.textPrimary),
          ),
          for (final w in warn) line('⚠ $w', style: AppTypography.footnote(color: AppColors.danger)),
          if (note != null) line(note!, style: AppTypography.footnote(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Pump rates across the usual range.
class _RateTable extends StatelessWidget {
  const _RateTable({
    required this.drug,
    required this.kg,
    required this.mixture,
    required this.range,
    required this.unitLabel,
  });
  final Drug drug;
  final double kg;
  final Mixture mixture;
  final (double, double) range;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final steps = doseSteps(range.$1, range.$2);
    TextStyle cell = AppTypography.body(color: AppColors.textPrimary).copyWith(fontFeatures: AppTypography.tabular);
    return InsetGroup(
      header: 'Rates for this syringe',
      footer: 'Rounded to 0.1 mL/h. ⚠ = below 0.1 mL/h; use a weaker syringe for these doses.',
      dividerIndent: 16,
      children: [
        for (final s in steps)
          Builder(
            builder: (context) {
              final r = rateFor(drug: drug, dose: s, kg: kg, concentration: mixture.concentration);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Expanded(child: Text('${doseText(s)} $unitLabel', style: cell)),
                    Text(
                      '${r < 0.1 ? '⚠ ' : ''}${trimNum(roundRate(r), 1)} mL/h',
                      style: cell.copyWith(
                        fontWeight: FontWeight.w600,
                        color: r < 0.1 ? AppColors.warning : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
