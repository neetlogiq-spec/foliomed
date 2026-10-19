import 'package:intl/intl.dart';

import '../models/patient.dart';

/// Maturity from gestational age (WHO categories).
enum Maturity {
  preterm('PRETERM'), // < 34 weeks
  latePreterm('LATE PRETERM'), // 34+0 – 36+6
  term('TERM'), // 37+0 – 41+6
  postTerm('POST-TERM'); // ≥ 42+0

  const Maturity(this.label);
  final String label;

  static Maturity? fromGestation(int? weeks) {
    if (weeks == null) return null;
    if (weeks < 34) return preterm;
    if (weeks < 37) return latePreterm;
    if (weeks < 42) return term;
    return postTerm;
  }
}

const List<String> kSizesForDates = ['AGA', 'SGA', 'LGA'];
const List<String> kDeliveryModes = ['NVD', 'LSCS', 'Vacuum', 'Forceps'];

/// "3.1kgs", "2.85kgs" — the ward's usual way of writing birth weight.
String formatBirthWeightKg(int grams) {
  final kg = grams / 1000;
  var s = kg.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${s}kgs';
}

/// Composes the newborn diagnosis line from structured fields, e.g.
/// "TERM/MALE/AGA/LSCS (CPD) on 19/10/2026 at 10:19pm with birth weight of
/// 3.1kgs". Missing parts are left out; returns null without a birth time.
/// Non-term babies get the gestation in brackets: "PRETERM (32+4 wks)".
String? birthSummaryLine(Patient p) {
  final born = p.bornAt;
  if (born == null) return null;
  final maturity = Maturity.fromGestation(p.gestationWeeks);
  final head = <String>[
    if (maturity != null)
      maturity == Maturity.term
          ? maturity.label
          : '${maturity.label} (${p.gestationWeeks}+${p.gestationDays ?? 0} wks)',
    if (p.gender.isNotEmpty) p.gender.toUpperCase(),
    if (p.sizeForDates != null) p.sizeForDates!,
    if (p.deliveryMode != null)
      p.deliveryIndication == null || p.deliveryIndication!.trim().isEmpty
          ? p.deliveryMode!
          : '${p.deliveryMode} (${p.deliveryIndication!.trim()})',
  ].join('/');
  final local = born.toLocal();
  final when = '${DateFormat('dd/MM/yyyy').format(local)} at '
      '${DateFormat('h:mma').format(local).toLowerCase()}';
  final weight = p.birthWeightG == null
      ? ''
      : ' with birth weight of ${formatBirthWeightKg(p.birthWeightG!)}';
  return '${head.isEmpty ? 'Born' : '$head'} on $when$weight';
}

/// "APGAR 8/9" etc., or null.
String? apgarLabel(Patient p) {
  if (p.apgar1 == null && p.apgar5 == null) return null;
  return 'APGAR ${p.apgar1 ?? '–'}/${p.apgar5 ?? '–'}';
}
