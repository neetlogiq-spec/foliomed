import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/monitor_alert.dart';
import '../models/monitor_comment.dart';
import '../models/monitor_vitals.dart';
import '../models/monitored_patient.dart';
import '../models/patient.dart';
import '../models/ward.dart';

class VitalSnapshot {
  final DateTime time;
  final Map<VitalType, double> vitals;
  const VitalSnapshot(this.time, this.vitals);
}

class MonitorProvider extends ChangeNotifier {
  List<MonitoredPatient> _patients = [];
  List<MonitorAlert> _alerts = [];
  List<MonitorComment> _comments = [];
  bool _soundEnabled = true;
  Timer? _simTimer;
  final _rng = Random();
  final Map<String, DateTime> _lastAlertTime = {};

  final Map<String, List<VitalSnapshot>> _history = {};
  static const int _maxHistory = 2200;

  List<MonitoredPatient> get patients => _patients;
  List<MonitorAlert> get alerts => _alerts;
  List<MonitorComment> get comments => _comments;
  bool get soundEnabled => _soundEnabled;

  List<VitalSnapshot> historyFor(String patientId) => _history[patientId] ?? [];

  bool _usingRealPatients = false;

  // Patients with live OCR data skip simulation so real readings show
  final _ocrActive = <String>{};
  final Map<String, Timer> _ocrExpiry = {};

  // Patients with an assigned camera show ONLY real readings — no demo
  // simulation, ever. Their vitals stay empty ("waiting for monitor")
  // until the first camera/AI reading arrives.
  final _liveOnly = <String>{};

  bool isLiveOnly(String patientId) => _liveOnly.contains(patientId);

  /// Called from the UI with the ids of every patient watched by a camera
  /// (directly or via a monitor zone). Newly camera-assigned patients get
  /// their simulated vitals and history wiped so only real readings show;
  /// patients whose camera was removed fall back to simulation.
  void syncLiveOnly(Set<String> patientIds) {
    final added = patientIds.difference(_liveOnly);
    final removed = _liveOnly.difference(patientIds);
    if (added.isEmpty && removed.isEmpty) return;

    for (final id in added) {
      final idx = _patients.indexWhere((p) => p.id == id);
      if (idx < 0) continue;
      _patients[idx] = _patients[idx].copyWith(vitals: {});
      _history[id] = [];
    }
    for (final id in removed) {
      final idx = _patients.indexWhere((p) => p.id == id);
      if (idx < 0) continue;
      // Resume simulation from each vital's baseline.
      final p = _patients[idx];
      final vitals = <VitalType, double>{
        for (final e in p.sim.entries) e.key: e.value.base,
      };
      final sbp = vitals[VitalType.sbp] ?? 0;
      final dbp = vitals[VitalType.dbp] ?? 0;
      vitals[VitalType.map] = ((sbp + 2 * dbp) / 3).roundToDouble();
      _patients[idx] = p.copyWith(vitals: vitals);
    }
    _liveOnly
      ..clear()
      ..addAll(patientIds);
    // Callers may invoke this during build — defer the notification.
    Future.microtask(notifyListeners);
  }

  /// Called by EdgeCameraViewer when OCR detects vitals from the RTSP frame.
  /// Suppresses simulation for this patient for 15s after last OCR push.
  void injectOcrVitals(String patientId, Map<VitalType, double> vitals) {
    final idx = _patients.indexWhere((p) => p.id == patientId);
    if (idx < 0) return;
    _ocrActive.add(patientId);
    _ocrExpiry[patientId]?.cancel();
    _ocrExpiry[patientId] = Timer(const Duration(seconds: 15), () {
      _ocrActive.remove(patientId);
      _ocrExpiry.remove(patientId);
    });
    final merged = Map<VitalType, double>.from(_patients[idx].vitals)..addAll(vitals);
    _patients[idx] = _patients[idx].copyWith(vitals: merged);
    _checkAlerts(patientId, merged, _patients[idx].thresholds);
    _history.putIfAbsent(patientId, () => []);
    _history[patientId]!.add(VitalSnapshot(DateTime.now(), Map.from(merged)));
    if (_history[patientId]!.length > _maxHistory) _history[patientId]!.removeAt(0);
    notifyListeners();
  }

