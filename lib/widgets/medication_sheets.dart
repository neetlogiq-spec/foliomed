import 'package:flutter/material.dart';

import '../clinical/medications.dart';
import '../models/medication.dart';
import '../models/patient.dart';
import '../services/medication_service.dart';
import '../tools/drugs/drug_list.dart';
import '../tools/drugs/drug_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'chip_choice.dart';
import 'inset_group.dart';

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
    child: Text(
      text.toUpperCase(),
      style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600),
    ),
  );
}

class _Warning extends StatelessWidget {
  const _Warning(this.text, {this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.danger : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(danger ? Icons.warning_rounded : Icons.info_outline, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTypography.subheadline(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// A sheet with a title, scrollable body and one action button.
Widget _sheetFrame(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  required Widget action,
}) => SafeArea(
  child: SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTypography.title3(color: AppColors.textPrimary)),
        ...children,
        const SizedBox(height: 20),
        action,
      ],
    ),
  ),
);

double? _num(TextEditingController c) {
  final v = double.tryParse(c.text.trim());
  return v == null || v <= 0 ? null : v;
}

// ── Add a medicine ───────────────────────────────────────────────────────

/// Start a medicine on this admission ([context] inpatient) or record drug
/// history (home / past). Warns about allergies and high doses first.
Future<void> showAddMedication(
  BuildContext context, {
  required Patient patient,
  required MedContext medContext,
  required List<PatientAllergy> allergies,
  double? weightKg,
  String? initialName,
}) => showAppSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _AddMedication(
    patient: patient,
    medContext: medContext,
    allergies: allergies,
    weightKg: weightKg,
    initialName: initialName,
  ),
);

class _AddMedication extends StatefulWidget {
  const _AddMedication({
    required this.patient,
    required this.medContext,
    required this.allergies,
    this.weightKg,
    this.initialName,
  });
  final Patient patient;
  final MedContext medContext;
  final List<PatientAllergy> allergies;
  final double? weightKg;
  final String? initialName;

  @override
  State<_AddMedication> createState() => _AddMedicationState();
}

