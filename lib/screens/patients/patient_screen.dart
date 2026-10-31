import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../clinical/early_warning.dart';
import '../../models/note.dart';
import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/patient_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../widgets/discharge_readiness_row.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/newborn_section.dart';
import '../../widgets/observations_section.dart';
import '../../widgets/patient_handover_section.dart';
import '../../widgets/patient_photos_section.dart';
import '../../widgets/patient_status_card.dart';
import '../../widgets/patient_team_section.dart';
import '../../widgets/newborn_tracking_section.dart';
import '../../widgets/patient_actions.dart';
import '../../widgets/patient_infusions_section.dart';
import '../../widgets/patient_jobs_section.dart';
import '../../widgets/reminder_widgets.dart';
import '../jobs/add_job_sheet.dart';
import '../notes/compose_note_sheet.dart';
import '../notes/note_actions.dart';

enum _View { overview, timeline }

/// Timeline filter: everything, what people wrote, or system events.
enum _Show { all, notes, events }

const _eventKinds = {
  'transfer',
  'discharge',
  'admission',
  'investigation',
  'phototherapy',
  'status',
  'photo',
  'infusion',
};

/// One patient, laid out like a contact card: who they are and quick
/// actions at the top, then Overview (details, newborn care, jobs,
/// reminders) or Timeline (everything written, by day). Live.
class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  late final Stream<Patient?> _patient = PatientService().watchPatient(widget.patientId);
  WardFeed? _feed;
  _View _view = _View.overview;
  _Show _show = _Show.all;
  String? _wardIdLoaded;
  Ward? _ward;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feed = context.read<WardFeed>()..watchPatient(widget.patientId);
    });
  }

  @override
  void dispose() {
    _feed?.stopWatchingPatient();
    super.dispose();
  }

  /// The ward's name for the header; looked up once per ward.
  void _loadWard(String wardId) {
    if (_wardIdLoaded == wardId) return;
    _wardIdLoaded = wardId;
    WardService().getWard(wardId).then((w) {
      if (mounted) setState(() => _ward = w);
    }).catchError((Object _) {
      // The header just leaves the ward name out.
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Patient?>(
      stream: _patient,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _shell(
              title: 'Patient',
              body: const SliverFillRemaining(child: Center(child: CircularProgressIndicator.adaptive())));
        }
        final p = snap.data;
        if (p == null) {
          return _shell(
            title: 'Patient',
            body: const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyPlaceholder(
                icon: Icons.visibility_off_outlined,
                title: 'Not available',
                subtitle: 'This patient was moved to a ward you’re not in, or was removed.',
              ),
            ),
          );
        }
        _loadWard(p.wardId);
        return _shell(
          title: p.name,
          actions: [if (p.isActive) FollowButton(patient: p), PatientActionsButton(patient: p)],
          body: SliverPadding(
            padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 32)),
            sliver: SliverList.list(children: [
              _Header(patient: p, ward: _ward),
              const SizedBox(height: 18),
              if (p.isActive) ...[
                _QuickActions(patient: p),
                const SizedBox(height: 20),
              ],
              CupertinoSlidingSegmentedControl<_View>(
                groupValue: _view,
                onValueChanged: (v) {
                  if (v == null) return;
                  Haptics.selection();
                  setState(() => _view = v);
                },
                children: {
                  _View.overview: _segment('Overview'),
                  _View.timeline: _segment('Timeline'),
                },
              ),
              const SizedBox(height: 18),
              if (_view == _View.overview) ..._overview(p) else _timeline(p),
            ]),
          ),
        );
      },
    );
  }

  Widget _shell({required String title, required Widget body, List<Widget> actions = const []}) => Scaffold(
        backgroundColor: AppColors.surface,
        body: CustomScrollView(slivers: [
          LargeTitleAppBar(title: title, showBackButton: true, actions: actions),
          body,
        ]),
      );

  Widget _segment(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(label, style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
      );

  List<Widget> _overview(Patient p) => [
        if (p.isDischarged) ...[_DischargeNotice(patient: p), const SizedBox(height: 20)],
        if (p.isActive) ...[
          PatientStatusCard(key: ValueKey('status-${p.id}'), patient: p, wardKind: _ward?.kind),
          const SizedBox(height: 24),
          PatientHandoverSection(key: ValueKey('handover-${p.id}'), patient: p),
          const SizedBox(height: 24),
          PatientTeamSection(patient: p, ward: _ward),
          const SizedBox(height: 24),
        ],
        _Details(patient: p),
        const SizedBox(height: 24),
        if (p.bornAt != null) ...[
          if (p.isActive) ...[
            DischargeReadinessRow(patient: p),
            const SizedBox(height: 16),
          ],
          NewbornSection(patient: p),
          const SizedBox(height: 16),
          NewbornTrackingSection(patient: p),
          const SizedBox(height: 16),
        ],
        if (earlyWarningFor(p, DateTime.now()) != null) ...[
          ObservationsSection(key: ValueKey('obs-${p.id}'), patient: p),
          const SizedBox(height: 16),
        ],
        PatientInfusionsSection(key: ValueKey('infusions-${p.id}'), patient: p),
        const SizedBox(height: 16),
        PatientPhotosSection(key: ValueKey('photos-${p.id}'), patient: p),
        const SizedBox(height: 16),
        PatientJobsSection(patient: p),
        const SizedBox(height: 16),
        PatientRemindersSection(patient: p),
      ];

  Widget _timeline(Patient p) {
    final all = context.watch<WardFeed>().timeline;
    bool isEvent(Note n) => _eventKinds.contains(n.kind.toLowerCase());
    final shown = switch (_show) {
      _Show.all => all,
      _Show.notes => all.where((n) => !isEvent(n)).toList(),
      _Show.events => all.where(isEvent).toList(),
    };
    final byDay = <DateTime, List<Note>>{};
    for (final n in shown) {
      final l = n.createdAt.toLocal();
      (byDay[DateTime(l.year, l.month, l.day)] ??= []).add(n);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8, children: [
            for (final (v, label) in [(_Show.all, 'All'), (_Show.notes, 'Notes'), (_Show.events, 'Events')])
              ChoiceChip(
                label: Text(label),
                selected: _show == v,
                onSelected: (_) {
                  Haptics.selection();
                  setState(() => _show = v);
                },
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          EmptyPlaceholder(
            icon: Icons.timeline,
            title: _show == _Show.events ? 'No events yet' : 'Nothing on the timeline yet',
            subtitle: p.isActive ? 'Notes and events about ${p.name} appear here.' : 'This patient has been discharged.',
            buttonLabel: p.isActive && _show != _Show.events ? 'Write a Note' : null,
            onButtonTap: p.isActive ? () => showComposeNote(context, patient: p) : null,
          )
        else
          for (final e in byDay.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
              child: Text(_dayLabel(e.key).toUpperCase(),
                  style: AppTypography.footnote(color: AppColors.textSecondary).copyWith(letterSpacing: 0.4)),
            ),
            for (final n in e.value) ...[FeedNote(note: n), const SizedBox(height: 10)],
          ],
      ],
    );
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gap = today.difference(day).inDays;
    if (gap == 0) return 'Today';
    if (gap == 1) return 'Yesterday';
    if (gap < 7) return DateFormat('EEEE').format(day);
    return DateFormat('d MMMM y').format(day);
  }
}

