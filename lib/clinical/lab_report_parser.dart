/// Pulls newborn investigation values out of OCR'd lab-report text.
///
/// Conservative by design: one value per field (first match), normalised
/// to the units the results form uses. Everything it fills is shown for
/// the user to check before saving.
class ParsedLabValues {
  ParsedLabValues(this.values, {this.bilirubinInUmol = false});

  /// Keys: hb, tlc, platelets, hct, tsh, tsb_total, tsb_direct, urea,
  /// creatinine, sodium, potassium, chloride.
  final Map<String, double> values;
  final bool bilirubinInUmol;

  bool get isEmpty => values.isEmpty;
}

class _Field {
  const _Field(this.key, this.pattern, {this.exclude});
  final String key;
  final RegExp pattern;

  /// Lines that mention the keyword but mean something else.
  final RegExp? exclude;
}

final _number = RegExp(r'(\d{1,6}(?:[.,]\d{1,3})?)');

final _fields = <_Field>[
  _Field('hb', RegExp(r'\b(ha?emoglobin|hgb|hb)\b', caseSensitive: false),
      exclude: RegExp(r'hba1c|mchc?\b', caseSensitive: false)),
  _Field('tlc', RegExp(r'\b(tlc|total\s+(leu[ck]ocyte|wbc|white\s+(blood\s+)?cell)s?\s*(count)?|wbc(\s+count)?)\b',
      caseSensitive: false)),
  _Field('platelets', RegExp(r'\b(platelets?(\s+count)?|plt)\b', caseSensitive: false),
      exclude: RegExp(r'\bmpv\b|volume', caseSensitive: false)),
  _Field('hct', RegExp(r'\b(hct|ha?ematocrit|pcv|packed\s+cell\s+volume)\b', caseSensitive: false)),
  _Field('tsh', RegExp(r'\btsh\b', caseSensitive: false)),
  _Field('tsb_direct', RegExp(r'\b(direct|conjugated)\b[^\n]*bilirubin|bilirubin[^\n]*\b(direct|conjugated)\b|\bd\.?\s*bil',
      caseSensitive: false)),
  _Field('tsb_total', RegExp(r'\btotal\b[^\n]*bilirubin|bilirubin[^\n]*\btotal\b|\bt\.?\s*bil|\btsb\b|serum\s+bilirubin',
      caseSensitive: false),
      exclude: RegExp(r'direct|indirect|conjugated|unconjugated', caseSensitive: false)),
  _Field('urea', RegExp(r'\b(blood\s+urea|urea|bun)\b', caseSensitive: false)),
  _Field('creatinine', RegExp(r'\b(s\.?\s*)?creatinine\b', caseSensitive: false),
      exclude: RegExp(r'clearance|ratio', caseSensitive: false)),
  _Field('sodium', RegExp(r'\b(sodium|na\+?)\b', caseSensitive: false)),
  _Field('potassium', RegExp(r'\b(potassium|k\+?)\b', caseSensitive: false)),
  _Field('chloride', RegExp(r'\b(chloride|cl-?)\b', caseSensitive: false)),
];

ParsedLabValues parseLabReport(String text) {
  final values = <String, double>{};
  var umol = false;
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final f in _fields) {
      if (values.containsKey(f.key)) continue;
      final m = f.pattern.firstMatch(line);
      if (m == null) continue;
      if (f.exclude != null && f.exclude!.hasMatch(line)) continue;
      // Value after the label on the same line, else on the next line
      // (column layouts often put it below).
      final rest = line.substring(m.end);
      final n = _number.firstMatch(rest) ??
          (i + 1 < lines.length ? _number.firstMatch(lines[i + 1]) : null);
      if (n == null) continue;
      var v = double.tryParse(n.group(1)!.replaceAll(',', ''));
      if (v == null) continue;
      final context = '$rest ${i + 1 < lines.length ? lines[i + 1] : ''}'.toLowerCase();
      v = _normalise(f.key, v, context);
      if (v == null) continue;
      if (f.key.startsWith('tsb') && RegExp(r'[µu]mol').hasMatch(context)) umol = true;
      values[f.key] = v;
    }
  }
  return ParsedLabValues(values, bilirubinInUmol: umol);
}

/// Converts to form units (TLC/platelets ×10³/µL) and drops values that
/// can't be right, so a stray reference range isn't taken as a result.
double? _normalise(String key, double v, String context) {
  switch (key) {
    case 'tlc':
      if (v > 1000) v = v / 1000; // 12,500 /cumm → 12.5
      return v > 0 && v < 200 ? v : null;
    case 'platelets':
      if (context.contains('lakh')) v = v * 100; // 2.1 lakhs → 210
      if (v > 10000) v = v / 1000; // 210000 /cumm → 210
      return v > 0 && v < 2000 ? v : null;
    case 'hb':
      return v > 2 && v < 30 ? v : null;
    case 'hct':
      return v > 5 && v < 90 ? v : null;
    case 'tsh':
      return v >= 0 && v < 500 ? v : null;
    case 'tsb_total':
    case 'tsb_direct':
      return v >= 0 && v < 800 ? v : null;
    case 'urea':
      return v > 0 && v < 400 ? v : null;
    case 'creatinine':
      return v > 0 && v < 20 ? v : null;
    case 'sodium':
      return v > 90 && v < 200 ? v : null;
    case 'potassium':
      return v > 1 && v < 12 ? v : null;
    case 'chloride':
      return v > 60 && v < 160 ? v : null;
  }
  return v;
}