class _AddMedicationState extends State<_AddMedication> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  final _dose = TextEditingController();
  final _why = TextEditingController();
  late MedContext _context = widget.medContext;
  String? _drugKey;
  String? _unit = 'mg';
  String? _route;
  String? _freq;
  String? _source;
  bool _saving = false;

  bool get _inpatient => _context == MedContext.inpatient;

  @override
  void dispose() {
    for (final c in [_name, _dose, _why]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fromList() async {
    final key = await showOptionSheet<String>(
      context,
      title: 'FolioMed drug list',
      options: {
        for (final d in [...kDrugs]..sort((a, b) => a.name.compareTo(b.name))) d.key: d.name,
      },
    );
    final d = key == null ? null : drugByKey(key);
    if (d == null) return;
    setState(() {
      _drugKey = d.key;
      _name.text = d.name;
      if (d.boluses.isNotEmpty) _unit = '${d.boluses.first.unit.label}/kg';
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final hits = allergyHits(name, widget.allergies);
    if (hits.isNotEmpty) {
      final go = await showAdaptiveDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: const Text('Allergy recorded'),
          content: Text('${hits.map((h) => h.message).join('\n')}\n\nSave $name anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save Anyway')),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await MedicationService().add(
        patientId: widget.patient.id,
        context: _context,
        drugKey: _drugKey,
        name: name,
        dose: _num(_dose),
        unit: _unit ?? '',
        route: _route ?? '',
        frequency: _freq ?? '',
        indication: _inpatient ? _why.text : null,
        infoSource: _inpatient ? null : _source,
      );
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(_inpatient ? '$name started' : '$name added to drug history')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = allergyHits(_name.text, widget.allergies);
    final dw = doseWarning(drugKey: _drugKey, dose: _num(_dose), unit: _unit ?? '', weightKg: widget.weightKg);
    return _sheetFrame(
      context,
      title: _inpatient ? 'Start a Medicine' : 'Add Drug History',
      children: [
        if (!_inpatient) ...[
          const SizedBox(height: 12),
          SegmentedButton<MedContext>(
            segments: const [
              ButtonSegment(value: MedContext.home, label: Text('Takes at home')),
              ButtonSegment(value: MedContext.past, label: Text('Previously')),
            ],
            selected: {_context},
            onSelectionChanged: (s) => setState(() => _context = s.first),
          ),
        ],
        const SizedBox(height: 12),
        InsetGroup(
          dividerIndent: 16,
          children: [
            InsetTextRow(
              label: 'Drug',
              controller: _name,
              placeholder: 'Type a name',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) =>
                  setState(() => _drugKey = drugByKey(_drugKey ?? '')?.name == _name.text ? _drugKey : null),
            ),
            SettingsRow(icon: Icons.list_alt, title: 'Pick from FolioMed’s list', showChevron: true, onTap: _fromList),
            InsetTextRow(
              label: 'Dose',
              controller: _dose,
              placeholder: 'Optional',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffix: _unit,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        for (final h in hits) _Warning(h.message, danger: !h.possible),
        if (dw != null) _Warning(dw),
        const _Label('Unit'),
        ChipChoice(options: kDoseUnits, value: _unit, onChanged: (v) => setState(() => _unit = v)),
        const _Label('Route'),
        ChipChoice(options: kRoutes, value: _route, onChanged: (v) => setState(() => _route = v)),
        const _Label('How often'),
        ChipChoice(options: kFrequencies, value: _freq, onChanged: (v) => setState(() => _freq = v)),
        if (_inpatient) ...[
          const _Label('Why'),
          InsetGroup(
            children: [InsetTextRow(label: 'Reason', controller: _why, placeholder: 'Optional')],
          ),
        ] else ...[
          const _Label('Who told us'),
          ChipChoice(options: kHistorySources, value: _source, onChanged: (v) => setState(() => _source = v)),
        ],
      ],
      action: FilledButton(
        onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
        child: Text(_inpatient ? 'Start' : 'Add'),
      ),
    );
  }
}

// ── Change a medicine ────────────────────────────────────────────────────

Future<void> showChangeMedication(BuildContext context, {required PatientMedication med, double? weightKg}) =>
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Change(med: med, weightKg: weightKg),
    );

class _Change extends StatefulWidget {
  const _Change({required this.med, this.weightKg});
  final PatientMedication med;
  final double? weightKg;

  @override
  State<_Change> createState() => _ChangeState();
}

class _ChangeState extends State<_Change> {
  late final _dose = TextEditingController(text: widget.med.dose == null ? '' : trimNum(widget.med.dose!));
  final _reason = TextEditingController();
  late String? _unit = widget.med.doseUnit.isEmpty ? null : widget.med.doseUnit;
  late String? _route = widget.med.route.isEmpty ? null : widget.med.route;
  late String? _freq = widget.med.frequency.isEmpty ? null : widget.med.frequency;
  bool _saving = false;

  @override
  void dispose() {
    _dose.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await MedicationService().change(
        widget.med.id,
        dose: _num(_dose),
        unit: _unit ?? '',
        route: _route ?? '',
        frequency: _freq ?? '',
        reason: _reason.text,
      );
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('${widget.med.drugName} changed')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.med;
    final dw = doseWarning(drugKey: m.drugKey, dose: _num(_dose), unit: _unit ?? '', weightKg: widget.weightKg);
    return _sheetFrame(
      context,
      title: 'Change ${m.drugName}',
      children: [
        Text(
          'Now ${m.regimen.isEmpty ? 'no dose recorded' : m.regimen}',
          style: AppTypography.footnote(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        InsetGroup(
          dividerIndent: 16,
          children: [
            InsetTextRow(
              label: 'Dose',
              controller: _dose,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffix: _unit,
              onChanged: (_) => setState(() {}),
            ),
            InsetTextRow(label: 'Reason', controller: _reason, placeholder: 'Optional'),
          ],
        ),
        if (dw != null) _Warning(dw),
        const _Label('Unit'),
        ChipChoice(options: kDoseUnits, value: _unit, onChanged: (v) => setState(() => _unit = v)),
        const _Label('Route'),
        ChipChoice(options: kRoutes, value: _route, onChanged: (v) => setState(() => _route = v)),
        const _Label('How often'),
        ChipChoice(options: kFrequencies, value: _freq, onChanged: (v) => setState(() => _freq = v)),
      ],
      action: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save Change')),
    );
  }
}

// ── Stop / remove with a reason ──────────────────────────────────────────

/// Asks for a reason (quick picks or typed). Null when cancelled.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String action,
  required List<String> quick,
  bool required = false,
}) => showAppSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _Reason(title: title, action: action, quick: quick, required: required),
);

class _Reason extends StatefulWidget {
  const _Reason({required this.title, required this.action, required this.quick, required this.required});
  final String title;
  final String action;
  final List<String> quick;
  final bool required;

  @override
  State<_Reason> createState() => _ReasonState();
}

class _ReasonState extends State<_Reason> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _sheetFrame(
    context,
    title: widget.title,
    children: [
      const _Label('Reason'),
      ChipChoice(
        options: widget.quick,
        value: widget.quick.contains(_text.text) ? _text.text : null,
        onChanged: (v) => setState(() => _text.text = v ?? ''),
      ),
      const SizedBox(height: 12),
      InsetGroup(
        children: [
          InsetTextRow(
            label: 'Or',
            controller: _text,
            placeholder: widget.required ? 'Required' : 'Optional',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ],
    action: FilledButton(
      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
      onPressed: widget.required && _text.text.trim().isEmpty ? null : () => Navigator.pop(context, _text.text.trim()),
      child: Text(widget.action),
    ),
  );
}

// ── Allergies ────────────────────────────────────────────────────────────

const _commonAllergens = ['Penicillin', 'Cephalosporin', 'Sulfonamide', 'NSAID', 'Egg', 'Peanut', 'Milk', 'Latex'];

Future<void> showAddAllergy(BuildContext context, {required Patient patient, String? initialSubstance}) =>
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddAllergy(patient: patient, initialSubstance: initialSubstance),
    );

class _AddAllergy extends StatefulWidget {
  const _AddAllergy({required this.patient, this.initialSubstance});
  final Patient patient;
  final String? initialSubstance;

  @override
  State<_AddAllergy> createState() => _AddAllergyState();
}

class _AddAllergyState extends State<_AddAllergy> {
  late final _substance = TextEditingController(text: widget.initialSubstance ?? '');
  final _reaction = TextEditingController();
  AllergySeverity _severity = AllergySeverity.unknown;
  AllergyKind _kind = AllergyKind.drug;
  String? _source;
  bool _saving = false;

  @override
  void dispose() {
    _substance.dispose();
    _reaction.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await MedicationService().addAllergy(
        patientId: widget.patient.id,
        substance: _substance.text.trim(),
        reaction: _reaction.text,
        severity: _severity,
        kind: _kind,
        infoSource: _source,
      );
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Allergy to ${_substance.text.trim()} recorded')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) => _sheetFrame(
    context,
    title: 'Record an Allergy',
    children: [
      const SizedBox(height: 12),
      InsetGroup(
        dividerIndent: 16,
        children: [
          InsetTextRow(
            label: 'Allergic to',
            controller: _substance,
            placeholder: 'Drug, food or other',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          InsetTextRow(label: 'Reaction', controller: _reaction, placeholder: 'e.g. rash, wheeze, anaphylaxis'),
        ],
      ),
      const SizedBox(height: 8),
      ChipChoice(
        options: _commonAllergens,
        value: _commonAllergens.contains(_substance.text) ? _substance.text : null,
        onChanged: (v) => setState(() => _substance.text = v ?? ''),
      ),
      const _Label('Type'),
      ChipChoice(
        options: [for (final k in AllergyKind.values) k.label],
        value: _kind.label,
        optional: false,
        onChanged: (v) => setState(() => _kind = AllergyKind.values.firstWhere((k) => k.label == v)),
      ),
      const _Label('Severity'),
      ChipChoice(
        options: [for (final s in AllergySeverity.values) s.label],
        value: _severity.label,
        optional: false,
        onChanged: (v) => setState(() => _severity = AllergySeverity.values.firstWhere((s) => s.label == v)),
      ),
      const _Label('Who told us'),
      ChipChoice(options: kHistorySources, value: _source, onChanged: (v) => setState(() => _source = v)),
    ],
    action: FilledButton(
      onPressed: _saving || _substance.text.trim().isEmpty ? null : _save,
      child: const Text('Record Allergy'),
    ),
  );
}
