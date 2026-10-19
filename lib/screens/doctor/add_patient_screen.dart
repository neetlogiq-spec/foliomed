import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../clinical/birth_summary.dart';
import '../../models/newborn_screen.dart';
import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/unit_provider.dart';
import '../../services/patient_service.dart';
import '../../services/newborn_screen_service.dart';
import '../../services/reminder_notifications.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/app_utils.dart';
import '../../utils/friendly_error.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/birth_time_field.dart';
import '../../widgets/inset_group.dart';

/// Admits a new patient, or edits [existing]. An iOS modal form: Cancel and
/// Add/Save in the navigation bar, inset grouped sections. Setting a birth
/// time reveals the newborn investigation plan (48 h or 72 h, with an 8 h
/// or 12 h heads-up). The ward is changed only via Transfer.
class AddPatientScreen extends StatefulWidget {
  final String? initialWardId;
  final Patient? existing;

  const AddPatientScreen({super.key, this.initialWardId, this.existing});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

/// When to send the newborn investigations.
enum _Plan { h48, h72, none }

class _AddPatientScreenState extends State<AddPatientScreen> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final _wardStreams = StreamCache<List<Ward>>();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _hospitalId = TextEditingController();
  final _bed = TextEditingController();
  final _diagnosis = TextEditingController();

  AgeUnit _ageUnit = AgeUnit.years;
  String _gender = 'Male';
  String? _bloodGroup;
  String? _wardId;
  DateTime? _bornAt;
  int? _gaWeeks;
  int? _gaDays;

  // Birth details (newborns)
  final _birthWeight = TextEditingController(); // kg
  final _indication = TextEditingController();
  String? _sizeForDates;
  String? _deliveryMode;
  String? _motherGroup;
  int? _apgar1;
  int? _apgar5;
  bool _resuscitated = false;

  /// Unit (team) within the ward; null = unassigned.
  String? _unitId;
  bool _unitTouched = false;

  _Plan _plan = _Plan.h48;
  int _leadHours = 12;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  /// The plan question appears for a new birth time (new patient, or one
  /// added/changed while editing). Existing plans are managed on the
  /// patient page.
  bool get _askPlan =>
      _bornAt != null &&
      (widget.existing == null || widget.existing!.bornAt != _bornAt);

  @override
  void initState() {
    super.initState();
    _wardId = widget.initialWardId;
    final p = widget.existing;
    if (p != null) {
      _wardId = p.wardId;
      _name.text = p.name;
      _age.text = p.age > 0 ? '${p.age}' : '';
      _ageUnit = p.ageUnit;
      _hospitalId.text = p.hospitalId ?? '';
      _bornAt = p.bornAt;
      _gaWeeks = p.gestationWeeks;
      _gaDays = p.gestationDays;
      _bed.text = p.bedNumber;
      _diagnosis.text = p.diagnosis;
      _gender = p.gender.isEmpty ? 'Male' : p.gender;
      _bloodGroup = _bloodGroups.contains(p.bloodGroup) ? p.bloodGroup : null;
      if (p.birthWeightG != null) {
        _birthWeight.text = (p.birthWeightG! / 1000)
            .toStringAsFixed(3)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
      }
      _indication.text = p.deliveryIndication ?? '';
      _sizeForDates = p.sizeForDates;
      _deliveryMode = p.deliveryMode;
      _motherGroup = p.motherBloodGroup;
      _apgar1 = p.apgar1;
      _apgar5 = p.apgar5;
      _resuscitated = p.resuscitated ?? false;
      _unitId = p.unitId;
      _unitTouched = true;
    }
  }

  /// New patients default to the unit being viewed, else "my unit".
  String? _defaultUnit(String? wardId) {
    if (wardId == null) return null;
    final units = context.read<UnitProvider>();
    final scope = units.scope;
    if (scope.wardId == wardId && scope.unitId != null) return scope.unitId;
    return units.myUnitFor(wardId);
  }

