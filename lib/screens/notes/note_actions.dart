import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/app_user.dart';
import '../../models/note.dart';
import '../../providers/account_provider.dart';
import '../../providers/ward_feed.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/note_tile.dart';
import 'confirm_note_sheet.dart';
import 'note_thread_sheet.dart';

/// Asks before deleting — a note and its replies can't be brought back.
Future<void> askDeleteNote(BuildContext context, Note note) async {
  final feed = context.read<WardFeed>();
  final yes = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: const Text('Delete this note?'),
      content: const Text('The note and its replies will be removed for the whole ward. This can’t be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (yes == true) await feed.remove(note.id);
}

/// A [NoteTile] with the signed-in user's actions: nurses confirm through
/// the confirm sheet (to record what was done); doctors confirm in one tap
/// and may delete.
class FeedNote extends StatelessWidget {
  const FeedNote({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final me = context.read<AccountProvider>().currentUser;
    final feed = context.read<WardFeed>();
    final nurse = me?.role == UserRole.nurse;
    final mayDelete = !nurse || (me != null && me.uid == note.authorId);
    return NoteTile(
      note: note,
      onOpen: () => showNoteThread(context, note),
      onConfirm: note.isConfirmed
          ? null
          : () => nurse ? showConfirmNote(context, note) : feed.confirm(note.id, me?.name ?? 'Team'),
      onUndoConfirm: () => feed.undoConfirm(note.id),
      onDelete: mayDelete ? () => askDeleteNote(context, note) : null,
    );
  }
}

/// One line per note for the compact feed; tapping opens it in place.
class NoteLine extends StatefulWidget {
  const NoteLine({super.key, required this.note});

  final Note note;

  @override
  State<NoteLine> createState() => _NoteLineState();
}

class _NoteLineState extends State<NoteLine> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return AnimatedSize(
      duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _open
          ? Column(
              children: [
                FeedNote(note: n),
                TextButton(
                  onPressed: () => setState(() => _open = false),
                  child: const Text('Show less'),
                ),
              ],
            )
          : Material(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.card),
                onTap: () => setState(() => _open = true),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                  child: Row(
                    children: [
                      Icon(
                        n.isConfirmed ? Icons.check_circle : Icons.circle,
                        size: n.isConfirmed ? 16 : 9,
                        color: n.isConfirmed
                            ? AppColors.accent
                            : (n.isUrgent ? AppColors.danger : AppColors.warning),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '${n.patientName.isEmpty ? n.category : n.patientName}  ',
                              style: AppTypography.subheadline(
                                  color: AppColors.textPrimary, weight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: n.content.replaceAll('\n', ' '),
                              style: AppTypography.subheadline(color: AppColors.textSecondary),
                            ),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(timeago.format(n.createdAt, locale: 'en_short'),
                          style: AppTypography.footnote(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
