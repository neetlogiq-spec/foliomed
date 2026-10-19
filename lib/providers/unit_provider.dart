import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ward_unit.dart';
import '../services/unit_service.dart';

/// Units for the user's wards, the shared Ward ▸ Unit filter used by Today
/// and Patients, and each person's "My unit" per ward (kept on this
/// device).
class UnitProvider extends ChangeNotifier {
  UnitProvider({UnitService? service}) : _service = service ?? UnitService();

  final UnitService _service;
  static const _myUnitsKey = 'my_units_v1';
  static const _scopeKey = 'patient_scope_v1';

  StreamSubscription<List<WardUnit>>? _sub;
  List<String> _wardIds = const [];
  List<WardUnit> _units = const [];
  Map<String, String> _myUnits = const {}; // wardId → unitId
  PatientScope _scope = const PatientScope.all();
  bool _loadedPrefs = false;

  List<WardUnit> get units => _units;
  PatientScope get scope => _scope;
  Map<String, String> get myUnits => _myUnits;

  List<WardUnit> unitsOf(String wardId) =>
      _units.where((u) => u.wardId == wardId).toList();

  WardUnit? unitById(String? id) {
    if (id == null) return null;
    for (final u in _units) {
      if (u.id == id) return u;
    }
    return null;
  }

  String? myUnitFor(String wardId) => _myUnits[wardId];

  void subscribe(List<String> wardIds) {
    if (listEquals(wardIds, _wardIds) && _sub != null) return;
    _wardIds = List.of(wardIds);
    _sub?.cancel();
    _sub = _service.forWards(_wardIds).listen((rows) {
      _units = rows;
      _dropStale();
      notifyListeners();
    }, onError: (Object e) => debugPrint('UnitProvider stream: $e'));
    if (!_loadedPrefs) _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _loadedPrefs = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_myUnitsKey) ?? const [];
      _myUnits = {
        for (final e in raw)
          if (e.contains('=')) e.split('=').first: e.split('=').last,
      };
      _scope = PatientScope.decode(prefs.getString(_scopeKey));
      notifyListeners();
    } catch (e) {
      debugPrint('UnitProvider prefs: $e');
    }
  }

  /// Forget a scope / my-unit whose ward or unit no longer exists.
  void _dropStale() {
    final s = _scope;
    if (s.wardId != null && !_wardIds.contains(s.wardId)) {
      _scope = const PatientScope.all();
    } else if (s.unitId != null && unitById(s.unitId) == null) {
      _scope = PatientScope.ward(s.wardId!);
    }
    final valid = {for (final u in _units) u.id};
    if (_myUnits.values.any((id) => !valid.contains(id))) {
      _myUnits = {
        for (final e in _myUnits.entries)
          if (valid.contains(e.value)) e.key: e.value,
      };
    }
  }

  Future<void> setScope(PatientScope scope) async {
    _scope = scope;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scopeKey, scope.encode());
    } catch (_) {}
  }

  /// Sets (or clears, with null) "My unit" for a ward, and switches the
  /// lists to it.
  Future<void> setMyUnit(String wardId, String? unitId) async {
    _myUnits = {
      for (final e in _myUnits.entries)
        if (e.key != wardId) e.key: e.value,
      if (unitId != null) wardId: unitId,
    };
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _myUnitsKey, [for (final e in _myUnits.entries) '${e.key}=${e.value}']);
    } catch (_) {}
    await setScope(unitId == null
        ? PatientScope.ward(wardId)
        : PatientScope.unit(wardId, unitId));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
