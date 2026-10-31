import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../clinical/workload.dart';
import '../../models/app_user.dart';
import '../../models/ward.dart';
import '../../models/ward_unit.dart';
import '../../providers/unit_provider.dart';
import '../../services/unit_service.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/app_sheet.dart';
import '../../providers/account_provider.dart';
import '../../providers/patient_roster.dart';
import '../../providers/appearance_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/ward_actions.dart';
import 'ward_drugs_screen.dart';
import 'workload_screen.dart';
import '../jobs/jobs_screen.dart';
import '../notes/ward_notes_screen.dart';
import '../../providers/job_board.dart';
import '../../providers/ward_feed.dart';

/// One ward: what's happening now, the invite code, units, members,
/// details, and leave / delete.
class WardPage extends StatefulWidget {
  const WardPage({super.key, required this.ward});

  final Ward ward;

  @override
  State<WardPage> createState() => _WardPageState();
}

class _WardPageState extends State<WardPage> {
  late final Future<List<AppUser>> _members =
      WardService().getWardMembers(widget.ward.id);

  late WardKind _kind = widget.ward.kind;
  late List<String> _tags = widget.ward.tagOptions;
  late List<int> _shifts = widget.ward.shiftStarts;

  Future<void> _editShifts() async {
    final starts = await showAppSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShiftSheet(initial: _shifts),
    );
    if (starts == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WardService().setShiftStarts(widget.ward.id, starts);
      Haptics.success();
      setState(() => _shifts = [...starts]..sort());
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  Future<void> _editTags() async {
    final tags = await showAppSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TagListSheet(initial: _tags),
    );
    if (tags == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WardService().setTagOptions(widget.ward.id, tags);
      Haptics.success();
      setState(() => _tags = tags);
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  Future<void> _pickKind() async {
    final k = await showOptionSheet<WardKind>(
      context,
      title: 'Ward type',
      options: {for (final k in WardKind.values) k: k.label},
      selected: _kind,
    );
    if (k == null || k == _kind || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WardService().setKind(widget.ward.id, k);
      Haptics.success();
      setState(() => _kind = k);
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  bool get _isOwner =>
      widget.ward.ownerId.isNotEmpty &&
      widget.ward.ownerId == supabase.auth.currentUser?.id;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.ward.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${widget.ward.id}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    final w = widget.ward;
    final patients = context
        .watch<PatientRoster>()
        .patients
        .where((p) => p.wardId == w.id)
        .length;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(title: w.name, showBackButton: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList.list(
              children: [
                _rightNow(w, patients),
                const SizedBox(height: 24),
                _codeCard(w),
                const SizedBox(height: 24),
                _unitsGroup(),
                const SizedBox(height: 24),
                _membersGroup(),
                const SizedBox(height: 24),
                InsetGroup(
                  header: 'About',
                  footer: 'The ward type picks the automatic checks behind the patients’ status dots — '
                      'newborn bilirubin and weight on PNC and NICU, support tags on PICU. '
                      'Other follows the patient’s age.${_isOwner ? '' : ' Only the owner can change it.'}',
                  dividerIndent: 16,
                  children: [
                    SettingsRow(
                      title: 'Ward type',
                      value: _kind.label,
                      onTap: _isOwner ? _pickKind : null,
                    ),
                    SettingsRow(
                      title: 'Shifts start',
                      value: _shifts.map(clockLabel).join(' · '),
                      onTap: _isOwner ? _editShifts : null,
                    ),
                    if (_isOwner || context.watch<AccountProvider>().currentUser?.role == UserRole.admin)
                      SettingsRow(
                        icon: Icons.insights_outlined,
                        title: 'Workload',
                        subtitle: 'Tasks per shift and response times',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => WorkloadScreen(ward: w, shiftStarts: _shifts))),
                      ),
                    SettingsRow(
                      icon: Icons.medication_outlined,
                      title: 'Drug List',
                      subtitle: 'Vials, standard syringes and sign-off',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WardDrugsScreen(ward: w, kind: _kind))),
                    ),
                    SettingsRow(
                      title: 'Clinical tags',
                      subtitle: _tags.isEmpty ? null : _tags.join(' · '),
                      value: _tags.isEmpty ? 'None' : null,
                      onTap: _isOwner ? _editTags : null,
                    ),
                    if (w.location.isNotEmpty) SettingsRow(title: 'Where', value: w.location),
                    SettingsRow(
                      title: 'Owner',
                      subtitle: w.ownerEmail.isEmpty || _isOwner ? null : w.ownerEmail,
                      value: _isOwner ? 'You' : (w.ownerName.isEmpty ? '—' : w.ownerName),
                    ),
                    SettingsRow(title: 'Set up', value: formatDay(w.createdAt)),
                  ],
                ),
                const SizedBox(height: 24),
                InsetGroup(
                  footer: _isOwner
                      ? 'Deleting erases every patient, note and reminder in this ward for everyone.'
                      : null,
                  children: [
                    if (_isOwner)
                      SettingsRow(
                        icon: Icons.delete_outline,
                        title: 'Delete ward',
                        destructive: true,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          if (await WardActions.delete(context, w)) {
                            navigator.pop();
                          }
                        },
                      )
                    else
                      SettingsRow(
                        icon: Icons.logout,
                        title: 'Leave ward',
                        destructive: true,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          if (await WardActions.leave(context, w)) {
                            navigator.pop();
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What's happening in this ward now; rows open the list with this ward
  /// selected (the filter button there changes it back).
  Widget _rightNow(Ward w, int admitted) {
    final toConfirm = context.watch<WardFeed>().feed.where((n) => n.wardId == w.id && !n.isConfirmed).length;
    final jobs = context.watch<JobBoard>().open().where((j) => j.wardId == w.id).length;
    Future<void> open(Widget page) async {
      await context.read<UnitProvider>().setScope(PatientScope.ward(w.id));
      if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    return InsetGroup(
      header: 'Right now',
      children: [
        SettingsRow(icon: Icons.bed_outlined, iconColor: AppColors.doctorColor, title: 'Admitted', value: '$admitted'),
        SettingsRow(
          icon: Icons.mark_chat_unread_outlined,
          iconColor: AppColors.warning,
          title: 'Notes to Confirm',
          value: '$toConfirm',
          onTap: () => open(const WardNotesScreen(initial: NotesView.pending)),
        ),
        SettingsRow(
          icon: Icons.checklist,
          iconColor: AppColors.stable,
          title: 'Open Jobs',
          value: '$jobs',
          onTap: () => open(const JobsScreen()),
        ),
      ],
    );
  }

  Widget _unitsGroup() {
    final w = widget.ward;
    final units = context.watch<UnitProvider>();
    final list = units.unitsOf(w.id);
    final admitted = context
        .watch<PatientRoster>()
        .patients
        .where((p) => p.wardId == w.id)
        .toList();
    final counts = UnitCounts.of(admitted.map((p) => p.unitId));
    final mine = units.myUnitFor(w.id);
    return InsetGroup(
      header: 'Units (teams)',
      footer: list.isEmpty
          ? (_isOwner
              ? 'Add units such as Unit A and Unit B to sort and count patients by team. Everyone in the ward still sees every unit.'
              : 'The ward owner can add units (teams) here.')
          : '${counts.total} admitted · ${[
              for (final u in list) '${u.name} ${counts.byUnit[u.id] ?? 0}',
              if (counts.unassigned > 0) 'Unassigned ${counts.unassigned}',
            ].join(' · ')}',
      children: [
        for (final (i, u) in list.indexed)
          SettingsRow(
            icon: Icons.groups_outlined,
            iconColor: AppColors.secondary,
            title: u.name,
            subtitle: mine == u.id ? 'My unit' : null,
            value: '${counts.byUnit[u.id] ?? 0}',
            showChevron: _isOwner,
            onTap: _isOwner ? () => _unitActions(u, i, list) : null,
          ),
        if (list.isNotEmpty)
          SettingsRow(
            icon: Icons.person_pin_outlined,
            iconColor: AppColors.accent,
            title: 'My unit',
            subtitle: 'Today and Patients open on this unit',
            value: units.unitById(mine)?.name ?? 'None',
            onTap: () async {
              final id = await showOptionSheet<String>(
                context,
                title: 'Your unit in ${w.name}',
                selected: mine ?? '',
                options: {for (final u in list) u.id: u.name, '': 'None — whole ward'},
              );
              if (id != null) await units.setMyUnit(w.id, id.isEmpty ? null : id);
            },
          ),
        if (_isOwner)
          SettingsRow(
            icon: Icons.add,
            title: 'Add unit',
            onTap: () => _editUnitName(position: list.length),
          ),
      ],
    );
  }

  Future<void> _editUnitName({WardUnit? unit, int position = 0}) async {
    final name = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: unit?.name ?? '');
        return AppAlertDialog(
          title: Text(unit == null ? 'New unit' : 'Rename unit'),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Unit A', counterText: ''),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(unit == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _run(() => unit == null
        ? UnitService().add(widget.ward.id, name, position: position)
        : UnitService().rename(unit.id, name));
  }

  Future<void> _unitActions(WardUnit u, int index, List<WardUnit> list) async {
    final action = await showOptionSheet<String>(
      context,
      title: u.name,
      options: {
        'rename': 'Rename',
        if (index > 0) 'up': 'Move up',
        if (index < list.length - 1) 'down': 'Move down',
        'delete': 'Delete unit',
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'rename':
        await _editUnitName(unit: u);
      case 'up':
      case 'down':
        final other = list[action == 'up' ? index - 1 : index + 1];
        // Normalise positions to the list order, then swap the pair.
        await _run(() async {
          for (final (i, x) in list.indexed) {
            final pos = x.id == u.id
                ? (action == 'up' ? index - 1 : index + 1)
                : x.id == other.id
                    ? index
                    : i;
            if (pos != x.position) await UnitService().setPosition(x.id, pos);
          }
        });
      case 'delete':
        final ok = await showAdaptiveDialog<bool>(
          context: context,
          builder: (ctx) => AppAlertDialog(
            title: Text('Delete ${u.name}?'),
            content: const Text('Its patients stay in the ward and become Unassigned.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) await _run(() => UnitService().delete(u.id));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      Haptics.commit();
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(e is PostgrestException && e.code == '23505'
            ? 'There is already a unit with that name.'
            : friendlyError(e)),
      ));
    }
  }

  Widget _codeCard(Ward w) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          Text('WARD CODE',
              style: AppTypography.footnote(color: AppColors.textSecondary)
                  .copyWith(letterSpacing: 0.6)),
          const SizedBox(height: 6),
          // Monospaced, tabular digits: the code is read aloud and typed —
          // every digit must be unambiguous.
          SelectableText(
            w.id,
            semanticsLabel: 'Ward code ${w.id.split('').join(' ')}',
            style: appMonoText(
              color: AppColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ).copyWith(fontFeatures: AppTypography.tabular),
          ),
          const SizedBox(height: 4),
          Text('Colleagues tap Join a Ward on the Wards tab and enter this code',
              textAlign: TextAlign.center,
              style: AppTypography.footnote(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => WardActions.share(context, w),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Invite'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _membersGroup() {
    return FutureBuilder<List<AppUser>>(
      future: _members,
      builder: (context, snap) {
        if (snap.hasError) {
          return const InsetGroup(header: 'Members', children: [
            SettingsRow(title: "Couldn't load members"),
          ]);
        }
        if (!snap.hasData) {
          return const InsetGroup(header: 'Members', children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ]);
        }
        final members = [...snap.data!]..sort((a, b) {
            if (a.uid == widget.ward.ownerId) return -1;
            if (b.uid == widget.ward.ownerId) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return InsetGroup(
          header: 'Members · ${members.length}',
          dividerIndent: 68,
          children: [
            for (final m in members)
              _MemberRow(member: m, isOwner: m.uid == widget.ward.ownerId),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.isOwner});

  final AppUser member;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final name = m.name.isEmpty ? 'User' : m.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: m.roleColor.withValues(alpha: 0.15),
            child: m.emoji != null && m.emoji!.isNotEmpty
                ? Text(m.emoji!, style: const TextStyle(fontSize: 18))
                : Text(initialsOf(name),
                    style: AppTypography.footnote(
                        color: m.roleColor, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTypography.body(color: AppColors.textPrimary)),
                if (m.email.isNotEmpty)
                  Text(m.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote(
                          color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            isOwner ? '${m.roleLabel} · Owner' : m.roleLabel,
            style: AppTypography.footnote(
                color: AppColors.textSecondary, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Owner: the ward's clinical tags (add, remove, reorder by re-adding).
class _TagListSheet extends StatefulWidget {
  const _TagListSheet({required this.initial});
  final List<String> initial;

  @override
  State<_TagListSheet> createState() => _TagListSheetState();
}

class _TagListSheetState extends State<_TagListSheet> {
  late final List<String> _tags = [...widget.initial];
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _addTag() {
    final t = _add.text.trim();
    if (t.isEmpty || t.length > 24 || _tags.length >= 30) return;
    if (_tags.any((x) => x.toLowerCase() == t.toLowerCase())) return;
    setState(() => _tags.add(t));
    _add.clear();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              Expanded(
                child: Text('Clinical tags',
                    textAlign: TextAlign.center, style: AppTypography.headline(color: AppColors.textPrimary)),
              ),
              CupertinoButton(
                onPressed: () => Navigator.pop(context, _tags),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
            Flexible(
              child: SingleChildScrollView(
                child: InsetGroup(
                  footer: 'Up to 30 tags of 24 characters. Members tick them on each patient; '
                      'removing one here doesn’t remove it from patients who have it.',
                  dividerIndent: 16,
                  children: [
                    for (final t in _tags)
                      SettingsRow(
                        title: t,
                        trailing: IconButton(
                          tooltip: 'Remove $t',
                          icon: Icon(Icons.remove_circle, color: AppColors.danger),
                          onPressed: () => setState(() => _tags.remove(t)),
                        ),
                      ),
                    InsetTextRow(
                      label: 'Add',
                      controller: _add,
                      placeholder: 'e.g. Oxygen',
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) {},
                    ),
                    SettingsRow(icon: Icons.add, title: 'Add tag', onTap: _addTag),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Owner: shift start times (1–6), for the workload report.
class _ShiftSheet extends StatefulWidget {
  const _ShiftSheet({required this.initial});
  final List<int> initial;

  @override
  State<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<_ShiftSheet> {
  late final List<int> _starts = [...widget.initial]..sort();

  Future<int?> _pick(int initial) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              Expanded(
                child: Text('Shift start times',
                    textAlign: TextAlign.center, style: AppTypography.headline(color: AppColors.textPrimary)),
              ),
              CupertinoButton(
                onPressed: _starts.isEmpty ? null : () => Navigator.pop(context, _starts),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
            InsetGroup(
              footer: 'Each shift runs until the next one starts; the last runs past midnight. '
                  'Used by the Workload report.',
              dividerIndent: 16,
              children: [
                for (final (i, m) in _starts.indexed)
                  SettingsRow(
                    title: '${clockLabel(m)}–${clockLabel(_starts[(i + 1) % _starts.length])}',
                    trailing: _starts.length <= 1
                        ? null
                        : IconButton(
                            tooltip: 'Remove',
                            icon: Icon(Icons.remove_circle, color: AppColors.danger),
                            onPressed: () => setState(() => _starts.removeAt(i)),
                          ),
                    onTap: () async {
                      final v = await _pick(m);
                      if (v == null || _starts.contains(v)) return;
                      setState(() {
                        _starts[i] = v;
                        _starts.sort();
                      });
                    },
                  ),
                if (_starts.length < 6)
                  SettingsRow(
                    icon: Icons.add,
                    title: 'Add a shift',
                    onTap: () async {
                      final v = await _pick(_starts.isEmpty ? 480 : (_starts.last + 240) % 1440);
                      if (v == null || _starts.contains(v)) return;
                      setState(() => _starts
                        ..add(v)
                        ..sort());
                    },
                  ),
              ],
            ),
          ]),
        ),
      );
}
