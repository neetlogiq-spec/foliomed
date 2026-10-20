import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

import '../../models/app_user.dart';
import '../../models/note.dart';
import '../../models/note_reply.dart';
import '../../providers/account_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/notes_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/inset_group.dart';
import 'confirm_note_sheet.dart';

/// The note and its conversation, Messages-style: your replies on the
/// right, everyone else's on the left, the composer pinned to the bottom.
Future<void> showNoteThread(BuildContext context, Note note) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NoteThreadSheet(note: note),
    );

class _NoteThreadSheet extends StatefulWidget {
  const _NoteThreadSheet({required this.note});
  final Note note;

  @override
  State<_NoteThreadSheet> createState() => _NoteThreadSheetState();
}

class _NoteThreadSheetState extends State<_NoteThreadSheet> {
  final _repo = NotesRepository();
  late final Stream<List<NoteReply>> _replies = _repo.replies(widget.note.id);
  late final Stream<bool> _confirmed = _repo.confirmedState(widget.note.id);
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    final me = context.read<AccountProvider>().currentUser;
    if (text.isEmpty || me == null) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.reply(
        widget.note.id,
        NoteReply(
          id: const Uuid().v4(),
          text: text,
          authorId: me.uid,
          authorName: me.name,
          authorRole: me.roleLabel,
          createdAt: DateTime.now(),
        ),
      );
      Haptics.commit();
      _draft.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
        }
      });
    } catch (e) {
      Haptics.error();
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _replyMenu(NoteReply r) async {
    final choice = await showOptionSheet<String>(context, title: 'Reply', options: {'delete': 'Delete reply'});
    if (choice == 'delete') await _repo.removeReply(widget.note.id, r.id);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final me = context.read<AccountProvider>().currentUser;
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: h * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.patientName.isEmpty ? 'Note' : n.patientName,
                            style: AppTypography.headline(color: AppColors.textPrimary)),
                        Text('${n.category} · ${timeago.format(n.createdAt)}',
                            style: AppTypography.footnote(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: _confirmed,
                    initialData: n.isConfirmed,
                    builder: (context, s) => s.data == true
                        ? Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Row(children: [
                              Icon(Icons.check_circle, color: AppColors.accent, size: 18),
                              const SizedBox(width: 4),
                              Text('Confirmed', style: AppTypography.subheadline(color: AppColors.accent)),
                            ]),
                          )
                        : CupertinoButton(
                            onPressed: () {
                              if (me?.role == UserRole.nurse) {
                                Navigator.pop(context);
                                showConfirmNote(context, n);
                              } else {
                                context.read<WardFeed>().confirm(n.id, me?.name ?? 'Team');
                              }
                            },
                            child: const Text('Confirm'),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5, thickness: 0.5),
            Expanded(
              child: StreamBuilder<List<NoteReply>>(
                stream: _replies,
                builder: (context, snap) {
                  final replies = snap.data ?? const <NoteReply>[];
                  return ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    children: [
                      _Original(note: n),
                      const SizedBox(height: 14),
                      if (snap.hasError)
                        Text("Couldn't load replies.", style: AppTypography.footnote(color: AppColors.danger))
                      else if (snap.hasData && replies.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('No replies yet.',
                              textAlign: TextAlign.center,
                              style: AppTypography.footnote(color: AppColors.textSecondary)),
                        ),
                      for (final r in replies)
                        _Bubble(
                          reply: r,
                          mine: r.authorId == me?.uid,
                          onLongPress: r.authorId == me?.uid ? () => _replyMenu(r) : null,
                        ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 0.5, thickness: 0.5),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _draft,
                        placeholder: 'Reply to the team',
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        style: AppTypography.body(color: AppColors.textPrimary),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending || _draft.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Original extends StatelessWidget {
  const _Original({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: note.isUrgent ? Border(left: BorderSide(color: AppColors.danger, width: 3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${note.authorName}${note.authorRole.isEmpty ? '' : ' · ${note.authorRole}'}',
              style: AppTypography.footnote(color: AppColors.textSecondary, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          SelectableText(note.content,
              style: AppTypography.body(color: AppColors.textPrimary).copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.reply, required this.mine, this.onLongPress});
  final NoteReply reply;
  final bool mine;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final r = reply;
    final bg = mine ? AppColors.primary : AppColors.card;
    final fg = mine ? AppColors.onPrimary : AppColors.textPrimary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(r.authorName,
                      style: AppTypography.caption1(color: AppColors.textSecondary)),
                ),
              GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: r.isConfirmation ? Border.all(color: AppColors.accent, width: 1.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.isConfirmation)
                        Text('✓ Confirmed',
                            style: AppTypography.caption1(
                                color: mine ? AppColors.onPrimary : AppColors.accent,
                                weight: FontWeight.w700)),
                      Text(r.text, style: AppTypography.body(color: fg)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Text(timeago.format(r.createdAt, locale: 'en_short'),
                    style: AppTypography.caption2(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
