import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/ward.dart';
import '../../../services/drug_service.dart';
import '../../../tools/drugs/drug_list.dart';
import '../../../tools/drugs/drug_model.dart';
import '../../../tools/drugs/ward_drugs.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/app_typography.dart';
import '../../../utils/friendly_error.dart';
import '../../../utils/haptics.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/inset_group.dart';
import '../tool_page.dart';
import 'drug_scope.dart';

/// Amounts with sensible precision: 0.025, 0.3, 2.5, 30, 300.
String doseText(double v) => trimNum(v, v < 1 ? 3 : (v < 10 ? 2 : 1));

/// "0.3–0.9" or "0.3".
String rangeText(double a, double b, String Function(double) f) => (b - a).abs() < 1e-9 ? f(a) : '${f(a)}–${f(b)}';

/// Signed-off state for one drug on one ward.
class DrugCheckChip extends StatelessWidget {
  const DrugCheckChip({super.key, required this.drug});
  final WardDrug drug;

  @override
  Widget build(BuildContext context) {
    final s = drug.setting;
    final (text, color) = drug.isChecked
        ? ('Checked', AppColors.stable)
        : drug.checkIsStale
        ? ('Changed — recheck', AppColors.warning)
        : ('Not checked', AppColors.warning);
    return Semantics(
      label: drug.isChecked ? 'Checked by ${s?.checkedByName ?? 'a doctor'}' : text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
        child: Text(
          text,
          style: AppTypography.caption1(color: color, weight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// "Ward: NICU · 4 of 25 checked" — tap to change ward when there are several.
class DrugWardRow extends StatelessWidget {
  const DrugWardRow({super.key, required this.scope, required this.pick});
  final DrugScope scope;
  final ValueChanged<Ward> pick;

  @override
  Widget build(BuildContext context) {
    final w = scope.ward;
    if (w == null) return const SizedBox.shrink();
    final all = scope.drugs.where((d) => !d.hidden).toList();
    final checked = all.where((d) => d.isChecked).length;
    return InsetGroup(
      footer: 'Vials, mixtures and sign-off follow this ward’s drug list (ward page → Drug List).',
      children: [
        SettingsRow(
          icon: Icons.corporate_fare,
          title: w.name,
          subtitle: '$checked of ${all.length} drugs checked for this ward',
          showChevron: scope.wards.length > 1,
          onTap: scope.wards.length < 2
              ? null
              : () async {
                  final id = await showOptionSheet<String>(
                    context,
                    title: 'Use the drug list of',
                    options: {for (final x in scope.wards) x.id: x.name},
                    selected: w.id,
                  );
                  final picked = scope.wards.where((x) => x.id == id).firstOrNull;
                  if (picked != null) pick(picked);
                },
        ),
      ],
    );
  }
}

/// Everything about one drug, with sign-off (doctors) and ward settings
/// (owner).
Future<void> showDrugDetails(BuildContext context, {required WardDrug drug, required DrugScope scope}) => showAppSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _DrugDetails(drug: drug, scope: scope),
);

class _DrugDetails extends StatefulWidget {
  const _DrugDetails({required this.drug, required this.scope});
  final WardDrug drug;
  final DrugScope scope;

  @override
  State<_DrugDetails> createState() => _DrugDetailsState();
}

class _DrugDetailsState extends State<_DrugDetails> {
  bool _busy = false;

  Future<void> _signOff(bool check) async {
    final ward = widget.scope.ward!;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await DrugService().checkWardDrug(ward.id, widget.drug.drug.key, check ? widget.drug.signature : null);
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(check ? '${widget.drug.drug.name} checked for ${ward.name}' : 'Sign-off withdrawn')),
      );
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wd = widget.drug, d = wd.drug, s = wd.setting, scope = widget.scope;
    final inf = d.infusion;
    String when(DateTime t) => DateFormat('d MMM yyyy').format(t);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.name, style: AppTypography.title2(color: AppColors.textPrimary)),
                ),
                if (scope.ward != null) DrugCheckChip(drug: wd),
              ],
            ),
            if (d.aka != null) Text(d.aka!, style: AppTypography.subheadline(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            InsetGroup(
              dividerIndent: 16,
              children: [
                SettingsRow(title: 'Vial', value: d.vial.label),
                SettingsRow(title: 'Group', value: d.category),
                if (inf != null) ...[
                  for (final e in inf.ranges.entries)
                    SettingsRow(
                      title: 'Infusion (${e.key.label})',
                      value: '${rangeText(e.value.$1, e.value.$2, doseText)} ${inf.unit.label}',
                    ),
                  SettingsRow(title: 'Dilute in', subtitle: inf.diluent),
                ],
              ],
            ),
            if (wd.unitNote != null) ...[
              const SizedBox(height: 16),
              _Note(icon: Icons.info_outline, text: 'Ward note: ${wd.unitNote}'),
            ],
            if (scope.ward != null) ...[
              const SizedBox(height: 16),
              _Note(
                icon: wd.isChecked ? Icons.verified_outlined : Icons.pending_outlined,
                text: wd.isChecked
                    ? 'Checked for ${scope.ward!.name} by ${s!.checkedByName ?? 'a doctor'}'
                          '${s.checkedAt == null ? '' : ' on ${when(s.checkedAt!)}'}.'
                    : wd.checkIsStale
                    ? 'The doses or this ward’s vial or mixture changed after the last sign-off. Check again.'
                    : 'Not yet checked for ${scope.ward!.name}. Compare every dose with your unit’s reference '
                          'before signing off.',
              ),
            ],
            const SizedBox(height: 12),
            Text('Source: ${d.source}', style: AppTypography.footnote(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            if (scope.ward != null && scope.canSignOff)
              FilledButton(
                onPressed: _busy ? null : () => _signOff(!wd.isChecked),
                child: Text(wd.isChecked ? 'Withdraw Sign-off' : 'Sign Off for ${scope.ward!.name}'),
              ),
            if (scope.isOwner) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        showWardDrugEditor(context, drug: wd, ward: scope.ward!);
                      },
                child: const Text('Ward Settings…'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTypography.footnote(color: AppColors.textPrimary)),
        ),
      ],
    ),
  );
}

