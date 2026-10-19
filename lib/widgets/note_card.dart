import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_typography.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/note.dart';
import '../utils/app_theme.dart';
import 'pressable.dart';
import 'note_comments_sheet.dart';
import '../providers/theme_provider.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onUnacknowledge;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NoteCard({
    super.key,
    required this.note,
    this.onAcknowledge,
    this.onUnacknowledge,
    this.onTap,
    this.onDelete,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  static const Duration _expandDuration = Duration(milliseconds: 250);

  bool _expanded = false;

  Color _priorityColor(String p) {
    switch (p) {
      case 'Urgent':
        return AppColors.danger;
      case 'Low':
        return AppColors.textSecondary;
      case 'Normal':
      default:
        return AppColors.primary;
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return AppColors.doctorColor;
      case 'nurse':
        return AppColors.nurseColor;
      case 'admin':
        return AppColors.adminColor;
      default:
        return AppColors.primary;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    final n = widget.note;
    final pColor = _priorityColor(n.priority);
    final rColor = _roleColor(n.authorRole);
    final acknowledged = n.isAcknowledged;
    // Acknowledged notes read as "done": secondary colour, not opacity.
    final contentStyle = AppTypography.subheadline(
      color: acknowledged ? AppColors.textSecondary : AppColors.textPrimary,
    ).copyWith(height: 1.4);

    final reduced = AppMotion.reduced(context);

    return Pressable(
      onTap: widget.onTap ?? () => showNoteCommentsSheet(context, widget.note),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Stack(
            children: [
              // Leading-edge priority indicator: triage at a glance without
              // reading (same pattern as iOS Health's grouped rows).
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: Semantics(
                  label: '${n.priority} priority',
                  child: ColoredBox(color: pColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: pColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Rows shrink and truncate instead of overflowing
                        // at large Dynamic Type sizes.
                        Expanded(
                          child: Text(
                            n.priority,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption1(
                              color: pColor,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(n.categoryIcon, size: 14, color: pColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    n.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption2(
                                      color: AppColors.textPrimary,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(n.createdAt, locale: 'en_short'),
                          style: AppTypography.caption2(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (widget.onDelete != null)
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onSelected: (v) {
                              if (v == 'delete') widget.onDelete!();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _AuthorAvatar(
                          initials: _initials(n.authorName),
                          color: rColor,
                          acknowledged: acknowledged,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              text: 'Note by ',
                              style: AppTypography.caption1(
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: n.authorName,
                                  style: AppTypography.footnote(
                                    color: AppColors.textPrimary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            n.authorRole,
                            style: AppTypography.caption2(
                              color: AppColors.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'for ${n.patientName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption1(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Expanding explains that content is being revealed, and avoids
                    // a jarring layout jump.
                    AnimatedCrossFade(
                      duration: reduced ? Duration.zero : _expandDuration,
                      firstCurve: Curves.easeOutCubic,
                      secondCurve: Curves.easeOutCubic,
                      sizeCurve: Curves.easeOutCubic,
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Text(
                        n.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: contentStyle,
                      ),
                      secondChild: Text(n.content, style: contentStyle),
                    ),
                    if (n.content.length > 180)
                      Semantics(
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _expanded ? 'Show less' : 'Show more',
                                style: AppTypography.footnote(
                                  color: AppColors.primary,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (acknowledged) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Acknowledged by ${n.acknowledgedBy ?? 'staff'}',
                                overflow: TextOverflow.ellipsis,
                                style: appText(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (n.acknowledgedAt != null)
                              Text(
                                timeago.format(
                                  n.acknowledgedAt!,
                                  locale: 'en_short',
                                ),
                                style: appText(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (widget.onUnacknowledge != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                                minimumSize: const Size(0, 44),
                              ),
                              icon: const Icon(Icons.undo, size: 14),
                              label: const Text(
                                'Unacknowledge',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: widget.onUnacknowledge,
                            ),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 44),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                            ),
                            label: const Text(
                              'Open thread',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () =>
                                showNoteCommentsSheet(context, widget.note),
                          ),
                        ],
                      ),
                    ] else if (widget.onAcknowledge != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to acknowledge',
                            style: appText(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                minimumSize: const Size(0, 44),
                              ),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 14,
                              ),
                              label: const Text(
                                'Reply',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () =>
                                  showNoteCommentsSheet(context, widget.note),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: widget.onAcknowledge,
                              child: const Text(
                                'Acknowledge ✓',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Author initials in the role colour; acknowledged notes get a checkmark
/// badge — a semantic marker instead of dimming the whole card.
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.initials,
    required this.color,
    required this.acknowledged,
  });

  final String initials;
  final Color color;
  final bool acknowledged;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _radius * 2 + 4,
      height: _radius * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: _radius,
            backgroundColor: color.withOpacity(AppColors.iconChipOpacity),
            child: Text(
              initials,
              style: AppTypography.caption2(
                color: color,
                weight: FontWeight.w600,
              ),
            ),
          ),
          if (acknowledged)
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                label: 'Acknowledged',
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(1),
                  child: const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppColors.stable,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
