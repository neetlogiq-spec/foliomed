import '../clinical/labs.dart';
import 'row_parsing.dart';

/// One lab result on a patient: a number (with unit and the report's
/// reference range when known) or a text result such as a culture.
class LabResult {
  const LabResult({
    required this.id,
    required this.patientId,
    required this.testKey,
    required this.testName,
    required this.sampledAt,
    this.value,
    this.valueText,
    this.unit = '',
    this.refLow,
    this.refHigh,
    this.flag,
    this.source = 'manual',
    this.createdByName,
  });

  final String id;
  final String patientId;
  final String testKey;
  final String testName;
  final double? value;
  final String? valueText;
  final String unit;
  final double? refLow, refHigh;
  final LabFlag? flag;
  final DateTime sampledAt;
  final String source;
  final String? createdByName;

  static String _n(double v) => v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  /// "9.1 g/dL" or the text result.
  String get display => value == null ? (valueText ?? '') : '${_n(value!)}${unit.isEmpty ? '' : ' $unit'}';

  /// "Hb 9.1 g/dL ↓".
  String get line => '$testName $display${flag == null ? '' : ' ${flag!.mark}'}';

  String? get refText => refLow == null && refHigh == null
      ? null
      : refLow == null
      ? '< ${_n(refHigh!)}'
      : refHigh == null
      ? '> ${_n(refLow!)}'
      : '${_n(refLow!)}–${_n(refHigh!)}';

  static LabResult fromRow(DbRow row) => LabResult(
    id: row['id'] as String? ?? '',
    patientId: row['patient_id'] as String? ?? '',
    testKey: row['test_key'] as String? ?? '',
    testName: row['test_name'] as String? ?? '',
    value: (row['value'] as num?)?.toDouble(),
    valueText: row['value_text'] as String?,
    unit: row['unit'] as String? ?? '',
    refLow: (row['ref_low'] as num?)?.toDouble(),
    refHigh: (row['ref_high'] as num?)?.toDouble(),
    flag: LabFlag.fromName(row['flag'] as String?),
    sampledAt: parseTimestamp(row['sampled_at']),
    source: row['source'] as String? ?? 'manual',
    createdByName: row['created_by_name'] as String?,
  );
}

/// A result about to be saved.
class LabEntry {
  const LabEntry({required this.test, this.value, this.text, this.refLow, this.refHigh});
  final LabTest test;
  final double? value;
  final String? text;
  final double? refLow, refHigh;

  LabFlag? get flag => flagFor(test, value, refLow: refLow, refHigh: refHigh);

  String get line {
    if (value == null) return '${test.name}: ${text ?? ''}';
    final v = LabResult._n(value!);
    return '${test.name} $v${test.unit.isEmpty ? '' : ' ${test.unit}'}${flag == null ? '' : ' ${flag!.mark}'}';
  }

  Map<String, Object?> toJson() => {
    'test_key': test.key,
    'test_name': test.name,
    if (value != null) 'value': value,
    if (text != null) 'value_text': text,
    'unit': test.unit,
    if (refLow != null) 'ref_low': refLow,
    if (refHigh != null) 'ref_high': refHigh,
    if (flag != null) 'flag': flag!.name,
  };
}

/// The timeline note for a batch: flagged results first.
String labSummary(List<LabEntry> entries) {
  final flagged = entries.where((e) => e.flag != null).toList()
    ..sort((a, b) => (b.flag!.critical ? 1 : 0) - (a.flag!.critical ? 1 : 0));
  final rest = entries.where((e) => e.flag == null);
  return 'Labs: ${[...flagged, ...rest].map((e) => e.line).join(', ')}.';
}