  int? get _birthWeightG {
    final kg = double.tryParse(_birthWeight.text.trim().replaceAll(',', '.'));
    return kg == null ? null : (kg * 1000).round();
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _hospitalId, _bed, _diagnosis, _birthWeight, _indication]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _name.text.trim().isNotEmpty && (_editing || _wardId != null);

  Patient _build({required String id, required String wardId}) {
    final old = widget.existing;
    final newborn = _bornAt != null;
    final draft = _draft(id: id, wardId: wardId, diagnosis: _diagnosis.text.trim());
    // The composed birth line fills an empty diagnosis, and replaces it
    // when the diagnosis was the old composed line (i.e. never hand-edited).
    final line = newborn ? birthSummaryLine(draft) : null;
    final oldLine = old == null ? null : birthSummaryLine(old);
    final typed = _diagnosis.text.trim();
    final diagnosis = line != null && (typed.isEmpty || typed == oldLine) ? line : typed;
    return _draft(id: id, wardId: wardId, diagnosis: diagnosis);
  }

  Patient _draft({required String id, required String wardId, required String diagnosis}) {
    final old = widget.existing;
    final newborn = _bornAt != null;
    final assisted = _deliveryMode != null && _deliveryMode != 'NVD';
    return Patient(
      id: id,
      patientCode: old?.patientCode ?? '',
      name: _name.text.trim(),
      age: int.tryParse(_age.text.trim()) ?? 0,
      ageUnit: _ageUnit,
      hospitalId: _hospitalId.text.trim(),
      gender: _gender,
      wardId: wardId,
      bedNumber: _bed.text.trim(),
      diagnosis: diagnosis,
      bloodGroup: _bloodGroup,
      admittedAt: old?.admittedAt ?? DateTime.now(),
      status: old?.status ?? PatientStatus.admitted,
      dischargedAt: old?.dischargedAt,
      dischargedBy: old?.dischargedBy,
      dischargeSummary: old?.dischargeSummary,
      bornAt: _bornAt,
      gestationWeeks: _gaWeeks,
      gestationDays: _gaWeeks == null ? null : _gaDays,
      birthWeightG: newborn ? _birthWeightG : null,
      sizeForDates: newborn ? _sizeForDates : null,
      deliveryMode: newborn ? _deliveryMode : null,
      deliveryIndication: newborn && assisted ? _indication.text.trim() : null,
      motherBloodGroup: newborn ? _motherGroup : null,
      apgar1: newborn ? _apgar1 : null,
      apgar5: newborn ? _apgar5 : null,
      resuscitated: newborn ? _resuscitated : null,
      unitId: _unitId,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final wardId = _wardId ?? '';
    if (!_editing && wardId.isEmpty) return;
    setState(() => _saving = true);
    final provider = context.read<PatientProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final askPlan = _askPlan;

    String? patientId;
    if (_editing) {
      final ok = await provider.updatePatient(
          _build(id: widget.existing!.id, wardId: widget.existing!.wardId));
      if (ok) patientId = widget.existing!.id;
      if (ok && _unitId != widget.existing!.unitId) {
        try {
          await PatientService().moveToUnit(widget.existing!.id, _unitId);
        } catch (e) {
          messenger.showSnackBar(SnackBar(
            backgroundColor: AppColors.danger,
            content: Text("Saved, but couldn't change the unit — ${friendlyError(e)}"),
          ));
        }
      }
    } else {
      patientId =
          await provider.addPatient(_build(id: const Uuid().v4(), wardId: wardId));
    }
    if (patientId == null) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
            "Couldn't save — ${friendlyError(provider.error ?? 'unknown error')}"),
      ));
      return;
    }

    var planNote = '';
    if (askPlan && _plan != _Plan.none) {
      try {
        await NewbornScreenService().plan(patientId,
            hours: _plan == _Plan.h48 ? 48 : 72, leadHours: _leadHours);
        await ReminderNotifications.instance.requestPermission();
        planNote = ' · investigations planned';
      } catch (e) {
        planNote = " · couldn't plan investigations (${friendlyError(e)})";
      }
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text('${_editing ? 'Changes saved' : 'Patient added'}$planNote'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
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
        title: Text(_editing ? 'Edit Patient' : 'New Patient',
            style: AppTypography.headline(color: AppColors.textPrimary)),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: CupertinoActivityIndicator(),
                )
              : CupertinoButton(
                  padding: const EdgeInsets.only(right: 16),
                  onPressed: _canSave ? _save : null,
                  child: Text(_editing ? 'Save' : 'Add',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (!_editing) ...[_wardGroup(), const SizedBox(height: 24)],
            _patientGroup(),
            const SizedBox(height: 24),
            _ageGroup(),
            const SizedBox(height: 24),
            _newbornGroup(),
            if (_bornAt != null) ...[const SizedBox(height: 24), _birthDetailsGroup()],
            if (_askPlan) ...[const SizedBox(height: 24), _planGroup()],
            const SizedBox(height: 24),
            _admissionGroup(),
          ],
        ),
      ),
    );
  }

  Widget _wardGroup() {
    final ids =
        context.watch<AuthProvider>().currentUser?.wardIds ?? const <String>[];
    return StreamBuilder<List<Ward>>(
      stream: ids.isEmpty
          ? Stream.value(const <Ward>[])
          : _wardStreams.get(
              ids.join(','), () => WardService().wardsForUser(ids)),
      builder: (context, snap) {
        final wards = snap.data ?? const <Ward>[];
        if (_wardId == null && wards.length == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _wardId = wards.first.id);
          });
        }
        if (!_unitTouched && _wardId != null) {
          final d = _defaultUnit(_wardId);
          if (d != _unitId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_unitTouched) setState(() => _unitId = d);
            });
          }
        }
        final current = wards.where((w) => w.id == _wardId).firstOrNull;
        return InsetGroup(
          footer: wards.isEmpty && snap.hasData
              ? 'Create or join a ward in the Wards tab first.'
              : null,
          children: [
            SettingsRow(
              title: 'Ward',
              value: current?.name ?? (snap.hasData ? 'Choose' : 'Loading…'),
              onTap: wards.isEmpty
                  ? null
                  : () async {
                      final id = await showOptionSheet<String>(
                        context,
                        title: 'Admit to ward',
                        selected: _wardId,
                        options: {for (final w in wards) w.id: w.name},
                      );
                      if (id != null && id != _wardId) {
                        setState(() {
                          _wardId = id;
                          _unitId = _defaultUnit(id);
                        });
                      }
                    },
            ),
            ..._unitRow(),
          ],
        );
      },
    );
  }

  /// Unit picker for the chosen ward (hidden when the ward has none).
  List<Widget> _unitRow() {
    final wardId = _wardId;
    if (wardId == null) return const [];
    final units = context.watch<UnitProvider>();
    final list = units.unitsOf(wardId);
    if (list.isEmpty) return const [];
    return [
      SettingsRow(
        title: 'Unit',
        value: units.unitById(_unitId)?.name ?? 'Unassigned',
        onTap: () async {
          final id = await showOptionSheet<String>(
            context,
            title: 'Unit (team)',
            selected: _unitId ?? '',
            options: {for (final u in list) u.id: u.name, '': 'Unassigned'},
          );
          if (id != null) {
            setState(() {
              _unitTouched = true;
              _unitId = id.isEmpty ? null : id;
            });
          }
        },
      ),
    ];
  }

  Widget _patientGroup() {
    return InsetGroup(
      header: 'Patient',
      dividerIndent: 16,
      children: [
        if (_editing) ..._unitRow(),
        InsetTextRow(
          label: 'Name',
          controller: _name,
          placeholder: 'Required',
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        InsetSegmentedRow<String>(
          label: 'Sex',
          value: _gender,
          options: const {'Male': 'Male', 'Female': 'Female', 'Other': 'Other'},
          onChanged: (g) => setState(() => _gender = g),
        ),
        InsetTextRow(
          label: 'Hospital ID',
          controller: _hospitalId,
          placeholder: 'MRN / IP no.',
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  Widget _ageGroup() {
    final fromBirth = _bornAt != null;
    return InsetGroup(
      header: 'Age',
      dividerIndent: 16,
      footer: fromBirth ? 'Worked out from the birth time.' : null,
      children: [
        if (fromBirth)
          SettingsRow(
            title: 'Age',
            value: ageSinceBirthLabel(_bornAt!, DateTime.now()),
          )
        else ...[
          InsetSegmentedRow<AgeUnit>(
            label: 'Unit',
            value: _ageUnit,
            options: {for (final u in AgeUnit.values) u: u.label},
            onChanged: (u) => setState(() => _ageUnit = u),
          ),
          InsetTextRow(
            label: 'Age',
            controller: _age,
            placeholder: 'Optional',
            suffix: _ageUnit.label.toLowerCase(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (n == null) return null;
              final max = switch (_ageUnit) {
                AgeUnit.days => 365,
                AgeUnit.months => 60,
                AgeUnit.years => 130,
              };
              return n > max
                  ? 'At most $max ${_ageUnit.label.toLowerCase()}'
                  : null;
            },
          ),
        ],
      ],
    );
  }

  Widget _newbornGroup() {
    return InsetGroup(
      header: 'Newborn',
      dividerIndent: 16,
      footer: _bornAt == null
          ? 'For PNC and NICU babies: the birth time gives hours of life and '
              'plans the 48 h / 72 h investigations.'
          : null,
      children: [
        SettingsRow(
          title: 'Birth date & time',
          value: _bornAt == null ? 'Not set' : formatDueTime(_bornAt!),
          onTap: () async {
            final picked = await pickBirthDateTime(context, _bornAt);
            if (picked != null) setState(() => _bornAt = picked);
          },
        ),
        if (_bornAt != null) ...[
          SettingsRow(
            title: 'Gestational age',
            value: _gaWeeks == null
                ? 'Not set'
                : '$_gaWeeks+${_gaDays ?? 0} weeks',
            onTap: () async {
              final ga = await pickGestation(context, _gaWeeks, _gaDays);
              if (ga != null) {
                setState(() {
                  _gaWeeks = ga.$1;
                  _gaDays = ga.$2;
                });
              }
            },
          ),
          if (Maturity.fromGestation(_gaWeeks) != null)
            SettingsRow(
              title: 'Maturity',
              value: Maturity.fromGestation(_gaWeeks)!.label,
            ),
          SettingsRow(
            title: 'Clear birth time',
            destructive: true,
            onTap: () => setState(() {
              _bornAt = null;
              _gaWeeks = null;
              _gaDays = null;
            }),
          ),
        ],
      ],
    );
  }

  Widget _birthDetailsGroup() {
    final assisted = _deliveryMode != null && _deliveryMode != 'NVD';
    final preview = birthSummaryLine(
        _draft(id: '', wardId: '', diagnosis: ''));
    Future<int?> pickApgar(String title, int? current) => showOptionSheet<int>(
          context,
          title: title,
          selected: current,
          options: {for (var i = 10; i >= 0; i--) i: '$i'},
        );
    return InsetGroup(
      header: 'Birth details',
      dividerIndent: 16,
      footer: preview == null
          ? null
          : '$preview\nUsed as the diagnosis unless you write your own.',
      children: [
        InsetTextRow(
          label: 'Birth weight',
          controller: _birthWeight,
          placeholder: 'e.g. 3.1',
          suffix: 'kg',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,1}([.,]\d{0,3})?')),
          ],
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final g = _birthWeightG;
            if ((v ?? '').trim().isEmpty || g == null) return null;
            return g < 300 || g > 7000 ? 'Between 0.3 and 7 kg' : null;
          },
        ),
        InsetSegmentedRow<String>(
          label: 'Size for dates',
          value: _sizeForDates,
          options: {for (final s in kSizesForDates) s: s},
          onChanged: (v) => setState(() => _sizeForDates = v),
        ),
        SettingsRow(
          title: 'Delivery',
          value: _deliveryMode ?? 'Not set',
          onTap: () async {
            final m = await showOptionSheet<String>(
              context,
              title: 'Mode of delivery',
              selected: _deliveryMode,
              options: {
                'NVD': 'NVD (normal vaginal)',
                'LSCS': 'LSCS (caesarean)',
                'Vacuum': 'Vacuum-assisted',
                'Forceps': 'Forceps-assisted',
                '': 'Not known',
              },
            );
            if (m != null) setState(() => _deliveryMode = m.isEmpty ? null : m);
          },
        ),
        if (assisted)
          InsetTextRow(
            label: 'Indication',
            controller: _indication,
            placeholder: 'e.g. CPD',
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        SettingsRow(
          title: 'APGAR 1 min',
          value: _apgar1?.toString() ?? 'Not set',
          onTap: () async {
            final v = await pickApgar('APGAR at 1 minute', _apgar1);
            if (v != null) setState(() => _apgar1 = v);
          },
        ),
        SettingsRow(
          title: 'APGAR 5 min',
          value: _apgar5?.toString() ?? 'Not set',
          onTap: () async {
            final v = await pickApgar('APGAR at 5 minutes', _apgar5);
            if (v != null) setState(() => _apgar5 = v);
          },
        ),
        SettingsRow(
          title: 'Resuscitation needed',
          trailing: Switch.adaptive(
            value: _resuscitated,
            onChanged: (v) => setState(() => _resuscitated = v),
          ),
          showChevron: false,
        ),
        SettingsRow(
          title: "Mother's blood group",
          subtitle: 'Flags ABO / Rh risk for jaundice',
          value: _motherGroup ?? 'Not set',
          onTap: () async {
            final g = await showOptionSheet<String>(
              context,
              title: "Mother's blood group",
              selected: _motherGroup,
              options: {for (final g in _bloodGroups) g: g, '': 'Not known'},
            );
            if (g != null) setState(() => _motherGroup = g.isEmpty ? null : g);
          },
        ),
      ],
    );
  }

  Widget _planGroup() {
    final born = _bornAt!;
    final hours = _plan == _Plan.h72 ? 72 : 48;
    final due = born.add(Duration(hours: hours));
    final heads = due.subtract(Duration(hours: _leadHours));
    final footer = _plan == _Plan.none
        ? 'You can plan them later from the patient page.'
        : 'Heads-up ${formatDueTime(heads)}. At ${formatDueTime(due)} FolioMed '
            'asks if they were sent, then for the results.\n'
            '${kNewbornInvestigations.join(' · ')}';
    return InsetGroup(
      header: 'Newborn investigations',
      dividerIndent: 16,
      footer: footer,
      children: [
        InsetSegmentedRow<_Plan>(
          label: 'When will you send them?',
          value: _plan,
          options: const {
            _Plan.h48: '48 h',
            _Plan.h72: '72 h',
            _Plan.none: 'Not now',
          },
          onChanged: (p) => setState(() => _plan = p),
        ),
        if (_plan != _Plan.none)
          InsetSegmentedRow<int>(
            label: 'Remind me before',
            value: _leadHours,
            options: const {8: '8 h before', 12: '12 h before'},
            onChanged: (h) => setState(() => _leadHours = h),
          ),
      ],
    );
  }

  Widget _admissionGroup() {
    return InsetGroup(
      header: 'Admission',
      dividerIndent: 16,
      children: [
        InsetTextRow(label: 'Bed', controller: _bed, placeholder: 'Optional'),
        InsetTextRow(
          label: 'Diagnosis',
          controller: _diagnosis,
          placeholder: _bornAt != null ? 'From birth details if left blank' : 'Optional',
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        SettingsRow(
          title: 'Blood group',
          value: _bloodGroup ?? 'Not set',
          onTap: () async {
            final g = await showOptionSheet<String>(
              context,
              title: 'Blood group',
              selected: _bloodGroup,
              options: {for (final g in _bloodGroups) g: g, '': 'Not known'},
            );
            if (g != null) setState(() => _bloodGroup = g.isEmpty ? null : g);
          },
        ),
      ],
    );
  }
}
