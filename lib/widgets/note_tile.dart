import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/note.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/app_utils.dart';
import 'inset_group.dart';
import 'pressable.dart';

/// A note in a list. Tap opens the thread; long-press offers undo /
/// delete. The footer says plainly whether anyone has confirmed it.
class NoteTile extends StatefulWidget {
  const NoteTile({
    super.key,
    required this.note,
    this.onOpen,
    this.onConfirm,
    this.onUndoConfirm,
    this.onDelete,
  });

  final Note note;
  final VoidCallback? onOpen;

  /// Null hides the Confirm button (e.g. already confirmed, or read-only).
  final VoidCallback? onConfirm;
  final VoidCallback? onUndoConfirm;
  final VoidCallback? onDelete;

  @override
  State<NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<NoteTile> {
  static const _collapsedLines = 4;
  bool _showAll = false;

  Future<void> _menu() async {
    final n = widget.note;
    final choice = await showOptionSheet<String>(
      context,
      title: n.patientName.isEmpty ? 'Note' : n.patientName,
      options: {
        if (n.isConfirmed && widget.onUndoConfirm != null) 'undo': 'Mark as not confirmed',
        if (widget.onDelete != null) 'delete': 'Delete note',
      },
    );
    if (choice == 'undo') widget.onUndoConfirm?.call();
    if (choice == 'delete') widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final faded = n.isConfirmed;
    final body = AppTypography.subheadline(
      color: faded ? AppColors.textSecondary : AppColors.textPrimary,
    ).copyWith(height: 1.35);
    final hasMenu = widget.onDelete != null || (n.isConfirmed && widget.onUndoConfirm != null);
    return Semantics(
      container: true,
      label: '${n.isUrgent ? 'Urgent. ' : ''}${n.patientName}. ${n.content}. '
          '${n.isConfirmed ? 'Confirmed by ${n.acknowledgedBy ?? 'a team member'}' : 'Waiting for confirmation'}',
      child: Pressable(
        onTap: widget.onOpen,
        onLongPress: hasMenu ? _menu : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: n.isUrgent && !n.isConfirmed
                ? Border(left: BorderSide(color: AppColors.danger, width: 3))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      n.patientName.isEmpty ? 'Ward note' : n.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline(color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(timeago.format(n.createdAt, locale: 'en_short'),
                      style: AppTypography.footnote(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(n.categoryIcon, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [n.category, if (n.authorName.isNotEmpty) '${n.authorName}${n.authorRole.isEmpty ? '' : ' (${n.authorRole})'}']
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote(color: AppColors.textSecondary),
                    ),
                  ),
                  if (n.isUrgent) _UrgentLabel(muted: n.isConfirmed),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, box) {
                final tp = TextPainter(
                  text: TextSpan(text: n.content, style: body),
                  maxLines: _collapsedLines,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: box.maxWidth);
                final long = tp.didExceedMaxLines;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 200),
                      alignment: Alignment.topLeft,
                      child: Text(
                        n.content,
                        maxLines: _showAll ? null : _collapsedLines,
                        overflow: _showAll ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: body,
                      ),
                    ),
                    if (long)
                      GestureDetector(
                        onTap: () => setState(() => _showAll = !_showAll),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(_showAll ? 'Less' : 'More',
                              style: AppTypography.subheadline(
                                  color: AppColors.primary, weight: FontWeight.w600)),
                        ),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _Status(note: n)),
                  if (widget.onOpen != null)
                    IconButton(
                      tooltip: 'Replies',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.textSecondary),
                      onPressed: widget.onOpen,
                    ),
                  if (!n.isConfirmed && widget.onConfirm != null)
                    FilledButton.tonal(
                      onPressed: widget.onConfirm,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Confirm'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentLabel extends StatelessWidget {
  const _UrgentLabel({required this.muted});
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = muted ? AppColors.textSecondary : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Urgent', style: AppTypography.caption1(color: c, weight: FontWeight.w700)),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final n = note;
    if (n.isConfirmed) {
      final when = n.acknowledgedAt == null ? '' : ' · ${formatTime(n.acknowledgedAt!.toLocal())}';
      return Row(children: [
        Icon(Icons.check_circle, size: 16, color: AppColors.accent),
        const SizedBox(width: 5),
        Flexible(
          child: Text('Confirmed by ${n.acknowledgedBy ?? 'team'}$when',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.footnote(color: AppColors.textSecondary)),
        ),
      ]);
    }
    return Row(children: [
      Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('Waiting for confirmation', style: AppTypography.footnote(color: AppColors.textSecondary)),
    ]);
  }
}
