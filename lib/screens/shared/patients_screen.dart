import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/account_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/appearance_provider.dart';
import '../../services/patient_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/scope_button.dart';
import '../../widgets/tip_card.dart';
import '../../providers/unit_provider.dart';
import '../../widgets/large_title_app_bar.dart';
import '../patients/patient_form_screen.dart';
import '../patients/patient_screen.dart';
import 'census_screen.dart';

/// Every patient on the user's wards, grouped by ward, with search, a ward
/// filter and an Admitted / Discharged switch. Shared by doctors and nurses.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _wardStreams = StreamCache<List<Ward>>();
  final _patientStreams = StreamCache<List<Patient>>();
  final _search = TextEditingController();

  String _query = '';
  bool _discharged = false;


  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final q = _search.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _addPatient(List<Ward> wards) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PatientFormScreen(
        initialWardId: context.read<UnitProvider>().scope.wardId ??
            (wards.isEmpty ? null : wards.first.id),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    final ids =
        context.watch<AccountProvider>().currentUser?.wardIds ?? const <String>[];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<List<Ward>>(
        stream: ids.isEmpty
            ? Stream.value(const <Ward>[])
            : _wardStreams.get(
                ids.join(','), () => WardService().wardsForUser(ids)),
        builder: (context, wardSnap) {
          final wards = wardSnap.data ?? const <Ward>[];
          return CustomScrollView(
            slivers: [
              LargeTitleAppBar(
                title: 'Patients',
                actions: [
                  if (wards.isNotEmpty)
                    ChromeIconButton(
                      icon: Icons.assignment_outlined,
                      tooltip: 'Census & handover',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CensusScreen()),
                      ),
                    ),
                  if (wards.isNotEmpty)
                    ChromeIconButton(
                      icon: Icons.person_add_alt,
                      tooltip: 'Add patient',
                      onPressed: () => _addPatient(wards),
                    ),
                ],
              ),
              if (wardSnap.hasError)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load your wards",
                    subtitle: 'Check your connection and try again.',
                  ),
                )
              else if (ids.isEmpty || (wardSnap.hasData && wards.isEmpty))
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.corporate_fare_outlined,
                    title: 'No wards yet',
                    subtitle:
                        'Create or join a ward in the Wards tab to see patients.',
                  ),
                )
              else if (!wardSnap.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else ...[
                SliverToBoxAdapter(child: _controls(wards)),
                _list(wards),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _controls(List<Ward> wards) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoSearchTextField(
            controller: _search,
            placeholder: 'Name, mother, bed, diagnosis or ID',
            style: AppTypography.body(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: _discharged,
            onValueChanged: (v) {
              if (v == null) return;
              Haptics.selection();
              setState(() => _discharged = v);
            },
            children: {
              false: _segment('Admitted'),
              true: _segment('Discharged'),
            },
          ),
          const SizedBox(height: 6),
          const Align(alignment: Alignment.centerLeft, child: ScopeButton()),
          const SizedBox(height: 8),
          const TipCard(
            id: 'patients_census',
            icon: Icons.assignment_outlined,
            title: 'Handing over?',
            message: 'The clipboard button at the top gives today’s census and a handover list you can share.',
          ),
        ],
      ),
    );
  }

  Widget _segment(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(label,
            style: AppTypography.subheadline(
                color: AppColors.textPrimary, weight: FontWeight.w600)),
      );

  Widget _list(List<Ward> wards) {
    final wardIds = wards.map((w) => w.id).toList();
    final key = '$_discharged:${wardIds.join(',')}';
    return StreamBuilder<List<Patient>>(
      stream: _patientStreams.get(
        key,
        () => _discharged
            ? PatientService().getDischargedPatientsForWards(wardIds)
            : PatientService().getActivePatientsForWards(wardIds),
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load patients",
              subtitle: 'Pull to refresh or try again shortly.',
            ),
          );
        }
        if (!snap.hasData) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final units = context.watch<UnitProvider>();
        final scope = units.scope;
        final all = snap.data!;
        final matches = all
            .where((p) => scope.includes(wardId: p.wardId, unitId: p.unitId))
            .where(_matches)
            .toList();
        // Head count for the ward in view (or everything), before search.
        final countWard = scope.wardId ?? (wards.length == 1 ? wards.first.id : null);
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: UnitCountsLine(
            patients: all,
            wardId: countWard,
            noun: _discharged ? 'discharged' : 'admitted',
          ),
        );
        if (matches.isEmpty) {
          return SliverToBoxAdapter(
            child: Column(children: [header, _empty()]),
          );
        }

        // Ward → unit (in the ward's order) → unassigned.
        final groups = <(String, List<Patient>)>[];
        for (final w in wards) {
          final inWard = matches.where((p) => p.wardId == w.id).toList();
          if (inWard.isEmpty) continue;
          final wardUnits = units.unitsOf(w.id);
          if (wardUnits.isEmpty) {
            groups.add((w.name, inWard));
            continue;
          }
          for (final u in wardUnits) {
            final inUnit = inWard.where((p) => p.unitId == u.id).toList();
            if (inUnit.isNotEmpty) groups.add(('${w.name} · ${u.name}', inUnit));
          }
          final none = inWard.where((p) => units.unitById(p.unitId) == null).toList();
          if (none.isNotEmpty) groups.add(('${w.name} · Unassigned', none));
        }
        return SliverPadding(
          padding: withBottomBarInset(
              context, const EdgeInsets.fromLTRB(0, 0, 0, 24)),
          sliver: SliverList.builder(
            itemCount: groups.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return header;
              final (title, patients) = groups[i - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _Group(title: title, patients: patients),
              );
            },
          ),
        );
      },
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

  Widget _empty() {
    if (_query.isNotEmpty) {
      return EmptyState(
        icon: Icons.person_search_outlined,
        title: 'No matches',
        subtitle: 'Nothing matches “${_search.text.trim()}”.',
      );
    }
    return _discharged
        ? const EmptyState(
            icon: Icons.logout,
            title: 'No discharged patients',
            subtitle: 'Patients you discharge appear here, newest first.',
          )
        : const EmptyState(
            icon: Icons.bed_outlined,
            title: 'No patients admitted',
            subtitle: 'Tap + to admit your first patient.',
          );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.patients});

  final String title;
  final List<Patient> patients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTypography.footnote(color: AppColors.textSecondary)
                      .copyWith(letterSpacing: 0.4),
                ),
              ),
              Text(
                '${patients.length}',
                style: AppTypography.footnote(color: AppColors.textSecondary)
                    .copyWith(fontFeatures: AppTypography.tabular),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, p) in patients.indexed) ...[
                if (i > 0)
                  const Divider(height: 0.5, thickness: 0.5, indent: 68),
                PatientRow(patient: p),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A patient as a table row: avatar with bed, name, age · sex · diagnosis,
/// IDs, and a red alarm when a reminder is overdue.
class PatientRow extends StatelessWidget {
  const PatientRow({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final overdue = context.select<ReminderProvider, int>((rp) {
      final now = DateTime.now();
      return rp.open
          .where((r) => r.patientId == p.id && r.isOverdueAt(now))
          .length;
    });
    final color = tintForName(p.name);
    final meta = [
      p.ageLabel,
      if (p.gender.isNotEmpty) p.gender,
      if (p.diagnosis.isNotEmpty) p.diagnosis,
    ].join(' · ');
    final ids = [
      if (p.patientCode.isNotEmpty) p.patientCode,
      if (p.hospitalId != null) p.hospitalId!,
    ].join(' · ');
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PatientScreen(patientId: p.id),
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    p.bedNumber.isNotEmpty ? p.bedNumber : p.initials,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: AppTypography.subheadline(
                            color: color, weight: FontWeight.w700)
                        .copyWith(fontFeatures: AppTypography.tabular),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          color: AppColors.textPrimary,
                          weight: FontWeight.w600),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote(
                            color: AppColors.textSecondary),
                      ),
                    Text(
                      p.isDischarged && p.dischargedAt != null
                          ? [
                              if (ids.isNotEmpty) ids,
                              'Discharged ${DateFormat('d MMM').format(p.dischargedAt!)}',
                            ].join(' · ')
                          : ids,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appMonoText(
                              color: AppColors.textSecondary, fontSize: 12)
                          .copyWith(fontFeatures: AppTypography.tabular),
                    ),
                  ],
                ),
              ),
              if (overdue > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.alarm,
                      size: 20,
                      color: AppColors.danger,
                      semanticLabel: '$overdue overdue reminder'),
                ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
