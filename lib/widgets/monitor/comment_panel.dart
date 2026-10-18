import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/monitor_comment.dart';
import '../../utils/app_theme.dart';

class MonitorCommentPanel extends StatefulWidget {
  final List<MonitorComment> comments;
  final void Function(String text, String type) onAdd;

  const MonitorCommentPanel({super.key, required this.comments, required this.onAdd});

  @override
  State<MonitorCommentPanel> createState() => _MonitorCommentPanelState();
}

class _MonitorCommentPanelState extends State<MonitorCommentPanel> {
  final _ctrl = TextEditingController();
  String _type = 'order';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text, _type);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Orders & Notes', style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              Text('shown on bedside display', style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _typeChip('order', 'Order'),
              const SizedBox(width: 8),
              _typeChip('note', 'Note'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _type == 'order' ? 'Write an order...' : 'Write a note...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _submit,
                icon: const Icon(Icons.send, size: 20),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.comments.take(8).map((c) => _commentTile(c)),
        ],
      ),
    );
  }

  Widget _typeChip(String type, String label) {
    final active = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : AppColors.divider),
        ),
        child: Text(
          '${type == 'order' ? '📋' : '📝'} $label',
          style: GoogleFonts.dmSans(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _commentTile(MonitorComment c) {
    final isOrder = c.type == 'order';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOrder ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isOrder ? AppColors.primary : AppColors.accent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isOrder ? "📋" : "📝"} ${isOrder ? "Order" : "Note"}',
                style: GoogleFonts.dmSans(
                  color: isOrder ? AppColors.primary : AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                DateFormat('d MMM · hh:mm a').format(c.time),
                style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(c.text, style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13, height: 1.5)),
          const SizedBox(height: 4),
          Text(
            '${c.author} · ${_timeAgo(c.time)}',
            style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
