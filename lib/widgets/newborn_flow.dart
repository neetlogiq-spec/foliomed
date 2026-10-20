import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/newborn_screen.dart';
import '../models/patient.dart';
import '../models/patient_reminder.dart';
import '../screens/shared/newborn_results_screen.dart';
import '../services/newborn_screen_service.dart';
import '../services/patient_service.dart';
import '../services/reminder_notifications.dart';
import '../utils/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import 'app_alert_dialog.dart';
import 'app_sheet.dart';
import 'inset_group.dart';

/// The newborn investigation conversation: heads-up → "sent?" → "results?".
class NewbornFlow {
  NewbornFlow._();

  static final _service = NewbornScreenService();

  static void _error(BuildContext context, Object e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.danger,
      content: Text(friendlyError(e)),
    ));
  }

  /// Due prompt for a newborn-plan reminder. Returns true if it handled it.
  static Future<bool> handleDue(BuildContext context, PatientReminder r,
      {required Future<void> Function() markDone,
      required Future<void> Function() snooze}) async {
    final screenId = r.screenId;
    if (screenId == null) return false;
    final who = r.patientName.isEmpty ? 'This baby' : r.patientName;
    switch (r.kind) {
      case 'newborn_prep':
        await showAdaptiveDialog<void>(
          context: context,
          builder: (ctx) => AppAlertDialog(
            title: Text(r.title),
            content: Text('$who — due ${_dueAt(r)}.\n\nTo send:\n'
                '${kNewbornInvestigations.map((i) => '• $i').join('\n')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        await markDone();
        return true;
      case 'newborn_send':
        final sent = await showAdaptiveDialog<bool>(
          context: context,
          builder: (ctx) => AppAlertDialog(
            title: const Text('Investigations sent?'),
            content: Text('$who is due for the ${r.title.replaceFirst('Send ', '')}.\n\n'
                'Have CBC, TSH, blood grouping, TSB, RFT and OAE been sent?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, sent'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not yet — ask in 1 h'),
              ),
            ],
          ),
        );
        if (sent == null) return true; // dismissed: asks again next launch
        if (!sent) {
          await snooze();
          return true;
        }
        if (!context.mounted) return true;
        await markSent(context, screenId, r.patientId);
        return true;
      case 'newborn_results':
        if (!context.mounted) return true;
        await askResults(context, screenId, r.patientId);
        return true;
    }
    return false;
  }

  static String _dueAt(PatientReminder r) {
    final lead = RegExp(r'in (\d+) h').firstMatch(r.title)?.group(1);
    final due = lead == null ? r.dueAt : r.dueAt.add(Duration(hours: int.parse(lead)));
    return formatDueTime(due);
  }

  /// Marks the plan sent, then asks about results.
  static Future<void> markSent(BuildContext context, String screenId, String patientId) async {
    try {
      await _service.markSent(screenId);
      Haptics.success();
    } catch (e) {
      if (context.mounted) _error(context, e);
      return;
    }
    if (!context.mounted) return;
    await askResults(context, screenId, patientId);
  }

  /// "Are the results back?" → enter now, or a reminder in 6 hours.
  static Future<void> askResults(
      BuildContext context, String screenId, String patientId) async {
    final choice = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Results back?'),
        content: const Text('Enter the results now, or FolioMed will ask again in 6 hours.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'enter'),
            child: const Text('Enter results'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: const Text('Not yet — ask in 6 h'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == 'enter') {
      await openResults(context, screenId, patientId);
    } else if (choice == 'later') {
      try {
        await _service.remindResults(screenId, hours: 6);
      } catch (e) {
        if (context.mounted) _error(context, e);
      }
    }
  }

  static Future<void> openResults(BuildContext context, String screenId, String patientId) async {
    try {
      final results = await Future.wait([
        _service.get(screenId),
        PatientService().getPatient(patientId),
      ]);
      final screen = results[0] as NewbornScreen?;
      final patient = results[1] as Patient?;
      if (screen == null || patient == null) {
        if (context.mounted) _error(context, 'This plan is no longer available.');
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewbornResultsScreen(screen: screen, patient: patient),
      ));
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  /// Plan (or re-plan) from the patient page.
  static Future<void> plan(BuildContext context, Patient p) async {
    var hours = 48;
    var lead = 12;
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final due = p.bornAt!.add(Duration(hours: hours));
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Plan', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  InsetGroup(
                    header: 'Newborn investigations',
                    dividerIndent: 16,
                    footer: 'Heads-up ${formatDueTime(due.subtract(Duration(hours: lead)))} · '
                        'asks if sent at ${formatDueTime(due)}.\n'
                        '${kNewbornInvestigations.join(' · ')}',
                    children: [
                      InsetSegmentedRow<int>(
                        label: 'Send at',
                        value: hours,
                        options: const {48: '48 h of life', 72: '72 h of life'},
                        onChanged: (v) => setState(() => hours = v),
                      ),
                      InsetSegmentedRow<int>(
                        label: 'Remind me before',
                        value: lead,
                        options: const {8: '8 h before', 12: '12 h before'},
                        onChanged: (v) => setState(() => lead = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await _service.plan(p.id, hours: hours, leadHours: lead);
      Haptics.success();
      await ReminderNotifications.instance.requestPermission();
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }
}
