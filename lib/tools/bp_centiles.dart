/// Blood pressure centiles for infants after 2 weeks of age, by
/// postmenstrual age (Dionne JM, Abitbol CL, Flynn JT. Hypertension in
/// infancy: diagnosis, management and outcome. Pediatr Nephrol
/// 2012;27:17–32, Table 2). Values in mmHg.
library;

class BpRow {
  const BpRow(this.pmaWeeks, this.sbp, this.map, this.dbp);
  final int pmaWeeks;

  /// (50th, 95th, 99th) centiles.
  final (int, int, int) sbp, map, dbp;
}

const List<BpRow> kDionneBp = [
  BpRow(44, (88, 105, 110), (63, 80, 85), (50, 68, 73)),
  BpRow(42, (85, 98, 102), (62, 76, 81), (50, 65, 70)),
  BpRow(40, (80, 95, 100), (60, 75, 80), (50, 65, 70)),
  BpRow(38, (77, 92, 97), (59, 74, 79), (50, 65, 70)),
  BpRow(36, (72, 87, 92), (57, 72, 77), (50, 65, 70)),
  BpRow(34, (70, 85, 90), (50, 65, 70), (40, 55, 60)),
  BpRow(32, (68, 83, 88), (49, 64, 69), (40, 55, 60)),
  BpRow(30, (65, 80, 85), (48, 63, 68), (40, 55, 60)),
  BpRow(28, (60, 75, 80), (45, 58, 63), (38, 50, 54)),
  BpRow(26, (55, 72, 77), (38, 57, 63), (30, 50, 56)),
];

/// The table row for [pmaWeeks]: the nearest listed age, taking the lower
/// row when exactly between two. Null outside 26–44 weeks.
BpRow? bpRowFor(double pmaWeeks) {
  if (pmaWeeks < 26 || pmaWeeks >= 45) return null;
  BpRow? best;
  for (final r in kDionneBp) {
    final d = (r.pmaWeeks - pmaWeeks).abs();
    if (best == null) {
      best = r;
      continue;
    }
    final bd = (best.pmaWeeks - pmaWeeks).abs();
    if (d < bd || (d == bd && r.pmaWeeks < best.pmaWeeks)) best = r;
  }
  return best;
}

enum BpBand {
  normal('Below the 95th centile'),
  high('At or above the 95th centile'),
  veryHigh('At or above the 99th centile');

  const BpBand(this.label);
  final String label;
}

BpBand bpBand(int value, (int, int, int) centiles) =>
    value >= centiles.$3 ? BpBand.veryHigh : (value >= centiles.$2 ? BpBand.high : BpBand.normal);
