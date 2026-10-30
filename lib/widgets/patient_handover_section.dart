import 'package:flutter/material.dart';

import '../models/handover_session.dart';
import '../models/patient.dart';
import '../services/handover_service.dart';
import '../services/patient_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'inset_group.dart';

/// Patient page: what the next shift needs — the I-PASS summary (kept up
/// to date, not rewritten each shift) and "If … then …" lines. Severity
/// (Status) and the action list (Jobs, Reminders) have their own sections.
class PatientHandoverSection extends StatefulWidget {
  const PatientHandoverSection({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientHandoverSection> createState() => _PatientHandoverSectionState();
}

class _PatientHandoverSectionState extends State<PatientHandoverSection> {
  final _service = HandoverService();
  late final Stream<List<Contingency>> _ifThen = _service.contingencies(widget.patient.id);

  Patient get p => widget.patient;

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

  @override
  Widget build(BuildContext context) {
    final summary = p.handoverSummary?.trim() ?? '';
    return StreamBuilder<List<Contingency>>(
      stream: _ifThen,
      builder: (context, snap) {
        final lines = snap.data ?? const <Contingency>[];
        return InsetGroup(
          header: 'Handover',
          footer: 'The summary and If/Then lines appear in the shift handover. Keep them current — '
              'the next shift reads them, not the whole timeline.',
          children: [
            SettingsRow(
              icon: Icons.short_text,
              title: summary.isEmpty ? 'Add a handover summary' : summary,
              subtitle: summary.isEmpty
                  ? 'One to three lines: what’s going on and the plan'
                  : [
                      'Summary',
                      if ((p.handoverSummaryByName ?? '').isNotEmpty) p.handoverSummaryByName!,
                      if (p.handoverSummaryAt != null) formatDueTime(p.handoverSummaryAt!),
                    ].join(' · '),
              onTap: p.isActive ? _editSummary : null,
            ),
            for (final c in lines)
              SettingsRow(
                icon: Icons.call_split,
                iconColor: AppColors.warning,
                title: c.line,
                subtitle: (c.createdByName ?? '').isEmpty ? null : c.createdByName,
                onTap: p.isActive ? () => _removeIfThen(c) : null,
                showChevron: false,
              ),
            if (p.isActive)
              SettingsRow(icon: Icons.add, title: 'Add If / Then', onTap: _addIfThen),
          ],
        );
      },
    );
  }

  Future<void> _editSummary() async {
    final c = TextEditingController(text: p.handoverSummary ?? '');
    final text = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Handover summary'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Day 2 bronchiolitis, on HFNC 1 L/kg, feeding NG. Plan: wean as tolerated.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (text == null) return;
    await _run(() => PatientService().setHandoverSummary(p.id, text));
  }

  Future<void> _addIfThen() async {
    final ifC = TextEditingController(), thenC = TextEditingController();
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('If / Then'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ifC,
            autofocus: true,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'If', hintText: 'e.g. SpO₂ below 92% on 2 L/kg'),
          ),
          TextField(
            controller: thenC,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Then', hintText: 'e.g. Increase flow, call the registrar'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || ifC.text.trim().isEmpty || thenC.text.trim().isEmpty) return;
    await _run(() => _service.addContingency(
        patientId: p.id, wardId: p.wardId, ifText: ifC.text, thenText: thenC.text));
  }

  Future<void> _removeIfThen(Contingency c) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Remove this line?'),
        content: Text(c.line),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.deleteContingency(c.id));
  }
}
