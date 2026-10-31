import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../clinical/bilirubin.dart';
import '../clinical/bilirubin_assess.dart';
import '../clinical/birth_summary.dart';
import '../models/newborn_tracking.dart';
import '../models/patient.dart';
import '../services/patient_service.dart';
import '../services/tracking_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'bilirubin_chart.dart';
import 'birth_time_field.dart';
import 'inset_group.dart';
import 'risk_factors_sheet.dart';

/// Patient page (newborns): bilirubin trend + phototherapy, and weights.
class NewbornTrackingSection extends StatefulWidget {
  const NewbornTrackingSection({super.key, required this.patient});

  final Patient patient;

  @override
  State<NewbornTrackingSection> createState() => _NewbornTrackingSectionState();
}

class _NewbornTrackingSectionState extends State<NewbornTrackingSection> {
  final _service = TrackingService();
  late final _readings = _service.readings(widget.patient.id);
  late final _sessions = _service.phototherapy(widget.patient.id);
  late final _weights = _service.weights(widget.patient.id);

  Patient get p => widget.patient;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      Haptics.success();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<BilirubinReading>>(
          stream: _readings,
          builder: (context, rs) => StreamBuilder<List<PhototherapySession>>(
            stream: _sessions,
            builder: (context, ss) => _bilirubinGroup(
                rs.data ?? const [], ss.data ?? const [], rs.hasError || ss.hasError),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<WeightEntry>>(
          stream: _weights,
          builder: (context, ws) => _weightsGroup(ws.data ?? const [], ws.hasError),
        ),
      ],
    );
  }

  // ───────────────────────────── Bilirubin ─────────────────────────────

  String _guidelineFooter(ThresholdLines? lines) {
    final ga = p.gestationWeeks;
    if (lines == null) {
      if (ga == null) return 'Add the gestational age (Edit details) to draw guideline lines.';
      if (ga < NiceCg98.minPretermWeeks) {
        return 'NICE graphs start at ${NiceCg98.minPretermWeeks} weeks — use your unit\'s chart.';
      }
      if (ga >= kAapMinWeeks && p.neuroRisk == null) {
        return 'Record the neurotoxicity risk factors above to draw AAP lines.';
      }
      return 'Guideline thresholds unavailable.';
    }
    final aap = lines.guideline == 'AAP 2022';
    return '${aap ? 'Orange: phototherapy · pale red: escalation of care · red: exchange (AAP 2022, '
            '${p.neuroRisk! ? 'with' : 'no'} neurotoxicity risk factors).' : 'Orange: phototherapy · red: exchange '
            '(NICE CG98, ${ga! >= NiceCg98.termWeeks ? '≥38 weeks' : '$ga weeks'}).'}'
        ' AAP 2022 is used from $kAapMinWeeks weeks, NICE below.'
        ' Hollow dots are transcutaneous — confirm with a serum level before treating.'
        '${aap && !Aap2022.dataVerified ? ' AAP data not yet verified against the published tables.' : ''}'
        '${!aap && ga! < NiceCg98.termWeeks && !NiceCg98.pretermVerified ? ' NICE preterm lines not yet verified against the published graphs.' : ''}'
        ' Decision support only.';
  }

  Widget _bilirubinGroup(List<BilirubinReading> readings,
      List<PhototherapySession> sessions, bool error) {
    final choice = guidelineForGestation(p.gestationWeeks);
    final lines = linesForPatient(p);
    final latest = readings.isEmpty ? null : readings.last;
    final assessment =
        latest == null ? null : assessForPatient(p, latest.measuredAt, latest.umol);
    final running = sessions.where((s) => s.isRunning).firstOrNull;
    final serum = [
      for (final r in readings)
        if (!r.transcutaneous) (at: r.measuredAt, umol: r.umol),
    ];
    final rate = riseRateMgdlPerHour(serum);
    final rateAge = serum.isEmpty ? 0.0 : serum.last.at.difference(p.bornAt!).inMinutes / 60;
    final now = DateTime.now();
    final factors = p.neuroRiskFactors;
    return InsetGroup(
      header: 'Bilirubin',
      footer: _guidelineFooter(lines),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            choice == null
                ? 'Guideline: needs gestational age'
                : 'Guideline: ${choice.label} (${p.gestationLabel})',
            style: AppTypography.subheadline(
                color: choice == null ? AppColors.warning : AppColors.textPrimary,
                weight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: error
              ? Text("Couldn't load readings.",
                  style: AppTypography.footnote(color: AppColors.danger))
              : BilirubinChart(
                  bornAt: p.bornAt!,
                  readings: readings,
                  sessions: sessions,
                  lines: lines,
                ),
        ),
        if (latest != null)
          SettingsRow(
            icon: Icons.show_chart,
            iconColor: assessment != null &&
                    assessment.action.index >= BiliAction.considerPhototherapy.index
                ? AppColors.danger
                : AppColors.accent,
            title: 'Latest ${latest.transcutaneous ? 'TcB' : 'TSB'} '
                '${_fmt(latest.value)} ${latest.isUmol ? 'µmol/L' : 'mg/dL'}',
            subtitle: [
              '${latest.measuredAt.difference(p.bornAt!).inHours} h · ${formatDueTime(latest.measuredAt)}',
              if (assessment != null) '${assessment.guideline}: ${assessment.action.label}',
            ].join('\n'),
            onTap: () => _readingsList(readings),
          ),
        if (rate != null)
          SettingsRow(
            icon: rate > 0 ? Icons.trending_up : Icons.trending_down,
            iconColor: isRapidRise(rate, rateAge) ? AppColors.danger : AppColors.textSecondary,
            title: '${rate >= 0 ? 'Rising' : 'Falling'} ${rate.abs().toStringAsFixed(2)} mg/dL per hour',
            subtitle: isRapidRise(rate, rateAge)
                ? 'Rapid rise (AAP: ≥${rateAge < 24 ? '0.3' : '0.2'} mg/dL/h) — consider haemolysis'
                : 'Between the last two serum readings',
          ),
        SettingsRow(
          icon: Icons.health_and_safety_outlined,
          iconColor: factors == null
              ? AppColors.warning
              : factors.isEmpty
                  ? AppColors.accent
                  : AppColors.danger,
          title: 'Neurotoxicity risk factors',
          subtitle: riskFactorsLabel(factors) ?? 'Not assessed — needed for AAP thresholds',
          onTap: p.isActive ? _editRiskFactors : null,
        ),
        if (p.isActive)
          SettingsRow(
            icon: Icons.add,
            title: 'Add bilirubin reading',
            onTap: () => _addReading(),
          ),
        if (running != null)
          SettingsRow(
            icon: Icons.light_mode,
            iconColor: AppColors.warning,
            title: '${running.kind.label} phototherapy running',
            subtitle: 'Started ${formatDueTime(running.startedAt)} · '
                '${running.durationAt(now).inMinutes ~/ 60} h ${running.durationAt(now).inMinutes % 60} min',
            trailing: Text('Stop', style: AppTypography.body(color: AppColors.danger)),
            onTap: () => _stopPhototherapy(running),
          )
        else if (p.isActive)
          SettingsRow(
            icon: Icons.light_mode_outlined,
            iconColor: AppColors.warning,
            title: 'Start phototherapy',
            subtitle: sessions.isEmpty
                ? null
                : '${sessions.length} previous session${sessions.length == 1 ? '' : 's'}',
            onTap: _startPhototherapy,
          ),
      ],
    );
  }

  Future<void> _editRiskFactors() async {
    final selected = await showRiskFactorsSheet(context, p.neuroRiskFactors);
    if (selected == null) return;
    await _run(() => PatientService().setNeuroRiskFactors(p.id, selected));
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _readingsList(List<BilirubinReading> readings) async {
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              InsetGroup(
                header: 'All readings',
                footer: 'Readings from investigation results are edited there.',
                children: [
                  for (final r in readings.reversed)
                    SettingsRow(
                      title: '${r.transcutaneous ? 'TcB' : 'TSB'} ${_fmt(r.value)} '
                          '${r.isUmol ? 'µmol/L' : 'mg/dL'}',
                      subtitle: '${r.measuredAt.difference(p.bornAt!).inHours} h · '
                          '${formatDueTime(r.measuredAt)}'
                          '${r.createdByName?.isNotEmpty ?? false ? ' · ${r.createdByName}' : ''}',
                      trailing: r.fromScreen
                          ? null
                          : IconButton(
                              tooltip: 'Delete reading',
                              icon: Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _run(() => _service.deleteReading(r.id));
                              },
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addReading() async {
    final draft = await showAppSheet<_ReadingDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddReadingSheet(bornAt: p.bornAt!),
    );
    if (draft == null) return;
    await _run(() => _service.addReading(
          patientId: p.id,
          wardId: p.wardId,
          measuredAt: draft.at,
          value: draft.value,
          umol: draft.umol,
          transcutaneous: draft.tcb,
        ));
  }

  Future<void> _startPhototherapy() async {
    final kind = await showOptionSheet<PhototherapyKind>(
      context,
      title: 'Start phototherapy',
      options: {for (final k in PhototherapyKind.values) k: k.label},
    );
    if (kind == null) return;
    await _run(() => _service.startPhototherapy(p.id, p.wardId, kind),
        done: '${kind.label} phototherapy started');
  }

  Future<void> _stopPhototherapy(PhototherapySession s) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Stop phototherapy?'),
        content: Text('Running since ${formatDueTime(s.startedAt)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop')),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.stopPhototherapy(s.id), done: 'Phototherapy stopped');
  }

  // ───────────────────────────── Weights ─────────────────────────────

  Widget _weightsGroup(List<WeightEntry> weights, bool error) {
    final birth = p.birthWeightG;
    Color flagColor(WeightFlag f) => switch (f) {
          WeightFlag.ok => AppColors.textSecondary,
          WeightFlag.watch => AppColors.warning,
          WeightFlag.alert => AppColors.danger,
        };
    final recent = weights.reversed.take(7).toList();
    final latestChange =
        birth == null || weights.isEmpty ? null : WeightChange(birth, weights.last.grams);
    return InsetGroup(
      header: 'Weight',
      footer: birth == null
          ? 'Add the birth weight (Edit details) to see the change from birth.'
          : latestChange?.flag == WeightFlag.alert
              ? 'More than 10% below birth weight — review feeding and hydration.'
              : 'Change is from the birth weight of ${(birth / 1000).toStringAsFixed(2)} kg. '
                  'Amber beyond 7% loss, red beyond 10%.',
      children: [
        if (error)
          const SettingsRow(title: "Couldn't load weights")
        else
          for (final w in recent)
            SettingsRow(
              title: formatBirthWeightKg(w.grams).replaceFirst('kgs', ' kg'),
              subtitle: formatDueTime(w.measuredAt),
              trailing: birth == null
                  ? null
                  : Text(
                      WeightChange(birth, w.grams).label,
                      style: AppTypography.subheadline(
                        color: flagColor(WeightChange(birth, w.grams).flag),
                        weight: FontWeight.w600,
                      ).copyWith(fontFeatures: AppTypography.tabular),
                    ),
              onTap: () => _deleteWeight(w),
              showChevron: false,
            ),
        if (p.isActive)
          SettingsRow(icon: Icons.add, title: 'Add weight', onTap: _addWeight),
      ],
    );
  }

  Future<void> _addWeight() async {
    final c = TextEditingController();
    final kg = await showAdaptiveDialog<double>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text("Today's weight"),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,1}([.,]\d{0,3})?'))],
          decoration: const InputDecoration(hintText: 'e.g. 2.95', suffixText: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(c.text.trim().replaceAll(',', '.'))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (kg == null) return;
    final grams = (kg * 1000).round();
    if (grams < 300 || grams > 8000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a weight between 0.3 and 8 kg.')));
      return;
    }
    await _run(() => _service.addWeight(
        patientId: p.id, wardId: p.wardId, measuredAt: DateTime.now(), grams: grams));
  }

  Future<void> _deleteWeight(WeightEntry w) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Delete this weight?'),
        content: Text('${w.grams} g · ${formatDueTime(w.measuredAt)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.deleteWeight(w.id));
  }
}