  void init() {
    if (!_usingRealPatients) {
      _patients = List.from(_demoPatients);
      _comments = List.from(_seedComments);
      _seedHistory();
    }
    _startSimulation();
  }

  /// Called by ProxyProvider whenever PatientProvider or WardProvider changes.
  /// Merges real ward patients into the monitor list, preserving simulation
  /// state for patients already being tracked.
  void syncFromPatients(List<Patient> patients, List<Ward> wards) {
    final wardById = {for (final w in wards) w.id: w.name};

    if (patients.isEmpty) {
      if (_usingRealPatients) {
        // All real patients removed — fall back to demo
        _usingRealPatients = false;
        _patients = List.from(_demoPatients);
        _comments = List.from(_seedComments);
        _seedHistory();
        notifyListeners();
      }
      return;
    }

    _usingRealPatients = true;
    final existingById = {for (final p in _patients) p.id: p};
    final newList = <MonitoredPatient>[];

    for (final p in patients) {
      if (existingById.containsKey(p.id)) {
        // Keep live simulation state — just update metadata that may have changed
        final existing = existingById[p.id]!;
        newList.add(MonitoredPatient(
          id: existing.id,
          name: p.name,
          gender: p.gender,
          age: '${p.age}y',
          diagnosis: p.diagnosis.isNotEmpty ? p.diagnosis : 'Not specified',
          support: existing.support,
          bed: p.bedNumber.isNotEmpty ? 'Bed ${p.bedNumber}' : existing.bed,
          ward: wardById[p.wardId] ?? existing.ward,
          wardId: p.wardId,
          dutyPhone: existing.dutyPhone,
          thresholds: existing.thresholds,
          vitals: existing.vitals,
          sim: existing.sim,
        ));
      } else {
        // New patient — initialise with defaults, start simulation from scratch
        final wardName = wardById[p.wardId] ?? '';
        newList.add(MonitoredPatient.fromPatient(p, wardName: wardName));
        _history[p.id] = [];
      }
    }

    // Remove history for patients no longer in the list
    final newIds = {for (final p in newList) p.id};
    _history.removeWhere((id, _) => !newIds.contains(id));

    _patients = newList;
    notifyListeners();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  void _seedHistory() {
    final now = DateTime.now();
    for (final p in _patients) {
      final snapshots = <VitalSnapshot>[];
      var vitals = Map<VitalType, double>.from(p.vitals);
      for (int i = 720; i >= 0; i--) {
        final time = now.subtract(Duration(minutes: i));
        final newVitals = <VitalType, double>{};
        for (final vt in VitalType.values) {
          if (vt == VitalType.map) continue;
          final cfg = p.sim[vt];
          if (cfg == null) { newVitals[vt] = vitals[vt] ?? 0; continue; }
          newVitals[vt] = _simStep(vitals[vt] ?? cfg.base, cfg).roundToDouble();
          final meta = vitalMeta[vt]!;
          newVitals[vt] = newVitals[vt]!.clamp(meta.absMin, meta.absMax);
        }
        final sbp = newVitals[VitalType.sbp] ?? 0;
        final dbp = newVitals[VitalType.dbp] ?? 0;
        newVitals[VitalType.map] = ((sbp + 2 * dbp) / 3).roundToDouble();
        vitals = newVitals;
        snapshots.add(VitalSnapshot(time, Map.from(newVitals)));
      }
      _history[p.id] = snapshots;
    }
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
  }

  void addComment(String patientId, String text, String type) {
    _comments.insert(0, MonitorComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      text: text,
      author: 'Dr. Kashyap',
      time: DateTime.now(),
      type: type,
    ));
    notifyListeners();
  }

  List<MonitorComment> commentsFor(String patientId) =>
      _comments.where((c) => c.patientId == patientId).toList();

