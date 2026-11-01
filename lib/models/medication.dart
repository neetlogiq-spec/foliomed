import 'row_parsing.dart';

/// Where a medicine sits: given on this admission, taken at home before
/// admission, or an important earlier drug.
enum MedContext {
  inpatient('This admission'),
  home('Home medicine'),
  past('Previously');

  const MedContext(this.label);
  final String label;

  static MedContext fromName(String? v) => values.firstWhere((c) => c.name == v, orElse: () => inpatient);
}

/// A medicine on the patient's record. Rows change only through RPCs
/// (add / change / stop_medication), which also write timeline notes.
class PatientMedication {
  const PatientMedication({
    required this.id,
    required this.patientId,
    required this.context,
    required this.drugName,
    required this.createdAt,
    this.drugKey,
    this.dose,
    this.doseUnit = '',
    this.route = '',
    this.frequency = '',
    this.indication,
    this.infoSource,
    this.note,
    this.startedOn,
    this.createdByName,
    this.stoppedAt,
    this.stoppedByName,
    this.stopReason,
  });

  final String id;
  final String patientId;
  final MedContext context;
  final String? drugKey;
  final String drugName;
  final double? dose;
  final String doseUnit;
  final String route;
  final String frequency;
  final String? indication;
  final String? infoSource;
  final String? note;
  final DateTime? startedOn;
  final DateTime createdAt;
  final String? createdByName;
  final DateTime? stoppedAt;
  final String? stoppedByName;
  final String? stopReason;

  bool get isActive => context == MedContext.inpatient && stoppedAt == null;

  /// "30 mg/kg IV TDS" (without the name).
  String get regimen => [
        if (dose != null) '${_n(dose!)}${doseUnit.isEmpty ? '' : ' $doseUnit'}',
        if (route.isNotEmpty) route,
        if (frequency.isNotEmpty) frequency,
      ].join(' ');

  /// "Amoxicillin 30 mg/kg IV TDS".
  String get line => regimen.isEmpty ? drugName : '$drugName $regimen';

  static String _n(double v) =>
      v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  static PatientMedication fromRow(DbRow row) => PatientMedication(
        id: row['id'] as String? ?? '',
        patientId: row['patient_id'] as String? ?? '',
        context: MedContext.fromName(row['context'] as String?),
        drugKey: row['drug_key'] as String?,
        drugName: row['drug_name'] as String? ?? '',
        dose: (row['dose'] as num?)?.toDouble(),
        doseUnit: row['dose_unit'] as String? ?? '',
        route: row['route'] as String? ?? '',
        frequency: row['frequency'] as String? ?? '',
        indication: row['indication'] as String?,
        infoSource: row['info_source'] as String?,
        note: row['note'] as String?,
        startedOn: parseTimestampOrNull(row['started_on']),
        createdAt: parseTimestamp(row['created_at']),
        createdByName: row['created_by_name'] as String?,
        stoppedAt: parseTimestampOrNull(row['stopped_at']),
        stoppedByName: row['stopped_by_name'] as String?,
        stopReason: row['stop_reason'] as String?,
      );
}

/// Start / change / stop history of an admission medicine.
class MedicationEvent {
  const MedicationEvent({
    required this.medicationId,
    required this.kind,
    required this.summary,
    required this.at,
    this.byName,
  });

  final String medicationId;

  /// 'start', 'change' or 'stop'.
  final String kind;
  final String summary;
  final DateTime at;
  final String? byName;

  static MedicationEvent fromRow(DbRow row) => MedicationEvent(
        medicationId: row['medication_id'] as String? ?? '',
        kind: row['kind'] as String? ?? '',
        summary: row['summary'] as String? ?? '',
        at: parseTimestamp(row['at']),
        byName: row['by_name'] as String?,
      );
}

enum AllergySeverity {
  mild('Mild'),
  moderate('Moderate'),
  severe('Severe'),
  unknown('Not known');

  const AllergySeverity(this.label);
  final String label;

  static AllergySeverity fromName(String? v) => values.firstWhere((s) => s.name == v, orElse: () => unknown);
}

enum AllergyKind {
  drug('Drug'),
  food('Food'),
  anaesthesia('Anaesthesia'),
  other('Other');

  const AllergyKind(this.label);
  final String label;

  static AllergyKind fromName(String? v) => values.firstWhere((k) => k.name == v, orElse: () => other);
}

class PatientAllergy {
  const PatientAllergy({
    required this.id,
    required this.patientId,
    required this.substance,
    required this.createdAt,
    this.reaction,
    this.severity = AllergySeverity.unknown,
    this.kind = AllergyKind.drug,
    this.infoSource,
    this.createdByName,
  });

  final String id;
  final String patientId;
  final String substance;
  final String? reaction;
  final AllergySeverity severity;
  final AllergyKind kind;
  final String? infoSource;
  final DateTime createdAt;
  final String? createdByName;

  /// "Penicillin (urticaria, moderate)".
  String get line {
    final extra = [
      if (reaction != null && reaction!.isNotEmpty) reaction!,
      if (severity != AllergySeverity.unknown) severity.label.toLowerCase(),
    ];
    return extra.isEmpty ? substance : '$substance (${extra.join(', ')})';
  }

  static PatientAllergy fromRow(DbRow row) => PatientAllergy(
        id: row['id'] as String? ?? '',
        patientId: row['patient_id'] as String? ?? '',
        substance: row['substance'] as String? ?? '',
        reaction: row['reaction'] as String?,
        severity: AllergySeverity.fromName(row['severity'] as String?),
        kind: AllergyKind.fromName(row['kind'] as String?),
        infoSource: row['info_source'] as String?,
        createdAt: parseTimestamp(row['created_at']),
        createdByName: row['created_by_name'] as String?,
      );
}
