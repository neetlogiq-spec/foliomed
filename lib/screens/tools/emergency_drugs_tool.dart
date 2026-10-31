import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/drugs/drug_model.dart';
import '../../tools/drugs/ward_drugs.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/pressable.dart';
import 'drugs/drug_scope.dart';
import 'drugs/drug_widgets.dart';
import 'infusion_tool.dart';
import 'tool_page.dart';

enum _Mode { oneOff, infusion }

enum _Layout { cards, table }

/// Weight-based emergency drugs for NICU and PICU: one-off doses with the
/// volume to draw up, and infusions with the standard syringe. Applies the
/// ward's own vials and shows each drug's sign-off.
class EmergencyDrugsTool extends StatefulWidget {
  const EmergencyDrugsTool({super.key, this.initialCare});
  final CareSetting? initialCare;

  @override
  State<EmergencyDrugsTool> createState() => _EmergencyDrugsToolState();
}

class _EmergencyDrugsToolState extends State<EmergencyDrugsTool> {
  Patient? _baby;
  final _kg = TextEditingController();
  CareSetting? _care;
  _Mode _mode = _Mode.oneOff;
  _Layout _layout = _Layout.cards;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _care = widget.initialCare;
  }

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  void _fromBaby(Patient p) => setState(() {
    _baby = p;
    if (p.birthWeightG != null) writeNumber(_kg, p.birthWeightG! / 1000);
  });

  bool _matches(Drug d) {
    if (_q.isEmpty) return true;
    final hay = '${d.name} ${d.aka ?? ''} ${d.category} ${d.boluses.map((b) => b.label).join(' ')}'.toLowerCase();
    return _q.toLowerCase().split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    return DrugScopeBuilder(
      preferWardId: _baby?.wardId,
      builder: (context, scope, pickWard) {
        final care = _care ?? scope.care ?? CareSetting.nicu;
        final kg = readNumber(_kg);
        final drugs = [
          for (final wd in scope.drugs)
            if (!wd.hidden &&
                _matches(wd.drug) &&
                (_mode == _Mode.oneOff ? wd.drug.bolusesFor(care).isNotEmpty : wd.drug.hasInfusionFor(care)))
              wd,
        ];
        return ToolPage(
          title: 'Emergency Drugs',
          method:
              'Dose = dose per kg × weight, limited to the maximum single dose.\n'
              'Volume = dose ÷ strength of what is drawn up (the vial, or the dilution shown).\n'
              'Infusions: the 1× syringe makes 1 mL/h give the dose shown; '
              'drug in syringe = dose per hour per mL × weight × syringe volume.',
          source:
              'Doses follow published resuscitation, seizure and DKA guidelines and usual neonatal and paediatric '
              'ranges; each drug lists its source. Check every drug against your unit’s reference and sign it off '
              'for your ward. Double-check with a second person before giving.',
          children: [
            BabyRow(patient: _baby, onPicked: _fromBaby),
            const SizedBox(height: 20),
            InsetGroup(
              dividerIndent: 16,
              children: [
                NumberRow(label: 'Weight', controller: _kg, unit: 'kg', onChanged: () => setState(() {})),
                InsetSegmentedRow<CareSetting>(
                  label: 'For',
                  value: care,
                  options: {for (final c in CareSetting.values) c: c.label},
                  onChanged: (c) => setState(() => _care = c),
                ),
                InsetSegmentedRow<_Mode>(
                  label: 'Show',
                  value: _mode,
                  options: const {_Mode.oneOff: 'One-off Doses', _Mode.infusion: 'Infusions'},
                  onChanged: (m) => setState(() => _mode = m),
                ),
                if (_mode == _Mode.oneOff)
                  InsetSegmentedRow<_Layout>(
                    label: 'Layout',
                    value: _layout,
                    options: const {_Layout.cards: 'Step by Step', _Layout.table: 'Table'},
                    onChanged: (l) => setState(() => _layout = l),
                  ),
              ],
            ),
            if (scope.ward != null) ...[const SizedBox(height: 16), DrugWardRow(scope: scope, pick: pickWard)],
            const SizedBox(height: 16),
            CupertinoSearchTextField(placeholder: 'Search drugs', onChanged: (v) => setState(() => _q = v.trim())),
            const SizedBox(height: 16),
            if (kg == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Enter the weight to see doses and volumes. Showing doses per kg.',
                  style: AppTypography.footnote(color: AppColors.textSecondary),
                ),
              ),
            if (drugs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No drugs match.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(color: AppColors.textSecondary),
                ),
              )
            else if (_mode == _Mode.oneOff && _layout == _Layout.table)
              _BolusTable(drugs: drugs, care: care, kg: kg, scope: scope)
            else
              for (final wd in drugs) ...[
                _mode == _Mode.oneOff
                    ? _BolusCard(drug: wd, care: care, kg: kg, scope: scope)
                    : _InfusionCard(
                        drug: wd,
                        care: care,
                        kg: kg,
                        scope: scope,
                        onOpen: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) =>
                                InfusionTool(drugKey: wd.drug.key, care: care, weightKg: kg, patient: _baby),
                          ),
                        ),
                      ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.drug, required this.scope, required this.subtitle, required this.children});
  final WardDrug drug;
  final DrugScope scope;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final d = drug.drug;
    return Pressable(
      onTap: () => showDrugDetails(context, drug: drug, scope: scope),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: d.name,
                          style: AppTypography.headline(color: AppColors.textPrimary),
                        ),
                        if (d.aka != null)
                          TextSpan(
                            text: '  ${d.aka}',
                            style: AppTypography.footnote(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                if (scope.ward != null) DrugCheckChip(drug: drug),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: AppTypography.footnote(color: AppColors.textSecondary)),
            if (drug.unitNote != null) ...[
              const SizedBox(height: 6),
              Text('Ward: ${drug.unitNote}', style: AppTypography.footnote(color: AppColors.primary)),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BolusCard extends StatelessWidget {
  const _BolusCard({required this.drug, required this.care, required this.kg, required this.scope});
  final WardDrug drug;
  final CareSetting care;
  final double? kg;
  final DrugScope scope;

  @override
  Widget build(BuildContext context) {
    final d = drug.drug;
    return _CardFrame(
      drug: drug,
      scope: scope,
      subtitle: '${d.vial.label} · ${d.category}',
      children: [
        for (final use in d.bolusesFor(care)) ...[const Divider(height: 22), _UseLines(use: use, drug: d, kg: kg)],
      ],
    );
  }
}

class _UseLines extends StatelessWidget {
  const _UseLines({required this.use, required this.drug, required this.kg});
  final BolusUse use;
  final Drug drug;
  final double? kg;

  @override
  Widget build(BuildContext context) {
    final u = use.unit.label;
    final strength = use.give ?? drug.vial;
    final perKg = '${rangeText(use.min, use.max, doseText)} $u/kg';
    final dose = kg == null ? null : bolusDose(use, drug, kg!);
    String vol(double v) => doseText(roundDraw(v));
    final main = dose == null ? perKg : '${rangeText(dose.low, dose.high, doseText)} $u';
    final draw = use.unit == Amount.mL
        ? null
        : dose == null
        ? '${rangeText(_ml(use.min, strength), _ml(use.max, strength), doseText)} mL/kg of ${strength.label}'
        : '${rangeText(dose.volumeLow, dose.volumeHigh, vol)} mL of ${strength.label}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${use.label} · ${use.route}', style: AppTypography.subheadline(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          main,
          style: AppTypography.title3(color: AppColors.textPrimary).copyWith(fontFeatures: AppTypography.tabular),
        ),
        if (draw != null)
          Text(
            draw,
            style: AppTypography.body(color: AppColors.textPrimary).copyWith(fontFeatures: AppTypography.tabular),
          ),
        if (dose != null && use.unit != Amount.mL)
          Text(perKg, style: AppTypography.footnote(color: AppColors.textSecondary)),
        if (use.recipe != null) _Line(icon: Icons.science_outlined, text: 'Make: ${use.recipe}'),
        if (use.maxDose != null)
          _Line(
            icon: Icons.vertical_align_top,
            text: 'Max ${doseText(use.maxDose!)} $u per dose${dose?.capped == true ? ' — reached at this weight' : ''}',
            color: dose?.capped == true ? AppColors.warning : null,
          ),
        if (use.repeat != null) _Line(icon: Icons.repeat, text: use.repeat!),
        if (use.note != null) _Line(icon: Icons.info_outline, text: use.note!),
      ],
    );
  }

  /// mL of [s] holding [amount] (in the dose unit).
  double _ml(double amount, Strength s) => use.unit.to(s.unit, amount) / s.perMl;
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: AppTypography.footnote(color: color ?? AppColors.textSecondary)),
        ),
      ],
    ),
  );
}

