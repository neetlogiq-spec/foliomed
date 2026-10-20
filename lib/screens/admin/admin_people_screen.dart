import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/account_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/layout.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

/// Everyone signed up to FolioMed, grouped by role, with search. Admins
/// change someone's role here (the database keeps at least one admin).
class AdminPeopleScreen extends StatefulWidget {
  const AdminPeopleScreen({super.key});

  @override
  State<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends State<AdminPeopleScreen> {
  late Future<List<AppUser>> _people = _fetch();
  String _q = '';

  static Future<List<AppUser>> _fetch() async {
    final rows = await supabase.from(Tables.profiles).select().order('name').limit(1000);
    return [for (final r in rows) AppUser.fromRow(r)];
  }

  Future<void> _changeRole(AppUser p) async {
    final role = await showOptionSheet<UserRole>(
      context,
      title: p.name.isEmpty ? p.email : p.name,
      selected: p.role,
      options: {for (final r in UserRole.values) r: _roleTitle(r)},
    );
    if (role == null || role == p.role || !mounted) return;
    if (role == UserRole.admin) {
      final ok = await showAdaptiveDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text('Make ${p.name} an admin?'),
          content: const Text('Admins can see figures for all of FolioMed and change anyone’s role.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Make Admin')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AccountService().setUserRole(p.uid, role.name);
      Haptics.success();
      setState(() => _people = _fetch());
      messenger.showSnackBar(SnackBar(content: Text('${p.name} is now ${_roleTitle(role).toLowerCase()}')));
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  static String _roleTitle(UserRole r) => switch (r) {
        UserRole.admin => 'Admin',
        UserRole.doctor => 'Doctor',
        UserRole.nurse => 'Nurse',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          setState(() => _people = _fetch());
          await _people.catchError((_) => <AppUser>[]);
        },
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const LargeTitleAppBar(title: 'People'),
            SliverPadding(
              padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 24)),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<List<AppUser>>(
                  future: _people,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return InsetGroup(children: [
                        SettingsRow(title: "Couldn't load people", subtitle: friendlyError(snap.error!)),
                      ]);
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator.adaptive()),
                      );
                    }
                    final q = _q.toLowerCase();
                    final shown = [
                      for (final p in snap.data!)
                        if (q.isEmpty || p.name.toLowerCase().contains(q) || p.email.toLowerCase().contains(q)) p,
                    ];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CupertinoSearchTextField(
                          placeholder: 'Name or email',
                          onChanged: (v) => setState(() => _q = v.trim()),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                          child: Text('${snap.data!.length} people · tap someone to change their role',
                              style: AppTypography.footnote(color: AppColors.textSecondary)),
                        ),
                        for (final role in [UserRole.admin, UserRole.doctor, UserRole.nurse])
                          if (shown.any((p) => p.role == role)) ...[
                            InsetGroup(
                              header: '${_roleTitle(role)}s',
                              dividerIndent: 16,
                              children: [
                                for (final p in shown.where((p) => p.role == role))
                                  SettingsRow(
                                    title: p.name.isEmpty ? '(no name)' : p.name,
                                    subtitle: [p.email, if (!p.roleConfirmed) 'hasn’t picked a role yet'].join(' · '),
                                    onTap: () => _changeRole(p),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        if (shown.isEmpty)
                          Text('Nobody matches “$_q”.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(color: AppColors.textSecondary)),
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
}
