import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/theme_provider.dart';

Future<void> showAcknowledgeSheet(BuildContext context, Note note) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => AcknowledgeSheet(note: note),
  );
}

class AcknowledgeSheet extends StatefulWidget {
  final Note note;

  const AcknowledgeSheet({super.key, required this.note});

  @override
  State<AcknowledgeSheet> createState() => _AcknowledgeSheetState();
}

class _AcknowledgeSheetState extends State<AcknowledgeSheet> {
  bool _submitting = false;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final user = context.read<AuthProvider>().currentUser;
    final ok = await context
        .read<NoteProvider>()
        .acknowledgeNote(widget.note.id, user?.name ?? 'Staff');
    if (!mounted) return;
    Navigator.of(context).pop();
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note acknowledged ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.accent,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Acknowledge Note',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'By acknowledging, you confirm this has been noted and will be acted upon.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  onPressed: _submitting ? null : _confirm,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Confirm Acknowledge'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
