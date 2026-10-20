import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/row_parsing.dart';
import '../../models/ward.dart';
import '../../providers/appearance_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/layout.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/ward_actions.dart';
import 'admin_ward_screen.dart';

/// Figures from `dashboard_counts()` (admin-only RPC).
class _Figures {
  const _Figures(this.raw);
  final Map<String, dynamic> raw;

  int of(String key) => (raw[key] as num?)?.toInt() ?? 0;

  /// Share of all notes that have been confirmed, or null with no notes.
  int? get confirmedPercent {
    final total = of('notes');
    return total == 0 ? null : (of('acked_notes') * 100 / total).round();
  }
}

/// The admin's home: today's activity, totals across FolioMed, latest
/// notes, and every ward.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<(_Figures, List<Map<String, dynamic>>)> _load = _fetch();
  final Stream<List<Ward>> _wards = WardService().getAllWards();

  Future<(_Figures, List<Map<String, dynamic>>)> _fetch() async {
    final now = DateTime.now();
    final results = await Future.wait<dynamic>([
      supabase.rpc('dashboard_counts', params: {
        'p_since': toTimestamp(DateTime(now.year, now.month, now.day)),
      }),
      supabase
          .from(Tables.notes)
          .select('author_name, patient_name, created_at, priority')
          .order('created_at', ascending: false)
          .limit(6),
    ]);
    return (
      _Figures(Map<String, dynamic>.from(results[0] as Map)),
      List<Map<String, dynamic>>.from(results[1] as List),
    );
  }

  Future<void> _refresh() async {
    setState(() => _load = _fetch());
    await _load.catchError((_) => (const _Figures({}), <Map<String, dynamic>>[]));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppearanceProvider>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LargeTitleAppBar(
              eyebrow: DateFormat('EEEE d MMMM').format(DateTime.now()),
              title: 'Overview',
              actions: [
                ChromeIconButton(
                  icon: Icons.add_business_outlined,
                  tooltip: 'New ward',
                  onPressed: () => WardActions.create(context),
                ),
              ],
            ),
            SliverPadding(
              padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 24)),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<(_Figures, List<Map<String, dynamic>>)>(
                  future: _load,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return InsetGroup(children: [
                        SettingsRow(
                          icon: Icons.cloud_off_outlined,
                          iconColor: AppColors.danger,
                          title: "Couldn't load figures",
                          subtitle: 'Pull down to try again.',
                        ),
                      ]);
                    }
                    final f = snap.data?.$1;
                    final latest = snap.data?.$2 ?? const [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _todayTiles(f),
                        const SizedBox(height: 24),
                        _totals(f),
                        const SizedBox(height: 24),
                        if (latest.isNotEmpty) ...[
                          _latest(latest),
                          const SizedBox(height: 24),
                        ],
                        _wardList(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todayTiles(_Figures? f) {
    Widget tile(String label, String value, IconData icon, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Semantics(
              label: '$label: $value',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 8),
                  Text(value,
                      style: AppTypography.title2(color: AppColors.textPrimary)
                          .copyWith(fontFeatures: AppTypography.tabular)),
                  Text(label, style: AppTypography.footnote(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
    final pct = f?.confirmedPercent;
    return Row(
      children: [
        tile('Notes today', f == null ? '–' : '${f.of('notes_today')}', Icons.edit_note, AppColors.primary),
        const SizedBox(width: 10),
        tile('Urgent', f == null ? '–' : '${f.of('urgent_notes')}', Icons.priority_high, AppColors.danger),
        const SizedBox(width: 10),
        tile('Confirmed', pct == null ? '–' : '$pct%', Icons.verified_outlined, AppColors.accent),
      ],
    );
  }

  Widget _totals(_Figures? f) {
    String v(String k) => f == null ? '–' : NumberFormat.decimalPattern().format(f.of(k));
    return InsetGroup(
      header: 'Across FolioMed',
      children: [
        SettingsRow(icon: Icons.people_alt_outlined, title: 'People', value: v('staff')),
        SettingsRow(icon: Icons.corporate_fare, iconColor: AppColors.secondary, title: 'Wards', value: v('wards')),
        SettingsRow(
          icon: Icons.bed_outlined,
          iconColor: AppColors.doctorColor,
          title: 'Patients admitted',
          subtitle: f == null ? null : '${v('patients')} ever recorded',
          value: v('active_patients'),
        ),
        SettingsRow(icon: Icons.notes, iconColor: AppColors.warning, title: 'Notes', value: v('notes')),
        SettingsRow(icon: Icons.forum_outlined, iconColor: AppColors.accent, title: 'Replies', value: v('comments')),
      ],
    );
  }

  Widget _latest(List<Map<String, dynamic>> rows) {
    return InsetGroup(
      header: 'Latest notes',
      dividerIndent: 16,
      children: [
        for (final r in rows)
          SettingsRow(
            title: '${r['author_name'] ?? 'Someone'} → ${r['patient_name'] ?? 'a patient'}',
            subtitle: r['priority'] == 'Urgent' ? 'Urgent' : null,
            value: timeago.format(parseTimestamp(r['created_at']), locale: 'en_short'),
          ),
      ],
    );
  }

  Widget _wardList() {
    return StreamBuilder<List<Ward>>(
      stream: _wards,
      builder: (context, snap) {
        final wards = [...?snap.data]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return InsetGroup(
          header: 'Wards${snap.hasData ? ' · ${wards.length}' : ''}',
          footer: snap.hasData && wards.isEmpty ? 'No wards yet — tap the + button to create one.' : null,
          children: [
            if (!snap.hasData)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            for (final w in wards)
              SettingsRow(
                icon: Icons.corporate_fare,
                title: w.name,
                subtitle: [if (w.floor.isNotEmpty) w.floor, 'Code ${w.id}'].join(' · '),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AdminWardScreen(wardId: w.id),
                )),
              ),
          ],
        );
      },
    );
  }
}
