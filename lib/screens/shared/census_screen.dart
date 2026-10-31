import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../clinical/handover.dart';
import '../../clinical/patient_status.dart';
import '../../models/handover_session.dart';
import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/patient_roster.dart';
import '../../providers/unit_provider.dart';
import '../../services/handover_service.dart';
import '../../services/patient_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/handover_card.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/scope_button.dart';
import 'handover_data.dart';
import 'handover_session_screen.dart';

enum _CensusView { census, handover }

/// Daily census per ward/unit, and a shareable handover list — both for
/// the Ward ▸ Unit filter in use.
class CensusScreen extends StatefulWidget {
  const CensusScreen({super.key});

  @override
  State<CensusScreen> createState() => _CensusScreenState();
}

class _CensusScreenState extends State<CensusScreen> {
  static final _discharged = StreamCache<List<Patient>>();

  _CensusView _mode = _CensusView.census;
  DateTime _day = DateTime.now();
  static final _sessionStreams = StreamCache<List<HandoverSession>>();
  Future<HandoverExtras>? _extras;
  String _extrasKey = '';
  bool _sickestFirst = false;

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitProvider>();
    final scope = units.scope;
    final active = context
        .watch<PatientRoster>()
        .patients
        .where((p) => scope.includes(wardId: p.wardId, unitId: p.unitId))
        .toList();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<List<Ward>>(
        stream: myWardsStream(context),
        builder: (context, wardSnap) {
          final wards = wardSnap.data ?? const <Ward>[];
          return CustomScrollView(
            slivers: [
              LargeTitleAppBar(
                title: _mode == _CensusView.census ? 'Census' : 'Handover',
                showBackButton: true,
                actions: [
                  if (_mode == _CensusView.handover)
                    ChromeIconButton(
                      icon: Icons.ios_share,
                      tooltip: 'Share handover',
                      onPressed: () => _share(active, wards, units),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList.list(
                  children: [
                    CupertinoSlidingSegmentedControl<_CensusView>(
                      groupValue: _mode,
                      onValueChanged: (m) {
                        if (m == null) return;
                        Haptics.selection();
                        setState(() => _mode = m);
                      },
                      children: {
                        _CensusView.census: _seg('Census'),
                        _CensusView.handover: _seg('Handover'),
                      },
                    ),
                    const SizedBox(height: 6),
                    const Align(alignment: Alignment.centerLeft, child: ScopeButton()),
                    const SizedBox(height: 10),
                    if (_mode == _CensusView.census)
                      _census(active, wards)
                    else
                      _handover(active, wards, units),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seg(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(t,
            style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
      );

  // ───────────────────────────── Census ─────────────────────────────

  Widget _census(List<Patient> active, List<Ward> wards) {
    final scope = context.read<UnitProvider>().scope;
    final ids = wards.map((w) => w.id).toList();
    return StreamBuilder<List<Patient>>(
      stream: ids.isEmpty
          ? Stream.value(const <Patient>[])
          : _discharged.get(ids.join(','),
              () => PatientService().getDischargedPatientsForWards(ids)),
      builder: (context, snap) {
        final discharged = (snap.data ?? const <Patient>[])
            .where((p) => scope.includes(wardId: p.wardId, unitId: p.unitId))
            .toList();
        final today = DateTime.now();
        final isToday = _day.year == today.year && _day.month == today.month && _day.day == today.day;
        final c = DayCensus.of(active: active, discharged: discharged, day: _day);
        final countWard = scope.wardId ?? (wards.length == 1 ? wards.first.id : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InsetGroup(
              header: 'Day',
              children: [
                SettingsRow(
                  icon: Icons.calendar_today_outlined,
                  title: isToday ? 'Today' : DateFormat('EEEE').format(_day),
                  value: DateFormat('d MMM yyyy').format(_day),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: today.subtract(const Duration(days: 60)),
                      lastDate: today,
                    );
                    if (d != null) setState(() => _day = d);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            InsetGroup(
              header: 'Head count',
              footer: isToday
                  ? null
                  : '“Admitted now” is always today’s number; the rest are for the day chosen.',
              children: [
                SettingsRow(
                  icon: Icons.bed_outlined,
                  iconColor: AppColors.doctorColor,
                  title: 'Admitted now',
                  value: '${c.current}',
                ),
                SettingsRow(
                  icon: Icons.login,
                  iconColor: AppColors.accent,
                  title: 'Admissions',
                  value: '${c.admitted}',
                ),
                SettingsRow(
                  icon: Icons.logout,
                  iconColor: AppColors.textSecondary,
                  title: 'Discharges',
                  value: '${c.discharged}',
                ),
                SettingsRow(
                  icon: Icons.child_friendly_outlined,
                  iconColor: AppColors.nurseColor,
                  title: 'Births',
                  value: '${c.born}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: UnitCountsLine(patients: active, wardId: countWard),
            ),
            if (snap.data != null && snap.data!.length >= 100)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Discharges counted from the latest 100 discharged patients.',
                    style: AppTypography.footnote(color: AppColors.textSecondary)),
              ),
          ],
        );
      },
    );
  }

  // ───────────────────────────── Handover ─────────────────────────────

  Future<HandoverExtras> _extrasFor(List<Patient> active) {
    final key = (active.map((p) => p.id).toList()..sort()).join(',');
    if (key != _extrasKey || _extras == null) {
      _extrasKey = key;
      _extras = HandoverExtras.load(active.map((p) => p.id).toList());
    }
    return _extras!;
  }

  Widget _handover(List<Patient> active, List<Ward> wards, UnitProvider units) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sessionsGroup(wards, units),
        const SizedBox(height: 16),
        if (active.isEmpty)
          const EmptyPlaceholder(
            icon: Icons.assignment_outlined,
            title: 'Nobody to hand over',
            subtitle: 'No admitted patients in this ward or unit.',
          )
        else
          FutureBuilder<HandoverExtras>(
            future: _extrasFor(active),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }
              final items = handoverItems(context,
                  patients: active, wards: wards, extras: snap.data!, sickestFirst: _sickestFirst);
              final now = DateTime.now();
              final red = items.where((i) => i.status?.level == StatusLevel.act).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 4, 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${items.length} patients · $red need action',
                          style: AppTypography.footnote(color: AppColors.textSecondary, weight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _sickestFirst = !_sickestFirst),
                        icon: const Icon(Icons.swap_vert, size: 18),
                        label: Text(_sickestFirst ? 'Sickest first' : 'Bed order'),
                      ),
                    ]),
                  ),
                  for (final i in items) ...[
                    HandoverCard(item: i, now: now),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  /// Start Handover, the one in progress, and the last few.
  Widget _sessionsGroup(List<Ward> wards, UnitProvider units) {
    final ids = wards.map((w) => w.id).toList();
    return StreamBuilder<List<HandoverSession>>(
      stream: ids.isEmpty ? Stream.value(const []) : _sessionStreams.get(ids.join(','), () => HandoverService().sessions(ids)),
      builder: (context, snap) {
        final sessions = snap.data ?? const <HandoverSession>[];
        final open = sessions.where((s) => s.isOpen).toList();
        final recent = sessions.where((s) => !s.isOpen).take(5).toList();
        return InsetGroup(
          header: 'Shift handover',
          footer: 'I-PASS: Illness severity, Patient summary, Action list, Situation awareness (if/then), '
              'Synthesis — the person taking over confirms each patient.',
          children: [
            for (final s in open)
              SettingsRow(
                icon: Icons.play_circle_outline,
                iconColor: AppColors.stable,
                title: 'In progress · ${s.scopeLabel}',
                subtitle: 'Started ${formatClock(s.startedAt)} by ${s.givenByName}',
                onTap: () => _openSession(s),
              ),
            SettingsRow(
              icon: Icons.handshake_outlined,
              title: 'Start Handover',
              subtitle: 'For ${scopeLabel(units.scope, wards, units)}',
              onTap: wards.isEmpty ? null : () => _start(wards, units),
            ),
            for (final s in recent)
              SettingsRow(
                icon: Icons.history,
                iconColor: AppColors.textSecondary,
                title: s.scopeLabel,
                subtitle: '${formatDueTime(s.startedAt)} · ${s.givenByName}',
                onTap: () => _openSession(s),
              ),
          ],
        );
      },
    );
  }

  void _openSession(HandoverSession s) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HandoverSessionScreen(handoverId: s.id, wardId: s.wardId)));

  Future<void> _start(List<Ward> wards, UnitProvider units) async {
    final scope = units.scope;
    var wardId = scope.wardId ?? (wards.length == 1 ? wards.first.id : null);
    wardId ??= await showOptionSheet<String>(
      context,
      title: 'Hand over which ward?',
      options: {for (final w in wards) w.id: w.name},
    );
    if (wardId == null || !mounted) return;
    final unitId = scope.wardId == wardId ? scope.unitId : null;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await HandoverService().start(wardId, unitId: unitId);
      Haptics.success();
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => HandoverSessionScreen(handoverId: id, wardId: wardId!)));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  Future<void> _share(List<Patient> active, List<Ward> wards, UnitProvider units) async {
    final extras = await _extrasFor(active);
    if (!mounted) return;
    final items = handoverItems(context, patients: active, wards: wards, extras: extras, sickestFirst: _sickestFirst);
    final scope = scopeLabel(units.scope, wards, units);
    await Share.share(handoverText(items, scope, DateTime.now()), subject: 'Handover — $scope');
  }
}