class _BolusTable extends StatelessWidget {
  const _BolusTable({required this.drugs, required this.care, required this.kg, required this.scope});
  final List<WardDrug> drugs;
  final CareSetting care;
  final double? kg;
  final DrugScope scope;

  @override
  Widget build(BuildContext context) {
    TextStyle head = AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600);
    TextStyle cell = AppTypography.footnote(color: AppColors.textPrimary).copyWith(fontFeatures: AppTypography.tabular);
    final rows = <TableRow>[
      TableRow(
        children: [
          for (final t in ['Drug', 'Dose', 'Draw up'])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(t, style: head),
            ),
        ],
      ),
    ];
    for (final wd in drugs) {
      for (final use in wd.drug.bolusesFor(care)) {
        final u = use.unit.label;
        final s = use.give ?? wd.drug.vial;
        final dose = kg == null ? null : bolusDose(use, wd.drug, kg!);
        rows.add(
          TableRow(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${wd.drug.name}\n${use.label}',
                  style: AppTypography.footnote(color: AppColors.textPrimary, weight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  dose == null
                      ? '${rangeText(use.min, use.max, doseText)} $u/kg'
                      : '${rangeText(dose.low, dose.high, doseText)} $u${dose.capped ? ' (max)' : ''}',
                  style: cell,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  use.unit == Amount.mL
                      ? '—'
                      : dose == null
                      ? s.label
                      : '${rangeText(dose.volumeLow, dose.volumeHigh, (v) => doseText(roundDraw(v)))} mL\nof ${s.label}',
                  style: cell,
                ),
              ),
            ],
          ),
        );
      }
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.1)},
        children: rows,
      ),
    );
  }
}

