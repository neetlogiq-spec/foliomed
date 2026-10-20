import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ward_job.dart';
import '../../providers/account_provider.dart';
import '../../providers/job_board.dart';
import '../../utils/app_theme.dart';
import '../../utils/friendly_error.dart';
import '../patients/patient_screen.dart';
import 'add_job_sheet.dart';

/// Actions for one job, as an iOS action sheet.
Future<void> showJobActions(BuildContext context, WardJob job, {bool fromPatient = false}) async {
  final board = context.read<JobBoard>();
  final myUid = context.read<AccountProvider>().currentUser?.uid;
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(job.title),
      message: Text([
        if (job.patientName.isNotEmpty) job.patientName,
        if (job.createdByName != null) 'Added by ${job.createdByName}',
      ].join(' · ')),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, 'done'),
          child: Text(job.isDone ? 'Not Done Yet' : 'Mark as Done'),
        ),
        if (!job.isDone && !job.isFor(myUid ?? ''))
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'mine'),
            child: const Text('I’ll Do It'),
          ),
        if (!job.isDone)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'assign'),
            child: const Text('Assign To…'),
          ),
        if (!job.isDone)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('Edit'),
          ),
        if (!fromPatient)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'patient'),
            child: const Text('Open Patient'),
          ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, 'delete'),
          child: const Text('Delete Job'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  Future<void> report(Future<bool> op, [String? success]) async {
    final ok = await op;
    if (!ok) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text(friendlyError(board.lastError ?? 'error'))));
    } else if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
  }

  switch (choice) {
    case 'done':
      await report(board.setDone(job, !job.isDone));
    case 'mine':
      await report(board.assign(job, myUid), 'It’s yours.');
    case 'assign':
      final pick = await pickJobAssignee(context, wardId: job.wardId, current: job.assignedTo);
      if (pick == null || !context.mounted) return;
      await report(board.assign(job, pick.uid), pick.uid == null ? 'Anyone can take it.' : 'Assigned to ${pick.name}.');
    case 'edit':
      await showAddJob(context, editing: job);
    case 'patient':
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientScreen(patientId: job.patientId)));
    case 'delete':
      await report(board.delete(job), 'Job deleted.');
  }
}
