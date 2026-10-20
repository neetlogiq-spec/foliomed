import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ward.dart';
import '../providers/account_provider.dart';
import '../services/ward_service.dart';
import '../utils/app_theme.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';

/// Joining, setting up, sharing, leaving and deleting wards — used by the
/// Wards tab and the ward page. Every action refreshes the signed-in
/// account afterwards so ward lists update everywhere.
class WardActions {
  WardActions._();

  static Future<void> share(BuildContext context, Ward ward) async {
    final from = context.read<AccountProvider>().currentUser?.name;
    await Share.share(
      [
        if (from != null && from.isNotEmpty) '$from invited you to ${ward.name} on FolioMed.'
        else 'You’re invited to ${ward.name} on FolioMed.',
        '',
        'Code: ${ward.id}',
        'In FolioMed: Wards → Join a Ward.',
      ].join('\n'),
      subject: 'FolioMed: ${ward.name}',
    );
  }

  static Future<void> join(BuildContext context) async {
    final code = await _ask(
      context,
      title: 'Join a Ward',
      message: 'Ask a teammate for the ward’s 5-digit code.',
      fields: const [_Field('Code', hint: '5 digits', digits: true)],
      action: 'Join',
    );
    if (code == null || code.first.isEmpty || !context.mounted) return;
    await _run(context, () async {
      final found = await WardService().joinWard(code.first);
      return found ? 'You’re in. Patients and notes are loading.' : null;
    }, notFound: 'There’s no ward with code ${code.first}. Check the digits.');
  }

  static Future<void> create(BuildContext context) async {
    final values = await _ask(
      context,
      title: 'Set Up a Ward',
      message: 'You’ll get a code to invite your team.',
      fields: const [
        _Field('Name', hint: 'PNC, NICU, Ward 4…', words: true),
        _Field('Where (optional)', hint: 'Floor or block'),
      ],
      action: 'Set Up',
    );
    if (values == null || values.first.isEmpty || !context.mounted) return;
    final owner = context.read<AccountProvider>().currentUser?.name ?? '';
    await _run(context, () async {
      final code = await WardService().createWard(name: values[0], location: values[1], ownerName: owner);
      return '${values[0]} is ready. Its code is $code.';
    });
  }

  /// True when the person left.
  static Future<bool> leave(BuildContext context, Ward ward) async {
    final sure = await _confirm(
      context,
      title: 'Leave ${ward.name}?',
      message: 'Its patients and notes disappear from your lists. The ward code brings you back.',
      action: 'Leave',
    );
    if (!sure || !context.mounted) return false;
    return _run(context, () async {
      await WardService().leaveWard(ward.id);
      return 'You’ve left ${ward.name}.';
    });
  }

  /// Owner only. True when the ward was removed.
  static Future<bool> delete(BuildContext context, Ward ward) async {
    final sure = await _confirm(
      context,
      title: 'Delete ${ward.name} for everyone?',
      message: 'All of its patients, notes, replies and reminders go too, and '
          'members lose access straight away. This can’t be undone.',
      action: 'Delete Ward',
    );
    if (!sure || !context.mounted) return false;
    // The database removes everything inside the ward and the code from
    // each member's profile.
    return _run(context, () async {
      await WardService().deleteWard(ward.id);
      return '${ward.name} was deleted.';
    });
  }

  // ── helpers ──────────────────────────────────────────────────────────

  /// Runs [task], refreshes the account, and reports the outcome. [task]
  /// returns the success message, or null for "not found".
  static Future<bool> _run(BuildContext context, Future<String?> Function() task, {String? notFound}) async {
    final account = context.read<AccountProvider>();
    final messenger = ScaffoldMessenger.of(context);
    void say(String text, {bool bad = false}) => messenger.showSnackBar(
        SnackBar(content: Text(text), backgroundColor: bad ? AppColors.danger : null));
    try {
      final done = await task();
      if (done == null) {
        Haptics.error();
        say(notFound ?? 'Not found.', bad: true);
        return false;
      }
      await account.loadCurrentUser();
      Haptics.success();
      say(done);
      return true;
    } catch (e) {
      Haptics.error();
      say(friendlyError(e), bad: true);
      return false;
    }
  }

  static Future<bool> _confirm(BuildContext context,
      {required String title, required String message, required String action}) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// A small form in an alert. Returns the trimmed values, or null.
  static Future<List<String>?> _ask(BuildContext context,
      {required String title, required String message, required List<_Field> fields, required String action}) {
    return showAdaptiveDialog<List<String>>(
      context: context,
      builder: (ctx) => _AskDialog(title: title, message: message, fields: fields, action: action),
    );
  }
}

class _Field {
  const _Field(this.label, {this.hint, this.digits = false, this.words = false});
  final String label;
  final String? hint;
  final bool digits;
  final bool words;
}

class _AskDialog extends StatefulWidget {
  const _AskDialog({required this.title, required this.message, required this.fields, required this.action});
  final String title, message, action;
  final List<_Field> fields;

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  late final _inputs = [for (final _ in widget.fields) TextEditingController()];

  @override
  void dispose() {
    for (final c in _inputs) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() => Navigator.pop(context, [for (final c in _inputs) c.text.trim()]);

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          for (var i = 0; i < widget.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _inputs[i],
                autofocus: i == 0,
                // Codes are 5 digits; some early wards have 8-character ones.
                maxLength: widget.fields[i].digits ? 8 : null,
                keyboardType: widget.fields[i].digits ? TextInputType.number : TextInputType.text,
                textCapitalization:
                    widget.fields[i].words ? TextCapitalization.words : TextCapitalization.sentences,
                textInputAction: i == widget.fields.length - 1 ? TextInputAction.done : TextInputAction.next,
                onSubmitted: i == widget.fields.length - 1 ? (_) => _submit() : null,
                decoration: InputDecoration(
                  labelText: widget.fields[i].label,
                  hintText: widget.fields[i].hint,
                  counterText: '',
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
