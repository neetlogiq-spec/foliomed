import 'row_parsing.dart';

/// Unit the patient's age is recorded in — neonates in days, infants in
/// months, everyone else in years.
enum AgeUnit {
  days('d', 'Days'),
  months('mo', 'Months'),
  years('y', 'Years');

  const AgeUnit(this.short, this.label);

  final String short;
  final String label;

  static AgeUnit fromName(String? value) => AgeUnit.values.firstWhere(
        (u) => u.name == value,
        orElse: () => AgeUnit.years,
      );
}

enum PatientStatus {
  admitted,
  discharged;

  static PatientStatus fromName(String? value) =>
      value == 'discharged' ? discharged : admitted;
}

class Patient {
  final String id;

  /// System-wide unique, immutable ID assigned by the database (FM000123).
  /// Empty only for a patient that hasn't been saved yet.
  final String patientCode;

  /// Optional hospital MRN / IP number.
  final String? hospitalId;
  final String name;
  final int age;
  final AgeUnit ageUnit;
  final String gender;
  final String wardId;
  final String bedNumber;
  final String diagnosis;
  final String? bloodGroup;
  final DateTime admittedAt;
  final PatientStatus status;
  final DateTime? dischargedAt;
  final String? dischargedBy;
  final String? dischargeSummary;

  /// Exact date and time of birth (newborns / PNC). When set, the age is
  /// derived from it instead of [age] / [ageUnit].
  final DateTime? bornAt;

  /// Gestational age at birth (newborns): completed weeks + days.
  final int? gestationWeeks;
  final int? gestationDays;

  /// Birth details (newborns). See `lib/clinical/birth_summary.dart`.
  final int? birthWeightG;
  final String? sizeForDates; // AGA / SGA / LGA
  final String? deliveryMode; // NVD / LSCS / Vacuum / Forceps
  final String? deliveryIndication; // e.g. "CPD"
  final String? motherBloodGroup;
  final int? apgar1;
  final int? apgar5;
  final bool? resuscitated;

  /// Unit (consultant team) within the ward, or null = unassigned.
  /// Changed through `move_patient_unit`, so [toRow] never writes it.
  final String? unitId;

  /// Mother (newborns): name, age, gravida/para (e.g. "G2P1").
  final String? motherName;
  final int? motherAge;
  final String? gravidaPara;

  /// AAP neurotoxicity risk factors (names of `NeuroRiskFactor`). Null =
  /// not yet assessed; empty = assessed, none. Saved separately
  /// (PatientService.setNeuroRiskFactors), so [toRow] never writes it.
  final List<String>? neuroRiskFactors;

  /// true/false once assessed, null before.
  bool? get neuroRisk => neuroRiskFactors == null ? null : neuroRiskFactors!.isNotEmpty;

  /// Status staff set by hand: 'stable' / 'watch' / 'sick' (`Acuity`), or
  /// null when not set, with an optional reason. Who and when are stamped
  /// by the server. Saved only through PatientService.setStatus, so
  /// [toRow] never writes these.
  final String? acuity;
  final String? acuityReason;
  final DateTime? acuitySetAt;
  final String? acuitySetByName;

  /// Organ support ticked by staff (names of `SupportTag`), mostly PICU.
  final List<String> supportTags;

  const Patient({
    required this.id,
    this.patientCode = '',
    this.hospitalId,
    required this.name,
    required this.age,
    this.ageUnit = AgeUnit.years,
    required this.gender,
    required this.wardId,
    required this.bedNumber,
    required this.diagnosis,
    this.bloodGroup,
    required this.admittedAt,
    this.status = PatientStatus.admitted,
    this.dischargedAt,
    this.dischargedBy,
    this.dischargeSummary,
    this.bornAt,
    this.gestationWeeks,
    this.gestationDays,
    this.birthWeightG,
    this.sizeForDates,
    this.deliveryMode,
    this.deliveryIndication,
    this.motherBloodGroup,
    this.apgar1,
    this.apgar5,
    this.resuscitated,
    this.unitId,
    this.motherName,
    this.motherAge,
    this.gravidaPara,
    this.neuroRiskFactors,
    this.acuity,
    this.acuityReason,
    this.acuitySetAt,
    this.acuitySetByName,
    this.supportTags = const [],
  });

  /// "39+2 wk", or null when not recorded.
  String? get gestationLabel => gestationWeeks == null
      ? null
      : '$gestationWeeks+${gestationDays ?? 0} wk';

  bool get isActive => status == PatientStatus.admitted;
  bool get isDischarged => status == PatientStatus.discharged;

  /// "38 h", "12 d", "5 mo", "61 y". From the birth time when known.
  String get ageLabel => bornAt == null
      ? '$age ${ageUnit.short}'
      : ageSinceBirthLabel(bornAt!, DateTime.now());

  /// Whole hours since birth, or null when the birth time isn't recorded.
  int? hoursSinceBirth([DateTime? now]) => bornAt == null
      ? null
      : (now ?? DateTime.now()).difference(bornAt!).inHours;

