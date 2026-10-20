import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import '../../providers/account_provider.dart';
import '../../providers/patient_roster.dart';
import '../../providers/unit_provider.dart';
import '../../providers/ward_feed.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../utils/scope_filter.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/scope_button.dart';
import 'compose_note_sheet.dart';
import 'note_actions.dart';

enum NotesView { pending, all, urgent }

/// Every recent note on your wards, live: waiting for confirmation, all,
/// or urgent. One line per note by default; tap a line to read it.
class WardNotesScreen extends StatefulWidget {
  const WardNotesScreen({super.key, this.initial = NotesView.pending});
  final NotesView initial;

  @override
  State<WardNotesScreen> createState() => _WardNotesScreenState();
}

class _WardNotesScreenState extends State<WardNotesScreen> {
  static const _compactKey = 'notes_compact_v2';
  static const _pageSize = 25;

  late NotesView _view = widget.initial;
  bool _compact = true;
  int _shown = _pageSize;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final v = (await SharedPreferences.getInstance()).getBool(_compactKey);
        if (v != null && mounted) setState(() => _compact = v);
      } catch (_) {
        // A display preference; the default is fine.
      }
    }();
  }

  Future<void> _toggleCompact() async {
    Haptics.selection();
    setState(() => _compact = !_compact);
    try {
      await (await SharedPreferences.getInstance()).setBool(_compactKey, _compact);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<WardFeed>();
    final f = ScopeFilter(context.watch<UnitProvider>().scope, context.watch<PatientRoster>().patients);
    final canPost = context.watch<AccountProvider>().currentUser?.role == UserRole.doctor;
    final all = switch (_view) {
      NotesView.pending => feed.feed.where((n) => !n.isConfirmed),
      NotesView.urgent => feed.urgent,
      NotesView.all => feed.feed,
    }.where(f.note).toList();
    final visible = all.take(_shown).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(
            title: 'Notes',
            showBackButton: true,
            actions: [
              ChromeIconButton(
                icon: _compact ? Icons.unfold_more : Icons.unfold_less,
                tooltip: _compact ? 'Show notes in full' : 'One line per note',
                onPressed: _toggleCompact,
              ),
              if (canPost)
                ChromeIconButton(icon: Icons.edit_square, tooltip: 'New note', onPressed: () => showComposeNote(context)),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(children: [
              const Align(alignment: Alignment.centerLeft, child: ScopeButton()),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<NotesView>(
                groupValue: _view,
                onValueChanged: (v) {
                  if (v == null) return;
                  Haptics.selection();
                  setState(() {
                    _view = v;
                    _shown = _pageSize;
                  });
                },
                children: {
                  NotesView.pending: _segment('To Confirm'),
                  NotesView.all: _segment('All'),
                  NotesView.urgent: _segment('Urgent'),
                },
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                _empty()
              else
                for (final n in visible)
                  Padding(
                    padding: EdgeInsets.only(bottom: _compact ? 8 : 10),
                    child: _compact
                        ? NoteLine(key: ValueKey('c${n.id}'), note: n)
                        : FeedNote(key: ValueKey('f${n.id}'), note: n),
                  ),
              if (all.length > visible.length)
                TextButton(
                  onPressed: () => setState(() => _shown += _pageSize),
                  child: Text('Show ${all.length - visible.length} More'),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(label, style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
      );

  Widget _empty() {
    final (icon, title, subtitle) = switch (_view) {
      NotesView.pending => (Icons.check_circle_outline, 'Nothing to confirm', 'Every note on your wards has been seen to.'),
      NotesView.urgent => (Icons.verified_outlined, 'Nothing urgent', 'Urgent notes show here first.'),
      NotesView.all => (Icons.notes_outlined, 'No notes yet', 'Notes your team posts appear here as they’re written.'),
    };
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: EmptyPlaceholder(icon: icon, title: title, subtitle: subtitle),
    );
  }
}
