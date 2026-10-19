import 'package:flutter/material.dart';

import '../clinical/bilirubin.dart';
import '../models/newborn_screen.dart';
import '../models/patient.dart';
import '../services/newborn_screen_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/app_utils.dart';
import 'inset_group.dart';
import 'newborn_flow.dart';

/// Patient page: the newborn investigation plan and its results.
/// Shown only when a birth time is recorded.
class NewbornSection extends StatefulWidget {
  const NewbornSection({super.key, required this.patient});

  final Patient patient;

  @override
  State<NewbornSection> createState() => _NewbornSectionState();
}

class _NewbornSectionState extends State<NewbornSection> {
  late final Stream<List<NewbornScreen>> _stream =
      NewbornScreenService().forPatient(widget.patient.id);

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return StreamBuilder<List<NewbornScreen>>(
      stream: _stream,
      builder: (context, snap) {
        final screens = snap.data ?? const <NewbornScreen>[];
        final rows = <Widget>[
          SettingsRow(
            icon: Icons.child_friendly_outlined,
            iconColor: AppColors.nurseColor,
            title: 'Born ${formatDueTime(p.bornAt!)}',
            subtitle: [
              '${p.hoursSinceBirth()} h of life',
              if (p.gestationLabel != null) p.gestationLabel!,
            ].join(' · '),
          ),
          for (final s in screens) ..._screenRows(context, s),
          if (snap.hasData && p.isActive &&
              !screens.any((s) => s.status == ScreenStatus.planned))
            SettingsRow(
              icon: Icons.science_outlined,
              title: screens.isEmpty ? 'Plan investigations' : 'Plan another set',
              subtitle: '48 h or 72 h, with a reminder before',
              onTap: () => NewbornFlow.plan(context, p),
            ),
        ];
        return InsetGroup(
          header: 'Newborn',
          footer: p.gestationWeeks == null
              ? 'Add the gestational age (Edit details) so bilirubin can be compared with NICE thresholds.'
              : null,
          children: rows,
        );
      },
    );
  }

  List<Widget> _screenRows(BuildContext context, NewbornScreen s) {
    final p = widget.patient;
    switch (s.status) {
      case ScreenStatus.planned:
        return [
          SettingsRow(
            icon: Icons.schedule,
            iconColor: AppColors.warning,
            title: '${s.plannedHours}-hour investigations',
            subtitle: 'Send ${formatDueTime(s.dueAt)} · heads-up ${s.leadHours} h before',
            onTap: p.isActive ? () => NewbornFlow.plan(context, p) : null,
            trailing: Text('Change',
                style: AppTypography.body(color: AppColors.primary)),
          ),
          SettingsRow(
            icon: Icons.check_circle_outline,
            iconColor: AppColors.accent,
            title: 'Mark as sent',
            onTap: () => NewbornFlow.markSent(context, s.id, p.id),
          ),
        ];
      case ScreenStatus.sent:
        return [
          SettingsRow(
            icon: Icons.local_shipping_outlined,
            iconColor: AppColors.primary,
            title: '${s.plannedHours}-hour investigations sent',
            subtitle: [
              if (s.sentAt != null) formatDueTime(s.sentAt!),
              if (s.sentByName?.isNotEmpty ?? false) 'by ${s.sentByName}',
            ].join(' '),
          ),
          SettingsRow(
            icon: Icons.edit_note,
            iconColor: AppColors.accent,
            title: 'Enter results',
            onTap: () => NewbornFlow.openResults(context, s.id, p.id),
          ),
        ];
      case ScreenStatus.resulted:
        return [
          _ResultsRow(screen: s, patient: p),
        ];
    }
  }
}

class _ResultsRow extends StatelessWidget {
  const _ResultsRow({required this.screen, required this.patient});

  final NewbornScreen screen;
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final r = screen.results;
    BiliAssessment? nice;
    if (r.tsbTotal != null && patient.bornAt != null) {
      final at = r.sampledAt ?? screen.sentAt ?? screen.dueAt;
      final a = const NiceCg98().assess(
        gestationWeeks: patient.gestationWeeks,
        hoursOfAge: at.difference(patient.bornAt!).inMinutes / 60,
        tsbUmol: r.biliUnit == BiliUnit.mgdl ? mgdlToUmol(r.tsbTotal!) : r.tsbTotal!,
      );
      if (a is BiliAssessment) nice = a;
    }
    final alert = nice != null && nice.action.index >= BiliAction.considerPhototherapy.index;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => NewbornFlow.openResults(context, screen.id, patient.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: alert ? AppColors.danger : AppColors.accent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.science_outlined, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${screen.plannedHours}-hour results',
                        style: AppTypography.body(color: AppColors.textPrimary)),
                    if (nice != null)
                      Text('NICE: ${nice.action.label}',
                          style: AppTypography.subheadline(
                              color: alert ? AppColors.danger : AppColors.accent,
                              weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(r.summary(),
                        style: AppTypography.footnote(color: AppColors.textSecondary)),
                    if (screen.resultedAt != null)
                      Text(
                        'Entered ${formatDueTime(screen.resultedAt!)}'
                        '${screen.resultedByName?.isNotEmpty ?? false ? ' by ${screen.resultedByName}' : ''} · tap to edit',
                        style: AppTypography.caption1(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
