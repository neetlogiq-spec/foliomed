import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../clinical/early_warning.dart';
import '../clinical/patient_status.dart';
import '../models/observation.dart';
import '../models/patient.dart';
import '../services/observation_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'birth_time_field.dart';
import 'inset_group.dart';
import 'status_dot.dart';

/// Dot colour for a score band (same mapping as the status dot).
StatusLevel bandLevel(EarlyWarningBand b) => switch (b) {
      EarlyWarningBand.high || EarlyWarningBand.medium => StatusLevel.act,
      EarlyWarningBand.lowMedium => StatusLevel.watch,
      EarlyWarningBand.low => StatusLevel.ok,
    };

/// Patient page (28 days and over): latest observations with NEWS2 or
/// PEWS, earlier sets, and Add Observations. Live.
class ObservationsSection extends StatefulWidget {
  const ObservationsSection({super.key, required this.patient});

  final Patient patient;

  @override
  State<ObservationsSection> createState() => _ObservationsSectionState();
}

class _ObservationsSectionState extends State<ObservationsSection> {
  late final Stream<List<Observation>> _obs = ObservationService().watch(widget.patient.id);

  Patient get p => widget.patient;

  @override
  Widget build(BuildContext context) {
    final kind = earlyWarningFor(p, DateTime.now());
    if (kind == null) return const SizedBox.shrink();
    return StreamBuilder<List<Observation>>(
      stream: _obs,
      builder: (context, snap) {
        final all = snap.data ?? const <Observation>[];
        final recent = all.reversed.take(6).toList();
        return InsetGroup(
          header: 'Observations · ${kind.label}',
          footer: [
            kind == EarlyWarningKind.news2
                ? 'NEWS2 (RCP 2017) for 16 years and over — not for use in pregnancy.'
                : 'Brighton PEWS for children. Score each part from your chart’s normal ranges for age.',
            if (!kEarlyWarningVerified) 'Scoring not yet clinically checked — confirm on your chart.',
            'Decision support only.',
          ].join(' '),
          children: [
            if (snap.hasError)
              const SettingsRow(title: "Couldn't load observations")
            else if (recent.isEmpty)
              SettingsRow(title: 'No observations yet', subtitle: p.isActive ? null : 'Discharged')
            else
              for (final o in recent) _row(o),
            if (p.isActive)
              SettingsRow(
                icon: Icons.add,
                title: 'Add observations',
                onTap: () => _add(kind),
              ),
          ],
        );
      },
    );
  }

  Widget _row(Observation o) {
    final score = scoreObservation(p, o, DateTime.now());
    return SettingsRow(
      leading: score == null
          ? null
          : Center(
              child: StatusDot(
                status: PatientStatusResult(score.complete ? bandLevel(score.band) : StatusLevel.unknown, const []),
                size: 12,
              ),
            ),
      icon: score == null ? Icons.monitor_heart_outlined : null,
      title: score?.label ?? 'Observations',
      subtitle: [
        if (o.summary.isNotEmpty) o.summary,
        '${formatDueTime(o.takenAt)}${(o.createdByName ?? '').isEmpty ? '' : ' · ${o.createdByName}'}',
      ].join('\n'),
      onTap: () => _detail(o, score),
    );
  }

