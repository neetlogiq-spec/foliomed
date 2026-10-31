import 'row_parsing.dart';

/// An infusion running (or once run) on a patient. Rows change only through
/// the start/change/stop RPCs, which also write Infusion notes.
class PatientInfusion {
  const PatientInfusion({
    required this.id,
    required this.patientId,
    required this.wardId,
    required this.drugName,
    required this.dose,
    required this.doseUnit,
    required this.rateMlH,
    required this.concentration,
    required this.concUnit,
    required this.startedAt,
    this.drugKey,
    this.syringe = '',
    this.weightKg,
    this.startedByName,
    this.changedAt,
    this.changedByName,
    this.stoppedAt,
    this.stoppedByName,
  });

  final String id;
  final String patientId;
  final String wardId;
  final String? drugKey;
  final String drugName;
  final double dose;
  final String doseUnit;
  final double rateMlH;

  /// Drug per mL of the syringe, in [concUnit] (e.g. "mg/mL").
  final double concentration;
  final String concUnit;

  /// "30 mg in 50 mL".
  final String syringe;
  final double? weightKg;
  final DateTime startedAt;
  final String? startedByName;
  final DateTime? changedAt;
  final String? changedByName;
  final DateTime? stoppedAt;
  final String? stoppedByName;

  bool get isRunning => stoppedAt == null;

  /// "Dopamine 10 mcg/kg/min (1 mL/h)".
  String get line => '$drugName ${_n(dose)} $doseUnit (${_n(rateMlH)} mL/h)';

  static String _n(double v) {
    var s = v.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

  static PatientInfusion fromRow(DbRow row) => PatientInfusion(
    id: row['id'] as String? ?? '',
    patientId: row['patient_id'] as String? ?? '',
    wardId: row['ward_id'] as String? ?? '',
    drugKey: row['drug_key'] as String?,
    drugName: row['drug_name'] as String? ?? '',
    dose: _d(row['dose']),
    doseUnit: row['dose_unit'] as String? ?? '',
    rateMlH: _d(row['rate_ml_h']),
    concentration: _d(row['concentration']),
    concUnit: row['conc_unit'] as String? ?? '',
    syringe: row['syringe'] as String? ?? '',
    weightKg: (row['weight_kg'] as num?)?.toDouble(),
    startedAt: parseTimestamp(row['started_at']),
    startedByName: row['started_by_name'] as String?,
    changedAt: parseTimestampOrNull(row['changed_at']),
    changedByName: row['changed_by_name'] as String?,
    stoppedAt: parseTimestampOrNull(row['stopped_at']),
    stoppedByName: row['stopped_by_name'] as String?,
  );
}
