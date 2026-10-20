import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../models/app_user.dart';
import '../../models/ward.dart';
import '../../models/ward_unit.dart';
import '../../providers/unit_provider.dart';
import '../../services/unit_service.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_alert_dialog.dart';
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

/// One ward: its join code (copy / share), details, members, and
/// leave / delete.
class WardPage extends StatefulWidget {
  const WardPage({super.key, required this.ward});

  final Ward ward;

  @override
  State<WardPage> createState() => _WardPageState();
}

class _WardPageState extends State<WardPage> {
  late final Future<List<AppUser>> _members =
      WardService().getWardMembers(widget.ward.id);

  bool get _isOwner =>
      widget.ward.creatorId.isNotEmpty &&
      widget.ward.creatorId == supabase.auth.currentUser?.id;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.ward.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ward code ${widget.ward.id} copied')),
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
                _codeCard(w),
                const SizedBox(height: 24),
                InsetGroup(
                  header: 'Details',
                  children: [
                    if (w.floor.isNotEmpty)
                      SettingsRow(
                        icon: Icons.layers_outlined,
                        iconColor: AppColors.secondary,
                        title: 'Floor / unit',
                        value: w.floor,
                      ),
                    SettingsRow(
                      icon: Icons.bed_outlined,
                      iconColor: AppColors.doctorColor,
                      title: 'Admitted patients',
                      value: '$patients',
                    ),
                    SettingsRow(
                      icon: Icons.verified_user_outlined,
                      iconColor: AppColors.accent,
                      title: 'Owner',
                      subtitle: w.creatorEmail.isEmpty ? null : w.creatorEmail,
                      value: _isOwner
                          ? 'You'
                          : (w.headDoctorName.isEmpty ? '—' : w.headDoctorName),
                    ),
                    SettingsRow(
                      icon: Icons.event_outlined,
                      iconColor: AppColors.warning,
                      title: 'Created',
                      value: formatDay(w.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _unitsGroup(),
                const SizedBox(height: 24),
                _membersGroup(),
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
          Text('Colleagues join with this code from Wards → +',
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
            if (a.uid == widget.ward.creatorId) return -1;
            if (b.uid == widget.ward.creatorId) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return InsetGroup(
          header: 'Members · ${members.length}',
          dividerIndent: 68,
          children: [
            for (final m in members)
              _MemberRow(member: m, isOwner: m.uid == widget.ward.creatorId),
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
            child: m.avatarEmoji != null && m.avatarEmoji!.isNotEmpty
                ? Text(m.avatarEmoji!, style: const TextStyle(fontSize: 18))
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