  /// Builds a patient from a `patients` row.
  factory Patient.fromRow(DbRow row) {
    final hospitalId = (row['hospital_id'] as String?)?.trim();
    return Patient(
      id: row['id'] as String? ?? '',
      patientCode: row['patient_code'] as String? ?? '',
      hospitalId: hospitalId == null || hospitalId.isEmpty ? null : hospitalId,
      name: row['name'] as String? ?? '',
      age: (row['age'] as num?)?.toInt() ?? 0,
      ageUnit: AgeUnit.fromName(row['age_unit'] as String?),
      gender: row['gender'] as String? ?? '',
      wardId: row['ward_id'] as String? ?? '',
      bedNumber: row['bed_number'] as String? ?? '',
      diagnosis: row['diagnosis'] as String? ?? '',
      bloodGroup: row['blood_group'] as String?,
      admittedAt: parseTimestamp(row['admitted_at']),
      status: row['status'] != null
          ? PatientStatus.fromName(row['status'] as String?)
          : ((row['is_active'] as bool? ?? true)
              ? PatientStatus.admitted
              : PatientStatus.discharged),
      dischargedAt: parseTimestampOrNull(row['discharged_at']),
      dischargedBy: row['discharged_by'] as String?,
      dischargeSummary: row['discharge_summary'] as String?,
      bornAt: parseTimestampOrNull(row['born_at']),
      gestationWeeks: (row['gestation_weeks'] as num?)?.toInt(),
      gestationDays: (row['gestation_days'] as num?)?.toInt(),
      birthWeightG: (row['birth_weight_g'] as num?)?.toInt(),
      sizeForDates: row['size_for_dates'] as String?,
      deliveryMode: row['delivery_mode'] as String?,
      deliveryIndication: row['delivery_indication'] as String?,
      motherBloodGroup: row['mother_blood_group'] as String?,
      apgar1: (row['apgar_1'] as num?)?.toInt(),
      apgar5: (row['apgar_5'] as num?)?.toInt(),
      resuscitated: row['resuscitated'] as bool?,
      unitId: row['unit_id'] as String?,
      motherName: row['mother_name'] as String?,
      motherAge: (row['mother_age'] as num?)?.toInt(),
      gravidaPara: row['gravida_para'] as String?,
      neuroRiskFactors: (row['neuro_risk_factors'] as List?)?.cast<String>(),
      acuity: row['acuity'] as String?,
      acuityReason: row['acuity_reason'] as String?,
      acuitySetAt: parseTimestampOrNull(row['acuity_set_at']),
      acuitySetByName: row['acuity_set_by_name'] as String?,
      supportTags: (row['support_tags'] as List?)?.cast<String>() ?? const [],
    );
  }

  /// Columns written on insert/update. `id` and `patient_code` are
  /// generated by Postgres; status changes only through the
  /// discharge / readmit / transfer functions.
  DbRow toRow() {
    final mrn = hospitalId?.trim();
    return {
      'name': name,
      'age': age,
      'age_unit': ageUnit.name,
      'gender': gender,
      'ward_id': wardId,
      'bed_number': bedNumber,
      'diagnosis': diagnosis,
      'blood_group': bloodGroup,
      'hospital_id': mrn == null || mrn.isEmpty ? null : mrn,
      'admitted_at': toTimestamp(admittedAt),
      'born_at': toTimestampOrNull(bornAt),
      'gestation_weeks': gestationWeeks,
      'gestation_days': gestationWeeks == null ? null : (gestationDays ?? 0),
      'birth_weight_g': birthWeightG,
      'size_for_dates': sizeForDates,
      'delivery_mode': deliveryMode,
      'delivery_indication': _blankToNull(deliveryIndication),
      'mother_blood_group': motherBloodGroup,
      'apgar_1': apgar1,
      'apgar_5': apgar5,
      'resuscitated': resuscitated,
      'mother_name': _blankToNull(motherName),
      'mother_age': motherAge,
      'gravida_para': _blankToNull(gravidaPara),
    };
  }

  Patient copyWith({
    String? name,
    int? age,
    AgeUnit? ageUnit,
    String? gender,
    String? bedNumber,
    String? diagnosis,
    String? bloodGroup,
    String? hospitalId,
    List<String>? neuroRiskFactors,
  }) {
    return Patient(
      id: id,
      patientCode: patientCode,
      hospitalId: hospitalId ?? this.hospitalId,
      name: name ?? this.name,
      age: age ?? this.age,
      ageUnit: ageUnit ?? this.ageUnit,
      gender: gender ?? this.gender,
      wardId: wardId,
      bedNumber: bedNumber ?? this.bedNumber,
      diagnosis: diagnosis ?? this.diagnosis,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      admittedAt: admittedAt,
      status: status,
      dischargedAt: dischargedAt,
      dischargedBy: dischargedBy,
      dischargeSummary: dischargeSummary,
      bornAt: bornAt,
      gestationWeeks: gestationWeeks,
      gestationDays: gestationDays,
      birthWeightG: birthWeightG,
      sizeForDates: sizeForDates,
      deliveryMode: deliveryMode,
      deliveryIndication: deliveryIndication,
      motherBloodGroup: motherBloodGroup,
      apgar1: apgar1,
      apgar5: apgar5,
      resuscitated: resuscitated,
      unitId: unitId,
      motherName: motherName,
      motherAge: motherAge,
      gravidaPara: gravidaPara,
      neuroRiskFactors: neuroRiskFactors ?? this.neuroRiskFactors,
      acuity: acuity,
      acuityReason: acuityReason,
      acuitySetAt: acuitySetAt,
      acuitySetByName: acuitySetByName,
      supportTags: supportTags,
    );
  }

  static String? _blankToNull(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1][0]
        : (parts.first.length > 1 ? parts.first[1] : '');
    return (first + second).toUpperCase();
  }
}

/// Age since an exact birth time, at the precision clinicians use:
/// hours for the first week, then days, months, years.
String ageSinceBirthLabel(DateTime bornAt, DateTime now) {
  final diff = now.difference(bornAt);
  if (diff.isNegative) return '0 h';
  if (diff.inHours < 24 * 7) return '${diff.inHours} h';
  if (diff.inDays < 31) return '${diff.inDays} d';
  var months = (now.year - bornAt.year) * 12 + now.month - bornAt.month;
  if (now.day < bornAt.day) months--;
  if (months < 24) return '$months mo';
  return '${months ~/ 12} y';
}
