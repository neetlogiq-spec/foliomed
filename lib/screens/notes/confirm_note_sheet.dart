import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/note.dart';
import '../../models/note_reply.dart';
import '../../providers/account_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/notes_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_sheet.dart';

/// Confirm a note, optionally saying what was done (posted to the thread
/// as a confirmation reply so the author can see it).
Future<void> showConfirmNote(BuildContext context, Note note) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConfirmNoteSheet(note: note),
    );

class _ConfirmNoteSheet extends StatefulWidget {
  const _ConfirmNoteSheet({required this.note});
  final Note note;

  @override
  State<_ConfirmNoteSheet> createState() => _ConfirmNoteSheetState();
}

class _ConfirmNoteSheetState extends State<_ConfirmNoteSheet> {
  final _done = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _done.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final me = context.read<AccountProvider>().currentUser;
    final feed = context.read<WardFeed>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _done.text.trim();
    try {
      if (text.isNotEmpty && me != null) {
        await NotesRepository().reply(
          widget.note.id,
          NoteReply(
            id: const Uuid().v4(),
            text: text,
            authorId: me.uid,
            authorName: me.name,
            authorRole: me.roleLabel,
            createdAt: DateTime.now(),
            isConfirmation: true,
          ),
        );
      }
      final ok = await feed.confirm(widget.note.id, me?.name ?? 'Team');
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? 'Confirmed' : "Couldn't confirm — ${friendlyError(feed.lastError ?? 'error')}"),
      ));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text('Confirm Note',
                        textAlign: TextAlign.center,
                        style: AppTypography.headline(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.patientName, style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(n.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subheadline(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CupertinoTextField(
                controller: _done,
                placeholder: 'What was done? (optional)',
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                padding: const EdgeInsets.all(12),
                style: AppTypography.body(color: AppColors.textPrimary),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _confirm,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text('Confirm', style: AppTypography.headline(color: AppColors.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
