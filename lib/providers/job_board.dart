import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ward_job.dart';
import '../services/job_service.dart';
import '../utils/haptics.dart';

/// Live jobs across the signed-in user's wards, plus job actions.
class JobBoard extends ChangeNotifier {
  JobBoard({JobService? service}) : _injected = service;

  final JobService? _injected;
  late final JobService _service = _injected ?? JobService();

  List<WardJob> _jobs = const [];
  StreamSubscription<List<WardJob>>? _sub;
  List<String> _wardIds = const [];

  /// Last failure, for `friendlyError`.
  Object? lastError;

  JobService get service => _service;

  /// Open jobs, and jobs done since midnight.
  List<WardJob> get jobs => _jobs;

  List<WardJob> open() => [for (final j in _jobs) if (!j.isDone) j];

  List<WardJob> mine(String uid) => [for (final j in _jobs) if (!j.isDone && j.isFor(uid)) j];

  void watchWards(List<String> wardIds) {
    _wardIds = List.of(wardIds);
    _sub?.cancel();
    if (wardIds.isEmpty) {
      _jobs = const [];
      notifyListeners();
      return;
    }
    _sub = _service.forWards(wardIds).listen((rows) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      _jobs = [
        for (final j in rows)
          if (!j.isDone || j.doneAt!.isAfter(midnight)) j,
      ]..sort((a, b) => WardJob.byPriority(a, b, now));
      lastError = null;
      notifyListeners();
    }, onError: (Object e) {
      lastError = e;
      notifyListeners();
    });
  }

  void pause() {
    _sub?.cancel();
    _sub = null;
  }

  void resume() {
    if (_sub == null && _wardIds.isNotEmpty) watchWards(_wardIds);
  }

  Future<bool> _try(Future<void> Function() op, void Function() feedback) async {
    try {
      await op();
      feedback();
      return true;
    } catch (e) {
      Haptics.error();
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> add({
    required String wardId,
    required String patientId,
    required String title,
    bool urgent = false,
    DateTime? dueBy,
    String? assignedTo,
  }) =>
      _try(
        () => _service.add(
            wardId: wardId, patientId: patientId, title: title, urgent: urgent, dueBy: dueBy, assignedTo: assignedTo),
        Haptics.success,
      );

  Future<bool> setDone(WardJob job, bool done) =>
      _try(() => _service.setDone(job.id, done), done ? Haptics.success : Haptics.selection);

  Future<bool> assign(WardJob job, String? uid) => _try(() => _service.assign(job.id, uid), Haptics.commit);

  Future<bool> edit(WardJob job, {required String title, required bool urgent, DateTime? dueBy}) =>
      _try(() => _service.edit(job.id, title: title, urgent: urgent, dueBy: dueBy), Haptics.commit);

  Future<bool> delete(WardJob job) => _try(() => _service.delete(job.id), Haptics.destructive);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