/// Owner only: this ward's vial, standard mixture, note, or hide the drug.
Future<void> showWardDrugEditor(BuildContext context, {required WardDrug drug, required Ward ward}) => showAppSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _WardDrugEditor(drug: drug, ward: ward),
);

class _WardDrugEditor extends StatefulWidget {
  const _WardDrugEditor({required this.drug, required this.ward});
  final WardDrug drug;
  final Ward ward;

  @override
  State<_WardDrugEditor> createState() => _WardDrugEditorState();
}

class _WardDrugEditorState extends State<_WardDrugEditor> {
  late final _vial = TextEditingController(text: trimNum(widget.drug.drug.vial.perMl, 4));
  late final _mix = TextEditingController(
    text: widget.drug.mixOverride == null ? '' : trimNum(widget.drug.mixOverride!, 4),
  );
  late final _note = TextEditingController(text: widget.drug.unitNote ?? '');
  late bool _hidden = widget.drug.hidden;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_vial, _mix, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final base = drugBaseVial(widget.drug.drug.key);
    final vial = readNumber(_vial);
    final mix = readNumber(_mix);
    if (vial != null && vial <= 0 || mix != null && mix <= 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await DrugService().setWardDrug(
        wardId: widget.ward.id,
        drugKey: widget.drug.drug.key,
        vialPerMl: vial == null || (base != null && (vial - base).abs() < 1e-9) ? null : vial,
        mixAt1MlH: mix,
        hidden: _hidden,
        note: _note.text,
      );
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('${widget.drug.drug.name} saved for ${widget.ward.name}')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drug.drug;
    final inf = d.infusion;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${d.name} on ${widget.ward.name}', style: AppTypography.title3(color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            InsetGroup(
              dividerIndent: 16,
              footer: 'Changing the vial or mixture clears this drug’s sign-off.',
              children: [
                NumberRow(label: 'Vial strength', controller: _vial, unit: '${d.vial.unit.label}/mL', onChanged: () {}),
                if (inf != null)
                  NumberRow(
                    label: '1 mL/h gives',
                    controller: _mix,
                    unit: inf.unit.label,
                    placeholder: 'Default',
                    onChanged: () {},
                  ),
                SwitchListTile.adaptive(
                  value: _hidden,
                  onChanged: (v) => setState(() => _hidden = v),
                  title: Text('Hide on this ward', style: AppTypography.body(color: AppColors.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InsetGroup(
              header: 'Ward note',
              children: [
                InsetTextRow(label: 'Note', controller: _note, placeholder: 'e.g. Central line only', maxLines: 3),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
