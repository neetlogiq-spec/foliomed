/// Lab tests FolioMed knows by name: units it stores, how to spot them in
/// a scanned report, values that can't be real (so a stray number isn't
/// taken as a result), and critical values that always warrant attention.
///
/// "High"/"low" come from the reference range printed on the report (or
/// typed in) — normal ranges vary by age and laboratory, so FolioMed does
/// not assume them. Critical values are deliberately conservative and the
/// same at every age; they flag, they never interpret.
library;

class LabTest {
  const LabTest(
    this.key,
    this.name,
    this.unit,
    this.panel,
    this.pattern, {
    this.exclude,
    this.plausible,
    this.criticalLow,
    this.criticalHigh,
    this.text = false,
  });

  final String key;
  final String name;
  final String unit;
  final String panel;

  /// Finds the test's name on a report line.
  final RegExp pattern;

  /// Lines that mention it but mean something else.
  final RegExp? exclude;

  /// (low, high) a real result must fall in, after unit conversion.
  final (double, double)? plausible;
  final double? criticalLow, criticalHigh;

  /// A text result (e.g. a culture), not a number.
  final bool text;
}

RegExp _r(String p) => RegExp(p, caseSensitive: false);

const kLabPanels = ['Blood count', 'Inflammation', 'Kidney and salts', 'Bone', 'Glucose', 'Liver', 'Clotting',
  'Blood gas', 'Other', 'Microbiology'];

