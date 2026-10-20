import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ward.dart';
import '../../providers/account_provider.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/job_board.dart';
import '../../providers/patient_roster.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/supabase_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/ward_actions.dart';
import 'ward_page.dart';

/// Your wards as cards (like rooms in Apple Home): live counts, units and
/// the join code at a glance. Set up or join a ward from the buttons below.
class WardsTab extends StatefulWidget {
  const WardsTab({super.key});

  @override
  State<WardsTab> createState() => _WardsTabState();
}

class _WardsTabState extends State<WardsTab> {
  final _wardStreams = StreamCache<List<Ward>>();

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    final ids = context.watch<AccountProvider>().currentUser?.wards ?? const <String>[];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(
            title: 'Wards',
            eyebrow: ids.isEmpty ? null : '${ids.length} ward${ids.length == 1 ? '' : 's'}',
          ),
          if (ids.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _noWards())
          else
            StreamBuilder<List<Ward>>(
              stream: _wardStreams.get(ids.join(','), () => WardService().wardsForUser(ids)),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyPlaceholder(
                      icon: Icons.cloud_off_outlined,
                      title: "Couldn't load wards",
                      subtitle: 'Check your connection and try again.',
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }
                final wards = [...snap.data!]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                if (wards.isEmpty) return SliverFillRemaining(hasScrollBody: false, child: _noWards());
                return SliverPadding(
                  padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 24)),
                  sliver: SliverList.list(children: [
                    for (final w in wards) ...[_WardCard(ward: w), const SizedBox(height: 14)],
                    const SizedBox(height: 8),
                    const _AddButtons(),
                  ]),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _noWards() => const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyPlaceholder(
              icon: Icons.corporate_fare_outlined,
              title: 'No wards yet',
              subtitle: 'Set up a ward for your team, or join one with the 5-digit code a colleague shares.',
            ),
            SizedBox(height: 8),
            _AddButtons(),
          ],
        ),
      );
}

class _AddButtons extends StatelessWidget {
  const _AddButtons();

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => WardActions.create(context),
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: const Text('Set Up a Ward'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => WardActions.join(context),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Join a Ward'),
          ),
        ),
      ]);
}

/// One ward: who owns it, live counts, units and its code.
class _WardCard extends StatelessWidget {
  const _WardCard({required this.ward});
  final Ward ward;

  @override
  Widget build(BuildContext context) {
    final w = ward;
    final mine = w.ownedBy(supabase.auth.currentUser?.id ?? '');
    final admitted = context.watch<PatientRoster>().patients.where((p) => p.wardId == w.id).toList();
    final toConfirm = context.watch<WardFeed>().feed.where((n) => n.wardId == w.id && !n.isConfirmed).length;
    final jobs = context.watch<JobBoard>().open().where((j) => j.wardId == w.id).length;
    final units = context.watch<UnitProvider>().unitsOf(w.id);
    final tint = mine ? AppColors.primary : AppColors.accent;

    return Semantics(
      button: true,
      label: '${w.name}. ${admitted.length} admitted, $toConfirm notes to confirm, $jobs open jobs. Code ${w.id}.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WardPage(ward: w))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(Icons.corporate_fare, size: 20, color: tint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.name, style: AppTypography.headline(color: AppColors.textPrimary)),
                      Text(
                        [
                          if (w.location.isNotEmpty) w.location,
                          mine ? 'You own this ward' : (w.ownerName.isEmpty ? 'Joined' : 'Owner: ${w.ownerName}'),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote(color: AppColors.textSecondary),
                      ),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.tertiaryLabel),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _Count(value: admitted.length, label: 'Admitted'),
                  _Count(value: toConfirm, label: 'To Confirm', highlight: toConfirm > 0),
                  _Count(value: jobs, label: 'Open Jobs'),
                ]),
                if (units.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final u in units)
                      _Pill('${u.name} ${admitted.where((p) => p.unitId == u.id).length}'),
                  ]),
                ],
                const Divider(height: 22),
                Row(children: [
                  Text('Code ', style: AppTypography.footnote(color: AppColors.textSecondary)),
                  Text(w.id,
                      style: appMonoText(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)
                          .copyWith(fontFeatures: AppTypography.tabular, letterSpacing: 1.5)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Haptics.selection();
                      WardActions.share(context, w);
                    },
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Text('Invite'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.highlight = false});
  final int value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value',
              style: AppTypography.title2(color: highlight ? AppColors.warning : AppColors.textPrimary)
                  .copyWith(fontFeatures: AppTypography.tabular)),
          Text(label, style: AppTypography.caption1(color: AppColors.textSecondary)),
        ]),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600)),
      );
}
