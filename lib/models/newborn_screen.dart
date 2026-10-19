import 'row_parsing.dart';

/// Standard newborn investigations sent at 48 or 72 hours of life.
const List<String> kNewbornInvestigations = [
  'CBC',
  'TSH',
  'Blood grouping',
  'TSB (total, direct, indirect)',
  'RFT (urea, creatinine, electrolytes)',
  'OAE',
];

enum ScreenStatus {
  planned,
  sent,
  resulted;

  static ScreenStatus fromName(String? v) =>
      ScreenStatus.values.firstWhere((s) => s.name == v, orElse: () => planned);
}

/// The plan to send the newborn investigations, and their results.
class NewbornScreen {
  const NewbornScreen({
    required this.id,
    required this.patientId,
    required this.wardId,
    required this.plannedHours,
    required this.leadHours,
    required this.dueAt,
    required this.status,
    this.sentAt,
    this.sentByName,
    this.results = const NewbornResults(),
    this.resultedAt,
    this.resultedByName,
  });

  final String id;
  final String patientId;
  final String wardId;
  final int plannedHours;
  final int leadHours;
  final DateTime dueAt;
  final ScreenStatus status;
  final DateTime? sentAt;
  final String? sentByName;
  final NewbornResults results;
  final DateTime? resultedAt;
  final String? resultedByName;

  factory NewbornScreen.fromRow(DbRow row) => NewbornScreen(
        id: row['id'] as String? ?? '',
        patientId: row['patient_id'] as String? ?? '',
        wardId: row['ward_id'] as String? ?? '',
        plannedHours: (row['planned_hours'] as num?)?.toInt() ?? 48,
        leadHours: (row['lead_hours'] as num?)?.toInt() ?? 12,
        dueAt: parseTimestamp(row['due_at']),
        status: ScreenStatus.fromName(row['status'] as String?),
        sentAt: parseTimestampOrNull(row['sent_at']),
        sentByName: row['sent_by_name'] as String?,
        results: NewbornResults.fromJson(
            (row['results'] as Map?)?.cast<String, dynamic>() ?? const {}),
        resultedAt: parseTimestampOrNull(row['resulted_at']),
        resultedByName: row['resulted_by_name'] as String?,
      );
}

enum OaeResult {
  pass('Pass'),
  refer('Refer'),
  notDone('Not done');

  const OaeResult(this.label);
  final String label;

  static OaeResult? fromName(String? v) {
    for (final r in OaeResult.values) {
      if (r.name == v) return r;
    }
    return null;
  }
}

enum BiliUnit {
  mgdl('mg/dL'),
  umol('µmol/L');

  const BiliUnit(this.label);
  final String label;
}

/// Results of the newborn investigations. Every field is optional — labs
/// come back at different times and results can be corrected later.
class NewbornResults {
  const NewbornResults({
    this.sampledAt,
    this.hb,
    this.tlc,
    this.platelets,
    this.hct,
    this.tsh,
    this.babyBloodGroup,
    this.motherBloodGroup,
    this.biliUnit = BiliUnit.mgdl,
    this.tsbTotal,
    this.tsbDirect,
    this.urea,
    this.creatinine,
    this.sodium,
    this.potassium,
    this.chloride,
    this.oaeRight,
    this.oaeLeft,
    this.remarks,
  });

  /// When the blood was drawn — the bilirubin hour of age comes from this.
  final DateTime? sampledAt;

  // CBC
  final double? hb; // g/dL
  final double? tlc; // ×10³/µL
  final double? platelets; // ×10³/µL
  final double? hct; // %

  final double? tsh; // µIU/mL

  final String? babyBloodGroup;
  final String? motherBloodGroup;

  // Bilirubin
  final BiliUnit biliUnit;
  final double? tsbTotal;
  final double? tsbDirect;

  /// Indirect (unconjugated) = total − direct.
  double? get tsbIndirect => tsbTotal == null || tsbDirect == null
      ? null
      : (tsbTotal! - tsbDirect!).clamp(0, double.infinity).toDouble();

  // RFT
  final double? urea; // mg/dL
  final double? creatinine; // mg/dL
  final double? sodium; // mmol/L
  final double? potassium; // mmol/L
  final double? chloride; // mmol/L

  final OaeResult? oaeRight;
  final OaeResult? oaeLeft;

