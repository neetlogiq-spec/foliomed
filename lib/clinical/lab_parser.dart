/// Pulls lab results out of OCR'd report text: value, the report's own
/// reference range when printed, converted to the units FolioMed stores.
/// Conservative: one result per test (first match), implausible numbers
/// dropped. Everything is shown for checking before it is saved.
library;

import 'labs.dart';

class ParsedLab {
  const ParsedLab(this.test, {this.value, this.text, this.refLow, this.refHigh});
  final LabTest test;
  final double? value;
  final String? text;
  final double? refLow, refHigh;
}

final _number = RegExp(r'(-?\d{1,6}(?:[.,]\d{1,3})?)');
final _range = RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|–|—|to)\s*(\d+(?:\.\d+)?)');
final _below = RegExp(r'(?:<|less\s+than|upto|up\s+to)\s*(\d+(?:\.\d+)?)', caseSensitive: false);

double? _num(String s) => double.tryParse(s.replaceAll(',', ''));

/// Converts a reported number to FolioMed's unit for [key], using words
/// on the line (mmol, µmol, g/L, lakh) and the size of the number.
double convertLab(String key, double v, String context) {
  final c = context.toLowerCase();
  final molar = c.contains('mmol');
  final micromolar = RegExp(r'[µu]mol').hasMatch(c);
  switch (key) {
    case 'tlc':
      return v > 1000 ? v / 1000 : v; // 12,500 /cumm → 12.5
    case 'platelets':
      if (c.contains('lakh')) return v * 100; // 2.1 lakhs → 210
      return v > 10000 ? v / 1000 : v; // 210000 /cumm → 210
    case 'hb':
      return v > 30 ? v / 10 : v; // g/L → g/dL
    case 'albumin' || 'protein':
      return v > 15 ? v / 10 : v; // g/L → g/dL
    case 'glucose':
      return molar && v < 50 ? v * 18 : v; // mmol/L → mg/dL
    case 'urea':
      return molar && v < 100 ? v * 6.006 : v;
    case 'creatinine':
      return micromolar || v > 20 ? v / 88.4 : v; // µmol/L → mg/dL
    case 'calcium':
      return molar && v < 5 ? v * 4.008 : v;
    case 'magnesium':
      return molar && v < 4 ? v * 2.431 : v;
    case 'phosphate':
      return molar && v < 5 ? v * 3.097 : v;
    case 'bili_total' || 'bili_direct':
      return micromolar || v > 50 ? v / 17.1 : v; // µmol/L → mg/dL
  }
  return v;
}

List<ParsedLab> parseLabText(String text) {
  final out = <String, ParsedLab>{};
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final t in kLabTests) {
      if (out.containsKey(t.key)) continue;
      final m = t.pattern.firstMatch(line);
      if (m == null || (t.exclude?.hasMatch(line) ?? false)) continue;
      final rest = line.substring(m.end);
      if (t.text) {
        final r = rest.replaceFirst(RegExp(r'^[\s:–-]+'), '').trim();
        final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
        final value = r.isNotEmpty ? r : next;
        if (value.isNotEmpty) out[t.key] = ParsedLab(t, text: value.length > 120 ? value.substring(0, 120) : value);
        continue;
      }
      // Value on the same line after the name, else on the next line.
      var source = rest;
      var n = _number.firstMatch(rest);
      if (n == null && i + 1 < lines.length) {
        source = lines[i + 1];
        n = _number.firstMatch(source);
      }
      if (n == null) continue;
      final raw = _num(n.group(1)!);
      if (raw == null) continue;
      final context = '$rest ${i + 1 < lines.length ? lines[i + 1] : ''}';
      final v = convertLab(t.key, raw, context);
      final p = t.plausible;
      if (p != null && (v < p.$1 || v > p.$2)) continue;
      // Reference range printed after the value.
      final after = source.substring(n.end);
      double? lo, hi;
      final r = _range.firstMatch(after);
      if (r != null) {
        lo = convertLab(t.key, _num(r.group(1)!)!, context);
        hi = convertLab(t.key, _num(r.group(2)!)!, context);
        if (lo > hi) (lo, hi) = (null, null);
      } else if (_below.firstMatch(after) case final b?) {
        hi = convertLab(t.key, _num(b.group(1)!)!, context);
      }
      out[t.key] = ParsedLab(t, value: double.parse(v.toStringAsFixed(3)), refLow: lo, refHigh: hi);
    }
  }
  return [for (final t in kLabTests) if (out[t.key] != null) out[t.key]!];
}
