import '../clinical/bilirubin.dart';
import 'row_parsing.dart';

class BilirubinReading {
  const BilirubinReading({
    required this.id,
    required this.patientId,
    required this.measuredAt,
    required this.value,
    required this.isUmol,
    required this.transcutaneous,
    this.fromScreen = false,
    this.createdByName,
  });

  final String id;
  final String patientId;
  final DateTime measuredAt;
  final double value;
  final bool isUmol;
  final bool transcutaneous;

  /// Came from saved investigation results (edit those, not this row).
  final bool fromScreen;
  final String? createdByName;

  double get umol => isUmol ? value : mgdlToUmol(value);

  factory BilirubinReading.fromRow(DbRow r) => BilirubinReading(
        id: r['id'] as String? ?? '',
        patientId: r['patient_id'] as String? ?? '',
        measuredAt: parseTimestamp(r['measured_at']),
        value: (r['value'] as num?)?.toDouble() ?? 0,
        isUmol: r['unit'] == 'umol',
        transcutaneous: r['method'] == 'transcutaneous',
        fromScreen: r['screen_id'] != null,
        createdByName: r['created_by_name'] as String?,
      );
}

enum PhototherapyKind {
  single('Single'),
  double_('Double'),
  intensive('Intensive');

  const PhototherapyKind(this.label);
  final String label;

  String get dbName => this == double_ ? 'double' : name;

  static PhototherapyKind fromDb(String? v) => switch (v) {
        'double' => double_,
        'intensive' => intensive,
        _ => single,
      };
}

class PhototherapySession {
  const PhototherapySession({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.startedAt,
    this.stoppedAt,
  });

  final String id;
  final String patientId;
  final PhototherapyKind kind;
  final DateTime startedAt;
  final DateTime? stoppedAt;

  bool get isRunning => stoppedAt == null;

  Duration durationAt(DateTime now) => (stoppedAt ?? now).difference(startedAt);

  factory PhototherapySession.fromRow(DbRow r) => PhototherapySession(
        id: r['id'] as String? ?? '',
        patientId: r['patient_id'] as String? ?? '',
        kind: PhototherapyKind.fromDb(r['kind'] as String?),
        startedAt: parseTimestamp(r['started_at']),
        stoppedAt: parseTimestampOrNull(r['stopped_at']),
      );
}

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.patientId,
    required this.measuredAt,
    required this.grams,
    this.createdByName,
  });

  final String id;
  final String patientId;
  final DateTime measuredAt;
  final int grams;
  final String? createdByName;

  factory WeightEntry.fromRow(DbRow r) => WeightEntry(
        id: r['id'] as String? ?? '',
        patientId: r['patient_id'] as String? ?? '',
        measuredAt: parseTimestamp(r['measured_at']),
        grams: (r['grams'] as num?)?.toInt() ?? 0,
        createdByName: r['created_by_name'] as String?,
      );
}

enum WeightFlag { ok, watch, alert }

/// Change from birth weight. Loss beyond 10% is the usual red flag for
/// feeding problems / dehydration; 7–10% warrants a closer look.
class WeightChange {
  WeightChange(this.birthGrams, this.grams);

  final int birthGrams;
  final int grams;

  double get percent => (grams - birthGrams) / birthGrams * 100;

  WeightFlag get flag => percent <= -10
      ? WeightFlag.alert
      : percent <= -7
          ? WeightFlag.watch
          : WeightFlag.ok;

  /// "−6.5%" / "+2.0%".
  String get label {
    final p = percent;
    return '${p < 0 ? '−' : '+'}${p.abs().toStringAsFixed(1)}%';
  }
}