final kLabTests = <LabTest>[
  // Blood count
  LabTest('hb', 'Hb', 'g/dL', 'Blood count', _r(r'\b(ha?emoglobin|hgb|hb)\b'),
      exclude: _r(r'hba1c|mchc?\b|mean'), plausible: (2, 30), criticalLow: 7),
  LabTest('hct', 'Hct', '%', 'Blood count', _r(r'\b(hct|ha?ematocrit|pcv|packed\s+cell\s+volume)\b'),
      plausible: (5, 90)),
  LabTest('tlc', 'WBC', '×10³/µL', 'Blood count',
      _r(r'\b(tlc|total\s+(leu[ck]ocyte|wbc|white\s+(blood\s+)?cell)s?(\s+count)?|wbc(\s+count)?)\b'),
      plausible: (0.1, 200), criticalLow: 1.5, criticalHigh: 50),
  LabTest('neutrophils', 'Neutrophils', '%', 'Blood count', _r(r'\b(neutrophils?|polymorphs?|segmented)\b'),
      exclude: _r(r'absolute|anc'), plausible: (0, 100)),
  LabTest('lymphocytes', 'Lymphocytes', '%', 'Blood count', _r(r'\blymphocytes?\b'),
      exclude: _r(r'absolute|atypical'), plausible: (0, 100)),
  LabTest('platelets', 'Platelets', '×10³/µL', 'Blood count', _r(r'\b(platelets?(\s+count)?|plt)\b'),
      exclude: _r(r'\bmpv\b|volume|distribution'), plausible: (1, 2000), criticalLow: 20),
  LabTest('esr', 'ESR', 'mm/h', 'Blood count', _r(r'\besr\b|erythrocyte\s+sedimentation'), plausible: (0, 200)),
  LabTest('retic', 'Retic', '%', 'Blood count', _r(r'\breti[ck]ulocytes?\b|\bretic\b'), plausible: (0, 60)),
  // Inflammation
  LabTest('crp', 'CRP', 'mg/L', 'Inflammation', _r(r'\b(c[\s-]*reactive\s+protein|crp)\b'),
      exclude: _r(r'\bhs\b|high\s+sensitiv'), plausible: (0, 500)),
  LabTest('pct', 'Procalcitonin', 'ng/mL', 'Inflammation', _r(r'\b(procalcitonin|pct)\b'), plausible: (0, 500)),
  // Kidney and salts
  LabTest('urea', 'Urea', 'mg/dL', 'Kidney and salts', _r(r'\b(blood\s+urea|urea|bun)\b'),
      exclude: _r(r'nitrogen.*ratio|urine'), plausible: (1, 500)),
  LabTest('creatinine', 'Creatinine', 'mg/dL', 'Kidney and salts', _r(r'\b(s\.?\s*)?creatinine\b'),
      exclude: _r(r'clearance|ratio|urine'), plausible: (0.05, 20)),
  LabTest('na', 'Sodium', 'mmol/L', 'Kidney and salts', _r(r'\b(sodium|na\+?)\b'),
      exclude: _r(r'urine|fractional'), plausible: (90, 200), criticalLow: 125, criticalHigh: 155),
  LabTest('k', 'Potassium', 'mmol/L', 'Kidney and salts', _r(r'\b(potassium|k\+?)\b'),
      exclude: _r(r'urine'), plausible: (1, 12), criticalLow: 2.5, criticalHigh: 6.5),
  LabTest('cl', 'Chloride', 'mmol/L', 'Kidney and salts', _r(r'\b(chloride|cl-?)\b'),
      exclude: _r(r'urine'), plausible: (60, 160)),
  LabTest('bicarbonate', 'Bicarbonate', 'mmol/L', 'Kidney and salts', _r(r'\b(bicarbonate|hco3-?|tco2|total\s+co2)\b'),
      plausible: (2, 60), criticalLow: 10),
  // Bone
  LabTest('calcium', 'Calcium', 'mg/dL', 'Bone', _r(r'\b(total\s+)?calcium\b|\bs\.?\s*ca\b'),
      exclude: _r(r'ioni[sz]ed|ica\b|urine'), plausible: (2, 20), criticalLow: 6.5, criticalHigh: 13),
  LabTest('ica', 'Ionised calcium', 'mmol/L', 'Bone', _r(r'ioni[sz]ed\s+calcium|\bica\b'), plausible: (0.2, 3),
      criticalLow: 0.8),
  LabTest('magnesium', 'Magnesium', 'mg/dL', 'Bone', _r(r'\bmagnesium\b'),
      exclude: _r(r'urine'), plausible: (0.3, 10)),
  LabTest('phosphate', 'Phosphate', 'mg/dL', 'Bone', _r(r'\b(phosph(ate|orus)|po4)\b'),
      exclude: _r(r'alkaline|urine'), plausible: (0.5, 20)),
  // Glucose
  LabTest('glucose', 'Glucose', 'mg/dL', 'Glucose', _r(r'\b(glucose|sugar|grbs|rbs|fbs|bsl)\b'),
      exclude: _r(r'urine|csf'), plausible: (5, 1500), criticalLow: 45, criticalHigh: 400),
  LabTest('hba1c', 'HbA1c', '%', 'Glucose', _r(r'\bhba1c\b|glycated'), plausible: (3, 20)),
  // Liver
  LabTest('bili_total', 'Bilirubin total', 'mg/dL', 'Liver',
      _r(r'\btotal\b[^\n]*bilirubin|bilirubin[^\n]*\btotal\b|\bt\.?\s*bil|\btsb\b|serum\s+bilirubin'),
      exclude: _r(r'direct|indirect|conjugated|unconjugated'), plausible: (0, 50)),
  LabTest('bili_direct', 'Bilirubin direct', 'mg/dL', 'Liver',
      _r(r'\b(direct|conjugated)\b[^\n]*bilirubin|bilirubin[^\n]*\b(direct|conjugated)\b|\bd\.?\s*bil'),
      exclude: _r(r'indirect|unconjugated'), plausible: (0, 30)),
  LabTest('alt', 'ALT', 'U/L', 'Liver', _r(r'\b(alt|sgpt|alanine\s+(amino)?transferase)\b'), plausible: (1, 20000)),
  LabTest('ast', 'AST', 'U/L', 'Liver', _r(r'\b(ast|sgot|aspartate\s+(amino)?transferase)\b'), plausible: (1, 20000)),
  LabTest('alp', 'ALP', 'U/L', 'Liver', _r(r'\b(alp|alkaline\s+phosphatase)\b'), plausible: (10, 10000)),
  LabTest('albumin', 'Albumin', 'g/dL', 'Liver', _r(r'\b(s\.?\s*)?albumin\b'),
      exclude: _r(r'ratio|globulin|urine|micro'), plausible: (0.5, 7)),
  LabTest('protein', 'Total protein', 'g/dL', 'Liver', _r(r'\btotal\s+proteins?\b'), plausible: (1, 15)),
  // Clotting
  LabTest('pt', 'PT', 's', 'Clotting', _r(r'\b(pt|prothrombin\s+time)\b'), exclude: _r(r'inr|aptt|ptt|name|age|\bid\b|patient'),
      plausible: (5, 150)),
  LabTest('inr', 'INR', '', 'Clotting', _r(r'\binr\b'), plausible: (0.5, 15), criticalHigh: 4),
  LabTest('aptt', 'APTT', 's', 'Clotting', _r(r'\b(aptt|ptt|activated\s+partial)\b'), plausible: (10, 250)),
  // Blood gas
  LabTest('ph', 'pH', '', 'Blood gas', _r(r'\bph\b'), exclude: _r(r'urine|phosph'), plausible: (6.5, 8),
      criticalLow: 7.2, criticalHigh: 7.6),
  LabTest('pco2', 'pCO₂', 'mmHg', 'Blood gas', _r(r'\bp\s*co2\b'), plausible: (5, 200), criticalHigh: 70),
  LabTest('po2', 'pO₂', 'mmHg', 'Blood gas', _r(r'\bp\s*o2\b'), plausible: (5, 700)),
  LabTest('be', 'Base excess', 'mmol/L', 'Blood gas', _r(r'\b(base\s+excess|abe|sbe|beecf|be\s*\((b|ecf)\)|be\s*-\s*b)'),
      plausible: (-40, 40), criticalLow: -15),
  LabTest('lactate', 'Lactate', 'mmol/L', 'Blood gas', _r(r'\b(lactate|lactic\s+acid)\b'), plausible: (0.1, 30),
      criticalHigh: 4),
  // Other
  LabTest('tsh', 'TSH', 'µIU/mL', 'Other', _r(r'\btsh\b'), plausible: (0, 500)),
  LabTest('ammonia', 'Ammonia', 'µmol/L', 'Other', _r(r'\bammonia\b'), plausible: (1, 3000), criticalHigh: 150),
  // Microbiology
  LabTest('blood_culture', 'Blood culture', '', 'Microbiology', _r(r'blood\s+culture'), text: true),
  LabTest('urine_culture', 'Urine culture', '', 'Microbiology', _r(r'urine\s+culture'), text: true),
  LabTest('csf_culture', 'CSF culture', '', 'Microbiology', _r(r'csf\s+culture'), text: true),
];

LabTest? labTestByKey(String key) {
  for (final t in kLabTests) {
    if (t.key == key) return t;
  }
  return null;
}

enum LabFlag {
  low('Low'),
  high('High'),
  criticalLow('Critically low'),
  criticalHigh('Critically high');

  const LabFlag(this.label);
  final String label;

  bool get critical => this == criticalLow || this == criticalHigh;

  /// "↓", "↑", "⚠↓", "⚠↑".
  String get mark => switch (this) { low => '↓', high => '↑', criticalLow => '⚠↓', criticalHigh => '⚠↑' };

  static LabFlag? fromName(String? v) => values.where((f) => f.name == v).firstOrNull;
}

/// Critical values first, then the reference range (from the report).
LabFlag? flagFor(LabTest? test, double? value, {double? refLow, double? refHigh}) {
  if (value == null) return null;
  if (test?.criticalLow != null && value < test!.criticalLow!) return LabFlag.criticalLow;
  if (test?.criticalHigh != null && value > test!.criticalHigh!) return LabFlag.criticalHigh;
  if (refLow != null && value < refLow) return LabFlag.low;
  if (refHigh != null && value > refHigh) return LabFlag.high;
  return null;
}
