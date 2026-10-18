import 'dart:async';

import 'package:flutter/foundation.dart';

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

  Future<bool> addPatient(Patient patient) async {
    try {
      await _patientService.addPatient(patient);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePatient(Patient patient) async {
    try {
      await _patientService.updatePatient(patient);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePatient(String patientId) async {
    try {
      await _patientService.deletePatient(patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

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
