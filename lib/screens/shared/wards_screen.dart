import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/app_user.dart';
import '../../models/ward.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/ward_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/support_action.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_sheet.dart';
import '../../utils/layout.dart';
import '../../widgets/app_alert_dialog.dart';

class WardsScreen extends StatelessWidget {
  const WardsScreen({super.key});


  Future<void> _shareWard(BuildContext context, Ward w) async {
    final me = context.read<AuthProvider>().currentUser;
    final byLine = me == null
        ? ''
        : (me.specialty != null && me.specialty!.isNotEmpty
            ? '\nShared by Dr. ${me.name} · ${me.specialty}'
            : '\nShared by ${me.name}');
    final text =
        'Join my ward on FolioMed!$byLine\n\n${w.name}\nWard code: ${w.id}\n\n'
        'Open the FolioMed app → Wards → tap "Join Ward" → enter this 5-digit code.';
    await Share.share(text, subject: 'Join ward ${w.name}');
  }

  Widget _wardActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 14,
        color: disabled ? AppColors.textSecondary.withOpacity(0.5) : color,
      ),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: disabled ? AppColors.textSecondary.withOpacity(0.5) : color,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        side: BorderSide(
          color: disabled
              ? AppColors.divider
              : color,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showMembers(BuildContext context, Ward w) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) => ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: Scaffold(
            backgroundColor: AppColors.card,
            body: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                  child: Row(
                    children: [
                      Text(
                        '${w.name} · Members',
                        style: appText(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  // One-shot fetch: member lists barely change while the
                  // sheet is open, so a live stream isn't worth it.
                  child: FutureBuilder<List<AppUser>>(
                    future: WardService().getWardMembers(w.id),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator.adaptive(),
                        );
                      }
                      final users = snap.data!;
                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            'No other members yet.\nShare this ward ID to invite others.',
                            textAlign: TextAlign.center,
                            style: appText(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: controller,
                        itemCount: users.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final member = users[i];
                          final name =
                              member.name.isEmpty ? 'User' : member.name;
                          final email = member.email;
                          final role = member.role.name;
                          final isOwner = member.uid == w.creatorId;
                          final roleColor = role == 'nurse'
                              ? AppColors.nurseColor
                              : role == 'admin'
                                  ? AppColors.adminColor
                                  : AppColors.doctorColor;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: roleColor.withOpacity(0.15),
                              child: Text(
                                name.isEmpty
                                    ? '?'
                                    : name[0].toUpperCase(),
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(child: Text(name)),
                                if (isOwner) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'OWNER',
                                      style: appText(
                                        color: AppColors.accent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(email),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role[0].toUpperCase() + role.substring(1),
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOnlyCreatorCanDelete(BuildContext context, Ward w) {
    final owner = w.headDoctorName.isNotEmpty
        ? w.headDoctorName
        : 'the ward creator';
    showAdaptiveDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        title: const Text('Only the owner can delete this ward'),
        content: Text(
          'This ward was created by $owner. Only $owner can delete it. Ask them to do it from their account if it really needs to go.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWard(BuildContext context, Ward w) async {
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AppAlertDialog(
        title: Text('Delete ward "${w.name}"?'),
        content: const Text(
          'This will permanently delete the ward and every patient, note and reply inside it — fully erased from our database. Members will lose access immediately. There is no backup and no way to recover this data once you tap Delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      // Patients, notes and comments cascade in Postgres; a trigger strips
      // the code from every member's profile.
      await WardService().deleteWard(w.id);

      // Refresh local user so the ward vanishes from the UI immediately.
      if (context.mounted) {
        await context.read<AuthProvider>().loadCurrentUser();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ward "${w.name}" deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Could not delete the ward — ${friendlyError(e)}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Wards'),
        actions: const [SupportAppBarAction()],
      ),
      body: Builder(builder: (context) {
        final myWardIds =
            context.watch<AuthProvider>().currentUser?.wardIds ?? const [];
        if (myWardIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.corporate_fare,
                  size: 56,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'You are not in any ward yet',
                  style: appText(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use Create New Ward to start one,\nor Join Ward if you have a 5-digit code.',
                  textAlign: TextAlign.center,
                  style: appText(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        return StreamBuilder<List<Ward>>(
        stream: WardService().wardsForUser(myWardIds),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load wards:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final wards = snap.data!;
          if (wards.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.corporate_fare,
                    size: 56,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No wards yet',
                    style: appText(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the + button to create one',
                    style: appText(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: withBottomBarInset(context, const EdgeInsets.all(16)),
            itemCount: wards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _wardCard(
              context,
              wards[i],
              supabase.auth.currentUser?.id ??
                  context.read<AuthProvider>().currentUser?.uid ??
                  '',
            ),
          );
        },
        );
      }),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.appBarBg,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showJoinDialog(context),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Join Ward'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create New Ward'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wardCard(BuildContext context, Ward w, String currentUid) {
    final me = context.watch<AuthProvider>().currentUser;
    final fbUid = supabase.auth.currentUser?.id ?? '';
    final myUid = fbUid.isNotEmpty ? fbUid : (me?.uid ?? currentUid);
    final isCreator =
        w.creatorId.isNotEmpty && myUid.isNotEmpty && w.creatorId == myUid;
    final ownerName = isCreator
        ? (me?.name.isNotEmpty == true ? me!.name : 'You')
        : (w.headDoctorName.isNotEmpty ? w.headDoctorName : 'Unknown');
    final ownerEmail = isCreator
        ? (me?.email ?? w.creatorEmail)
        : w.creatorEmail;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ward name row ──
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F1FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_box_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            w.name,
                            style: appText(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (isCreator) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'OWNED BY YOU',
                              style: appText(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (w.floor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          w.floor,
                          style: appText(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isCreator
                            ? 'Owned by you · $ownerName'
                            : 'Owned by $ownerName',
                        style: appText(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (ownerEmail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          ownerEmail,
                          style: appText(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Ward code row ──
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: w.id));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ward code ${w.id} copied')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      w.id,
                      style: appText(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Action buttons ──
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 1,
                  child: _wardActionButton(
                    label: 'Members',
                    icon: Icons.group_outlined,
                    color: AppColors.primary,
                    onTap: () => _showMembers(context, w),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _wardActionButton(
                    label: 'Share',
                    icon: Icons.share_outlined,
                    color: AppColors.primary,
                    onTap: () => _shareWard(context, w),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _wardActionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: AppColors.danger,
                    onTap: isCreator
                        ? () => _deleteWard(context, w)
                        : () => _showOnlyCreatorCanDelete(context, w),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showAdaptiveDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        title: const Text('Join Ward'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: false),
          maxLength: 8, // 5-digit codes; older wards may have 8-char codes
          decoration: const InputDecoration(
            labelText: 'Ward code',
            hintText: '5-digit code (e.g. 47291)',
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(context);
              try {
                if (supabase.auth.currentUser == null) return;
                final joined = await WardService().joinWard(id);
                if (!joined) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.danger,
                        content: Text('No ward with ID $id'),
                      ),
                    );
                  }
                  return;
                }
                if (!context.mounted) return;
                await context.read<AuthProvider>().loadCurrentUser();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Joined $id')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text(friendlyError(e)),
                    ),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final floorController = TextEditingController();
    final auth = context.read<AuthProvider>();
    showAdaptiveDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        title: const Text('Create New Ward'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ward name',
                hintText: 'e.g. ICU Ward A',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: floorController,
              decoration: const InputDecoration(
                labelText: 'Floor (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                // Claims a random free 5-digit code (Postgres PK rejects
                // collisions; the service retries) and joins the creator.
                final id = await WardService().createWard(
                  name: name,
                  floor: floorController.text.trim(),
                  capacity: 0,
                  headDoctorName: auth.currentUser?.name ?? '',
                );
                await auth.loadCurrentUser();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Ward "$name" created · code $id (share this with your team)',
                      ),
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text(friendlyError(e)),
                    ),
                  );
                }
              }
            },
            child: const Text('Create & Join'),
          ),
        ],
      ),
    );
  }
}
