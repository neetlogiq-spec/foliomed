import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../clinical/bilirubin.dart';
import '../../clinical/handover.dart';
import '../../models/newborn_tracking.dart';
import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/patient_roster.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/unit_provider.dart';
import '../../services/patient_service.dart';
import '../../services/tracking_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/scope_button.dart';
import '../patients/patient_screen.dart';

enum _Mode { census, handover }

/// Daily census per ward/unit, and a shareable handover list — both for
/// the Ward ▸ Unit filter in use.
class CensusScreen extends StatefulWidget {
  const CensusScreen({super.key});

  @override
  State<CensusScreen> createState() => _CensusScreenState();
}

class _CensusScreenState extends State<CensusScreen> {
  static final _discharged = StreamCache<List<Patient>>();

  _Mode _mode = _Mode.census;
  DateTime _day = DateTime.now();
  Future<TrackingSnapshot>? _snapshot;
  String _snapshotKey = '';

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
                title: _mode == _Mode.census ? 'Census' : 'Handover',
                showBackButton: true,
                actions: [
                  if (_mode == _Mode.handover)
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
                    CupertinoSlidingSegmentedControl<_Mode>(
                      groupValue: _mode,
                      onValueChanged: (m) {
                        if (m == null) return;
                        Haptics.selection();
                        setState(() => _mode = m);
                      },
                      children: {
                        _Mode.census: _seg('Census'),
                        _Mode.handover: _seg('Handover'),
                      },
                    ),
                    const SizedBox(height: 6),
                    const Align(alignment: Alignment.centerLeft, child: ScopeButton()),
                    const SizedBox(height: 10),
                    if (_mode == _Mode.census)
                      _census(active, wards)
                    else
                      _handover(active, units),
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

  Future<TrackingSnapshot> _snapshotFor(List<Patient> active) {
    final key = (active.map((p) => p.id).toList()..sort()).join(',');
    if (key != _snapshotKey || _snapshot == null) {
      _snapshotKey = key;
      _snapshot = TrackingService().snapshot(active.map((p) => p.id).toList());
    }
    return _snapshot!;
  }

  List<HandoverItem> _items(List<Patient> active, TrackingSnapshot snap, UnitProvider units) {
    final reminders = context.read<ReminderProvider>().open;
    final items = [
      for (final p in active)
        HandoverItem(
          patient: p,
          unitName: units.unitById(p.unitId)?.name,
          openReminders: reminders.where((r) => r.patientId == p.id).toList(),
          bilirubin: snap.latestBilirubin[p.id],
          phototherapy: snap.runningPhototherapy[p.id],
          weight: snap.latestWeight[p.id],
        ),
    ];
    final unitOrder = units.units.map((u) => u.id).toList();
    items.sort((a, b) => compareHandover(a, b, unitOrder));
    return items;
  }

  Widget _handover(List<Patient> active, UnitProvider units) {
    if (active.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Nobody to hand over',
        subtitle: 'No admitted patients in this ward or unit.',
      );
    }
    return FutureBuilder<TrackingSnapshot>(
      future: _snapshotFor(active),
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load the handover",
            subtitle: 'Check your connection.',
            buttonLabel: 'Try again',
            onButtonTap: () => setState(() => _snapshot = null),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final items = _items(active, snap.data!, units);
        final now = DateTime.now();
        final flagged = items.where((i) => i.flags(now).isNotEmpty).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                '${items.length} patients · $flagged need attention',
                style: AppTypography.footnote(color: AppColors.textSecondary, weight: FontWeight.w600),
              ),
            ),
            for (final i in items) ...[
              _HandoverCard(item: i, now: now),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Future<void> _share(List<Patient> active, List<Ward> wards, UnitProvider units) async {
    final snap = await _snapshotFor(active);
    if (!mounted) return;
    final items = _items(active, snap, units);
    final now = DateTime.now();
    final header = 'Handover — ${scopeLabel(units.scope, wards, units)} — '
        '${DateFormat('d MMM, h:mm a').format(now)} — ${items.length} patients';
    final text = [header, for (final i in items) i.toText(now)].join('\n\n');
    await Share.share(text, subject: header);
  }
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.item, required this.now});

  final HandoverItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = item.patient;
    final flags = item.flags(now);
    final a = item.assessment;
    final wc = item.weightChange;
    final pending = item.openReminders.where((r) => !r.isOverdueAt(now)).toList();
    Widget line(IconData icon, String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: color ?? AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    style: AppTypography.footnote(color: color ?? AppColors.textSecondary)),
              ),
            ],
          ),
        );
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PatientScreen(patientId: p.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}',
                  p.name,
                ].join(' · '),
                style: AppTypography.headline(color: AppColors.textPrimary),
              ),
              Text(
                [p.ageLabel, if (item.unitName != null) item.unitName!, if (p.patientCode.isNotEmpty) p.patientCode]
                    .join(' · '),
                style: AppTypography.footnote(color: AppColors.textSecondary),
              ),
              if (p.diagnosis.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.diagnosis, style: AppTypography.subheadline(color: AppColors.textPrimary)),
              ],
              for (final f in flags) line(Icons.error, f, color: AppColors.danger),
              if (item.phototherapy != null)
                line(Icons.light_mode, '${item.phototherapy!.kind.label} phototherapy · '
                    '${item.phototherapy!.durationAt(now).inHours} h', color: AppColors.warning),
              if (item.bilirubin != null && (a == null || a.action.index < BiliAction.considerPhototherapy.index))
                line(Icons.show_chart,
                    'Last ${item.bilirubin!.transcutaneous ? 'TcB' : 'TSB'} '
                    '${item.bilirubin!.value} ${item.bilirubin!.isUmol ? 'µmol/L' : 'mg/dL'}'
                    '${a == null ? '' : ' · ${a.guideline}: ${a.action.label}'}'),
              if (wc != null && wc.flag == WeightFlag.ok)
                line(Icons.monitor_weight_outlined, 'Weight ${wc.label} from birth'),
              for (final r in pending.take(2)) line(Icons.schedule, r.title),
            ],
          ),
        ),
      ),
    );
  }
}
