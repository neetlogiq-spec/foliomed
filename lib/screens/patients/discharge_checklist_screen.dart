import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../clinical/discharge_checklist.dart';
import '../../models/patient.dart';
import '../../services/discharge_check_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

/// Is this baby ready to go home? Lines worked out from the record, then
/// the lines staff tick. Live for the whole ward.
class DischargeChecklistScreen extends StatefulWidget {
  const DischargeChecklistScreen({super.key, required this.patient});
  final Patient patient;

  @override
  State<DischargeChecklistScreen> createState() => _DischargeChecklistScreenState();
}

class _DischargeChecklistScreenState extends State<DischargeChecklistScreen> {
  final _service = DischargeCheckService();
  late final Stream<List<CheckLine>> _lines = _service.watch(widget.patient);
  final Set<String> _busy = {};

  Future<void> _toggle(CheckLine line) async {
    final item = kManualDischargeItems.firstWhere((m) => m.key == line.key);
    final messenger = ScaffoldMessenger.of(context);
    String? detail;
    if (line.state != CheckState.ok && item.askDetail != null) {
      detail = await _askDetail(item);
      if (detail == null) return; // cancelled
    }
    setState(() => _busy.add(line.key));
    try {
      if (line.state == CheckState.ok) {
        await _service.untick(widget.patient.id, line.key);
        Haptics.selection();
      } else {
        await _service.tick(widget.patient.id, line.key, detail: detail);
        Haptics.success();
      }
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(line.key));
    }
  }

  /// '' when skipped, null when cancelled.
  Future<String?> _askDetail(ManualItem item) {
    final controller = TextEditingController();
    return showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(item.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: item.askDetail, counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Tick')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(title: 'Discharge', eyebrow: widget.patient.name, showBackButton: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<List<CheckLine>>(
                stream: _lines,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return InsetGroup(children: [
                      SettingsRow(title: "Couldn't load the checklist", subtitle: friendlyError(snap.error!)),
                    ]);
                  }
                  final lines = snap.data;
                  if (lines == null) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }
                  final todo = outstanding(lines);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Summary(total: lines.length, todo: todo),
                      const SizedBox(height: 20),
                      InsetGroup(
                        header: 'From the record',
                        footer: 'Filled in from investigations, bilirubin, phototherapy and weights on the patient page.',
                        dividerIndent: 56,
                        children: [for (final l in lines.where((l) => !l.manual)) _AutoRow(line: l)],
                      ),
                      const SizedBox(height: 24),
                      InsetGroup(
                        header: 'Ticked by staff',
                        footer: 'Tap to tick or untick. FolioMed records who ticked each one.',
                        dividerIndent: 56,
                        children: [
                          for (final l in lines.where((l) => l.manual))
                            _ManualRow(line: l, busy: _busy.contains(l.key), onTap: () => _toggle(l)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A reminder list for the team, not a clinical decision. Follow your unit’s discharge policy.',
                        textAlign: TextAlign.center,
                        style: AppTypography.footnote(color: AppColors.textSecondary),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.todo});
  final int total;
  final List<CheckLine> todo;

  @override
  Widget build(BuildContext context) {
    final ready = todo.isEmpty;
    final attention = todo.where((l) => l.state == CheckState.attention).length;
    final color = ready ? AppColors.stable : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        children: [
          Icon(ready ? Icons.verified : Icons.pending_actions, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ready ? 'Ready to go home' : '${todo.length} of $total still to do',
                    style: AppTypography.headline(color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  ready
                      ? 'Everything on the list is done.'
                      : attention == 0
                          ? 'Items in red are not done or not recorded.'
                          : '$attention need a decision; the rest are not done or not recorded.',
                  style: AppTypography.footnote(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

(IconData, Color) checkStyle(CheckState s) => switch (s) {
      CheckState.ok => (Icons.check_circle, AppColors.stable),
      CheckState.attention => (Icons.error, AppColors.warning),
      CheckState.missing => (Icons.cancel, AppColors.danger),
    };

class _AutoRow extends StatelessWidget {
  const _AutoRow({required this.line});
  final CheckLine line;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = checkStyle(line.state);
    return Semantics(
      label: '${line.title}: ${line.detail ?? (line.state == CheckState.ok ? 'done' : 'not done')}',
      excludeSemantics: true,
      child: SettingsRow(
        title: line.title,
        subtitle: line.detail,
        trailing: Icon(icon, color: color),
      ),
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({required this.line, required this.busy, required this.onTap});
  final CheckLine line;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = line.state == CheckState.ok;
    return Semantics(
      checked: done,
      button: true,
      label: line.title,
      excludeSemantics: true,
      child: SettingsRow(
        title: line.title,
        subtitle: line.detail == null || line.detail!.isEmpty ? null : line.detail,
        onTap: busy ? null : onTap,
        trailing: busy
            ? const CupertinoActivityIndicator()
            : Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.stable : AppColors.tertiaryLabel),
      ),
    );
  }
}
