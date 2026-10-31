import 'row_parsing.dart';

/// A ward's own settings for one drug in the list: vial strength, standard
/// mixture, a unit note, hidden — and who signed it off. Written only by
/// `set_ward_drug` (owner) and `check_ward_drug` (the ward's doctors).
class WardDrugSetting {
  const WardDrugSetting({
    required this.wardId,
    required this.drugKey,
    this.vialPerMl,
    this.mixAt1MlH,
    this.hidden = false,
    this.unitNote,
    this.checkedSignature,
    this.checkedByName,
    this.checkedAt,
    this.updatedByName,
  });

  final String wardId;
  final String drugKey;

  /// Null = FolioMed's default.
  final double? vialPerMl;
  final double? mixAt1MlH;
  final bool hidden;
  final String? unitNote;

  /// What was signed off (see `drugSignature`); null = not signed off.
  final String? checkedSignature;
  final String? checkedByName;
  final DateTime? checkedAt;
  final String? updatedByName;

  static WardDrugSetting fromRow(DbRow row) => WardDrugSetting(
    wardId: row['ward_id'] as String? ?? '',
    drugKey: row['drug_key'] as String? ?? '',
    vialPerMl: (row['vial_per_ml'] as num?)?.toDouble(),
    mixAt1MlH: (row['mix_at_1ml_h'] as num?)?.toDouble(),
    hidden: row['hidden'] as bool? ?? false,
    unitNote: row['unit_note'] as String?,
    checkedSignature: row['checked_signature'] as String?,
    checkedByName: row['checked_by_name'] as String?,
    checkedAt: parseTimestampOrNull(row['checked_at']),
    updatedByName: row['updated_by_name'] as String?,
  );
}
