import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/note.dart';
import '../models/note_comment.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../services/note_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/friendly_error.dart';
import '../providers/theme_provider.dart';

Future<void> showNoteCommentsSheet(BuildContext context, Note note) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NoteCommentsSheet(note: note),
  );
}

class NoteCommentsSheet extends StatefulWidget {
  final Note note;

  const NoteCommentsSheet({super.key, required this.note});

  @override
  State<NoteCommentsSheet> createState() => _NoteCommentsSheetState();
}

class _NoteCommentsSheetState extends State<NoteCommentsSheet> {
  final _textController = TextEditingController();
  final _noteService = NoteService();
  bool _sending = false;

  // Live mirror of the note's ack state, fed by the doc-stream below.
  // The widget.note we got passed in is captured at sheet-open time —
  // if we relied on it, the Ack button would still show after a
  // successful ack and tapping it again would silently re-fire.
  late bool _isAcked = widget.note.isAcknowledged;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Lightweight stream of just the ack state of the note doc — used to
  /// keep the Ack-button visible / hidden in sync with reality.
  Stream<bool> get _ackStream => FirebaseFirestore.instance
      .collection(AppConstants.notesCollection)
      .doc(widget.note.id)
      .snapshots()
      .map((s) => (s.data()?['isAcknowledged'] as bool?) ?? false);

  void _toast(String msg, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: danger ? AppColors.danger : null,
        duration: Duration(seconds: danger ? 5 : 2),
        content: Text(msg),
      ),
    );
  }

  Future<void> _send({bool acknowledge = false}) async {
    // Dismiss the soft keyboard before the async work — without this,
    // the keyboard's IME layer occasionally swallows the tap that
    // triggered _send and the user has to tap twice.
    FocusScope.of(context).unfocus();

    final text = _textController.text.trim();
    final user = context.read<AuthProvider>().currentUser;

    // Visible failure paths — these used to silently `return` and made
    // it look like the buttons did nothing.
    if (user == null) {
      _toast("You're signed out. Sign in again to reply.", danger: true);
      return;
    }
    if (!acknowledge && text.isEmpty) {
      _toast("Type something before tapping Send.");
      return;
    }

    setState(() => _sending = true);
    try {
      // Drop a comment in the thread either way — when acknowledging
      // the comment is flagged so the bubble shows the green ack stripe.
      if (acknowledge) {
        await _noteService.addComment(
          widget.note.id,
          NoteComment(
            id: '',
            text: text.isEmpty ? 'Acknowledged' : text,
            authorId: user.uid,
            authorName: user.name,
            authorRole: user.roleLabel,
            createdAt: DateTime.now(),
            isAcknowledgement: true,
          ),
        );
      } else if (text.isNotEmpty) {
        await _noteService.addComment(
          widget.note.id,
          NoteComment(
            id: '',
            text: text,
            authorId: user.uid,
            authorName: user.name,
            authorRole: user.roleLabel,
            createdAt: DateTime.now(),
          ),
        );
      }
      // Flip the parent note's ack flag (idempotent — server-side check
      // not needed, the field can stay true even if multiple people ack).
      if (acknowledge && !_isAcked) {
        await context
            .read<NoteProvider>()
            .acknowledgeNote(widget.note.id, user.name);
      }
      _textController.clear();
      _toast(acknowledge ? 'Acknowledged ✓' : 'Reply posted');
    } catch (e, st) {
      // Log the raw error so we can diagnose if the friendly version
      // hides the cause (e.g. permission-denied vs network).
      debugPrint('NoteCommentsSheet._send failed: $e\n$st');
      _toast(friendlyError(e), danger: true);
    } finally {
      if (mounted) setState(() => _sending = false);
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
    final t = name.trim();
    if (t.isEmpty) return '?';
    final p = t.split(RegExp(r'\s+'));
    final a = p.first[0];
    final b = p.length > 1 && p[1].isNotEmpty ? p[1][0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    final n = widget.note;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Scaffold(
            // The outer Padding(bottom: viewInsets.bottom) above already
            // shifts the whole sheet up by the keyboard height. If the
            // Scaffold ALSO resizes for the keyboard (the default), the
            // input row gets pushed up TWICE — the buttons render at the
            // wrong y-position and taps land where the buttons used to be
            // a frame ago. Disable the inner shift; the outer Padding is
            // already doing the right thing.
            resizeToAvoidBottomInset: false,
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
                      Expanded(
                        child: Text(
                          'Thread',
                          style: GoogleFonts.dmSans(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (n.isAcknowledged)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ack',
                                style: GoogleFonts.dmSans(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      _originalNoteBubble(n),
                      const SizedBox(height: 16),
                      _commentsList(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding:
                        const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border(
                        top: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Write a reply…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StreamBuilder<bool>(
                          stream: _ackStream,
                          initialData: _isAcked,
                          builder: (context, snap) {
                            final acked = snap.data ?? _isAcked;
                            // Track the live state so _send doesn't
                            // re-fire the ack flip unnecessarily.
                            _isAcked = acked;
                            if (acked) return const SizedBox.shrink();
                            return IconButton(
                              tooltip: 'Ack with reply',
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.accent,
                              ),
                              onPressed: _sending
                                  ? null
                                  : () => _send(acknowledge: true),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Send',
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send,
                                  color: AppColors.primary),
                          onPressed: _sending ? null : () => _send(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _originalNoteBubble(Note n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _roleColor(n.authorRole).withOpacity(0.15),
                child: Text(
                  _initials(n.authorName),
                  style: TextStyle(
                    color: _roleColor(n.authorRole),
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: n.priorityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  n.priority,
                  style: GoogleFonts.dmSans(
                    color: n.priorityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            n.content,
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            timeago.format(n.createdAt),
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentsList() {
    return StreamBuilder<List<NoteComment>>(
      stream: _noteService.commentsStream(widget.note.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final comments = snap.data!;
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No replies yet. Be the first.',
                style: GoogleFonts.dmSans(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final c in comments) _commentBubble(c),
          ],
        );
      },
    );
  }

  Widget _commentBubble(NoteComment c) {
    final rc = _roleColor(c.authorRole);
    final mine = c.authorId ==
        (context.read<AuthProvider>().currentUser?.uid ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: rc.withOpacity(0.15),
            child: Text(
              _initials(c.authorName),
              style: TextStyle(
                color: rc,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.isAcknowledgement
                    ? AppColors.accent.withOpacity(0.08)
                    : (mine
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surface),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.isAcknowledgement
                      ? AppColors.accent.withOpacity(0.4)
                      : AppColors.divider,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c.authorName,
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
                          color: rc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.authorRole,
                          style: GoogleFonts.dmSans(
                            color: rc,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeago.format(c.createdAt, locale: 'en_short'),
                        style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (c.isAcknowledgement) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Acknowledged by ${c.authorName}',
                          style: GoogleFonts.dmSans(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    c.text,
                    style: GoogleFonts.dmSans(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
