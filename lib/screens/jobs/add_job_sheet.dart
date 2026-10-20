import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/patient.dart';
import '../../models/ward_job.dart';
import '../../providers/account_provider.dart';
import '../../providers/job_board.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/patient_picker.dart';

/// Add a job (for [patient], or pick one), or edit [editing].
Future<void> showAddJob(BuildContext context, {Patient? patient, WardJob? editing}) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddJobSheet(patient: patient, editing: editing),
    );

/// Who a job is for: a ward member, or nobody in particular ([uid] null).
class JobAssignee {
  const JobAssignee(this.uid, this.name);
  final String? uid;
  final String name;
}

/// Choose who takes a job on [wardId]. Null when cancelled.
Future<JobAssignee?> pickJobAssignee(BuildContext context, {required String wardId, String? current}) async {
  final board = context.read<JobBoard>();
  final me = context.read<AccountProvider>().currentUser;
  final messenger = ScaffoldMessenger.of(context);
  List<AppUser> people;
  try {
    people = await board.service.membersOf(wardId);
  } catch (e) {
    messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    return null;
  }
  if (!context.mounted) return null;
  const anyone = '__anyone__';
  final options = <String, String>{
    anyone: 'Anyone on the ward',
    if (me != null) me.uid: 'Me',
    for (final p in people)
      if (p.uid != me?.uid) p.uid: '${p.name.isEmpty ? p.email : p.name} · ${p.roleLabel}',
  };
  final picked = await showOptionSheet<String>(
    context,
    title: 'Who should do it?',
    options: options,
    selected: current ?? anyone,
  );
  if (picked == null) return null;
  if (picked == anyone) return const JobAssignee(null, 'Anyone');
  if (picked == me?.uid) return JobAssignee(picked, 'you');
  final person = people.firstWhere((p) => p.uid == picked);
  return JobAssignee(picked, person.name);
}

class _AddJobSheet extends StatefulWidget {
  const _AddJobSheet({this.patient, this.editing});
  final Patient? patient;
  final WardJob? editing;

  @override
  State<_AddJobSheet> createState() => _AddJobSheetState();
}

class _AddJobSheetState extends State<_AddJobSheet> {
  late final _title = TextEditingController(text: widget.editing?.title ?? '');
  late Patient? _patient = widget.patient;
  late bool _urgent = widget.editing?.urgent ?? false;
  late DateTime? _dueBy = widget.editing?.dueBy?.toLocal();
  JobAssignee _assignee = const JobAssignee(null, 'Anyone');
  bool _saving = false;

  bool get _isEdit => widget.editing != null;
  bool get _ready => !_saving && _title.text.trim().isNotEmpty && (_isEdit || _patient != null);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _choosePatient() async {
    final p = await showPatientPicker(context);
    if (p != null) {
      setState(() {
        // Assignees belong to a ward; a different patient may mean a different ward.
        if (_patient?.wardId != p.wardId) _assignee = const JobAssignee(null, 'Anyone');
        _patient = p;
      });
    }
  }

  Future<void> _chooseAssignee() async {
    final p = _patient;
    if (p == null) return;
    final a = await pickJobAssignee(context, wardId: p.wardId, current: _assignee.uid);
    if (a != null) setState(() => _assignee = a);
  }

