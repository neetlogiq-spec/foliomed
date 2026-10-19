import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/haptics.dart';

import '../models/patient.dart';
import '../services/patient_service.dart';

class PatientProvider extends ChangeNotifier {
  final PatientService _patientService;

  PatientProvider({PatientService? patientService})
      : _patientService = patientService ?? PatientService();

  List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<Patient>>? _subscription;

  List<Patient> get patients => _patients;
  Patient? get selectedPatient => _selectedPatient;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// The raw error from the last failed action, for `friendlyError`.
  Object? lastException;
  int get patientCount => _patients.length;

  void subscribeForWards(List<String> wardIds) {
    _subscription?.cancel();
    if (wardIds.isEmpty) {
      _patients = [];
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    _subscription =
        _patientService.getActivePatientsForWards(wardIds).listen((patients) {
      _patients = patients;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void subscribeToWard(String wardId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _subscription =
        _patientService.getPatientsByWard(wardId).listen((patients) {
      _patients = patients;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void selectPatient(Patient patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  void clearSelectedPatient() {
    _selectedPatient = null;
    notifyListeners();
  }

  /// Returns the new patient's id, or null on failure.
  Future<String?> addPatient(Patient patient) async {
    try {
      final id = await _patientService.addPatient(patient);
      Haptics.success();
      return id;
    } catch (e) {
      Haptics.error();
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updatePatient(Patient patient) async {
    try {
      await _patientService.updatePatient(patient);
      Haptics.commit();
      return true;
    } catch (e) {
      Haptics.error();
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePatient(String patientId) async {
    try {
      await _patientService.deletePatient(patientId);
      Haptics.destructive();
      return true;
    } catch (e) {
      Haptics.error();
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Runs a patient action with the standard haptics + error capture.
  Future<bool> _run(Future<void> Function() action, void Function() haptic) async {
    try {
      await action();
      haptic();
      return true;
    } catch (e) {
      Haptics.error();
      _error = e.toString();
      lastException = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> dischargePatient(String patientId, {String summary = ''}) =>
      _run(() => _patientService.dischargePatient(patientId, summary: summary),
          Haptics.success);

  Future<bool> readmitPatient(String patientId) =>
      _run(() => _patientService.readmitPatient(patientId), Haptics.commit);

  Future<bool> transferPatient(
    String patientId, {
    required String targetWardId,
    String reason = '',
    String? bedNumber,
  }) =>
      _run(
        () => _patientService.transferPatient(
          patientId,
          targetWardId: targetWardId,
          reason: reason,
          bedNumber: bedNumber,
        ),
        Haptics.success,
      );

  void pauseStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  void cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    cancelSubscription();
    super.dispose();
  }
}
