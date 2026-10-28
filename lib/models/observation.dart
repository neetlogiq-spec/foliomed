import 'row_parsing.dart';

/// Level of consciousness on the ACVPU scale (NEWS2).
enum Consciousness {
  alert('A', 'Alert'),
  confusion('C', 'New confusion'),
  voice('V', 'Responds to voice'),
  pain('P', 'Responds to pain'),
  unresponsive('U', 'Unresponsive');

  const Consciousness(this.code, this.label);
  final String code;
  final String label;

  static Consciousness? fromCode(String? v) {
    for (final c in values) {
      if (c.code == v) return c;
    }
    return null;
  }
}

/// One set of observations (`observations` row). Every value is optional;
/// the score is worked out in `lib/clinical/early_warning.dart`.
class Observation {
  const Observation({
    this.id = '',
    required this.patientId,
    this.wardId = '',
    required this.takenAt,
    this.respRate,
    this.spo2,
    this.spo2Scale2 = false,
    this.onOxygen,
    this.oxygenLpm,
    this.heartRate,
    this.systolicBp,
    this.diastolicBp,
    this.tempC,
    this.consciousness,
    this.pewsBehaviour,
    this.pewsCardio,
    this.pewsResp,
    this.pewsExtra = false,
    this.note,
    this.createdByName,
  });

  final String id;
  final String patientId;
  final String wardId;
  final DateTime takenAt;
  final int? respRate;
  final int? spo2;

  /// NEWS2 SpO2 scale 2 (target 88–92%, e.g. hypercapnic respiratory failure).
  final bool spo2Scale2;
  final bool? onOxygen;
  final double? oxygenLpm;
  final int? heartRate;
  final int? systolicBp;
  final int? diastolicBp;
  final double? tempC;
  final Consciousness? consciousness;

  /// Brighton PEWS components, 0–3 each, scored by staff from the chart.
  final int? pewsBehaviour;
  final int? pewsCardio;
  final int? pewsResp;

  /// +2: quarter-hourly nebulisers or persistent post-operative vomiting.
  final bool pewsExtra;
  final String? note;
  final String? createdByName;

  factory Observation.fromRow(DbRow r) => Observation(
        id: r['id'] as String? ?? '',
        patientId: r['patient_id'] as String? ?? '',
        wardId: r['ward_id'] as String? ?? '',
        takenAt: parseTimestamp(r['taken_at']),
        respRate: (r['resp_rate'] as num?)?.toInt(),
        spo2: (r['spo2'] as num?)?.toInt(),
        spo2Scale2: r['spo2_scale2'] as bool? ?? false,
        onOxygen: r['on_oxygen'] as bool?,
        oxygenLpm: (r['oxygen_lpm'] as num?)?.toDouble(),
        heartRate: (r['heart_rate'] as num?)?.toInt(),
        systolicBp: (r['systolic_bp'] as num?)?.toInt(),
        diastolicBp: (r['diastolic_bp'] as num?)?.toInt(),
        tempC: (r['temp_c'] as num?)?.toDouble(),
        consciousness: Consciousness.fromCode(r['consciousness'] as String?),
        pewsBehaviour: (r['pews_behaviour'] as num?)?.toInt(),
        pewsCardio: (r['pews_cardio'] as num?)?.toInt(),
        pewsResp: (r['pews_resp'] as num?)?.toInt(),
        pewsExtra: r['pews_extra'] as bool? ?? false,
        note: r['note'] as String?,
        createdByName: r['created_by_name'] as String?,
      );

  DbRow toRow() => {
        'patient_id': patientId,
        'ward_id': wardId,
        'taken_at': toTimestamp(takenAt),
        'resp_rate': respRate,
        'spo2': spo2,
        'spo2_scale2': spo2Scale2,
        'on_oxygen': onOxygen,
        'oxygen_lpm': oxygenLpm,
        'heart_rate': heartRate,
        'systolic_bp': systolicBp,
        'diastolic_bp': diastolicBp,
        'temp_c': tempC,
        'consciousness': consciousness?.code,
        'pews_behaviour': pewsBehaviour,
        'pews_cardio': pewsCardio,
        'pews_resp': pewsResp,
        'pews_extra': pewsExtra,
        'note': note == null || note!.trim().isEmpty ? null : note!.trim(),
      };

  /// "RR 32 · SpO₂ 94% (O₂) · HR 150 · BP 95/60 · 38.4 °C · A".
  String get summary => [
        if (respRate != null) 'RR $respRate',
        if (spo2 != null) 'SpO₂ $spo2%${onOxygen == true ? ' (O₂${oxygenLpm == null ? '' : ' ${_n(oxygenLpm!)} L/min'})' : ''}',
        if (heartRate != null) 'HR $heartRate',
        if (systolicBp != null) 'BP $systolicBp${diastolicBp == null ? '' : '/$diastolicBp'}',
        if (tempC != null) '${tempC!.toStringAsFixed(1)} °C',
        if (consciousness != null) consciousness!.code,
      ].join(' · ');

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
