import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/camera_config.dart';
import '../models/monitor_vitals.dart';

class CameraProvider extends ChangeNotifier {
  static const _key = 'edge_cameras_v1';

  List<CameraConfig> _cameras = [];
  bool _loaded = false;

  List<CameraConfig> get cameras => List.unmodifiable(_cameras);
  bool get loaded => _loaded;
  bool get hasAny => _cameras.isNotEmpty;
  int get activeCount => _cameras.where((c) => c.isEnabled).length;
  int get withRoiCount => _cameras.where((c) => c.hasRoi).length;

  CameraConfig? byId(String id) {
    try {
      return _cameras.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _cameras = list
            .map((j) => CameraConfig.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
      }
    } catch (_) {
      _cameras = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_cameras.map((c) => c.toJson()).toList()));
  }

  void add(CameraConfig c) {
    _cameras.add(c);
    _persist();
    notifyListeners();
  }

  void update(CameraConfig c) {
    final i = _cameras.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      _cameras[i] = c;
      _persist();
      notifyListeners();
    }
  }

  void remove(String id) {
    _cameras.removeWhere((c) => c.id == id);
    _persist();
    notifyListeners();
  }

  void toggleEnabled(String id) {
    final i = _cameras.indexWhere((c) => c.id == id);
    if (i >= 0) {
      _cameras[i] = _cameras[i].copyWith(isEnabled: !_cameras[i].isEnabled);
      _persist();
      notifyListeners();
    }
  }

  void saveRoi(String cameraId, Map<VitalType, RoiRect?> updates) {
    final i = _cameras.indexWhere((c) => c.id == cameraId);
    if (i < 0) return;
    final newRoi = Map<VitalType, RoiRect>.from(_cameras[i].roi);
    for (final entry in updates.entries) {
      if (entry.value == null) {
        newRoi.remove(entry.key);
      } else {
        newRoi[entry.key] = entry.value!;
      }
    }
    _cameras[i] = _cameras[i].copyWith(roi: newRoi);
    _persist();
    notifyListeners();
  }
}
