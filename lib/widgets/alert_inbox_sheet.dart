import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/alert_inbox.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'app_sheet.dart';
import 'empty_state.dart';
import 'inset_group.dart';

/// Recent alerts, newest first. Opening the sheet marks them read.
Future<void> showAlertInbox(BuildContext context) async {
  final inbox = context.read<AlertInbox>();
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AlertInboxSheet(),
  );
  inbox.markAllRead();
}

class _AlertInboxSheet extends StatelessWidget {
  const _AlertInboxSheet();

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<AlertInbox>();
    final items = inbox.items;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Alerts', style: AppTypography.title2(color: AppColors.textPrimary)),
                  ),
                  CupertinoButton(
                    onPressed: items.isEmpty ? null : inbox.clear,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: EmptyState(
                  icon: Icons.notifications_none,
                  title: 'You’re up to date',
                  subtitle: 'New notes from your wards appear here while FolioMed is open.',
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    InsetGroup(
                      dividerIndent: 34,
                      children: [for (final a in items) _AlertRow(item: a)],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item});
  final AlertItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.read ? Colors.transparent : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subheadline(
                              color: AppColors.textPrimary, weight: FontWeight.w600)),
                    ),
                    Text(timeago.format(item.at, locale: 'en_short'),
                        style: AppTypography.footnote(color: AppColors.textSecondary)),
                  ],
                ),
                if (item.body.isNotEmpty)
                  Text(item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
