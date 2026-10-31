import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../clinical/handover.dart';
import '../../models/handover_session.dart';
import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/patient_roster.dart';
import '../../services/handover_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/handover_card.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/scope_button.dart';
import 'handover_data.dart';

/// A live shift handover. The outgoing person walks through the cards;
/// the incoming person — ideally on their own phone, where this opens
/// from Today — taps Received on each (I-PASS synthesis), optionally with
/// a question. Finishing records anyone not received as missed.
class HandoverSessionScreen extends StatefulWidget {
  const HandoverSessionScreen({super.key, required this.handoverId, required this.wardId});

  final String handoverId;
  final String wardId;

  @override
  State<HandoverSessionScreen> createState() => _HandoverSessionScreenState();
}

class _HandoverSessionScreenState extends State<HandoverSessionScreen> {
  final _service = HandoverService();
  late final Stream<List<HandoverEntry>> _entries = _service.entries(widget.handoverId);
  late final Stream<List<HandoverSession>> _sessions = _service.sessions([widget.wardId]);
  Future<HandoverExtras>? _extras;
  String _extrasKey = '';
  bool _sickestFirst = false;

  Future<HandoverExtras> _extrasFor(List<String> ids) {
    final key = ([...ids]..sort()).join(',');
    if (key != _extrasKey || _extras == null) {
      _extrasKey = key;
      _extras = HandoverExtras.load(ids);
    }
    return _extras!;
  }

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
    return StreamBuilder<List<HandoverSession>>(
      stream: _sessions,
      builder: (context, ss) {
        final session = ss.data?.where((s) => s.id == widget.handoverId).firstOrNull;
        return StreamBuilder<List<HandoverEntry>>(
          stream: _entries,
          builder: (context, es) {
            final entries = es.data ?? const <HandoverEntry>[];
            return StreamBuilder<List<Ward>>(
              stream: myWardsStream(context),
              builder: (context, ws) => _page(session, entries, ws.data ?? const [], es.hasError || ss.hasError),
            );
          },
        );
      },
    );
  }

  Widget _page(HandoverSession? session, List<HandoverEntry> entries, List<Ward> wards, bool error) {
    final open = session?.isOpen ?? false;
    final received = entries.where((e) => e.received).length;
    final roster = {for (final p in context.watch<PatientRoster>().patients) p.id: p};
    final patients = [for (final e in entries) roster[e.patientId]].whereType<Patient>().toList();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(slivers: [
        LargeTitleAppBar(
          title: 'Handover',
          showBackButton: true,
          eyebrow: session?.scopeLabel,
          actions: [
            ChromeIconButton(
              icon: _sickestFirst ? Icons.sort : Icons.format_list_numbered,
              tooltip: _sickestFirst ? 'Sickest first' : 'Bed order',
              onPressed: () => setState(() => _sickestFirst = !_sickestFirst),
            ),
            if (patients.isNotEmpty)
              ChromeIconButton(
                icon: Icons.ios_share,
                tooltip: 'Share handover',
                onPressed: () => _share(session, patients, wards),
              ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          sliver: SliverList.list(children: [
            if (error)
              const EmptyPlaceholder(
                icon: Icons.cloud_off_outlined,
                title: "Couldn't load the handover",
                subtitle: 'Check your connection.',
              )
            else if (session == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator.adaptive()))
            else ...[
              _summary(session, entries, received),
              const SizedBox(height: 14),
              FutureBuilder<HandoverExtras>(
                future: _extrasFor([for (final p in patients) p.id]),
                builder: (context, xs) {
                  if (!xs.hasData) {
                    return const Padding(
                        padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator.adaptive()));
                  }
                  final items = handoverItems(context,
                      patients: patients, wards: wards, extras: xs.data!, sickestFirst: _sickestFirst);
                  final byPatient = {for (final e in entries) e.patientId: e};
                  final gone = entries.where((e) => !roster.containsKey(e.patientId)).toList();
                  final now = DateTime.now();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final i in items) ...[
                      HandoverCard(
                        item: i,
                        now: now,
                        footer: byPatient[i.patient.id] == null ? null : _receiveRow(byPatient[i.patient.id]!, open),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final e in gone) ...[
                      _GoneCard(entry: e, footer: _receiveRow(e, open)),
                      const SizedBox(height: 10),
                    ],
                  ]);
                },
              ),
              if (open) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _finish(entries.length - received),
                  child: const Text('Finish Handover'),
                ),
              ],
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _summary(HandoverSession s, List<HandoverEntry> entries, int received) {
    final missed = entries.where((e) => !e.received).toList();
    final text = s.isOpen
        ? 'Given by ${s.givenByName.isEmpty ? '—' : s.givenByName} · started ${formatClock(s.startedAt)}.\n'
            '$received of ${entries.length} received. The person taking over taps Received on each patient '
            '— on their own phone, from Today, or here.'
        : 'Given by ${s.givenByName.isEmpty ? '—' : s.givenByName} · ${formatDueTime(s.startedAt)}; '
            'finished ${formatClock(s.finishedAt!)}${(s.finishedByName ?? '').isEmpty ? '' : ' by ${s.finishedByName}'}.\n'
            '$received of ${entries.length} received'
            '${missed.isEmpty ? '.' : ' — missed: ${missed.map((e) => e.bedNumber.isEmpty ? e.patientName : 'bed ${e.bedNumber}').join(', ')}.'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LinearProgressIndicator(
          value: entries.isEmpty ? 0 : received / entries.length,
          color: missed.isEmpty ? AppColors.stable : (s.isOpen ? AppColors.primary : AppColors.warning),
          backgroundColor: AppColors.fill,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 10),
        Text(text, style: AppTypography.footnote(color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _receiveRow(HandoverEntry e, bool open) {
    if (e.received) {
      return Row(children: [
        Icon(Icons.check_circle, color: AppColors.stable, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Received by ${e.receivedByName ?? '—'} · ${formatClock(e.receivedAt!)}'
            '${(e.question ?? '').isEmpty ? '' : '\nQuestion: ${e.question}'}',
            style: AppTypography.footnote(color: AppColors.textSecondary),
          ),
        ),
        if (open)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 32),
            onPressed: () => _run(() => _service.unreceive(e.id)),
            child: const Text('Undo'),
          ),
      ]);
    }
    if (!open) {
      return Row(children: [
        Icon(Icons.error_outline, color: AppColors.warning, size: 18),
        const SizedBox(width: 6),
        Text('Not received', style: AppTypography.footnote(color: AppColors.warning)),
      ]);
    }
    return Row(children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: () => _run(() => _service.receive(e.id)),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Received'),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: () => _receiveWithQuestion(e),
        child: const Text('Question'),
      ),
    ]);
  }

  Future<void> _receiveWithQuestion(HandoverEntry e) async {
    final c = TextEditingController();
    final q = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Received, with a question'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Is the 6 pm gas due?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Received')),
        ],
      ),
    );
    if (q == null) return;
    await _run(() => _service.receive(e.id, question: q));
  }

  Future<void> _finish(int notReceived) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Finish handover?'),
        content: Text(notReceived == 0
            ? 'Every patient has been received.'
            : '$notReceived patient${notReceived == 1 ? ' hasn’t' : 's haven’t'} been received and will be recorded as missed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finish')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _service.finish(widget.handoverId), done: 'Handover finished');
  }

  Future<void> _share(HandoverSession? s, List<Patient> patients, List<Ward> wards) async {
    final extras = await _extrasFor([for (final p in patients) p.id]);
    if (!mounted) return;
    final items = handoverItems(context, patients: patients, wards: wards, extras: extras, sickestFirst: _sickestFirst);
    await Share.share(handoverText(items, s?.scopeLabel ?? 'Ward', DateTime.now()), subject: 'Handover');
  }
}

/// A patient who has left the list since the handover started.
class _GoneCard extends StatelessWidget {
  const _GoneCard({required this.entry, required this.footer});
  final HandoverEntry entry;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([if (entry.bedNumber.isNotEmpty) 'Bed ${entry.bedNumber}', entry.patientName].join(' · '),
              style: AppTypography.headline(color: AppColors.textPrimary)),
          Text('No longer admitted here (discharged or transferred).',
              style: AppTypography.footnote(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          footer,
        ]),
      );
}
