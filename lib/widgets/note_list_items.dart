import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/app_user.dart';
import '../models/note.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../screens/nurse/acknowledge_sheet.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'app_alert_dialog.dart';
import 'note_card.dart';

/// A full [NoteCard] wired with the right actions for the signed-in role:
/// doctors acknowledge in one tap and can delete; nurses acknowledge
/// through the sheet (which records what was done).
class WiredNoteCard extends StatelessWidget {
  const WiredNoteCard({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    final isNurse = user?.role == UserRole.nurse;
    final notes = context.read<NoteProvider>();
    return NoteCard(
      note: note,
      onAcknowledge: note.isAcknowledged
          ? null
          : () => isNurse
              ? showAcknowledgeSheet(context, note)
              : notes.acknowledgeNote(note.id, user?.name ?? 'Staff'),
      onUnacknowledge: () => notes.unacknowledgeNote(note.id),
      onDelete: isNurse ? null : () => confirmDeleteNote(context, note.id),
    );
  }
}

Future<void> confirmDeleteNote(BuildContext context, String noteId) async {
  final confirm = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: const Text('Delete note?'),
      content: const Text(
        'This permanently deletes the note and every reply on it. '
        'It cannot be recovered.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirm == true && context.mounted) {
    await context.read<NoteProvider>().deleteNote(noteId);
  }
}

/// One-line summary of a note that expands in place into the full card.
/// Used when the home feed is collapsed.
class CollapsibleNote extends StatefulWidget {
  const CollapsibleNote({super.key, required this.note});

  final Note note;

  @override
  State<CollapsibleNote> createState() => _CollapsibleNoteState();
}

class _CollapsibleNoteState extends State<CollapsibleNote> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return AnimatedSize(
      duration: AppMotion.reduced(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _open
          ? Column(
              children: [
                WiredNoteCard(note: n),
                TextButton.icon(
                  onPressed: () => setState(() => _open = false),
                  icon: const Icon(Icons.expand_less, size: 18),
                  label: const Text('Collapse'),
                ),
              ],
            )
          : _summary(n),
    );
  }

  Widget _summary(Note n) {
    final firstLine = n.content.split('\n').first.trim();
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => setState(() => _open = true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: n.priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.patientName.isEmpty ? n.category : n.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheadline(
                          color: AppColors.textPrimary,
                          weight: FontWeight.w600),
                    ),
                    Text(
                      firstLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeago.format(n.createdAt, locale: 'en_short'),
                    style: AppTypography.caption1(
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    n.isAcknowledged
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    semanticLabel:
                        n.isAcknowledged ? 'Acknowledged' : 'Not acknowledged',
                    color: n.isAcknowledged
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ],
              ),
              Icon(Icons.expand_more, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
