import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ward.dart';
import '../providers/auth_provider.dart';
import '../services/ward_service.dart';
import '../utils/app_theme.dart';
import '../utils/friendly_error.dart';
import 'app_alert_dialog.dart';

/// Ward operations shared by the Wards list and the ward page.
class WardActions {
  WardActions._();

  static void _snack(BuildContext context, String text, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error ? AppColors.danger : null,
      content: Text(text),
    ));
  }

  static Future<void> share(BuildContext context, Ward w) async {
    final me = context.read<AuthProvider>().currentUser;
    final byLine = me == null ? '' : '\nShared by ${me.name}';
    final text = 'Join my ward on FolioMed!$byLine\n\n${w.name}\n'
        'Ward code: ${w.id}\n\n'
        'Open FolioMed → Wards → + → Join with code, and enter the code.';
    await Share.share(text, subject: 'Join ward ${w.name}');
  }

  static Future<void> join(BuildContext context) async {
    final code = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AppAlertDialog(
          title: const Text('Join a ward'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 8, // 5-digit codes; older wards may have 8-char codes
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Ward code',
              hintText: 'e.g. 47291',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final joined = await WardService().joinWard(code);
      if (!joined) {
        if (context.mounted) _snack(context, 'No ward with code $code', error: true);
        return;
      }
      await auth.loadCurrentUser();
      if (context.mounted) _snack(context, 'Joined ward $code');
    } catch (e) {
      if (context.mounted) _snack(context, friendlyError(e), error: true);
    }
  }

  static Future<void> create(BuildContext context) async {
    final result = await showAdaptiveDialog<(String, String)>(
      context: context,
      builder: (ctx) {
        final name = TextEditingController();
        final floor = TextEditingController();
        return AppAlertDialog(
          title: const Text('New ward'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ward name',
                  hintText: 'e.g. PNC Ward, NICU',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: floor,
                decoration:
                    const InputDecoration(labelText: 'Floor / unit (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, (name.text.trim(), floor.text.trim())),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (result == null || result.$1.isEmpty || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      // Claims a random free 5-digit code and joins the creator.
      final id = await WardService().createWard(
        name: result.$1,
        floor: result.$2,
        capacity: 0,
        headDoctorName: auth.currentUser?.name ?? '',
      );
      await auth.loadCurrentUser();
      if (context.mounted) {
        _snack(context, 'Ward “${result.$1}” created · code $id — share it with your team');
      }
    } catch (e) {
      if (context.mounted) _snack(context, friendlyError(e), error: true);
    }
  }

  /// Returns true when the user left.
  static Future<bool> leave(BuildContext context, Ward w) async {
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text('Leave ${w.name}?'),
        content: const Text(
            "You'll stop seeing its patients and notes. You can rejoin with the ward code."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return false;
    final auth = context.read<AuthProvider>();
    try {
      await WardService().leaveWard(w.id);
      await auth.loadCurrentUser();
      if (context.mounted) _snack(context, 'You left ${w.name}');
      return true;
    } catch (e) {
      if (context.mounted) _snack(context, friendlyError(e), error: true);
      return false;
    }
  }

  /// Owner only. Returns true when deleted.
  static Future<bool> delete(BuildContext context, Ward w) async {
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text('Delete ${w.name}?'),
        content: const Text(
          'This permanently deletes the ward and every patient, note, reply '
          'and reminder in it. Members lose access immediately. It cannot be '
          'recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return false;
    final auth = context.read<AuthProvider>();
    try {
      // Patients, notes and comments cascade in Postgres; a trigger strips
      // the code from every member's profile.
      await WardService().deleteWard(w.id);
      await auth.loadCurrentUser();
      if (context.mounted) _snack(context, 'Ward “${w.name}” deleted');
      return true;
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Could not delete the ward — ${friendlyError(e)}',
            error: true);
      }
      return false;
    }
  }
}
