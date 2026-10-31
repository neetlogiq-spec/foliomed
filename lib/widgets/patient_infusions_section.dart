import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../models/patient_infusion.dart';
import '../screens/tools/infusion_tool.dart';
import '../screens/tools/tool_page.dart';
import '../services/drug_service.dart';
import '../tools/drugs/drug_list.dart';
import '../tools/drugs/drug_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'inset_group.dart';

/// Infusions running on a patient: change the dose, stop, or start one
/// from the Infusion Rate tool. Every change is on the timeline.
class PatientInfusionsSection extends StatefulWidget {
  const PatientInfusionsSection({super.key, required this.patient});
  final Patient patient;

  @override
  State<PatientInfusionsSection> createState() => _PatientInfusionsSectionState();
}

class _PatientInfusionsSectionState extends State<PatientInfusionsSection> {
  late final Stream<List<PatientInfusion>> _stream = DrugService().watchInfusions(widget.patient.id);

  void _startNew() =>
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => InfusionTool(patient: widget.patient)));

  Future<void> _actions(PatientInfusion i) async {
    final choice = await showOptionSheet<String>(
      context,
      title: i.line,
      message: i.syringe.isEmpty ? null : i.syringe,
      options: const {'change': 'Change Dose', 'stop': 'Stop Infusion'},
    );
    if (!mounted) return;
    if (choice == 'change')
      await showAppSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ChangeSheet(infusion: i),
      );
    if (choice == 'stop') await _stop(i);
  }

  Future<void> _stop(PatientInfusion i) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text('Stop ${i.drugName}?'),
        content: Text('Running since ${formatDueTime(i.startedAt)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DrugService().stop(i.id);
      Haptics.success();
      messenger.showSnackBar(SnackBar(content: Text('${i.drugName} stopped')));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(content: Text("Couldn't stop — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return StreamBuilder<List<PatientInfusion>>(
      stream: _stream,
      builder: (context, snap) {
        final running = [
          for (final i in snap.data ?? const <PatientInfusion>[])
            if (i.isRunning) i,
        ];
        if (!p.isActive && running.isEmpty) return const SizedBox.shrink();
        return InsetGroup(
          header: 'Infusions',
          footer: running.isEmpty ? null : 'Tap an infusion to change the dose or stop it.',
          children: [
            if (snap.hasError)
              SettingsRow(title: "Couldn't load infusions", icon: Icons.cloud_off_outlined)
            else
              for (final i in running)
                SettingsRow(
                  key: ValueKey(i.id),
                  icon: Icons.water_drop_outlined,
                  iconColor: AppColors.stable,
                  title: i.line,
                  subtitle: [
                    if (i.syringe.isNotEmpty) i.syringe,
                    i.changedAt == null
                        ? 'since ${formatDueTime(i.startedAt)}${i.startedByName == null ? '' : ' · ${i.startedByName}'}'
                        : 'changed ${formatDueTime(i.changedAt!)}${i.changedByName == null ? '' : ' · ${i.changedByName}'}',
                  ].join(' · '),
                  showChevron: true,
                  onTap: () => _actions(i),
                ),
            if (p.isActive)
              SettingsRow(
                icon: Icons.add,
                title: running.isEmpty ? 'Start an Infusion' : 'Start Another',
                showChevron: true,
                onTap: _startNew,
              ),
          ],
        );
      },
    );
  }
}

/// New dose; the rate is worked out for list drugs when the weight is known.
class _ChangeSheet extends StatefulWidget {
  const _ChangeSheet({required this.infusion});
  final PatientInfusion infusion;

  @override
  State<_ChangeSheet> createState() => _ChangeSheetState();
}

class _ChangeSheetState extends State<_ChangeSheet> {
  late final _dose = TextEditingController(text: trimNum(widget.infusion.dose));
  late final _rate = TextEditingController(text: trimNum(widget.infusion.rateMlH));
  bool _saving = false;

  Drug? get _drug {
    final k = widget.infusion.drugKey;
    final d = k == null ? null : drugByKey(k);
    return d?.infusion?.unit.label == widget.infusion.doseUnit ? d : null;
  }

  @override
  void dispose() {
    _dose.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _doseChanged() {
    final d = _drug, kg = widget.infusion.weightKg, dose = readNumber(_dose);
    if (d != null && kg != null && dose != null) {
      final r = rateFor(drug: d, dose: dose, kg: kg, concentration: widget.infusion.concentration);
      _rate.text = trimNum(roundRate(r), 1);
    }
    setState(() {});
  }

  Future<void> _save() async {
    final dose = double.tryParse(_dose.text.trim()), rate = double.tryParse(_rate.text.trim());
    if (dose == null || rate == null || dose < 0 || rate < 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await DrugService().change(widget.infusion.id, dose: dose, rateMlH: rate);
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('${widget.infusion.drugName} changed — on the timeline')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't change — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.infusion;
    final auto = _drug != null && i.weightKg != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change ${i.drugName}', style: AppTypography.title3(color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Now ${i.line}${i.syringe.isEmpty ? '' : ' · ${i.syringe}'}',
              style: AppTypography.footnote(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            InsetGroup(
              dividerIndent: 16,
              footer: auto
                  ? 'The rate follows the dose for this syringe (${trimNum(i.concentration, 4)} ${i.concUnit}, '
                        '${trimNum(i.weightKg!)} kg). Check the pump before confirming.'
                  : 'Enter both the new dose and the pump rate.',
              children: [
                NumberRow(label: 'Dose', controller: _dose, unit: i.doseUnit, onChanged: _doseChanged),
                NumberRow(label: 'Pump rate', controller: _rate, unit: 'mL/h', onChanged: () => setState(() {})),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('Save Change')),
          ],
        ),
      ),
    );
  }
}