  final String? remarks;

  bool get isEmpty => toJson().keys.every((k) => k == 'bili_unit');

  Map<String, dynamic> toJson() => {
        if (sampledAt != null) 'sampled_at': sampledAt!.toUtc().toIso8601String(),
        if (hb != null) 'hb': hb,
        if (tlc != null) 'tlc': tlc,
        if (platelets != null) 'platelets': platelets,
        if (hct != null) 'hct': hct,
        if (tsh != null) 'tsh': tsh,
        if (_s(babyBloodGroup) != null) 'baby_blood_group': babyBloodGroup!.trim(),
        if (_s(motherBloodGroup) != null) 'mother_blood_group': motherBloodGroup!.trim(),
        'bili_unit': biliUnit.name,
        if (tsbTotal != null) 'tsb_total': tsbTotal,
        if (tsbDirect != null) 'tsb_direct': tsbDirect,
        if (urea != null) 'urea': urea,
        if (creatinine != null) 'creatinine': creatinine,
        if (sodium != null) 'sodium': sodium,
        if (potassium != null) 'potassium': potassium,
        if (chloride != null) 'chloride': chloride,
        if (oaeRight != null) 'oae_right': oaeRight!.name,
        if (oaeLeft != null) 'oae_left': oaeLeft!.name,
        if (_s(remarks) != null) 'remarks': remarks!.trim(),
      };

  factory NewbornResults.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return NewbornResults(
      sampledAt: parseTimestampOrNull(j['sampled_at']),
      hb: d('hb'),
      tlc: d('tlc'),
      platelets: d('platelets'),
      hct: d('hct'),
      tsh: d('tsh'),
      babyBloodGroup: j['baby_blood_group'] as String?,
      motherBloodGroup: j['mother_blood_group'] as String?,
      biliUnit: j['bili_unit'] == 'umol' ? BiliUnit.umol : BiliUnit.mgdl,
      tsbTotal: d('tsb_total'),
      tsbDirect: d('tsb_direct'),
      urea: d('urea'),
      creatinine: d('creatinine'),
      sodium: d('sodium'),
      potassium: d('potassium'),
      chloride: d('chloride'),
      oaeRight: OaeResult.fromName(j['oae_right'] as String?),
      oaeLeft: OaeResult.fromName(j['oae_left'] as String?),
      remarks: j['remarks'] as String?,
    );
  }

  /// One line for the patient's timeline.
  String summary({String? biliAssessment}) {
    String n(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    final parts = <String>[
      if (hb != null || tlc != null || platelets != null)
        'CBC: ${[
          if (hb != null) 'Hb ${n(hb!)}',
          if (tlc != null) 'TLC ${n(tlc!)}',
          if (platelets != null) 'Plt ${n(platelets!)}',
          if (hct != null) 'Hct ${n(hct!)}%',
        ].join(', ')}',
      if (tsh != null) 'TSH ${n(tsh!)} µIU/mL',
      if (_s(babyBloodGroup) != null)
        'Blood group ${babyBloodGroup!.trim()}'
            '${_s(motherBloodGroup) != null ? ' (mother ${motherBloodGroup!.trim()})' : ''}',
      if (tsbTotal != null)
        'TSB ${n(tsbTotal!)}'
            '${tsbDirect != null ? ' / D ${n(tsbDirect!)} / I ${n(tsbIndirect!)}' : ''}'
            ' ${biliUnit.label}',
      if ([urea, creatinine, sodium, potassium, chloride].any((v) => v != null))
        'RFT: ${[
          if (urea != null) 'Urea ${n(urea!)}',
          if (creatinine != null) 'Cr ${n(creatinine!)}',
          if (sodium != null) 'Na ${n(sodium!)}',
          if (potassium != null) 'K ${n(potassium!)}',
          if (chloride != null) 'Cl ${n(chloride!)}',
        ].join(', ')}',
      if (oaeRight != null || oaeLeft != null)
        'OAE R ${oaeRight?.label ?? '—'} / L ${oaeLeft?.label ?? '—'}',
      if (biliAssessment != null) biliAssessment,
      if (_s(remarks) != null) remarks!.trim(),
    ];
    return parts.join('. ');
  }

  static String? _s(String? v) => v == null || v.trim().isEmpty ? null : v;
}
