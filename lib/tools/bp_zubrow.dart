/// Neonatal blood pressure by gestation (Zubrow AB, Hulman S, Kushner H,
/// Falkner B. Determinants of blood pressure in infants admitted to neonatal
/// intensive care units: a prospective multicenter study. Philadelphia
/// Neonatal Blood Pressure Study Group. J Perinatol 1995;15(6):470–9), as
/// tabulated by EPIQ (version 27 June 2022, Tables 1 and 2). Each value is
/// (lower 95% limit, mean, upper 95% limit) in mmHg; mean BP was calculated
/// by EPIQ from systolic and diastolic.
library;

class ZubrowRow {
  const ZubrowRow(this.weeks, this.sbp, this.dbp, this.map);
  final int weeks;

  /// (lower limit, mean, upper limit).
  final (int, int, int) sbp, dbp, map;
}

/// Table 1: day one of life, by gestational age at birth (22–42 weeks).
const List<ZubrowRow> kZubrowDay1 = [
  ZubrowRow(22, (22, 39, 55), (14, 23, 31), (17, 28, 39)),
  ZubrowRow(23, (23, 40, 56), (15, 24, 32), (18, 29, 40)),
  ZubrowRow(24, (25, 42, 57), (16, 25, 33), (19, 31, 41)),
  ZubrowRow(25, (26, 43, 58), (17, 26, 34), (20, 32, 42)),
  ZubrowRow(26, (27, 44, 60), (18, 27, 35), (21, 33, 43)),
  ZubrowRow(27, (29, 45, 61), (19, 28, 36), (22, 34, 44)),
  ZubrowRow(28, (31, 47, 63), (20, 29, 37), (24, 35, 46)),
  ZubrowRow(29, (33, 48, 64), (21, 30, 38), (25, 36, 47)),
  ZubrowRow(30, (35, 50, 66), (22, 31, 39), (26, 37, 48)),
  ZubrowRow(31, (36, 51, 68), (23, 32, 40), (27, 38, 49)),
  ZubrowRow(32, (37, 52, 69), (24, 33, 41), (28, 39, 50)),
  ZubrowRow(33, (38, 53, 70), (25, 34, 42), (29, 40, 51)),
  ZubrowRow(34, (40, 55, 71), (26, 35, 43), (31, 42, 52)),
  ZubrowRow(35, (41, 57, 73), (27, 36, 44), (32, 43, 54)),
  ZubrowRow(36, (42, 59, 75), (28, 37, 45), (33, 44, 55)),
  ZubrowRow(37, (44, 60, 76), (29, 38, 46), (34, 45, 56)),
  ZubrowRow(38, (46, 61, 77), (30, 39, 47), (35, 46, 57)),
  ZubrowRow(39, (47, 62, 79), (31, 40, 48), (36, 47, 58)),
  ZubrowRow(40, (48, 64, 81), (32, 41, 49), (37, 49, 60)),
  ZubrowRow(41, (50, 65, 82), (33, 42, 50), (39, 50, 61)),
  ZubrowRow(42, (51, 67, 84), (34, 43, 51), (40, 51, 62)),
];

/// Table 2: by post-conceptional age (24–46 weeks).
const List<ZubrowRow> kZubrowByPca = [
  ZubrowRow(24, (33, 49, 68), (14, 29, 46), (20, 36, 53)),
  ZubrowRow(25, (36, 51, 69), (15, 30, 47), (22, 37, 54)),
  ZubrowRow(26, (38, 52, 70), (17, 31, 48), (24, 38, 55)),
  ZubrowRow(27, (40, 54, 71), (18, 32, 49), (25, 39, 56)),
  ZubrowRow(28, (41, 55, 72), (19, 33, 50), (26, 40, 57)),
  ZubrowRow(29, (42, 56, 73), (20, 34, 51), (27, 41, 58)),
  ZubrowRow(30, (43, 59, 75), (21, 35, 52), (28, 43, 60)),
  ZubrowRow(31, (46, 61, 78), (22, 36, 53), (30, 44, 61)),
  ZubrowRow(32, (48, 62, 80), (23, 37, 54), (31, 45, 63)),
  ZubrowRow(33, (50, 63, 81), (24, 38, 55), (33, 46, 64)),
  ZubrowRow(34, (51, 66, 83), (25, 39, 56), (34, 48, 65)),
  ZubrowRow(35, (52, 69, 84), (26, 40, 57), (35, 50, 66)),
  ZubrowRow(36, (55, 71, 87), (27, 41, 58), (36, 51, 68)),
  ZubrowRow(37, (57, 72, 89), (28, 42, 59), (38, 52, 69)),
  ZubrowRow(38, (59, 75, 90), (29, 43, 60), (39, 54, 70)),
  ZubrowRow(39, (60, 78, 91), (30, 44, 60), (40, 55, 70)),
  ZubrowRow(40, (61, 80, 92), (30, 44, 61), (40, 56, 71)),
  ZubrowRow(41, (62, 81, 93), (31, 46, 62), (41, 58, 72)),
  ZubrowRow(42, (63, 82, 95), (32, 47, 63), (42, 59, 74)),
  ZubrowRow(43, (65, 83, 97), (33, 48, 64), (44, 60, 75)),
  ZubrowRow(44, (67, 86, 98), (34, 49, 65), (45, 61, 76)),
  ZubrowRow(45, (69, 88, 100), (35, 50, 66), (46, 63, 77)),
  ZubrowRow(46, (71, 89, 102), (36, 51, 66), (48, 64, 78)),
];

/// The row for [weeks] in completed weeks, or null outside the table.
ZubrowRow? zubrowRowFor(List<ZubrowRow> table, double weeks) {
  final w = weeks.floor();
  for (final r in table) {
    if (r.weeks == w) return r;
  }
  return null;
}

enum ZubrowBand {
  low('Below the lower limit'),
  normal('Within the normal range'),
  high('Above the upper limit');

  const ZubrowBand(this.label);
  final String label;
}

ZubrowBand zubrowBand(int value, (int, int, int) range) =>
    value < range.$1 ? ZubrowBand.low : (value > range.$3 ? ZubrowBand.high : ZubrowBand.normal);