  void setThreshold(String patientId, VitalType vital, String key, double value) {
    final idx = _patients.indexWhere((p) => p.id == patientId);
    if (idx < 0) return;
    final patient = _patients[idx];
    final old = patient.thresholds[vital] ?? const VitalThreshold();
    final updated = VitalThreshold(
      warnLow: key == 'warnLow' ? value : old.warnLow,
      critLow: key == 'critLow' ? value : old.critLow,
      warnHigh: key == 'warnHigh' ? value : old.warnHigh,
      critHigh: key == 'critHigh' ? value : old.critHigh,
    );
    final newThresholds = Map<VitalType, VitalThreshold>.from(patient.thresholds);
    newThresholds[vital] = updated;
    _patients[idx] = patient.copyWith(thresholds: newThresholds);
    notifyListeners();
  }

  List<MonitorAlert> alertsFor(String patientId) =>
      _alerts.where((a) => a.patientId == patientId).toList();

  MonitoredPatient? patientById(String id) {
    for (final p in _patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _startSimulation() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 2), (_) => _simTick());
  }

  double _simStep(double current, SimConfig cfg) {
    final pull = 0.08 * (cfg.base - current);
    final noise = ((_rng.nextDouble() * 2) - 1) * cfg.range;
    double next = current + pull + noise;
    return next.clamp(cfg.base - cfg.maxDrift, cfg.base + cfg.maxDrift);
  }

  void _simTick() {
    for (int i = 0; i < _patients.length; i++) {
      final p = _patients[i];
      if (_ocrActive.contains(p.id)) continue; // live OCR — skip simulation
      if (_liveOnly.contains(p.id)) continue; // camera-assigned — real data only
      final newVitals = <VitalType, double>{};

      for (final vt in VitalType.values) {
        if (vt == VitalType.map) continue;
        final current = p.vitals[vt] ?? 0;
        final cfg = p.sim[vt];
        if (cfg == null) { newVitals[vt] = current; continue; }
        newVitals[vt] = _simStep(current, cfg).roundToDouble();
      }

      final sbp = newVitals[VitalType.sbp] ?? 0;
      final dbp = newVitals[VitalType.dbp] ?? 0;
      newVitals[VitalType.map] = ((sbp + 2 * dbp) / 3).roundToDouble();

      for (final vt in VitalType.values) {
        final meta = vitalMeta[vt]!;
        newVitals[vt] = (newVitals[vt] ?? 0).clamp(meta.absMin, meta.absMax);
      }

      _patients[i] = p.copyWith(vitals: newVitals);
      _checkAlerts(p.id, newVitals, p.thresholds);

      _history.putIfAbsent(p.id, () => []);
      _history[p.id]!.add(VitalSnapshot(DateTime.now(), Map.from(newVitals)));
      if (_history[p.id]!.length > _maxHistory) {
        _history[p.id]!.removeAt(0);
      }
    }
    notifyListeners();
  }

  void _checkAlerts(String patientId, Map<VitalType, double> vitals, Map<VitalType, VitalThreshold> thresholds) {
    for (final vt in VitalType.values) {
      final val = vitals[vt];
      final thr = thresholds[vt];
      if (val == null || thr == null) continue;

      final sev = thr.severity(val);
      if (sev == 'stable') continue;

      final key = '$patientId-${vt.name}-$sev';
      final last = _lastAlertTime[key];
      if (last != null && DateTime.now().difference(last).inSeconds < 20) continue;

      final meta = vitalMeta[vt]!;
      final isLow = (thr.critLow != null && val < thr.critLow!) ||
                     (thr.warnLow != null && val < thr.warnLow!);
      final direction = isLow ? 'below' : 'above';
      final label = vt == VitalType.spo2 ? 'SpO₂' : meta.label;

      _alerts.insert(0, MonitorAlert(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        patientId: patientId,
        message: '$label $direction ${sev == "critical" ? "critical" : "warning"}: ${val.round()}${meta.unit}',
        severity: sev,
        time: DateTime.now(),
      ));
      _lastAlertTime[key] = DateTime.now();
    }
  }
}