/// Bed badge, where the patient is, and a few status chips.
class _Header extends StatelessWidget {
  const _Header({required this.patient, required this.ward});
  final Patient patient;
  final Ward? ward;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final units = context.watch<UnitProvider>();
    final unit = units.unitsOf(p.wardId).isEmpty ? null : units.unitById(p.unitId)?.name;
    final tint = tintForName(p.name);
    final hours = p.hoursSinceBirth();
    final place = [
      if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}',
      if (ward != null) ward!.name,
      if (unit != null) unit,
    ].join(' · ');
    final chips = <(String, Color)>[
      if (p.isDischarged) ('Discharged', AppColors.textSecondary),
      if (hours != null && hours < 24 * 7) ('$hours h of life', AppColors.primary) else (p.ageLabel, AppColors.primary),
      if (p.gender.isNotEmpty) (p.gender, AppColors.secondary),
      if (p.bloodGroup != null) (p.bloodGroup!, AppColors.danger),
    ];
    return Column(
      children: [
        Semantics(
          label: p.bedNumber.isNotEmpty ? 'Bed ${p.bedNumber}' : p.name,
          excludeSemantics: true,
          child: Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  p.bedNumber.isNotEmpty ? p.bedNumber : initialsOf(p.name),
                  maxLines: 1,
                  style: AppTypography.title1(color: tint).copyWith(fontFeatures: AppTypography.tabular),
                ),
              ),
            ),
          ),
        ),
        if (place.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(place, textAlign: TextAlign.center, style: AppTypography.subheadline(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (label, color) in chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: AppTypography.footnote(color: color, weight: FontWeight.w600)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Round-cornered buttons under the header, like a contact card.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return Row(
      children: [
        _ActionButton(icon: Icons.edit_square, label: 'Note', onTap: () => showComposeNote(context, patient: p)),
        const SizedBox(width: 10),
        _ActionButton(icon: Icons.add_task, label: 'Job', onTap: () => showAddJob(context, patient: p)),
        const SizedBox(width: 10),
        _ActionButton(icon: Icons.alarm_add, label: 'Reminder', onTap: () => showAddReminder(context, p)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.card),
              onTap: () {
                Haptics.selection();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(children: [
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(height: 4),
                  Text(label, style: AppTypography.caption1(color: AppColors.primary, weight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Key facts as Settings-style rows; IDs copy on tap.
class _Details extends StatelessWidget {
  const _Details({required this.patient});
  final Patient patient;

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    Haptics.success();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $value')));
  }

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final units = context.watch<UnitProvider>();
    final hasUnits = units.unitsOf(p.wardId).isNotEmpty;
    return InsetGroup(
      header: 'Details',
      dividerIndent: 16,
      children: [
        if (p.diagnosis.isNotEmpty) SettingsRow(title: 'Diagnosis', subtitle: p.diagnosis),
        SettingsRow(title: 'Age', value: p.ageLabel),
        if (p.bornAt != null) SettingsRow(title: 'Born', value: formatDueTime(p.bornAt!)),
        SettingsRow(title: 'Admitted', value: formatDay(p.admittedAt.toLocal())),
        if (hasUnits) SettingsRow(title: 'Unit', value: units.unitById(p.unitId)?.name ?? 'Unassigned'),
        if (p.patientCode.isNotEmpty)
          SettingsRow(
            title: 'FolioMed ID',
            value: p.patientCode,
            trailing: Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
            onTap: () => _copy(context, p.patientCode),
          ),
        if (p.hospitalId != null)
          SettingsRow(
            title: 'Hospital ID',
            value: p.hospitalId,
            trailing: Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
            onTap: () => _copy(context, p.hospitalId!),
          ),
      ],
    );
  }
}

/// A discharged patient: when, why, and how to bring them back.
class _DischargeNotice extends StatelessWidget {
  const _DischargeNotice({required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.quaternaryFill, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.home_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.dischargedAt == null ? 'Gone home' : 'Gone home ${formatDueTime(p.dischargedAt!)}',
                    style: AppTypography.headline(color: AppColors.textPrimary)),
                if ((p.dischargeSummary ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p.dischargeSummary!, style: AppTypography.subheadline(color: AppColors.textSecondary)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Readmit from ••• to add notes again.',
                      style: AppTypography.footnote(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
