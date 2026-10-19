import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/ward.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/unit_provider.dart';
import '../services/patient_service.dart';
import '../utils/haptics.dart';
import 'inset_group.dart';
import '../services/ward_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/friendly_error.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'large_title_app_bar.dart';
import '../screens/doctor/add_patient_screen.dart';

/// "•••" in the patient's navigation bar: transfer, discharge or readmit.
class PatientActionsButton extends StatelessWidget {
  const PatientActionsButton({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return ChromeIconButton(
      icon: Icons.more_horiz,
      tooltip: 'Patient actions',
      onPressed: () => _showActions(context),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showAppSheet<_Action>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryLabel,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(patient.name,
                    style: AppTypography.headline(color: AppColors.textPrimary)),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit details'),
                subtitle: const Text('Name, age, birth time, bed, diagnosis, IDs'),
                onTap: () => Navigator.pop(sheetContext, _Action.edit),
              ),
              if (patient.isActive &&
                  context.read<UnitProvider>().unitsOf(patient.wardId).isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Move to another unit'),
                  subtitle: Text('Now: ${context.read<UnitProvider>().unitById(patient.unitId)?.name ?? 'Unassigned'}'),
                  onTap: () => Navigator.pop(sheetContext, _Action.unit),
                ),
              if (patient.isActive) ...[
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Transfer to another ward'),
                  subtitle: const Text('Notes and replies move with the patient'),
                  onTap: () => Navigator.pop(sheetContext, _Action.transfer),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Discharge'),
                  subtitle: const Text('Moves them to the Discharged list'),
                  onTap: () => Navigator.pop(sheetContext, _Action.discharge),
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Readmit'),
                  subtitle: const Text('Back on the ward list, same patient ID'),
                  onTap: () => Navigator.pop(sheetContext, _Action.readmit),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text('Delete permanently',
                    style: AppTypography.body(color: AppColors.danger)),
                subtitle: const Text('Erases the patient and all their notes'),
                onTap: () => Navigator.pop(sheetContext, _Action.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _Action.transfer:
        await _transfer(context);
      case _Action.discharge:
        await _discharge(context);
      case _Action.readmit:
        await _readmit(context);
      case _Action.edit:
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddPatientScreen(existing: patient),
        ));
      case _Action.delete:
        await _delete(context);
      case _Action.unit:
        await _moveUnit(context);
    }
  }

  Future<void> _moveUnit(BuildContext context) async {
    final units = context.read<UnitProvider>();
    final list = units.unitsOf(patient.wardId);
    final id = await showOptionSheet<String>(
      context,
      title: 'Move ${patient.name} to',
      selected: patient.unitId ?? '',
      options: {for (final u in list) u.id: u.name, '': 'Unassigned'},
    );
    if (id == null || !context.mounted) return;
    final target = id.isEmpty ? null : id;
    if (target == patient.unitId) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PatientService().moveToUnit(patient.id, target);
      Haptics.commit();
      messenger.showSnackBar(SnackBar(
          content: Text('Moved to ${units.unitById(target)?.name ?? 'Unassigned'}')));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text('Delete ${patient.name}?'),
        content: const Text(
          'This permanently deletes the patient, every note and reply about '
          'them, and their reminders. It cannot be recovered. To keep the '
          'record, discharge them instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<PatientProvider>();
    final navigator = Navigator.of(context);
    final ok = await provider.deletePatient(patient.id);
    if (!context.mounted) return;
    _report(context, ok, '${patient.name} deleted', provider);
    if (ok && navigator.canPop()) navigator.pop();
  }

  Future<void> _discharge(BuildContext context) async {
    final summary = TextEditingController();
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text('Discharge ${patient.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('They move to the Discharged list. You can readmit '
                'them later with the same patient ID.'),
            const SizedBox(height: 12),
            TextField(
              controller: summary,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Discharge summary (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discharge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<PatientProvider>();
    final ok = await provider.dischargePatient(patient.id, summary: summary.text);
    if (context.mounted) _report(context, ok, '${patient.name} discharged', provider);
  }

  Future<void> _readmit(BuildContext context) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text('Readmit ${patient.name}?'),
        content: Text('They return to the ward list as ${patient.patientCode}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Readmit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<PatientProvider>();
    final ok = await provider.readmitPatient(patient.id);
    if (context.mounted) _report(context, ok, '${patient.name} readmitted', provider);
  }

  Future<void> _transfer(BuildContext context) async {
    final myWards = context.read<AuthProvider>().currentUser?.wardIds ?? const [];
    final targets = myWards.where((id) => id != patient.wardId).toList();
    final result = await showAppSheet<_TransferRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransferSheet(patient: patient, wardIds: targets),
    );
    if (result == null || !context.mounted) return;
    final provider = context.read<PatientProvider>();
    final ok = await provider.transferPatient(
      patient.id,
      targetWardId: result.ward.id,
      reason: result.reason,
      bedNumber: result.bed,
    );
    if (context.mounted) {
      _report(context, ok, '${patient.name} moved to ${result.ward.name}', provider);
    }
  }

  void _report(BuildContext context, bool ok, String done, PatientProvider provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? null : AppColors.danger,
      content: Text(ok
          ? done
          : friendlyError(provider.lastException ?? 'Something went wrong')),
    ));
  }
}

enum _Action { edit, unit, transfer, discharge, readmit, delete }

class _TransferRequest {
  const _TransferRequest(this.ward, this.reason, this.bed);
  final Ward ward;
  final String reason;
  final String? bed;
}

/// Pick a destination ward (only wards you belong to — the database
/// requires membership of both), optional new bed and reason.
class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.patient, required this.wardIds});

  final Patient patient;
  final List<String> wardIds;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  late final Stream<List<Ward>> _wards = WardService().wardsForUser(widget.wardIds);
  final _reason = TextEditingController();
  final _bed = TextEditingController();
  Ward? _selected;

  @override
  void dispose() {
    _reason.dispose();
    _bed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryLabel,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Transfer ${widget.patient.name}',
                  style: AppTypography.title2(color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                'Their notes and replies move too. Staff in the current ward '
                'lose access unless they are also in the new one.',
                style: AppTypography.subheadline(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              const GroupedSectionHeader('Destination ward'),
              if (widget.wardIds.isEmpty)
                Text(
                  "You're only in this ward. Join the destination ward first "
                  '(Wards → Join Ward), then transfer.',
                  style: AppTypography.subheadline(color: AppColors.textPrimary),
                )
              else
                StreamBuilder<List<Ward>>(
                  stream: _wards,
                  builder: (context, snap) {
                    final wards = snap.data;
                    if (wards == null) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator.adaptive()),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Column(
                        children: [
                          for (final w in wards)
                            ListTile(
                              title: Text(w.name),
                              subtitle: Text(w.floor.isEmpty ? w.id : '${w.floor} · ${w.id}'),
                              trailing: _selected?.id == w.id
                                  ? Icon(Icons.check,
                                      color: AppColors.isDark
                                          ? AppColors.darkPrimary
                                          : AppColors.primary)
                                  : null,
                              selected: _selected?.id == w.id,
                              onTap: () => setState(() => _selected = w),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _bed,
                decoration: InputDecoration(
                  labelText: 'New bed (optional)',
                  hintText: 'Currently ${widget.patient.bedNumber.isEmpty ? 'not set' : widget.patient.bedNumber}',
                  prefixIcon: const Icon(Icons.bed_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Stepped down from ICU',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          _TransferRequest(_selected!, _reason.text, _bed.text),
                        ),
                child: Text(_selected == null
                    ? 'Choose a ward'
                    : 'Transfer to ${_selected!.name}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
