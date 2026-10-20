import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/note.dart';
import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../services/notes_repository.dart';
import '../../services/patient_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/note_tile.dart';
import '../../widgets/ward_actions.dart';
import '../notes/note_thread_sheet.dart';

enum _View { team, patients, notes }

/// Admin view of one ward: who's on it, its admitted patients and its
/// notes; rename it or share its join code.
class AdminWardScreen extends StatefulWidget {
  const AdminWardScreen({super.key, required this.wardId});

  final String wardId;

  @override
  State<AdminWardScreen> createState() => _AdminWardScreenState();
}

class _AdminWardScreenState extends State<AdminWardScreen> {
  late Future<Ward?> _ward = WardService().getWard(widget.wardId);
  late final Future<List<AppUser>> _team = WardService().getWardMembers(widget.wardId);
  late final Stream<List<Patient>> _patients = PatientService().getPatientsByWard(widget.wardId);
  late final Stream<List<Note>> _notes = NotesRepository().wardFeed(widget.wardId);
  _View _view = _View.team;

  Future<void> _rename(Ward w) async {
    final name = TextEditingController(text: w.name);
    final floor = TextEditingController(text: w.floor);
    final save = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Ward details'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: floor, decoration: const InputDecoration(labelText: 'Floor / unit')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (save != true || name.text.trim().isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WardService().updateWard(Ward(
        id: w.id,
        name: name.text.trim(),
        floor: floor.text.trim(),
        capacity: w.capacity,
        headDoctorName: w.headDoctorName,
        creatorId: w.creatorId,
        creatorEmail: w.creatorEmail,
        createdAt: w.createdAt,
      ));
      setState(() => _ward = WardService().getWard(widget.wardId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Ward?>(
      future: _ward,
      builder: (context, snap) {
        final w = snap.data;
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: CustomScrollView(
            slivers: [
              LargeTitleAppBar(
                title: w?.name ?? 'Ward',
                showBackButton: true,
                actions: [
                  if (w != null) ...[
                    ChromeIconButton(icon: Icons.ios_share, tooltip: 'Invite', onPressed: () => WardActions.share(context, w)),
                    ChromeIconButton(icon: Icons.edit_outlined, tooltip: 'Edit ward', onPressed: () => _rename(w)),
                  ],
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList.list(
                  children: [
                    if (w != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          [if (w.floor.isNotEmpty) w.floor, 'Join code ${w.id}'].join(' · '),
                          style: AppTypography.subheadline(color: AppColors.textSecondary),
                        ),
                      ),
                    CupertinoSlidingSegmentedControl<_View>(
                      groupValue: _view,
                      onValueChanged: (v) => setState(() => _view = v ?? _view),
                      children: {
                        for (final (v, label) in [(_View.team, 'Team'), (_View.patients, 'Patients'), (_View.notes, 'Notes')])
                          v: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Text(label,
                                style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
                          ),
                      },
                    ),
                    const SizedBox(height: 16),
                    switch (_view) {
                      _View.team => _teamList(w),
                      _View.patients => _patientList(),
                      _View.notes => _noteList(),
                    },
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _teamList(Ward? w) => FutureBuilder<List<AppUser>>(
        future: _team,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator.adaptive());
          final people = snap.data!;
          if (people.isEmpty) {
            return const EmptyState(icon: Icons.group_outlined, title: 'Nobody yet', subtitle: 'Share the join code to invite the team.');
          }
          return InsetGroup(
            header: '${people.length} member${people.length == 1 ? '' : 's'}',
            children: [
              for (final p in people)
                SettingsRow(
                  icon: Icons.person_outline,
                  iconColor: p.roleColor,
                  title: p.name.isEmpty ? p.email : p.name,
                  subtitle: p.email,
                  value: p.uid == w?.creatorId ? '${p.roleLabel} · Owner' : p.roleLabel,
                ),
            ],
          );
        },
      );

  Widget _patientList() => StreamBuilder<List<Patient>>(
        stream: _patients,
        builder: (context, snap) {
          if (snap.hasError) {
            return Text('Patients are visible to ward members only.',
                style: AppTypography.footnote(color: AppColors.textSecondary));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator.adaptive());
          final admitted = snap.data!.where((p) => p.isActive).toList();
          if (admitted.isEmpty) {
            return const EmptyState(icon: Icons.bed_outlined, title: 'No admitted patients', subtitle: 'Nobody is admitted here right now.');
          }
          return InsetGroup(
            header: '${admitted.length} admitted',
            dividerIndent: 16,
            children: [
              for (final p in admitted)
                SettingsRow(
                  title: p.name,
                  subtitle: [if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}', p.ageLabel, p.patientCode].join(' · '),
                ),
            ],
          );
        },
      );

  Widget _noteList() => StreamBuilder<List<Note>>(
        stream: _notes,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator.adaptive());
          final notes = snap.data!;
          if (notes.isEmpty) {
            return const EmptyState(icon: Icons.notes, title: 'No notes yet', subtitle: 'Notes posted in this ward appear here.');
          }
          return Column(children: [
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NoteTile(note: n, onOpen: () => showNoteThread(context, n)),
              ),
          ]);
        },
      );
}
