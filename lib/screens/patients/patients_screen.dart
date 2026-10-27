import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/account_provider.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/job_board.dart';
import '../../providers/patient_roster.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/patient_service.dart';
import '../../services/tracking_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/patient_row.dart';
import '../../widgets/status_dot.dart';
import '../../widgets/scope_button.dart';
import '../shared/census_screen.dart';
import 'patient_board.dart';
import 'patient_form_screen.dart';

/// Every patient on your wards as a ward board: bed, who, what's wrong and
/// what needs doing. Filter chips narrow it (needs attention, newborns,
/// phototherapy, discharged); a menu changes the order.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _wardStreams = StreamCache<List<Ward>>();
  final _dischargedStreams = StreamCache<List<Patient>>();
  String _query = '';
  PatientFilter _filter = PatientFilter.admitted;
  PatientSort _sort = PatientSort.bed;

  /// Phototherapy and weights, fetched once per set of admitted patients.
  String _trackingKey = '';
  Future<TrackingSnapshot>? _tracking;

  Future<TrackingSnapshot> _trackingFor(List<Patient> patients) {
    final ids = [for (final p in patients) p.id]..sort();
    final key = ids.join(',');
    if (key != _trackingKey || _tracking == null) {
      _trackingKey = key;
      _tracking = TrackingService().snapshot(ids).catchError((Object _) => TrackingSnapshot.empty());
    }
    return _tracking!;
  }

  void _admit(List<Ward> wards) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PatientFormScreen(
          initialWardId: context.read<UnitProvider>().scope.wardId ?? (wards.isEmpty ? null : wards.first.id),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    final ids = context.watch<AccountProvider>().currentUser?.wards ?? const <String>[];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<List<Ward>>(
        stream: ids.isEmpty
            ? Stream.value(const <Ward>[])
            : _wardStreams.get(ids.join(','), () => WardService().wardsForUser(ids)),
        builder: (context, wardSnap) {
          final wards = wardSnap.data ?? const <Ward>[];
          final admitted = context.watch<PatientRoster>().patients;
          return FutureBuilder<TrackingSnapshot>(
            future: _trackingFor(admitted),
            builder: (context, trackSnap) {
              final t = trackSnap.data ?? TrackingSnapshot.empty();
              final now = DateTime.now();
              final signals = withStatuses(
                now: now,
                admitted: admitted,
                signals: patientSignals(
                  now: now,
                  reminders: context.watch<ReminderProvider>().open,
                  jobs: context.watch<JobBoard>().open(),
                  notes: context.watch<WardFeed>().feed,
                  phototherapy: t.runningPhototherapy.keys.toSet(),
                  latestWeightG: {for (final e in t.latestWeight.entries) e.key: e.value.grams},
                ),
                wardKinds: {for (final w in wards) w.id: w.kind},
                latestBilirubin: t.latestBilirubin,
              );
              return RefreshIndicator.adaptive(
                edgeOffset: MediaQuery.paddingOf(context).top + 52,
                onRefresh: () async {
                  setState(() => _tracking = null);
                  await _trackingFor(admitted);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    LargeTitleAppBar(
                      title: 'Patients',
                      eyebrow: _eyebrow(admitted, signals),
                      actions: [
                        if (wards.isNotEmpty)
                          ChromeIconButton(
                            icon: Icons.assignment_outlined,
                            tooltip: 'Census & handover',
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const CensusScreen())),
                          ),
                        if (wards.isNotEmpty)
                          ChromeIconButton(icon: Icons.person_add_alt, tooltip: 'Admit patient', onPressed: () => _admit(wards)),
                      ],
                    ),
                    ..._body(ids, wardSnap, wards, admitted, signals),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String? _eyebrow(List<Patient> admitted, Map<String, PatientSignals> signals) {
    if (admitted.isEmpty) return null;
    final attention = admitted.where((p) => signals[p.id]?.needsAttention ?? false).length;
    return [
      '${admitted.length} admitted',
      if (attention > 0) '$attention need${attention == 1 ? 's' : ''} attention',
    ].join(' · ');
  }

  List<Widget> _body(List<String> ids, AsyncSnapshot<List<Ward>> wardSnap, List<Ward> wards, List<Patient> admitted,
      Map<String, PatientSignals> signals) {
    if (wardSnap.hasError) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyPlaceholder(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load your wards",
            subtitle: 'Check your connection and pull to try again.',
          ),
        ),
      ];
    }
    if (ids.isEmpty || (wardSnap.hasData && wards.isEmpty)) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyPlaceholder(
            icon: Icons.corporate_fare_outlined,
            title: 'No wards yet',
            subtitle: 'Set up or join a ward in the Wards tab to see patients.',
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: _controls(admitted, signals)),
      if (_filter == PatientFilter.discharged)
        StreamBuilder<List<Patient>>(
          stream: _dischargedStreams.get(
              wards.map((w) => w.id).join(','),
              () => PatientService().getDischargedPatientsForWards([for (final w in wards) w.id])),
          builder: (context, snap) {
            if (snap.hasError) return _message("Couldn't load discharged patients", Icons.cloud_off_outlined);
            if (!snap.hasData) {
              return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(32), child: Center(child: CupertinoActivityIndicator())));
            }
            return _groups(wards, snap.data!, signals, newestFirst: true);
          },
        )
      else
        _groups(wards, admitted, signals),
    ];
  }

  Widget _controls(List<Patient> admitted, Map<String, PatientSignals> signals) {
    int count(PatientFilter f) => switch (f) {
          PatientFilter.admitted => admitted.length,
          PatientFilter.discharged => -1,
          _ => admitted.where((p) => f.keeps(p, signals[p.id] ?? PatientSignals.none)).length,
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoSearchTextField(
            placeholder: 'Name, mother, bed, diagnosis or ID',
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in PatientFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(count(f) < 0 ? f.label : '${f.label}  ${count(f)}'),
                    selected: _filter == f,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _filter = f);
                    },
                  ),
                ),
            ]),
          ),
          if (_filter != PatientFilter.discharged) ...[
            const SizedBox(height: 8),
            const StatusLegend(),
          ],
          const SizedBox(height: 6),
          Row(children: [
            const ScopeButton(),
            const Spacer(),
            MenuAnchor(
              menuChildren: [
                for (final s in PatientSort.values)
                  MenuItemButton(
                    leadingIcon: Icon(s == _sort ? Icons.check : null),
                    onPressed: () => setState(() => _sort = s),
                    child: Text(s.label),
                  ),
              ],
              builder: (context, controller, _) => TextButton.icon(
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(_sort == PatientSort.attention ? 'Attention' : _sort.label),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  bool _matches(Patient p) {
    final q = _query;
    if (q.isEmpty) return true;
    return p.name.toLowerCase().contains(q) ||
        p.bedNumber.toLowerCase().contains(q) ||
        p.diagnosis.toLowerCase().contains(q) ||
        p.patientCode.toLowerCase().contains(q) ||
        (p.hospitalId?.toLowerCase().contains(q) ?? false) ||
        (p.motherName?.toLowerCase().contains(q) ?? false);
  }

  /// Ward → unit → unassigned groups, each sorted.
  Widget _groups(List<Ward> wards, List<Patient> source, Map<String, PatientSignals> signals,
      {bool newestFirst = false}) {
    final units = context.watch<UnitProvider>();
    final scope = units.scope;
    final shown = source
        .where((p) => scope.includes(wardId: p.wardId, unitId: p.unitId))
        .where((p) => _filter.keeps(p, signals[p.id] ?? PatientSignals.none))
        .where(_matches)
        .toList();
    if (shown.isEmpty) {
      return _query.isNotEmpty
          ? _message('Nothing matches “$_query”', Icons.person_search_outlined)
          : switch (_filter) {
              PatientFilter.attention => _message('Nothing needs attention', Icons.task_alt),
              PatientFilter.newborns => _message('No newborns admitted', Icons.child_care),
              PatientFilter.phototherapy => _message('Nobody is under phototherapy', Icons.light_mode_outlined),
              PatientFilter.discharged => _message('No one discharged yet', Icons.home_outlined),
              PatientFilter.admitted => _message('No patients admitted — tap the person button to admit one',
                  Icons.bed_outlined),
            };
    }
    final sort = newestFirst ? PatientSort.newest : _sort;
    final groups = <(String, List<Patient>)>[];
    for (final w in wards) {
      final inWard = shown.where((p) => p.wardId == w.id).toList();
      if (inWard.isEmpty) continue;
      final wardUnits = units.unitsOf(w.id);
      if (wardUnits.isEmpty) {
        groups.add((w.name, sortPatients(inWard, sort, signals)));
        continue;
      }
      for (final u in wardUnits) {
        final inUnit = inWard.where((p) => p.unitId == u.id).toList();
        if (inUnit.isNotEmpty) groups.add(('${w.name} · ${u.name}', sortPatients(inUnit, sort, signals)));
      }
      final none = inWard.where((p) => units.unitById(p.unitId) == null).toList();
      if (none.isNotEmpty) groups.add(('${w.name} · No unit', sortPatients(none, sort, signals)));
    }
    return SliverPadding(
      padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 0, 16, 24)),
      sliver: SliverList.builder(
        itemCount: groups.length,
        itemBuilder: (_, i) {
          final (title, patients) = groups[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: InsetGroup(
              header: '$title · ${patients.length}',
              dividerIndent: 58,
              children: [
                for (final p in patients)
                  PatientRow(
                    key: ValueKey(p.id),
                    patient: p,
                    signals: signals[p.id] ?? PatientSignals.none,
                    onReturn: () {
                      if (mounted) setState(() => _tracking = null);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _message(String text, IconData icon) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(children: [
            Icon(icon, size: 34, color: AppColors.tertiaryLabel),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: AppTypography.subheadline(color: AppColors.textSecondary)),
          ]),
        ),
      );
}
