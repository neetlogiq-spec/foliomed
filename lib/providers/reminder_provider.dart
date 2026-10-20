import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/patient_reminder.dart';
import '../services/reminder_notifications.dart';
import '../services/reminder_service.dart';
import '../services/review_request.dart';
import '../utils/haptics.dart';

/// Open reminders for the user's wards: drives the "Due" list, the local
/// notifications, and the "has this been done?" prompt.
class ReminderProvider extends ChangeNotifier {
  ReminderProvider({ReminderService? service, DateTime Function()? clock})
      : _injected = service,
        _clock = clock ?? DateTime.now;

  final ReminderService? _injected;

  /// Created on first use, so building the provider never touches the
  /// network.
  late final ReminderService _service = _injected ?? ReminderService();
  final DateTime Function() _clock;

  StreamSubscription<List<PatientReminder>>? _sub;
  Timer? _ticker;
  List<String> _wardIds = const [];
  List<PatientReminder> _open = const [];

  /// Reminders already asked about this session (until they change).
  final Map<String, DateTime> _prompted = {};

  /// Set by the UI to show the "has this been done?" prompt.
  Future<void> Function(PatientReminder reminder)? onDue;
  bool _prompting = false;

  Object? lastException;

  List<PatientReminder> get open => _open;

  List<PatientReminder> get due =>
      _open.where((r) => r.isDueAt(_clock())).toList();

  int get dueCount => due.length;

  void subscribe(List<String> wardIds) {
    if (listEquals(wardIds, _wardIds) && _sub != null) return;
    _wardIds = List.of(wardIds);
    _sub?.cancel();
    _sub = _service.openForWards(_wardIds).listen((rows) {
      _open = rows;
      ReminderNotifications.instance.sync(rows);
      notifyListeners();
      checkDue();
    }, onError: (Object e) {
      lastException = e;
      debugPrint('ReminderProvider stream: $e');
    });
    _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) => checkDue());
  }

  /// Asks about the next due reminder that hasn't been asked about yet.
  Future<void> checkDue() async {
    final handler = onDue;
    if (handler == null || _prompting) return;
    final now = _clock();
    for (final r in due) {
      // Re-ask only if the reminder changed (e.g. a snooze ran out).
      if (_prompted[r.id] == r.nextAlertAt) continue;
      _prompted[r.id] = r.nextAlertAt;
      _prompting = true;
      try {
        await handler(r);
      } finally {
        _prompting = false;
      }
      notifyListeners();
      if (_clock().difference(now) > const Duration(minutes: 5)) break;
    }
  }

  Future<bool> markDone(PatientReminder r) async {
    final ok = await _run(() => _service.markDone(r.id), Haptics.success);
    if (ok) ReviewRequest.maybeAsk();
    return ok;
  }

  Future<bool> reopen(PatientReminder r) =>
      _run(() => _service.reopen(r.id), Haptics.commit);

  /// "Not yet": ask everyone again after [delay].
  Future<bool> snooze(PatientReminder r,
          {Duration delay = const Duration(hours: 1)}) =>
      _run(() => _service.snooze(r.id, delay), Haptics.commit);

  Future<bool> delete(PatientReminder r) =>
      _run(() => _service.delete(r.id), Haptics.destructive);

  Future<bool> add({
    required String patientId,
    required String wardId,
    required String patientName,
    required String title,
    required DateTime dueAt,
  }) =>
      _run(
        () => _service.add(
          patientId: patientId,
          wardId: wardId,
          patientName: patientName,
          title: title,
          dueAt: dueAt,
        ),
        Haptics.success,
      );

  Future<bool> _run(Future<void> Function() action, void Function() ok) async {
    try {
      await action();
      ok();
      return true;
    } catch (e) {
      Haptics.error();
      lastException = e;
      notifyListeners();
      return false;
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _wardIds = const [];
    _open = const [];
    _prompted.clear();
    ReminderNotifications.instance.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