  Future<void> _detail(Observation o, EarlyWarningScore? score) async {
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InsetGroup(
                header: formatDueTime(o.takenAt),
                footer: score?.response,
                dividerIndent: 16,
                children: [
                  if (score != null) ...[
                    SettingsRow(title: score.label, showChevron: false),
                    for (final e in score.parts.entries)
                      SettingsRow(title: e.key, value: '${e.value}', showChevron: false),
                  ],
                  if (o.summary.isNotEmpty) SettingsRow(title: o.summary, showChevron: false),
                  if ((o.note ?? '').isNotEmpty) SettingsRow(title: o.note!, showChevron: false),
                ],
              ),
              if (p.isActive) ...[
                const SizedBox(height: 16),
                InsetGroup(children: [
                  SettingsRow(
                    title: 'Delete these observations',
                    destructive: true,
                    onTap: () async {
                      final sure = await showAdaptiveDialog<bool>(
                        context: ctx,
                        builder: (d) => AppAlertDialog(
                          title: const Text('Delete these observations?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: Text('Delete', style: TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      );
                      if (sure != true || !ctx.mounted) return;
                      Navigator.pop(ctx);
                      await _run(() => ObservationService().delete(o.id), done: 'Observations deleted');
                    },
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(EarlyWarningKind kind) async {
    final o = await showAppSheet<Observation>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ObservationSheet(patient: p, kind: kind),
    );
    if (o == null) return;
    await _run(() => ObservationService().add(o), done: 'Observations saved');
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      Haptics.success();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }
}

/// Entry sheet; pops the new [Observation] on Save. The score updates as
/// values are typed.
class ObservationSheet extends StatefulWidget {
  const ObservationSheet({super.key, required this.patient, required this.kind});

  final Patient patient;
  final EarlyWarningKind kind;

  @override
  State<ObservationSheet> createState() => _ObservationSheetState();
}

class _ObservationSheetState extends State<ObservationSheet> {
  final _rr = TextEditingController();
  final _spo2 = TextEditingController();
  final _lpm = TextEditingController();
  final _hr = TextEditingController();
  final _sbp = TextEditingController();
  final _dbp = TextEditingController();
  final _temp = TextEditingController();
  final _note = TextEditingController();
  DateTime _takenAt = DateTime.now();
  bool _scale2 = false;
  bool? _onOxygen;
  Consciousness? _acvpu;
  int? _behaviour, _cardio, _resp;
  bool _extra = false;

  bool get _news2 => widget.kind == EarlyWarningKind.news2;

  @override
  void dispose() {
    for (final c in [_rr, _spo2, _lpm, _hr, _sbp, _dbp, _temp, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  static int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  static double? _dec(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Observation get _draft => Observation(
        patientId: widget.patient.id,
        wardId: widget.patient.wardId,
        takenAt: _takenAt,
        respRate: _int(_rr),
        spo2: _int(_spo2),
        spo2Scale2: _news2 && _scale2,
        onOxygen: _onOxygen,
        oxygenLpm: _onOxygen == true ? _dec(_lpm) : null,
        heartRate: _int(_hr),
        systolicBp: _int(_sbp),
        diastolicBp: _int(_dbp),
        tempC: _dec(_temp),
        consciousness: _acvpu,
        pewsBehaviour: _news2 ? null : _behaviour,
        pewsCardio: _news2 ? null : _cardio,
        pewsResp: _news2 ? null : _resp,
        pewsExtra: !_news2 && _extra,
        note: _note.text,
      );

  /// Range checks matching the database, so a typo can't fail the save.
  String? get _problem {
    final o = _draft;
    bool out(num? v, num lo, num hi) => v != null && (v < lo || v > hi);
    if (out(o.respRate, 0, 150)) return 'Respiration rate should be 0–150.';
    if (out(o.spo2, 40, 100)) return 'SpO₂ should be 40–100%.';
    if (out(o.heartRate, 0, 300)) return 'Heart rate should be 0–300.';
    if (out(o.systolicBp, 20, 300) || out(o.diastolicBp, 10, 250)) return 'Check the blood pressure.';
    if (out(o.tempC, 25, 45)) return 'Temperature should be 25–45 °C.';
    if (out(o.oxygenLpm, 0, 60)) return 'Oxygen flow should be 0–60 L/min.';
    if (o.summary.isEmpty && o.pewsBehaviour == null && o.pewsCardio == null && o.pewsResp == null) {
      return 'Enter at least one observation.';
    }
    return null;
  }

  Widget _num(String label, TextEditingController c, String unit, {bool decimal = false}) => InsetTextRow(
        label: label,
        controller: c,
        placeholder: '—',
        suffix: unit,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
        onChanged: (_) => setState(() {}),
      );

  Widget _pewsPick(String title, List<String> options, int? value, ValueChanged<int> onPick) => SettingsRow(
        title: title,
        subtitle: value == null ? 'Tap to score' : '$value — ${options[value]}',
        value: value?.toString(),
        onTap: () async {
          final v = await showOptionSheet<int>(
            context,
            title: title,
            options: {for (var i = 0; i < options.length; i++) i: '$i — ${options[i]}'},
            selected: value,
          );
          if (v != null) setState(() => onPick(v));
        },
      );

  @override
  Widget build(BuildContext context) {
    final score = scoreObservation(widget.patient, _draft, DateTime.now());
    final problem = _problem;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                Expanded(
                  child: Text('Observations',
                      textAlign: TextAlign.center, style: AppTypography.headline(color: AppColors.textPrimary)),
                ),
                CupertinoButton(
                  onPressed: problem == null ? () => Navigator.pop(context, _draft) : null,
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _scoreCard(score, problem),
                    const SizedBox(height: 16),
                    InsetGroup(dividerIndent: 16, children: [
                      SettingsRow(
                        title: 'Taken at',
                        value: formatDueTime(_takenAt),
                        onTap: () async {
                          final t = await pickBirthDateTime(context, _takenAt, title: 'Observations taken at');
                          if (t != null) setState(() => _takenAt = t);
                        },
                      ),
                    ]),
                    if (!_news2) ...[
                      const SizedBox(height: 16),
                      InsetGroup(header: 'PEWS', dividerIndent: 16, children: [
                        _pewsPick('Behaviour', kPewsBehaviour, _behaviour, (v) => _behaviour = v),
                        _pewsPick('Cardiovascular', kPewsCardio, _cardio, (v) => _cardio = v),
                        _pewsPick('Respiratory', kPewsResp, _resp, (v) => _resp = v),
                        SettingsRow(
                          title: '¼-hourly nebulisers or persistent vomiting',
                          subtitle: 'Adds 2',
                          trailing: Switch.adaptive(value: _extra, onChanged: (v) => setState(() => _extra = v)),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    InsetGroup(
                      header: _news2 ? 'NEWS2' : 'Vital signs (recorded, not scored)',
                      dividerIndent: 16,
                      children: [
                        _num('Respiration rate', _rr, '/min'),
                        _num('SpO₂', _spo2, '%'),
                        if (_news2)
                          SettingsRow(
                            title: 'SpO₂ scale 2',
                            subtitle: 'Prescribed target 88–92%, e.g. hypercapnic respiratory failure',
                            trailing: Switch.adaptive(value: _scale2, onChanged: (v) => setState(() => _scale2 = v)),
                          ),
                        InsetSegmentedRow<bool>(
                          label: 'Breathing',
                          value: _onOxygen,
                          options: const {false: 'Air', true: 'Oxygen'},
                          onChanged: (v) => setState(() => _onOxygen = v),
                        ),
                        if (_onOxygen == true) _num('Oxygen', _lpm, 'L/min', decimal: true),
                        _num('Heart rate', _hr, '/min'),
                        _num('Systolic BP', _sbp, 'mmHg'),
                        _num('Diastolic BP', _dbp, 'mmHg'),
                        _num('Temperature', _temp, '°C', decimal: true),
                        InsetSegmentedRow<Consciousness>(
                          label: 'ACVPU',
                          value: _acvpu,
                          options: {for (final c in Consciousness.values) c: c.code},
                          onChanged: (v) => setState(() => _acvpu = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InsetGroup(children: [
                      InsetTextRow(
                        label: 'Note',
                        controller: _note,
                        placeholder: 'Optional',
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreCard(EarlyWarningScore? score, String? problem) {
    final level = score == null || !score.complete && bandLevel(score.band) == StatusLevel.ok
        ? StatusLevel.unknown
        : bandLevel(score.band);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: StatusDot(status: PatientStatusResult(level, const []), size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(score?.label ?? '${widget.kind.label} — enter observations',
                style: AppTypography.headline(color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(
              problem != null && score != null && problem != 'Enter at least one observation.'
                  ? problem
                  : score?.response ?? 'The score updates as you type.',
              style: AppTypography.footnote(
                  color: problem != null && score != null ? AppColors.danger : AppColors.textSecondary),
            ),
          ]),
        ),
      ]),
    );
  }
}