class _ReadingDraft {
  const _ReadingDraft(this.value, this.umol, this.tcb, this.at);
  final double value;
  final bool umol;
  final bool tcb;
  final DateTime at;
}

class _AddReadingSheet extends StatefulWidget {
  const _AddReadingSheet({required this.bornAt});
  final DateTime bornAt;

  @override
  State<_AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends State<_AddReadingSheet> {
  final _value = TextEditingController();
  bool _umol = false;
  bool _tcb = false;
  DateTime _at = DateTime.now();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  double? get _parsed => double.tryParse(_value.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final v = _parsed;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text('Bilirubin',
                        textAlign: TextAlign.center,
                        style: AppTypography.headline(color: AppColors.textPrimary)),
                  ),
                  CupertinoButton(
                    onPressed: v == null || v <= 0
                        ? null
                        : () => Navigator.pop(context, _ReadingDraft(v, _umol, _tcb, _at)),
                    child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              InsetGroup(
                dividerIndent: 16,
                children: [
                  InsetTextRow(
                    label: 'Value',
                    controller: _value,
                    autofocus: true,
                    placeholder: '—',
                    suffix: _umol ? 'µmol/L' : 'mg/dL',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d{0,1})?')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                  InsetSegmentedRow<bool>(
                    label: 'Unit',
                    value: _umol,
                    options: const {false: 'mg/dL', true: 'µmol/L'},
                    onChanged: (u) => setState(() => _umol = u),
                  ),
                  InsetSegmentedRow<bool>(
                    label: 'Method',
                    value: _tcb,
                    options: const {false: 'Serum (TSB)', true: 'Transcutaneous'},
                    onChanged: (t) => setState(() => _tcb = t),
                  ),
                  SettingsRow(
                    title: 'Measured',
                    subtitle: '${_at.difference(widget.bornAt).inHours} h of life',
                    value: formatDueTime(_at),
                    onTap: () async {
                      final t = await pickBirthDateTime(context, _at, title: 'Measured at');
                      if (t != null) setState(() => _at = t);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
