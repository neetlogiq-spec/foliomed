import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../widgets/note_card.dart';
import '../../providers/theme_provider.dart';

enum NoteFilterType { urgent, today, all, unacknowledged }

class FilteredNotesScreen extends StatelessWidget {
  final NoteFilterType filter;
  final String title;

  const FilteredNotesScreen({
    super.key,
    required this.filter,
    required this.title,
  });

  List<Note> _apply(List<Note> all) {
    switch (filter) {
      case NoteFilterType.urgent:
        return all.where((n) => n.priority == 'Urgent').toList();
      case NoteFilterType.today:
        return all.where((n) => isToday(n.createdAt)).toList();
      case NoteFilterType.unacknowledged:
        return all.where((n) => !n.isAcknowledged).toList();
      case NoteFilterType.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(title)),
      body: Consumer<NoteProvider>(
        builder: (context, np, _) {
          final filtered = _apply(np.notes);
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No matching notes.',
                style: GoogleFonts.dmSans(color: AppColors.textSecondary),
              ),
            );
          }
          return _groupedList(context, filtered);
        },
      ),
    );
  }

  Widget _groupedList(BuildContext context, List<Note> notes) {
    final groups = <String, List<Note>>{};
    for (final n in notes) {
      final key = _dateKey(n.createdAt);
      groups.putIfAbsent(key, () => []).add(n);
    }
    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            entry.key.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
      for (final n in entry.value) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NoteCard(
            note: n,
            onAcknowledge: n.isAcknowledged
                ? null
                : () {
                    final name = context
                            .read<AuthProvider>()
                            .currentUser
                            ?.name ??
                        'Staff';
                    context
                        .read<NoteProvider>()
                        .acknowledgeNote(n.id, name);
                  },
            onUnacknowledge: !n.isAcknowledged
                ? null
                : () => context
                    .read<NoteProvider>()
                    .unacknowledgeNote(n.id),
          ),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: widgets,
    );
  }

  String _dateKey(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE · d MMM').format(d);
    return DateFormat('EEEE · d MMM yyyy').format(d);
  }
}
