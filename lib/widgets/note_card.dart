import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/note.dart';
import '../utils/app_theme.dart';
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

    return Opacity(
      opacity: acknowledged ? 0.85 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap ??
            () => showNoteCommentsSheet(context, widget.note),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppColors.cardShadow,
          ),
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
                  Text(
                    n.priority,
                    style: GoogleFonts.dmSans(
                      color: pColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
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
                        Text(
                          n.category,
                          style: GoogleFonts.dmSans(
                            color: pColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(n.createdAt, locale: 'en_short'),
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 11,
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
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: rColor.withOpacity(0.15),
                    child: Text(
                      _initials(n.authorName),
                      style: TextStyle(
                        color: rColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Note by ',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    n.authorName,
                    style: GoogleFonts.dmSans(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: rColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      n.authorRole,
                      style: GoogleFonts.dmSans(
                        color: rColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
                  Text(
                    'for ${n.patientName}',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                n.content,
                maxLines: _expanded ? null : 4,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (!_expanded && n.content.length > 180)
                GestureDetector(
                  onTap: () => setState(() => _expanded = true),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Show more',
                      style: GoogleFonts.dmSans(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (acknowledged) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          style: GoogleFonts.dmSans(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (n.acknowledgedAt != null)
                        Text(
                          timeago.format(n.acknowledgedAt!,
                              locale: 'en_short'),
                          style: GoogleFonts.dmSans(
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
                          minimumSize: const Size(0, 30),
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
                        minimumSize: const Size(0, 30),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
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
                    Icon(Icons.info_outline,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to acknowledge',
                      style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary, fontSize: 11),
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
                          side: const BorderSide(color: AppColors.primary),
                          padding:
                              const EdgeInsets.symmetric(vertical: 0),
                          minimumSize: const Size(0, 34),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 14),
                        label: const Text('Reply',
                            style: TextStyle(fontSize: 12)),
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 0),
                          minimumSize: const Size(0, 34),
                        ),
                        onPressed: widget.onAcknowledge,
                        child: const Text('Acknowledge ✓',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