final List<MonitorComment> _seedComments = [
  MonitorComment(id: 's1', patientId: '1', text: 'iNO started at 20 ppm, wean by 5 ppm q4h if SpO₂ > 90%', author: 'Dr. Kashyap', time: DateTime.now().subtract(const Duration(hours: 2)), type: 'order'),
  MonitorComment(id: 's2', patientId: '1', text: 'Parents counselled about PPHN prognosis. Echo scheduled for tomorrow.', author: 'Dr. Kashyap', time: DateTime.now().subtract(const Duration(hours: 3)), type: 'note'),
  MonitorComment(id: 's3', patientId: '2', text: 'Noradrenaline tapered to 0.05 mcg/kg/min, reassess in 2 hrs', author: 'Dr. Kashyap', time: DateTime.now().subtract(const Duration(hours: 1)), type: 'order'),
  MonitorComment(id: 's4', patientId: '4', text: 'Blood cultures sent, Meropenem + Vancomycin started empirically', author: 'Dr. Kashyap', time: DateTime.now().subtract(const Duration(hours: 4)), type: 'order'),
  MonitorComment(id: 's5', patientId: '3', text: 'MgSO₄ loading dose completed. BP target < 155/100', author: 'Dr. Kashyap', time: DateTime.now().subtract(const Duration(hours: 5)), type: 'order'),
];

// Demo patients for simulation mode
const _neonatalThresholds = {
  VitalType.hr: VitalThreshold(warnLow: 110, critLow: 80, warnHigh: 180, critHigh: 200),
  VitalType.spo2: VitalThreshold(warnLow: 92, critLow: 88),
  VitalType.rr: VitalThreshold(warnLow: 30, critLow: 20, warnHigh: 65, critHigh: 75),
  VitalType.sbp: VitalThreshold(warnLow: 45, critLow: 35, warnHigh: 90, critHigh: 100),
  VitalType.dbp: VitalThreshold(warnLow: 25, critLow: 18, warnHigh: 60, critHigh: 70),
  VitalType.map: VitalThreshold(warnLow: 40, critLow: 30, warnHigh: 65, critHigh: 75),
};

