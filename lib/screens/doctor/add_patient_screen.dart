import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../services/ward_service.dart';
import '../../utils/stream_cache.dart';
import '../../utils/app_theme.dart';
import '../../utils/friendly_error.dart';
import '../../providers/theme_provider.dart';
import '../../models/patient_reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../services/reminder_notifications.dart';
import '../../widgets/birth_time_field.dart';
import '../../utils/app_utils.dart';

/// Admits a new patient, or edits [existing] when given. Ward changes go
/// through Transfer (patient ••• menu), so the ward is fixed when editing.
class AddPatientScreen extends StatefulWidget {
  final String? initialWardId;
  final Patient? existing;

  const AddPatientScreen({super.key, this.initialWardId, this.existing});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _wardStreams = StreamCache<List<Ward>>();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _hospitalIdController = TextEditingController();
  AgeUnit _ageUnit = AgeUnit.years;

  /// Newborns: exact date and time of birth, plus investigation reminders.
  DateTime? _bornAt;
  final Set<int> _reminderHours = {
    for (final p in NewbornReminderPreset.all) p.hours,
  };
  final _bedController = TextEditingController();
  final _diagnosisController = TextEditingController();

  String _gender = 'Male';
  String? _bloodGroup;
  String? _wardId;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _wardId = widget.initialWardId;
    final p = widget.existing;
    if (p != null) {
      _wardId = p.wardId;
      _nameController.text = p.name;
      _ageController.text = p.age > 0 ? '${p.age}' : '';
      _ageUnit = p.ageUnit;
      _hospitalIdController.text = p.hospitalId ?? '';
      _bornAt = p.bornAt;
      _bedController.text = p.bedNumber;
      _diagnosisController.text = p.diagnosis;
      _gender = p.gender.isEmpty ? 'Male' : p.gender;
      _bloodGroup = _bloodGroups.contains(p.bloodGroup) ? p.bloodGroup : null;
    }
  }

  /// Reminder presets are offered when the birth time is new or changed.
  bool get _offerReminders =>
      _bornAt != null &&
      (widget.existing == null || widget.existing!.bornAt != _bornAt);

  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _hospitalIdController.dispose();
    _bedController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final patientProvider = context.read<PatientProvider>();
    final wardId = _wardId ?? context.read<AuthProvider>().currentUser?.wardId ?? '';
    if (wardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a ward first')),
      );
      return;
    }

    setState(() => _saving = true);
    if (_editing) {
      await _saveEdits();
      return;
    }
    final patient = Patient(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      ageUnit: _ageUnit,
      hospitalId: _hospitalIdController.text.trim(),
      gender: _gender,
      wardId: wardId,
      bedNumber: _bedController.text.trim(),
      diagnosis: _diagnosisController.text.trim(),
      bloodGroup: _bloodGroup,
      admittedAt: DateTime.now(),
      bornAt: _bornAt,
    );

    final reminders = context.read<ReminderProvider>();
    final newId = await patientProvider.addPatient(patient);
    var remindersOk = true;
    if (newId != null && _bornAt != null) {
      for (final preset in NewbornReminderPreset.all) {
        if (!_reminderHours.contains(preset.hours)) continue;
        remindersOk &= await reminders.add(
          patientId: newId,
          wardId: wardId,
          patientName: patient.name,
          title: preset.title,
          dueAt: _bornAt!.add(Duration(hours: preset.hours)),
        );
      }
      if (_reminderHours.isNotEmpty) {
        await ReminderNotifications.instance.requestPermission();
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (newId != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(remindersOk
              ? 'Patient added successfully'
              : "Patient added, but the reminders couldn't be saved — "
                  'add them from the patient page.'),
        ),
      );
    } else {
      final err = patientProvider.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            err == null
                ? "Couldn't add patient — please try again."
                : 'Could not add patient — ${friendlyError(err)}',
          ),
        ),
      );
    }
  }

  Future<void> _saveEdits() async {
    final old = widget.existing!;
    final updated = Patient(
      id: old.id,
      patientCode: old.patientCode,
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      ageUnit: _ageUnit,
      hospitalId: _hospitalIdController.text.trim(),
      gender: _gender,
      wardId: old.wardId,
      bedNumber: _bedController.text.trim(),
      diagnosis: _diagnosisController.text.trim(),
      bloodGroup: _bloodGroup,
      admittedAt: old.admittedAt,
      status: old.status,
      dischargedAt: old.dischargedAt,
      dischargedBy: old.dischargedBy,
      dischargeSummary: old.dischargeSummary,
      bornAt: _bornAt,
    );
    final provider = context.read<PatientProvider>();
    final reminders = context.read<ReminderProvider>();
    final offer = _offerReminders;
    final ok = await provider.updatePatient(updated);
    var remindersOk = true;
    if (ok && offer) {
      for (final preset in NewbornReminderPreset.all) {
        if (!_reminderHours.contains(preset.hours)) continue;
        remindersOk &= await reminders.add(
          patientId: old.id,
          wardId: old.wardId,
          patientName: updated.name,
          title: preset.title,
          dueAt: _bornAt!.add(Duration(hours: preset.hours)),
        );
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(remindersOk
            ? 'Changes saved'
            : "Changes saved, but the reminders couldn't be added."),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
            'Could not save — ${friendlyError(provider.error ?? 'unknown error')}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_editing ? 'Edit Patient' : 'Add Patient'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_editing)
                _label('Ward is changed with Transfer, from the patient’s ••• menu.')
              else ...[
                _label('Ward (required)'),
                const SizedBox(height: 8),
                _wardPicker(),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name (required)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hospitalIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Hospital ID / MRN (optional)',
                  helperText:
                      'FolioMed also assigns its own unique patient ID automatically.',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              // Age in days / months / years — neonates and infants need
              // finer units than years. Ignored once a birth time is set.
              _label('Age'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<AgeUnit>(
                  groupValue: _ageUnit,
                  onValueChanged: (u) {
                    if (u != null && _bornAt == null) setState(() => _ageUnit = u);
                  },
                  children: {
                    for (final u in AgeUnit.values)
                      u: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(u.label,
                            style: AppTypography.footnote(
                                color: AppColors.textPrimary,
                                weight: FontWeight.w600)),
                      ),
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: _bornAt == null,
                decoration: InputDecoration(
                  labelText: 'Age in ${_ageUnit.label.toLowerCase()} (optional)',
                  helperText: _bornAt == null
                      ? null
                      : 'Worked out from the birth time below.',
                  prefixIcon: const Icon(Icons.cake_outlined),
                ),
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
              const SizedBox(height: 12),
              BirthTimeField(
                bornAt: _bornAt,
                onChanged: (v) => setState(() => _bornAt = v),
              ),
              if (_offerReminders) ...[
                const SizedBox(height: 8),
                for (final preset in NewbornReminderPreset.all)
                  CheckboxListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _reminderHours.contains(preset.hours),
                    onChanged: (v) => setState(() => v == true
                        ? _reminderHours.add(preset.hours)
                        : _reminderHours.remove(preset.hours)),
                    title: Text('Remind at ${preset.hours} h of life'),
                    subtitle: Text(
                      '${preset.title} · ${formatDueTime(_bornAt!.add(Duration(hours: preset.hours)))}',
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              _label('Gender'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final g in ['Male', 'Female', 'Other'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _toggleChip(g, _gender == g, () {
                        setState(() => _gender = g);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bedController,
                decoration: const InputDecoration(
                  labelText: 'Bed number (optional)',
                  prefixIcon: Icon(Icons.bed_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _diagnosisController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: const InputDecoration(
                  labelText: 'Blood group (optional)',
                  prefixIcon: Icon(Icons.bloodtype_outlined),
                ),
                items: _bloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodGroup = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator.adaptive(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(_editing ? 'Save Changes' : 'Add Patient'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: appText(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _wardPicker() {
    final me = context.watch<AuthProvider>().currentUser;
    final myWardIds = me?.wardIds ?? const <String>[];
    if (myWardIds.isEmpty) {
      return Text(
        'Join a ward first from the Wards tab.',
        style: appText(color: AppColors.textSecondary),
      );
    }
    final ids = myWardIds;
    return StreamBuilder<List<Ward>>(
      stream: _wardStreams.get(
          ids.join(','), () => WardService().wardsForUser(ids)),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            "Couldn't load wards. Pull down and try again.",
            style: appText(color: AppColors.danger),
          );
        }
        if (!snap.hasData) {
          return Text(
            'Loading wards...',
            style: appText(color: AppColors.textSecondary),
          );
        }
        final wards = snap.data!;
        if (wards.isEmpty) {
          return Text(
            'No wards yet. Create or join one from the Wards tab.',
            style: appText(color: AppColors.textSecondary),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final w in wards)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _toggleChip(
                    w.name,
                    _wardId == w.id,
                    () => setState(() => _wardId = w.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: appText(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
