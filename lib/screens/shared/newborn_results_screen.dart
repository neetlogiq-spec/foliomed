import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../clinical/bilirubin.dart';
import '../../models/newborn_screen.dart';
import '../../models/patient.dart';
import '../../services/newborn_screen_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/app_utils.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/birth_time_field.dart';
import '../../widgets/inset_group.dart';

/// Enter (or correct) the newborn investigation results. Bilirubin is
/// compared live with the guideline thresholds for the baby's hour of age
/// at sampling.
class NewbornResultsScreen extends StatefulWidget {
  const NewbornResultsScreen({super.key, required this.screen, required this.patient});

  final NewbornScreen screen;
  final Patient patient;

  @override
  State<NewbornResultsScreen> createState() => _NewbornResultsScreenState();
}

class _NewbornResultsScreenState extends State<NewbornResultsScreen> {
  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static final _decimal = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}([.,]\d{0,2})?')),
  ];

  late final NewbornResults _initial = widget.screen.results;
  late final _hb = _c(_initial.hb);
  late final _tlc = _c(_initial.tlc);
  late final _plt = _c(_initial.platelets);
  late final _hct = _c(_initial.hct);
  late final _tsh = _c(_initial.tsh);
  late final _tsbTotal = _c(_initial.tsbTotal);
  late final _tsbDirect = _c(_initial.tsbDirect);
  late final _urea = _c(_initial.urea);
  late final _creat = _c(_initial.creatinine);
  late final _na = _c(_initial.sodium);
  late final _k = _c(_initial.potassium);
  late final _cl = _c(_initial.chloride);
  late final _remarks = TextEditingController(text: _initial.remarks ?? '');

  late DateTime _sampledAt = _initial.sampledAt ??
      (DateTime.now().isBefore(widget.screen.dueAt) ? DateTime.now() : widget.screen.dueAt);
  late BiliUnit _unit = _initial.biliUnit;
  late String? _babyGroup = _initial.babyBloodGroup;
  late String? _motherGroup = _initial.motherBloodGroup;
  late OaeResult? _oaeR = _initial.oaeRight;
  late OaeResult? _oaeL = _initial.oaeLeft;
  bool _saving = false;

  static TextEditingController _c(double? v) => TextEditingController(
      text: v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'));

  static double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_hb, _tlc, _plt, _hct, _tsh, _tsbTotal, _tsbDirect, _urea,
        _creat, _na, _k, _cl, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  NewbornResults get _results => NewbornResults(
        sampledAt: _sampledAt,
        hb: _num(_hb),
        tlc: _num(_tlc),
        platelets: _num(_plt),
        hct: _num(_hct),
        tsh: _num(_tsh),
        babyBloodGroup: _babyGroup,
        motherBloodGroup: _motherGroup,
        biliUnit: _unit,
        tsbTotal: _num(_tsbTotal),
        tsbDirect: _num(_tsbDirect),
        urea: _num(_urea),
        creatinine: _num(_creat),
        sodium: _num(_na),
        potassium: _num(_k),
        chloride: _num(_cl),
        oaeRight: _oaeR,
        oaeLeft: _oaeL,
        remarks: _remarks.text,
      );

  double? get _hoursAtSample {
    final born = widget.patient.bornAt;
    if (born == null) return null;
    return _sampledAt.difference(born).inMinutes / 60;
  }

  /// One guideline assessment per configured guideline.
  List<Object> _assessments(NewbornResults r) {
    final total = r.tsbTotal;
    final hours = _hoursAtSample;
    if (total == null || hours == null) return const [];
    final umol = r.biliUnit == BiliUnit.mgdl ? mgdlToUmol(total) : total;
    return [
      for (final g in kBilirubinGuidelines)
        g.assess(
          gestationWeeks: widget.patient.gestationWeeks,
          hoursOfAge: hours,
          tsbUmol: umol,
        ),
    ];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = _results;
    final nice = _assessments(r).whereType<BiliAssessment>().firstOrNull;
    final summary = r.summary(
      biliAssessment: nice == null
          ? null
          : '${nice.guideline} at ${nice.hoursOfAge.round()} h: ${nice.action.label}',
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await NewbornScreenService().saveResults(widget.screen.id, r, summary);
      Haptics.success();
      navigator.pop(true);
      messenger.showSnackBar(
          const SnackBar(content: Text('Results saved and added to the timeline')));
    } catch (e) {
      Haptics.error();
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text("Couldn't save results — ${friendlyError(e)}"),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _results;
    final hours = _hoursAtSample;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 96,
        leading: CupertinoButton(
          padding: const EdgeInsets.only(left: 16),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        title: Column(
          children: [
            Text('Results', style: AppTypography.headline(color: AppColors.textPrimary)),
            Text(widget.patient.name,
                style: AppTypography.caption1(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: CupertinoActivityIndicator(),
                )
              : CupertinoButton(
                  padding: const EdgeInsets.only(right: 16),
                  onPressed: r.isEmpty ? null : _save,
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          InsetGroup(
            header: 'Sample',
            dividerIndent: 16,
            footer: 'Leave a field blank if it is not back yet — you can add it later.',
            children: [
              SettingsRow(
                title: 'Sampled at',
                subtitle: hours == null ? null : '${hours.round()} h of life',
                value: formatDueTime(_sampledAt),
                onTap: () async {
                  final t = await pickBirthDateTime(context, _sampledAt, title: 'Sample time');
                  if (t != null) setState(() => _sampledAt = t);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          InsetGroup(header: 'Bilirubin (TSB)', dividerIndent: 16, children: [
            InsetSegmentedRow<BiliUnit>(
              label: 'Unit',
              value: _unit,
              options: {for (final u in BiliUnit.values) u: u.label},
              onChanged: (u) => setState(() => _unit = u),
            ),
            _num$('Total', _tsbTotal, _unit.label),
            _num$('Direct', _tsbDirect, _unit.label),
            SettingsRow(
              title: 'Indirect',
              subtitle: 'Total − direct',
              value: r.tsbIndirect == null ? '—' : '${_fmt(r.tsbIndirect!)} ${_unit.label}',
            ),
          ]),
          const SizedBox(height: 12),
          _BilirubinCard(assessments: _assessments(r), patient: widget.patient,
              hasTsb: r.tsbTotal != null),
          const SizedBox(height: 24),
          InsetGroup(header: 'CBC', dividerIndent: 16, children: [
            _num$('Hb', _hb, 'g/dL'),
            _num$('TLC', _tlc, '×10³/µL'),
            _num$('Platelets', _plt, '×10³/µL'),
            _num$('Hct', _hct, '%'),
          ]),
          const SizedBox(height: 24),
          InsetGroup(header: 'Thyroid', dividerIndent: 16, children: [
            _num$('TSH', _tsh, 'µIU/mL'),
          ]),
          const SizedBox(height: 24),
          InsetGroup(header: 'Blood grouping', dividerIndent: 16, children: [
            _groupRow('Baby', _babyGroup, (g) => _babyGroup = g),
            _groupRow('Mother', _motherGroup, (g) => _motherGroup = g),
          ]),
          const SizedBox(height: 24),
          InsetGroup(header: 'RFT', dividerIndent: 16, children: [
            _num$('Urea', _urea, 'mg/dL'),
            _num$('Creatinine', _creat, 'mg/dL'),
            _num$('Sodium', _na, 'mmol/L'),
            _num$('Potassium', _k, 'mmol/L'),
            _num$('Chloride', _cl, 'mmol/L'),
          ]),
          const SizedBox(height: 24),
          InsetGroup(header: 'OAE (hearing)', dividerIndent: 16, children: [
            _oaeRow('Right ear', _oaeR, (v) => _oaeR = v),
            _oaeRow('Left ear', _oaeL, (v) => _oaeL = v),
          ]),
          const SizedBox(height: 24),
          InsetGroup(header: 'Remarks', dividerIndent: 16, children: [
            InsetTextRow(
              label: 'Notes',
              controller: _remarks,
              placeholder: 'Optional',
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _num$(String label, TextEditingController c, String unit) => InsetTextRow(
        label: label,
        controller: c,
        placeholder: '—',
        suffix: unit,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _decimal,
        onChanged: (_) => setState(() {}),
      );

  Widget _groupRow(String label, String? value, void Function(String?) set) => SettingsRow(
        title: label,
        value: value ?? 'Not set',
        onTap: () async {
          final g = await showOptionSheet<String>(
            context,
            title: '$label blood group',
            selected: value,
            options: {for (final g in _groups) g: g, '': 'Not known'},
          );
          if (g != null) setState(() => set(g.isEmpty ? null : g));
        },
      );

  Widget _oaeRow(String label, OaeResult? value, void Function(OaeResult?) set) =>
      InsetSegmentedRow<OaeResult>(
        label: label,
        value: value,
        options: {for (final o in OaeResult.values) o: o.label},
        onChanged: (v) => setState(() => set(v)),
      );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Live comparison of the TSB with each guideline. Decision support only.
class _BilirubinCard extends StatelessWidget {
  const _BilirubinCard({required this.assessments, required this.patient, required this.hasTsb});

  final List<Object> assessments;
  final Patient patient;
  final bool hasTsb;

  static Color _color(BiliAction a) => switch (a) {
        BiliAction.none => AppColors.accent,
        BiliAction.repeat => AppColors.primary,
        BiliAction.considerPhototherapy => AppColors.warning,
        BiliAction.phototherapy => AppColors.danger,
        BiliAction.exchange => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final String? prompt = patient.bornAt == null
        ? 'Add the birth time to compare bilirubin with guideline thresholds.'
        : !hasTsb
            ? 'Enter the total bilirubin to compare with NICE thresholds.'
            : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bilirubin thresholds',
              style: AppTypography.headline(color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (prompt != null)
            Text(prompt, style: AppTypography.footnote(color: AppColors.textSecondary))
          else
            for (final a in assessments) ...[
              if (a is BiliAssessment) _assessment(a) else _notApplicable(a as BiliNotApplicable),
              const SizedBox(height: 10),
            ],
          Text(
            'Decision support only — confirm against the guideline chart and '
            'clinical judgement (risk factors, trend, the baby in front of you).',
            style: AppTypography.caption1(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _assessment(BiliAssessment a) {
    final t = a.thresholds;
    final c = _color(a.action);
    String both(double umol) => '${umol.round()} µmol/L (${umolToMgdl(umol).toStringAsFixed(1)} mg/dL)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(a.action == BiliAction.none ? Icons.check_circle : Icons.error,
                color: c, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${a.guideline}: ${a.action.label}',
                  style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'At ${a.hoursOfAge.round()} h: TSB ${both(a.tsbUmol)}.\n'
          'Phototherapy > ${both(t.phototherapy)} · exchange > ${both(t.exchange)}.\n'
          '${a.action.detail}',
          style: AppTypography.footnote(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _notApplicable(BiliNotApplicable n) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${n.guideline}: ${n.reason}',
                style: AppTypography.footnote(color: AppColors.textSecondary)),
          ),
        ],
      );
}
