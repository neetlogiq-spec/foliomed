import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/ward.dart';
import '../providers/follows.dart';
import '../providers/patient_roster.dart';
import '../screens/patients/patient_board.dart';
import '../services/patient_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'inset_group.dart';
import 'large_title_app_bar.dart';

/// Star in the patient page's bar: follow / unfollow ("My patients").
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final following = context.watch<Follows>().follows(patient.id);
    return ChromeIconButton(
      icon: following ? Icons.star_rounded : Icons.star_border_rounded,
      tooltip: following ? 'Unfollow' : 'Follow — add to My Patients',
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final now = await context.read<Follows>().toggle(patient.id);
          messenger.showSnackBar(SnackBar(
              content: Text(now ? 'Added to My Patients' : 'Removed from My Patients'),
              duration: const Duration(seconds: 2)));
        } catch (e) {
          messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
        }
      },
    );
  }
}

/// Patient page: consultant and clinical tags.
class PatientTeamSection extends StatelessWidget {
  const PatientTeamSection({super.key, required this.patient, required this.ward});

  final Patient patient;

  /// For the tag list; null while loading (starter tags are used).
  final Ward? ward;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      Haptics.success();
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final editable = p.isActive;
    return InsetGroup(
      header: 'Team',
      dividerIndent: 16,
      children: [
        SettingsRow(
          title: 'Consultant',
          value: (p.consultant?.isNotEmpty ?? false) ? p.consultant : 'Not set',
          onTap: editable ? () => _pickConsultant(context) : null,
        ),
        SettingsRow(
          title: 'Tags',
          subtitle: p.tags.isEmpty ? null : p.tags.join(' · '),
          value: p.tags.isEmpty ? 'None' : null,
          onTap: editable ? () => _pickTags(context) : null,
        ),
      ],
    );
  }

  Future<void> _pickConsultant(BuildContext context) async {
    final known = consultantsOf(context.read<PatientRoster>().patients.where((x) => x.wardId == patient.wardId));
    const other = '\u0000other', clear = '\u0000clear';
    final pick = await showOptionSheet<String>(
      context,
      title: 'Consultant',
      options: {
        for (final c in known) c: c,
        other: 'Someone else…',
        if (patient.consultant?.isNotEmpty ?? false) clear: 'Clear',
      },
      selected: patient.consultant,
    );
    if (pick == null || !context.mounted) return;
    String? name = pick;
    if (pick == clear) name = null;
    if (pick == other) {
      final c = TextEditingController();
      name = await showAdaptiveDialog<String>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: const Text('Consultant'),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Dr Rao'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      if (name == null || name.isEmpty || !context.mounted) return;
    }
    await _run(context, () => PatientService().setConsultant(patient.id, name));
  }

  Future<void> _pickTags(BuildContext context) async {
    final options = [...(ward?.tagOptions ?? kDefaultTagOptions)];
    // Tags set earlier but since removed from the ward list stay pickable.
    for (final t in patient.tags) {
      if (!options.contains(t)) options.add(t);
    }
    final picked = await showAppSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TagSheet(options: options, initial: patient.tags.toSet()),
    );
    if (picked == null || !context.mounted) return;
    await _run(context, () => PatientService().setTags(patient.id, picked));
  }
}

class _TagSheet extends StatefulWidget {
  const _TagSheet({required this.options, required this.initial});
  final List<String> options;
  final Set<String> initial;

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  late final Set<String> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              Expanded(
                child: Text('Tags',
                    textAlign: TextAlign.center, style: AppTypography.headline(color: AppColors.textPrimary)),
              ),
              CupertinoButton(
                onPressed: () => Navigator.pop(context, [for (final t in widget.options) if (_sel.contains(t)) t]),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
            Flexible(
              child: SingleChildScrollView(
                child: InsetGroup(
                  footer: 'The ward owner edits this list on the ward’s page.',
                  dividerIndent: 16,
                  children: [
                    for (final t in widget.options)
                      SettingsRow(
                        title: t,
                        trailing: Icon(
                          _sel.contains(t) ? Icons.check_circle : Icons.circle_outlined,
                          color: _sel.contains(t) ? AppColors.primary : AppColors.textSecondary,
                        ),
                        showChevron: false,
                        onTap: () => setState(() => _sel.contains(t) ? _sel.remove(t) : _sel.add(t)),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
}