final List<MonitoredPatient> _demoPatients = [
  MonitoredPatient(
    id: '1', name: 'Baby Kiran', gender: 'M', age: '2 days',
    diagnosis: 'PPHN', support: 'HFO Ventilator', bed: 'Bed 3', ward: 'NICU',
    dutyPhone: '+911234567890',
    thresholds: Map.from(_neonatalThresholds),
    vitals: { VitalType.hr: 88, VitalType.spo2: 87, VitalType.rr: 48, VitalType.sbp: 52, VitalType.dbp: 32, VitalType.map: 39 },
    sim: { VitalType.hr: SimConfig(base: 88, range: 10, maxDrift: 28), VitalType.spo2: SimConfig(base: 87, range: 3, maxDrift: 9), VitalType.rr: SimConfig(base: 48, range: 6, maxDrift: 14), VitalType.sbp: SimConfig(base: 52, range: 5, maxDrift: 12), VitalType.dbp: SimConfig(base: 32, range: 3, maxDrift: 8) },
  ),
  MonitoredPatient(
    id: '2', name: 'Mr. Arjun Kumar', gender: 'M', age: '58 years',
    diagnosis: 'Post CABG (Day 1)', support: 'T-piece / Noradrenaline', bed: 'Bed 2', ward: 'ICU',
    dutyPhone: '+911234567891',
    thresholds: { VitalType.hr: VitalThreshold(warnLow: 55, critLow: 45, warnHigh: 100, critHigh: 120), VitalType.spo2: VitalThreshold(warnLow: 94, critLow: 90), VitalType.rr: VitalThreshold(warnLow: 10, critLow: 6, warnHigh: 22, critHigh: 28), VitalType.sbp: VitalThreshold(warnLow: 90, critLow: 75, warnHigh: 140, critHigh: 165), VitalType.dbp: VitalThreshold(warnLow: 50, critLow: 40, warnHigh: 90, critHigh: 100), VitalType.map: VitalThreshold(warnLow: 65, critLow: 50, warnHigh: 100, critHigh: 110) },
    vitals: { VitalType.hr: 82, VitalType.spo2: 97, VitalType.rr: 16, VitalType.sbp: 118, VitalType.dbp: 72, VitalType.map: 87 },
    sim: { VitalType.hr: SimConfig(base: 82, range: 5, maxDrift: 15), VitalType.spo2: SimConfig(base: 97, range: 1, maxDrift: 3), VitalType.rr: SimConfig(base: 16, range: 2, maxDrift: 5), VitalType.sbp: SimConfig(base: 118, range: 6, maxDrift: 18), VitalType.dbp: SimConfig(base: 72, range: 4, maxDrift: 12) },
  ),
  MonitoredPatient(
    id: '4', name: 'Mr. Rajesh Mehta', gender: 'M', age: '62 years',
    diagnosis: 'Septic Shock + ARDS', support: 'Invasive Vent + Norad + Vasopressin', bed: 'Bed 4', ward: 'MICU',
    dutyPhone: '+911234567893',
    thresholds: { VitalType.hr: VitalThreshold(warnLow: 55, critLow: 45, warnHigh: 125, critHigh: 145), VitalType.spo2: VitalThreshold(warnLow: 90, critLow: 88), VitalType.rr: VitalThreshold(warnLow: 8, critLow: 6, warnHigh: 30, critHigh: 36), VitalType.sbp: VitalThreshold(warnLow: 90, critLow: 70, warnHigh: 160, critHigh: 180), VitalType.dbp: VitalThreshold(warnLow: 50, critLow: 40, warnHigh: 100, critHigh: 110), VitalType.map: VitalThreshold(warnLow: 65, critLow: 55, warnHigh: 100, critHigh: 110) },
    vitals: { VitalType.hr: 122, VitalType.spo2: 86, VitalType.rr: 28, VitalType.sbp: 78, VitalType.dbp: 44, VitalType.map: 55 },
    sim: { VitalType.hr: SimConfig(base: 122, range: 12, maxDrift: 25), VitalType.spo2: SimConfig(base: 86, range: 3, maxDrift: 8), VitalType.rr: SimConfig(base: 28, range: 4, maxDrift: 10), VitalType.sbp: SimConfig(base: 78, range: 10, maxDrift: 22), VitalType.dbp: SimConfig(base: 44, range: 6, maxDrift: 15) },
  ),
  MonitoredPatient(
    id: '3', name: 'Mrs. Sunita Devi', gender: 'F', age: '28 years',
    diagnosis: 'Severe Pre-eclampsia', support: 'IV MgSO₄ / Hydralazine PRN', bed: 'LR Bed 1', ward: 'Labor Room',
    dutyPhone: '+911234567892',
    thresholds: { VitalType.hr: VitalThreshold(warnLow: 60, critLow: 50, warnHigh: 110, critHigh: 130), VitalType.spo2: VitalThreshold(warnLow: 94, critLow: 90), VitalType.rr: VitalThreshold(warnLow: 12, critLow: 8, warnHigh: 24, critHigh: 30), VitalType.sbp: VitalThreshold(warnLow: 100, critLow: 80, warnHigh: 155, critHigh: 170), VitalType.dbp: VitalThreshold(warnLow: 60, critLow: 50, warnHigh: 100, critHigh: 110), VitalType.map: VitalThreshold(warnLow: 70, critLow: 55, warnHigh: 110, critHigh: 120) },
    vitals: { VitalType.hr: 96, VitalType.spo2: 98, VitalType.rr: 20, VitalType.sbp: 158, VitalType.dbp: 104, VitalType.map: 122 },
    sim: { VitalType.hr: SimConfig(base: 96, range: 6, maxDrift: 18), VitalType.spo2: SimConfig(base: 98, range: 1, maxDrift: 2), VitalType.rr: SimConfig(base: 20, range: 2, maxDrift: 6), VitalType.sbp: SimConfig(base: 158, range: 8, maxDrift: 20), VitalType.dbp: SimConfig(base: 104, range: 5, maxDrift: 15) },
  ),
];
