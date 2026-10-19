import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/patient_reminder.dart';
import '../providers/reminder_provider.dart';
import '../services/reminder_notifications.dart';
import '../services/reminder_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/app_utils.dart';
import '../utils/friendly_error.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'newborn_flow.dart';

/// "Has this been done?" — shown when a reminder falls due. Yes marks it
/// done for the whole ward; Not yet asks everyone again in an hour.
Future<void> showReminderDuePrompt(
    BuildContext context, PatientReminder r) async {
  final provider = context.read<ReminderProvider>();
  if (r.isNewbornStep &&
      await NewbornFlow.handleDue(context, r,
          markDone: () => provider.markDone(r),
          snooze: () => provider.snooze(r))) {
    return;
  }
  if (!context.mounted) return;
  final answer = await showAdaptiveDialog<_Answer>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(r.title),
      content: Text(
        '${r.patientName.isEmpty ? 'This patient' : r.patientName} — due '
        '${formatDueTime(r.dueAt)}.\n\nHas this been done?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _Answer.done),
          child: const Text('Yes, done'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _Answer.snooze),
          child: const Text('Not yet — ask in 1 h'),
        ),
      ],
    ),
  );
  switch (answer) {
    case _Answer.done:
      await provider.markDone(r);
    case _Answer.snooze:
      await provider.snooze(r);
    case null:
      break; // dismissed: ask again next launch
  }
}

enum _Answer { done, snooze }

/// Reminders card on the patient page: list, tick off, add.
class PatientRemindersSection extends StatefulWidget {
  const PatientRemindersSection({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientRemindersSection> createState() =>
      _PatientRemindersSectionState();
}

class _PatientRemindersSectionState extends State<PatientRemindersSection> {
  late final Stream<List<PatientReminder>> _stream =
      ReminderService().forPatient(widget.patient.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PatientReminder>>(
      stream: _stream,
      builder: (context, snap) {
        // Newborn plan steps live in the Newborn section.
        final items = (snap.data ?? const <PatientReminder>[])
            .where((r) => !r.isNewbornStep)
            .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Reminders',
                          style: AppTypography.headline(
                              color: AppColors.textPrimary)),
                    ),
                    if (widget.patient.isActive)
                      TextButton.icon(
                        onPressed: () => _add(context),
                        icon: const Icon(Icons.add_alarm_outlined, size: 18),
                        label: const Text('Add'),
                      ),
                  ],
                ),
                if (snap.hasError)
                  Text("Couldn't load reminders.",
                      style: AppTypography.footnote(color: AppColors.danger))
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No reminders.',
                      style: AppTypography.footnote(
                          color: AppColors.textSecondary),
                    ),
                  )
                else
                  for (final r in items) _ReminderTile(reminder: r),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final provider = context.read<ReminderProvider>();
    final p = widget.patient;
    final draft = await showAppSheet<_Draft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddReminderSheet(patient: p),
    );
    if (draft == null) return;
    final ok = await provider.add(
      patientId: p.id,
      wardId: p.wardId,
      patientName: p.name,
      title: draft.title,
      dueAt: draft.dueAt,
    );
    await ReminderNotifications.instance.requestPermission();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? null : AppColors.danger,
      content: Text(ok
          ? 'Reminder set for ${formatDueTime(draft.dueAt)}'
          : friendlyError(provider.lastException ?? 'unknown error')),
    ));
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder});

  final PatientReminder reminder;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final provider = context.read<ReminderProvider>();
    final overdue = r.isOverdueAt(DateTime.now());
    final subtitle = r.isDone
        ? 'Done${r.doneByName == null ? '' : ' by ${r.doneByName}'} · ${formatDueTime(r.doneAt!)}'
        : '${overdue ? 'Overdue · was due' : 'Due'} ${formatDueTime(r.dueAt)}';
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => provider.delete(r),
      child: CheckboxListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: r.isDone,
        onChanged: (v) => v == true ? provider.markDone(r) : provider.reopen(r),
        title: Text(
          r.title,
          style: AppTypography.body(
            color: r.isDone ? AppColors.textSecondary : AppColors.textPrimary,
          ).copyWith(
              decoration: r.isDone ? TextDecoration.lineThrough : null),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.footnote(
              color: overdue ? AppColors.danger : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Draft {
  const _Draft(this.title, this.dueAt);
  final String title;
  final DateTime dueAt;
}

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet({required this.patient});

  final Patient patient;

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _title = TextEditingController();
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _due ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() => _due =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final bornAt = widget.patient.bornAt;
    final canSave = _title.text.trim().isNotEmpty && _due != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New reminder',
                style: AppTypography.title3(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What needs doing?'),
              onChanged: (_) => setState(() {}),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(_due == null ? 'Pick a time' : formatDueTime(_due!)),
              subtitle: bornAt != null && _due != null
                  ? Text('${_due!.difference(bornAt).inHours} h of life')
                  : null,
              onTap: _pickDue,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: canSave
                  ? () => Navigator.pop(context, _Draft(_title.text.trim(), _due!))
                  : null,
              child: const Text('Set reminder'),
            ),
          ],
        ),
      ),
    );
  }
}
