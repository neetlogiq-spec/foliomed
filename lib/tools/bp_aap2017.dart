/// Lookup and staging for the AAP 2017 childhood BP tables (data in
/// `bp_aap2017_data.dart`).
library;

import 'bp_aap2017_data.dart';

export 'bp_aap2017_data.dart';

/// Age range the tables cover, in completed years.
const int kAapBpFromYears = 1;
const int kAapBpToYears = 17;

/// From 13 years AAP stages with fixed adult cut-offs instead of centiles.
const int kAapAdultCutoffsFromYears = 13;

/// The BP percentiles for one child: the table row for the age and the
/// height column nearest the measured height.
class AapBpLevels {
  const AapBpLevels({
    required this.years,
    required this.heightCentile,
    required this.columnHeightCm,
    required this.sbp,
    required this.dbp,
  });

  final int years;

  /// The height percentile of the column used (5–95).
  final int heightCentile;
  final double columnHeightCm;

  /// (50th, 90th, 95th) percentiles.
  final (int, int, int) sbp, dbp;

  int get sbpStage2 => sbp.$3 + 12;
  int get dbpStage2 => dbp.$3 + 12;
}

/// Levels for a [male] child of [years] (completed) and [heightCm], or
/// null outside 1–17 years. Heights below the 5th or above the 95th
/// percentile column use that end column; an exact tie takes the shorter
/// column (lower thresholds).
AapBpLevels? aapBpLevels({required bool male, required int years, required double heightCm}) {
  if (years < kAapBpFromYears || years > kAapBpToYears) return null;
  final row = (male ? kAapBpBoys : kAapBpGirls)[years - kAapBpFromYears];
  var col = 0;
  for (var i = 1; i < row.heightsCm.length; i++) {
    if ((row.heightsCm[i] - heightCm).abs() < (row.heightsCm[col] - heightCm).abs()) col = i;
  }
  (int, int, int) at(List<List<int>> rows) => (rows[0][col], rows[1][col], rows[2][col]);
  return AapBpLevels(
    years: years,
    heightCentile: kAapHeightCentiles[col],
    columnHeightCm: row.heightsCm[col],
    sbp: at(row.sbp),
    dbp: at(row.dbp),
  );
}

enum AapBpCategory {
  normal('Normal BP'),
  elevated('Elevated BP'),
  stage1('Stage 1 hypertension'),
  stage2('Stage 2 hypertension');

  const AapBpCategory(this.label);
  final String label;
}

/// (elevated, stage 1, stage 2) lower bounds for one component.
typedef _Bounds = (int, int, int);

AapBpCategory _place(int value, _Bounds b) => value >= b.$3
    ? AapBpCategory.stage2
    : value >= b.$2
        ? AapBpCategory.stage1
        : value >= b.$1
            ? AapBpCategory.elevated
            : AapBpCategory.normal;

/// AAP 2017 Table 3. Under 13 years: elevated ≥90th (or ≥120/80), stage 1
/// ≥95th (or ≥130/80), stage 2 ≥95th + 12 mmHg (or ≥140/90), whichever is
/// lower. From 13 years: elevated 120–129/<80, stage 1 130–139 or 80–89,
/// stage 2 ≥140 or ≥90. The child takes the higher of the systolic and
/// diastolic categories. Null when neither reading is given.
AapBpCategory? aapBpCategory(AapBpLevels l, {int? sbp, int? dbp}) {
  if (sbp == null && dbp == null) return null;
  final adult = l.years >= kAapAdultCutoffsFromYears;
  int lower(int a, int b) => a < b ? a : b;
  final _Bounds s = adult
      ? (120, 130, 140)
      : (lower(l.sbp.$2, 120), lower(l.sbp.$3, 130), lower(l.sbpStage2, 140));
  // Diastolic has no "elevated" band from 13 years: 80 starts stage 1.
  final _Bounds d = adult
      ? (80, 80, 90)
      : (lower(l.dbp.$2, 80), lower(l.dbp.$3, 80), lower(l.dbpStage2, 90));
  final a = sbp == null ? AapBpCategory.normal : _place(sbp, s);
  final b = dbp == null ? AapBpCategory.normal : _place(dbp, d);
  return a.index >= b.index ? a : b;
}