class _InfusionCard extends StatelessWidget {
  const _InfusionCard({
    required this.drug,
    required this.care,
    required this.kg,
    required this.scope,
    required this.onOpen,
  });
  final WardDrug drug;
  final CareSetting care;
  final double? kg;
  final DrugScope scope;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final d = drug.drug, inf = d.infusion!;
    final range = inf.ranges[care]!;
    final mix = drug.mixFor(care)!;
    final m = kg == null ? null : mixture(drug: d, kg: kg!, volumeMl: 50, doseAt1MlH: mix);
    return _CardFrame(
      drug: drug,
      scope: scope,
      subtitle: '${d.vial.label} · ${d.category} · ${rangeText(range.$1, range.$2, doseText)} ${inf.unit.label}',
      children: [
        const Divider(height: 22),
        Text(
          '1 mL/h = ${doseText(mix)} ${inf.unit.label}',
          style: AppTypography.title3(color: AppColors.textPrimary).copyWith(fontFeatures: AppTypography.tabular),
        ),
        if (m == null)
          Text('Enter the weight for the syringe.', style: AppTypography.footnote(color: AppColors.textSecondary))
        else ...[
          if (m.stockRecipe != null) _Line(icon: Icons.science_outlined, text: 'First: ${m.stockRecipe}'),
          Text(
            'Draw ${doseText(roundDraw(m.drawMl))} mL of ${m.drawFrom.label} '
            '(${doseText(m.totalAmount)} ${m.amountUnit.label}), make up to 50 mL',
            style: AppTypography.body(color: AppColors.textPrimary),
          ),
          if (m.drawMl > m.volumeMl)
            _Line(
              icon: Icons.warning_amber_rounded,
              text: 'More drug than the syringe holds — use a weaker mixture.',
              color: AppColors.danger,
            ),
        ],
        _Line(icon: Icons.water_drop_outlined, text: 'Dilute in ${inf.diluent}'),
        if (inf.note != null) _Line(icon: Icons.info_outline, text: inf.note!),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.calculate_outlined, size: 18),
            label: const Text('Rates, Strengths & Start'),
          ),
        ),
      ],
    );
  }
}
