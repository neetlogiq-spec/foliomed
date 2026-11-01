import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../clinical/labs.dart';
import '../models/lab_result.dart';
import '../models/patient.dart';
import '../screens/labs/add_labs_screen.dart';
import '../services/lab_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'inset_group.dart';
import 'large_title_app_bar.dart';
import 'trend_chart.dart';

/// The latest result of each test with its trend; tap for the history.
class PatientLabsSection extends StatefulWidget {
  const PatientLabsSection({super.key, required this.patient});
  final Patient patient;

  @override
  State<PatientLabsSection> createState() => _PatientLabsSectionState();
}

class _PatientLabsSectionState extends State<PatientLabsSection> {
  late final Stream<List<LabResult>> _stream = LabService().watch(widget.patient.id);
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return StreamBuilder<List<LabResult>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <LabResult>[];
        final byTest = <String, List<LabResult>>{};
        for (final r in all) {
          (byTest[r.testKey] ??= []).add(r);
        }
        final order = [for (final t in kLabTests) t.key];
        final keys = byTest.keys.toList()
          ..sort((a, b) {
            final fa = byTest[a]!.last.flag, fb = byTest[b]!.last.flag;
            final ra = fa == null ? 2 : (fa.critical ? 0 : 1), rb = fb == null ? 2 : (fb.critical ? 0 : 1);
            if (ra != rb) return ra - rb;
            return (order.indexOf(a) < 0 ? 999 : order.indexOf(a)) - (order.indexOf(b) < 0 ? 999 : order.indexOf(b));
          });
        final shown = _showAll ? keys : keys.take(8).toList();
        if (!p.isActive && keys.isEmpty) return const SizedBox.shrink();
        return InsetGroup(
          header: 'Labs',
          footer: keys.isEmpty ? null : 'Latest result of each test; ↑↓ against the report’s range, ⚠ critical.',
          dividerIndent: 16,
          children: [
            if (snap.hasError) const SettingsRow(icon: Icons.cloud_off_outlined, title: "Couldn't load results"),
            for (final k in shown) _row(byTest[k]!),
            if (keys.length > 8 && !_showAll)
              SettingsRow(title: 'Show all ${keys.length} tests', onTap: () => setState(() => _showAll = true)),
            if (keys.isEmpty && !snap.hasError) const SettingsRow(title: 'No results yet'),
            if (p.isActive)
              SettingsRow(
                icon: Icons.add,
                title: 'Add Results',
                subtitle: 'Type them in or scan the report',
                showChevron: true,
                onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => AddLabsScreen(patient: p))),
              ),
          ],
        );
      },
    );
  }

  Widget _row(List<LabResult> history) {
    final last = history.last;
    final prev = history.length > 1 ? history[history.length - 2] : null;
    String? trend;
    if (prev != null && last.value != null && prev.value != null) {
      final d = last.value! - prev.value!;
      trend = d.abs() < 1e-9 ? 'same as before' : '${d > 0 ? '↑' : '↓'} from ${prev.display}';
    }
    final color = last.flag == null ? null : (last.flag!.critical ? AppColors.danger : AppColors.warning);
    return SettingsRow(
      key: ValueKey(last.testKey),
      icon: last.flag?.critical ?? false ? Icons.warning_rounded : Icons.science_outlined,
      iconColor: color ?? AppColors.primary,
      title: '${last.testName}  ${last.display}${last.flag == null ? '' : ' ${last.flag!.mark}'}',
      subtitle: [formatDueTime(last.sampledAt), ?trend].join(' · '),
      showChevron: true,
      onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => LabTrendScreen(history: history))),
    );
  }
}

/// One test over time: chart (numbers) and every result, newest first.
class LabTrendScreen extends StatelessWidget {
  const LabTrendScreen({super.key, required this.history});
  final List<LabResult> history;

  Future<void> _delete(BuildContext context, LabResult r) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text('Delete ${r.testName} ${r.display}?'),
        content: Text('Sampled ${formatDueTime(r.sampledAt)}. Only for results entered in error.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await LabService().delete(r.id);
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Result deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't delete — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final numbers = [
      for (final r in history)
        if (r.value != null) r,
    ];
    final withRef = numbers.lastWhere((r) => r.refLow != null || r.refHigh != null, orElse: () => history.last);
    final first = history.first;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(
            title: first.testName,
            eyebrow: first.unit.isEmpty ? '${history.length} results' : '${history.length} results · ${first.unit}',
            showBackButton: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(
              children: [
                if (numbers.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: TrendChart(
                      points: [for (final r in numbers) TrendPoint(r.sampledAt, r.value!, flagged: r.flag != null)],
                      bandLow: withRef.refLow,
                      bandHigh: withRef.refHigh,
                    ),
                  ),
                  if (withRef.refText != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Text(
                        'Shaded: reference range ${withRef.refText} (from the report)',
                        style: AppTypography.footnote(color: AppColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                InsetGroup(
                  dividerIndent: 16,
                  footer: 'Long-press a result entered in error to delete it.',
                  children: [
                    for (final r in history.reversed)
                      GestureDetector(
                        onLongPress: () => _delete(context, r),
                        child: SettingsRow(
                          icon: r.flag == null ? null : Icons.flag_outlined,
                          iconColor: r.flag == null ? null : (r.flag!.critical ? AppColors.danger : AppColors.warning),
                          title: '${r.display}${r.flag == null ? '' : '  ${r.flag!.label}'}',
                          subtitle: [
                            formatDueTime(r.sampledAt),
                            if (r.refText != null) 'ref ${r.refText}',
                            if (r.source == 'scan') 'scanned',
                            ?r.createdByName,
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
