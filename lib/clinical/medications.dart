/// Choices for prescribing, and the two safety checks shown before a
/// medicine is saved: recorded allergies, and a dose above the largest
/// single dose in FolioMed's drug list. Checks warn; they never block.
library;

import '../models/medication.dart';
import '../tools/drugs/drug_list.dart';
import '../tools/drugs/drug_model.dart';

const kDoseUnits = ['mg', 'mcg', 'g', 'units', 'mL', 'mg/kg', 'mcg/kg', 'units/kg', 'mL/kg', 'tab', 'puff', 'drop'];
const kRoutes = ['Oral', 'IV', 'IM', 'SC', 'NG/OG', 'Inhaled', 'Nebulised', 'PR', 'Topical', 'Eye', 'Ear', 'Nasal'];
const kFrequencies = [
  'OD',
  'BD',
  'TDS',
  'QID',
  'Every 4 h',
  'Every 6 h',
  'Every 8 h',
  'Every 12 h',
  'Stat',
  'PRN',
  'Weekly',
];
const kHistorySources = ['Parent', 'Patient', 'Records', 'Referral letter'];

/// Drug groups people record allergies by, with the members FolioMed
/// recognises. Matching is by name only — always read the warning.
const Map<String, List<String>> kAllergyGroups = {
  'penicillin': [
    'amoxicillin',
    'amoxycillin',
    'ampicillin',
    'flucloxacillin',
    'cloxacillin',
    'piperacillin',
    'benzylpenicillin',
    'phenoxymethylpenicillin',
    'co-amoxiclav',
    'augmentin',
    'penicillin',
  ],
  'cephalosporin': [
    'cefalexin',
    'cephalexin',
    'cefuroxime',
    'cefotaxime',
    'ceftriaxone',
    'ceftazidime',
    'cefixime',
    'cefazolin',
    'cefepime',
    'cefoperazone',
    'cefadroxil',
    'cefpodoxime',
  ],
  'carbapenem': ['meropenem', 'imipenem', 'ertapenem'],
  'sulfonamide': ['sulfamethoxazole', 'co-trimoxazole', 'cotrimoxazole', 'septran', 'sulfadiazine'],
  'nsaid': [
    'ibuprofen',
    'diclofenac',
    'aspirin',
    'naproxen',
    'ketorolac',
    'mefenamic acid',
    'indomethacin',
    'indometacin',
  ],
  'aminoglycoside': ['gentamicin', 'amikacin', 'tobramycin', 'netilmicin'],
  'opioid': ['morphine', 'fentanyl', 'codeine', 'tramadol', 'pethidine', 'methadone', 'oxycodone'],
  'macrolide': ['erythromycin', 'azithromycin', 'clarithromycin'],
};

/// Other names people write for a group.
const Map<String, String> _groupAliases = {
  'penicillins': 'penicillin',
  'beta-lactam': 'penicillin',
  'cephalosporins': 'cephalosporin',
  'sulfa': 'sulfonamide',
  'sulpha': 'sulfonamide',
  'sulphonamide': 'sulfonamide',
  'sulfonamides': 'sulfonamide',
  'nsaids': 'nsaid',
  'opioids': 'opioid',
  'opiates': 'opioid',
  'aminoglycosides': 'aminoglycoside',
  'macrolides': 'macrolide',
  'carbapenems': 'carbapenem',
};

/// Cross-reactions worth a "possible" warning (allergy group → drug group).
const Map<String, List<String>> _crossReacts = {
  'penicillin': ['cephalosporin', 'carbapenem'],
};

class AllergyHit {
  const AllergyHit(this.allergy, {required this.possible});
  final PatientAllergy allergy;

  /// A cross-reaction rather than the same drug or group.
  final bool possible;

  String get message =>
      possible ? 'Possible cross-reaction: recorded allergy to ${allergy.line}.' : 'Recorded allergy: ${allergy.line}.';
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\- ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// The groups a name belongs to (as a member, or by naming the group).
Set<String> _groupsOf(String name) {
  final n = _norm(name);
  final out = <String>{};
  for (final e in kAllergyGroups.entries) {
    if (n.contains(e.key) || e.value.any((m) => n.contains(m))) out.add(e.key);
  }
  for (final e in _groupAliases.entries) {
    if (n.contains(e.key)) out.add(e.value);
  }
  return out;
}

/// Allergies a new medicine may clash with: same name (either way round),
/// same drug group, or a known cross-reaction.
List<AllergyHit> allergyHits(String drugName, List<PatientAllergy> allergies) {
  final drug = _norm(drugName);
  if (drug.isEmpty) return const [];
  final drugGroups = _groupsOf(drug);
  final hits = <AllergyHit>[];
  for (final a in allergies) {
    final sub = _norm(a.substance);
    if (sub.isEmpty) continue;
    final sameName = (sub.length >= 4 && drug.contains(sub)) || (drug.length >= 4 && sub.contains(drug));
    final allergyGroups = _groupsOf(sub);
    if (sameName || allergyGroups.intersection(drugGroups).isNotEmpty) {
      hits.add(AllergyHit(a, possible: false));
      continue;
    }
    final cross = allergyGroups.expand((g) => _crossReacts[g] ?? const <String>[]).toSet();
    if (cross.intersection(drugGroups).isNotEmpty) hits.add(AllergyHit(a, possible: true));
  }
  return hits;
}

/// The amount unit of a dose unit, and whether it is per kg.
(Amount, bool)? _parseUnit(String unit) => switch (unit) {
  'mg' => (Amount.mg, false),
  'mcg' => (Amount.mcg, false),
  'g' => (Amount.g, false),
  'units' => (Amount.units, false),
  'mg/kg' => (Amount.mg, true),
  'mcg/kg' => (Amount.mcg, true),
  'units/kg' => (Amount.units, true),
  _ => null,
};

/// A warning when a single dose is above the largest single dose for this
/// drug in FolioMed's list (per kg, or the absolute maximum). Null when the
/// drug isn't listed, the unit can't be compared, or the dose is within.
String? doseWarning({required String? drugKey, required double? dose, required String unit, double? weightKg}) {
  final drug = drugKey == null ? null : drugByKey(drugKey);
  final parsed = _parseUnit(unit);
  if (drug == null || dose == null || parsed == null || drug.boluses.isEmpty) return null;
  final (amount, perKg) = parsed;
  final listUnit = drug.boluses.first.unit;
  double? inListUnit(double v) {
    try {
      return amount.to(listUnit, v);
    } on ArgumentError {
      return null;
    }
  }

  final maxPerKg = drug.boluses.map((b) => b.max).reduce((a, b) => a > b ? a : b);
  final caps = drug.boluses.map((b) => b.maxDose).whereType<double>();
  final maxAbsolute = caps.isEmpty ? null : caps.reduce((a, b) => a > b ? a : b);
  final perKgDose = perKg ? inListUnit(dose) : (weightKg == null ? null : inListUnit(dose / weightKg));
  final absolute = perKg ? (weightKg == null ? null : inListUnit(dose * weightKg)) : inListUnit(dose);
  String n(double v) => trimNum(v, 3);
  if (perKgDose != null && perKgDose > maxPerKg * 1.0001) {
    return 'Above the largest single dose in FolioMed’s list for ${drug.name} '
        '(${n(maxPerKg)} ${listUnit.label}/kg). Check the dose.';
  }
  if (absolute != null && maxAbsolute != null && absolute > maxAbsolute * 1.0001) {
    return 'Above the maximum single dose in FolioMed’s list for ${drug.name} '
        '(${n(maxAbsolute)} ${listUnit.label}). Check the dose.';
  }
  return null;
}
