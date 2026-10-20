import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../models/patient.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/patient_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/layout.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/newborn_section.dart';
import '../../widgets/patient_jobs_section.dart';
import '../../widgets/newborn_tracking_section.dart';
import '../../widgets/patient_actions.dart';
import '../../widgets/reminder_widgets.dart';
import '../../widgets/tip_card.dart';
import '../notes/compose_note_sheet.dart';
import '../notes/note_actions.dart';

/// Timeline filter: everything, what people wrote, or system events
/// (transfers, discharges, results, phototherapy…).
enum _Show { all, notes, events }

const _eventKinds = {'transfer', 'discharge', 'admission', 'investigation', 'phototherapy'};

/// One patient: who they are, newborn tracking, reminders, and a single
/// timeline grouped by day. Updates live as the team works.
class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  late final Stream<Patient?> _patient = PatientService().watchPatient(widget.patientId);
  WardFeed? _feed;
  _Show _show = _Show.all;

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Patient?>(
      stream: _patient,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _shell(title: 'Patient', body: const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator.adaptive())));
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
        return _shell(
          title: p.name,
          actions: [
            if (p.isActive)
              ChromeIconButton(
                icon: Icons.edit_square,
                tooltip: 'New note',
                onPressed: () => showComposeNote(context, patient: p),
              ),
            PatientActionsButton(patient: p),
          ],
          body: SliverPadding(
            padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 32)),
            sliver: SliverList.list(children: _content(p)),
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

  List<Widget> _content(Patient p) => [
        if (p.isDischarged) ...[_DischargeNotice(patient: p), const SizedBox(height: 16)],
        const TipCard(
          id: 'patient_actions',
          icon: Icons.more_horiz,
          title: 'More for this patient',
          message: 'Tap ••• at the top to edit details, move to another unit or ward, discharge or delete.',
        ),
        _Summary(patient: p),
        const SizedBox(height: 16),
        if (p.bornAt != null) ...[
          NewbornSection(patient: p),
          const SizedBox(height: 16),
          NewbornTrackingSection(patient: p),
          const SizedBox(height: 16),
        ],
        PatientJobsSection(patient: p),
        const SizedBox(height: 16),
        PatientRemindersSection(patient: p),
        const SizedBox(height: 24),
        _timeline(p),
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
        Text('Timeline', style: AppTypography.title3(color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        CupertinoSlidingSegmentedControl<_Show>(
          groupValue: _show,
          onValueChanged: (v) => setState(() => _show = v ?? _show),
          children: {
            for (final (v, label) in [(_Show.all, 'All'), (_Show.notes, 'Notes'), (_Show.events, 'Events')])
              v: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(label,
                    style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
              ),
          },
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          EmptyPlaceholder(
            icon: Icons.timeline,
            title: _show == _Show.events ? 'No events yet' : 'Nothing on the timeline yet',
            subtitle: p.isActive ? 'Notes and events about ${p.name} appear here.' : 'This patient has been discharged.',
            buttonLabel: p.isActive && _show != _Show.events ? 'Write a note' : null,
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

/// Identity and the key facts, at a glance.
class _Summary extends StatelessWidget {
  const _Summary({required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final units = context.watch<UnitProvider>();
    final unit = units.unitsOf(p.wardId).isEmpty ? null : (units.unitById(p.unitId)?.name ?? 'Unassigned');
    final facts = <(String, String)>[
      ('Age', p.ageLabel),
      if (p.gender.isNotEmpty) ('Sex', p.gender),
      ('Bed', p.bedNumber.isEmpty ? '–' : p.bedNumber),
      ('Blood', p.bloodGroup ?? '–'),
      if (unit != null) ('Unit', unit),
    ];
    final tint = tintForName(p.name);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: tint.withValues(alpha: 0.15),
                child: Text(initialsOf(p.name),
                    style: AppTypography.headline(color: tint, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  if (p.patientCode.isNotEmpty) _CopyableId(label: 'FolioMed ID', value: p.patientCode),
                  if (p.hospitalId != null) _CopyableId(label: 'Hospital ID', value: p.hospitalId!),
                ]),
              ),
            ],
          ),
          if (p.diagnosis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(p.diagnosis, style: AppTypography.body(color: AppColors.textPrimary)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            for (final (label, value) in facts)
              Expanded(
                child: Semantics(
                  label: '$label $value',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.caption1(color: AppColors.textSecondary)),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Text(
            [
              'Admitted ${formatDay(p.admittedAt.toLocal())}',
              if (p.bornAt != null) 'born ${formatDueTime(p.bornAt!)} · ${p.hoursSinceBirth()} h of life',
            ].join(' · '),
            style: AppTypography.footnote(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Monospaced ID that copies on tap.
class _CopyableId extends StatelessWidget {
  const _CopyableId({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $value. Double-tap to copy.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $value')));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$label ', style: AppTypography.caption1(color: AppColors.textSecondary)),
              Text(value,
                  style: appMonoText(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)
                      .copyWith(fontFeatures: AppTypography.tabular)),
              const SizedBox(width: 4),
              Icon(Icons.copy, size: 12, color: AppColors.textSecondary),
            ]),
          ),
        ),
      ),
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
                Text(p.dischargedAt == null ? 'Discharged' : 'Discharged ${formatDueTime(p.dischargedAt!)}',
                    style: AppTypography.headline(color: AppColors.textPrimary)),
                if ((p.dischargeSummary ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p.dischargeSummary!, style: AppTypography.subheadline(color: AppColors.textSecondary)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('To add notes again, readmit from •••.',
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
