import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/patient_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/app_utils.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../doctor/add_patient_screen.dart';
import '../doctor/patient_detail_screen.dart';

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

  /// null = all wards.
  String? _wardFilter;

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
      builder: (_) => AddPatientScreen(
        initialWardId: _wardFilter ?? (wards.isEmpty ? null : wards.first.id),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final ids =
        context.watch<AuthProvider>().currentUser?.wardIds ?? const <String>[];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<List<Ward>>(
        stream: ids.isEmpty
            ? Stream.value(const <Ward>[])
            : _wardStreams.get(
                ids.join(','), () => WardService().wardsForUser(ids)),
        builder: (context, wardSnap) {
          final wards = wardSnap.data ?? const <Ward>[];
          if (_wardFilter != null && !wards.any((w) => w.id == _wardFilter)) {
            _wardFilter = null;
          }
          return CustomScrollView(
            slivers: [
              LargeTitleAppBar(
                title: 'Patients',
                actions: [
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
            placeholder: 'Name, bed, diagnosis or ID',
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
          if (wards.length > 1) ...[
            const SizedBox(height: 6),
            // iOS pull-down button for the ward filter.
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                onPressed: () async {
                  final id = await showOptionSheet<String>(
                    context,
                    title: 'Show patients from',
                    selected: _wardFilter ?? '',
                    options: {'': 'All wards', for (final w in wards) w.id: w.name},
                  );
                  if (id == null) return;
                  Haptics.selection();
                  setState(() => _wardFilter = id.isEmpty ? null : id);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _wardFilter == null
                          ? 'All wards'
                          : wards.firstWhere((w) => w.id == _wardFilter).name,
                      style: AppTypography.subheadline(
                          color: AppColors.primary, weight: FontWeight.w600),
                    ),
                    Icon(Icons.expand_more, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
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
        final matches = snap.data!.where(_matches).toList();
        if (matches.isEmpty) return SliverToBoxAdapter(child: _empty());

        final byWard = <String, List<Patient>>{};
        for (final p in matches) {
          (byWard[p.wardId] ??= []).add(p);
        }
        final groups = [
          for (final w in wards)
            if (byWard[w.id]?.isNotEmpty ?? false) (w, byWard[w.id]!),
        ];
        return SliverPadding(
          padding: withBottomBarInset(
              context, const EdgeInsets.fromLTRB(16, 8, 16, 24)),
          sliver: SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final (ward, patients) = groups[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _WardGroup(ward: ward, patients: patients),
              );
            },
          ),
        );
      },
    );
  }

  bool _matches(Patient p) {
    if (_wardFilter != null && p.wardId != _wardFilter) return false;
    final q = _query;
    if (q.isEmpty) return true;
    return p.name.toLowerCase().contains(q) ||
        p.bedNumber.toLowerCase().contains(q) ||
        p.diagnosis.toLowerCase().contains(q) ||
        p.patientCode.toLowerCase().contains(q) ||
        (p.hospitalId?.toLowerCase().contains(q) ?? false);
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

class _WardGroup extends StatelessWidget {
  const _WardGroup({required this.ward, required this.patients});

  final Ward ward;
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
                  ward.name.toUpperCase(),
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
    final color = getAvatarColor(p.name);
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
          builder: (_) => PatientDetailScreen(patientId: p.id),
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
