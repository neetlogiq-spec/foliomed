import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/patient.dart';
import '../services/patient_service.dart';
import '../utils/haptics.dart';

/// Admitted patients across the signed-in user's wards (live), and the
/// patient actions — admit, edit, discharge, readmit, transfer, delete.
class PatientRoster extends ChangeNotifier {
  PatientRoster({PatientService? service}) : _injected = service;

  final PatientService? _injected;
  late final PatientService _service = _injected ?? PatientService();

  List<Patient> _patients = const [];
  StreamSubscription<List<Patient>>? _sub;

  /// Last failure, for `friendlyError`.
  Object? lastError;

  List<Patient> get patients => _patients;

  void watchWards(List<String> wardIds) {
    _sub?.cancel();
    if (wardIds.isEmpty) {
      _patients = const [];
      notifyListeners();
      return;
    }
    _sub = _service.getActivePatientsForWards(wardIds).listen((v) {
      _patients = v;
      notifyListeners();
    }, onError: (Object e) {
      lastError = e;
      notifyListeners();
    });
  }

  /// App in the background: stop the live read.
  void pause() {
    _sub?.cancel();
    _sub = null;
  }

  Future<T?> _try<T>(Future<T> Function() op, void Function() feedback) async {
    try {
      final r = await op();
      feedback();
      return r;
    } catch (e) {
      Haptics.error();
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  /// The new patient's id, or null if it wasn't saved.
  Future<String?> addPatient(Patient p) => _try(() => _service.addPatient(p), Haptics.success);

  Future<bool> updatePatient(Patient p) async =>
      await _try(() async { await _service.updatePatient(p); return true; }, Haptics.commit) ?? false;

  Future<bool> deletePatient(String id) async =>
      await _try(() async { await _service.deletePatient(id); return true; }, Haptics.destructive) ?? false;

  Future<bool> dischargePatient(String id, {String summary = ''}) async =>
      await _try(() async { await _service.dischargePatient(id, summary: summary); return true; }, Haptics.success) ??
      false;

  Future<bool> readmitPatient(String id) async =>
      await _try(() async { await _service.readmitPatient(id); return true; }, Haptics.commit) ?? false;

  Future<bool> transferPatient(String id, {required String targetWardId, String reason = '', String? bedNumber}) async =>
      await _try(() async {
        await _service.transferPatient(id, targetWardId: targetWardId, reason: reason, bedNumber: bedNumber);
        return true;
      }, Haptics.success) ??
      false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
