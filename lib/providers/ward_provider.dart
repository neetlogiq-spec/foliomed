import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/ward.dart';
import '../services/ward_service.dart';

class WardProvider extends ChangeNotifier {
  final WardService _wardService;

  WardProvider({WardService? wardService})
      : _wardService = wardService ?? WardService();

  List<Ward> _wards = [];
  List<AppUser> _wardStaff = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<Ward>>? _wardsSubscription;
  StreamSubscription<List<AppUser>>? _staffSubscription;

  List<Ward> get wards => _wards;
  List<AppUser> get wardStaff => _wardStaff;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void subscribeToWards() {
    _wardsSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _wardsSubscription = _wardService.getAllWards().listen((wards) {
      _wards = wards;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void loadWardStaff(String wardId) {
    _staffSubscription?.cancel();
    _staffSubscription = _wardService.getWardStaff(wardId).listen((staff) {
      _wardStaff = staff;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<bool> addWard(Ward ward) async {
    try {
      await _wardService.addWard(ward);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWard(Ward ward) async {
    try {
      await _wardService.updateWard(ward);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _wardsSubscription?.cancel();
    _staffSubscription?.cancel();
    super.dispose();
  }
}
