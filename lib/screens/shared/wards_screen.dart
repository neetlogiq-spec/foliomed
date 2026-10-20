import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ward.dart';
import '../../providers/account_provider.dart';
import '../../providers/patient_roster.dart';
import '../../providers/appearance_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/layout.dart';
import '../../utils/stream_cache.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/ward_actions.dart';
import 'ward_page.dart';

/// The user's wards as a grouped list; + creates or joins one.
class WardsScreen extends StatefulWidget {
  const WardsScreen({super.key});

  @override
  State<WardsScreen> createState() => _WardsScreenState();
}

class _WardsScreenState extends State<WardsScreen> {
  final _wardStreams = StreamCache<List<Ward>>();

  Future<void> _showAddMenu() async {
    final choice = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: InsetGroup(
            children: [
              SettingsRow(
                icon: Icons.add_business_outlined,
                title: 'Create a ward',
                subtitle: 'Get a 5-digit code to share with your team',
                onTap: () => Navigator.pop(ctx, 'create'),
              ),
              SettingsRow(
                icon: Icons.login,
                iconColor: AppColors.accent,
                title: 'Join with a code',
                subtitle: 'Ask a colleague for their ward code',
                onTap: () => Navigator.pop(ctx, 'join'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'create') {
      await WardActions.create(context);
    } else if (choice == 'join') {
      await WardActions.join(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    final ids =
        context.watch<AccountProvider>().currentUser?.wardIds ?? const <String>[];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(
            title: 'Wards',
            actions: [
              ChromeIconButton(
                icon: Icons.add,
                tooltip: 'Create or join a ward',
                onPressed: _showAddMenu,
              ),
            ],
          ),
          if (ids.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _noWards())
          else
            StreamBuilder<List<Ward>>(
              stream: _wardStreams.get(
                  ids.join(','), () => WardService().wardsForUser(ids)),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
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
                final wards = snap.data!;
                if (wards.isEmpty) {
                  return SliverFillRemaining(
                      hasScrollBody: false, child: _noWards());
                }
                return SliverPadding(
                  padding: withBottomBarInset(
                      context, const EdgeInsets.fromLTRB(16, 8, 16, 24)),
                  sliver: SliverToBoxAdapter(child: _wardList(wards)),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _wardList(List<Ward> wards) {
    final myId = supabase.auth.currentUser?.id ?? '';
    final patients = context.watch<PatientRoster>().patients;
    final owned = wards.where((w) => w.creatorId == myId).toList();
    final joined = wards.where((w) => w.creatorId != myId).toList();

    Widget row(Ward w) {
      final count = patients.where((p) => p.wardId == w.id).length;
      return SettingsRow(
        icon: Icons.corporate_fare,
        iconColor: w.creatorId == myId ? AppColors.primary : AppColors.accent,
        title: w.name,
        subtitle: [
          if (w.floor.isNotEmpty) w.floor,
          '$count patient${count == 1 ? '' : 's'}',
          if (w.creatorId != myId && w.headDoctorName.isNotEmpty)
            'by ${w.headDoctorName}',
        ].join(' · '),
        trailing: Text(
          w.id,
          style: appMonoText(color: AppColors.textSecondary, fontSize: 15)
              .copyWith(fontFeatures: AppTypography.tabular),
        ),
        showChevron: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WardPage(ward: w),
        )),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (owned.isNotEmpty)
          InsetGroup(
            header: 'Wards you own',
            children: [for (final w in owned) row(w)],
          ),
        if (owned.isNotEmpty && joined.isNotEmpty) const SizedBox(height: 24),
        if (joined.isNotEmpty)
          InsetGroup(
            header: 'Wards you joined',
            children: [for (final w in joined) row(w)],
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tap a ward for its code, members and settings.',
            style: AppTypography.footnote(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _noWards() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyState(
            icon: Icons.corporate_fare_outlined,
            title: 'No wards yet',
            subtitle:
                'Create a ward for your team, or join one with the 5-digit code a colleague shares.',
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => WardActions.create(context),
            icon: const Icon(Icons.add),
            label: const Text('Create a ward'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => WardActions.join(context),
            icon: const Icon(Icons.login),
            label: const Text('Join with a code'),
          ),
        ],
      ),
    );
  }
}