  Future<void> _chooseDue() async {
    final now = DateTime.now();
    DateTime at(int dayOffset, int hour) => DateTime(now.year, now.month, now.day + dayOffset, hour);
    final tonight = at(0, 20);
    final tomorrowMorning = at(1, 8);
    final options = <String, String>{
      'none': 'No particular time',
      '1': 'Within 1 hour',
      '2': 'Within 2 hours',
      '4': 'Within 4 hours',
      if (tonight.isAfter(now.add(const Duration(minutes: 30)))) 'tonight': 'By 8 pm today',
      'morning': 'By 8 am tomorrow',
      'custom': 'Choose a time…',
    };
    final pick = await showOptionSheet<String>(context, title: 'By when?', options: options);
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'none':
        setState(() => _dueBy = null);
      case '1' || '2' || '4':
        setState(() => _dueBy = now.add(Duration(hours: int.parse(pick))));
      case 'tonight':
        setState(() => _dueBy = tonight);
      case 'morning':
        setState(() => _dueBy = tomorrowMorning);
      case 'custom':
        final t = await _pickTime(_dueBy ?? now.add(const Duration(hours: 1)));
        if (t != null) setState(() => _dueBy = t);
    }
  }

  Future<DateTime?> _pickTime(DateTime initial) {
    var chosen = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: AppColors.card,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx, chosen),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: initial,
                  minimumDate: DateTime.now().subtract(const Duration(minutes: 5)),
                  maximumDate: DateTime.now().add(const Duration(days: 14)),
                  minuteInterval: 1,
                  onDateTimeChanged: (d) => chosen = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final board = context.read<JobBoard>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = _title.text.trim();
    final editing = widget.editing;
    final ok = editing != null
        ? await board.edit(editing, title: title, urgent: _urgent, dueBy: _dueBy)
        : await board.add(
            wardId: _patient!.wardId,
            patientId: _patient!.id,
            title: title,
            urgent: _urgent,
            dueBy: _dueBy,
            assignedTo: _assignee.uid,
          );
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      if (editing == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(_assignee.uid == null ? 'Job added for the ward.' : 'Job added for ${_assignee.name}.'),
        ));
      }
    } else {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text(friendlyError(board.lastError ?? 'error'))));
    }
  }

  void _usePreset(String preset) {
    Haptics.selection();
    _title.value = TextEditingValue(text: preset, selection: TextSelection.collapsed(offset: preset.length));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text(_isEdit ? 'Edit Job' : 'New Job',
                        textAlign: TextAlign.center,
                        style: AppTypography.headline(color: AppColors.textPrimary)),
                  ),
                  _saving
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: CupertinoActivityIndicator(),
                        )
                      : CupertinoButton(
                          onPressed: _ready ? _save : null,
                          child: Text(_isEdit ? 'Save' : 'Add',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                ],
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: CupertinoTextField.borderless(
                        controller: _title,
                        autofocus: true,
                        placeholder: 'What needs doing?',
                        maxLength: 200,
                        textCapitalization: TextCapitalization.sentences,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        style: AppTypography.body(color: AppColors.textPrimary),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in kCommonJobs)
                            ActionChip(
                              label: Text(preset),
                              onPressed: () => _usePreset(preset),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    InsetGroup(
                      dividerIndent: 16,
                      children: [
                        if (!_isEdit)
                          SettingsRow(
                            title: 'Patient',
                            value: p == null ? 'Choose' : p.name,
                            subtitle: p == null || p.bedNumber.isEmpty ? null : 'Bed ${p.bedNumber}',
                            onTap: widget.patient == null ? _choosePatient : null,
                            showChevron: widget.patient == null,
                          ),
                        SettingsRow(
                          title: 'By',
                          value: _dueBy == null ? 'Any time' : formatDueTime(_dueBy!),
                          onTap: _chooseDue,
                        ),
                        if (!_isEdit)
                          SettingsRow(
                            title: 'For',
                            value: _assignee.uid == null ? 'Anyone' : _assignee.name,
                            onTap: p == null ? null : _chooseAssignee,
                          ),
                        SettingsRow(
                          title: 'Urgent',
                          trailing: Switch.adaptive(
                            value: _urgent,
                            activeTrackColor: AppColors.danger,
                            onChanged: (v) {
                              Haptics.selection();
                              setState(() => _urgent = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _assignee.uid != null && _assignee.name != 'you'
                            ? '${_assignee.name} gets a notification.'
                            : 'Everyone on the ward sees it on their job list.',
                        style: AppTypography.footnote(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
