import 'patient.dart';
import 'monitor_vitals.dart';

class MonitoredPatient {
  final String id;
  final String name;
  final String gender;
  final String age;
  final String diagnosis;
  final String support;
  final String bed;
  final String ward;
  final String wardId;
  final String dutyPhone;
  final Map<VitalType, VitalThreshold> thresholds;
  final Map<VitalType, double> vitals;
  final Map<VitalType, SimConfig> sim;

  const MonitoredPatient({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.diagnosis,
    required this.support,
    required this.bed,
    required this.ward,
    this.wardId = '',
    this.dutyPhone = '',
    required this.thresholds,
    required this.vitals,
    required this.sim,
  });

  MonitoredPatient copyWith({
    Map<VitalType, VitalThreshold>? thresholds,
    Map<VitalType, double>? vitals,
  }) {
    return MonitoredPatient(
      id: id,
      name: name,
      gender: gender,
      age: age,
      diagnosis: diagnosis,
      support: support,
      bed: bed,
      ward: ward,
      wardId: wardId,
      dutyPhone: dutyPhone,
      thresholds: thresholds ?? this.thresholds,
      vitals: vitals ?? this.vitals,
      sim: sim,
    );
  }

  String get worstSeverity {
    String worst = 'stable';
    for (final vt in [VitalType.hr, VitalType.spo2, VitalType.rr, VitalType.sbp, VitalType.dbp, VitalType.map]) {
      final t = thresholds[vt];
      final v = vitals[vt];
      if (t == null || v == null) continue;
      final s = t.severity(v);
      if (s == 'critical') return 'critical';
      if (s == 'warning') worst = 'warning';
    }
    return worst;
  }

  double get mapValue => ((vitals[VitalType.sbp] ?? 0) + 2 * (vitals[VitalType.dbp] ?? 0)) / 3;

  /// Build a MonitoredPatient from a real ward Patient with sensible
  /// adult defaults. Simulation engine starts from normal-range vitals.
  factory MonitoredPatient.fromPatient(Patient p, {String wardName = ''}) {
    return MonitoredPatient(
      id: p.id,
      name: p.name,
      gender: p.gender,
      age: '${p.age}y',
      diagnosis: p.diagnosis.isNotEmpty ? p.diagnosis : 'Not specified',
      support: '',
      bed: p.bedNumber.isNotEmpty ? 'Bed ${p.bedNumber}' : '',
      ward: wardName.isNotEmpty ? wardName : 'Ward',
      wardId: p.wardId,
      thresholds: const {
        VitalType.hr:   VitalThreshold(warnLow: 55,  critLow: 45,  warnHigh: 100, critHigh: 120),
        VitalType.spo2: VitalThreshold(warnLow: 94,  critLow: 90),
        VitalType.rr:   VitalThreshold(warnLow: 10,  critLow: 6,   warnHigh: 22,  critHigh: 28),
        VitalType.sbp:  VitalThreshold(warnLow: 90,  critLow: 75,  warnHigh: 140, critHigh: 165),
        VitalType.dbp:  VitalThreshold(warnLow: 50,  critLow: 40,  warnHigh: 90,  critHigh: 100),
        VitalType.map:  VitalThreshold(warnLow: 65,  critLow: 50,  warnHigh: 100, critHigh: 110),
      },
      vitals: const {
        VitalType.hr: 80, VitalType.spo2: 98, VitalType.rr: 16,
        VitalType.sbp: 120, VitalType.dbp: 75, VitalType.map: 90,
      },
      sim: const {
        VitalType.hr:   SimConfig(base: 80,  range: 4, maxDrift: 12),
        VitalType.spo2: SimConfig(base: 98,  range: 1, maxDrift: 3),
        VitalType.rr:   SimConfig(base: 16,  range: 2, maxDrift: 5),
        VitalType.sbp:  SimConfig(base: 120, range: 6, maxDrift: 18),
        VitalType.dbp:  SimConfig(base: 75,  range: 4, maxDrift: 12),
      },
    );
  }
}
