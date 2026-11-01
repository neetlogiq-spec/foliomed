/// Turns a filled form into the short note that goes on the timeline:
/// "Ward round — Dr A: HR 120, T 37.2 °C; afebrile, tolerating feeds;
/// ⚠ not pain controlled — on PRN only. Plan: continue antibiotics."
library;

import 'form_model.dart';

class FormSummary {
  const FormSummary({required this.text, required this.abnormal, required this.vitals});

  final String text;

  /// The abnormal answers, as short phrases (no ⚠).
  final List<String> abnormal;

  /// Vital signs entered (keys from [kVitals]), for the observation.
  final Map<String, double> vitals;
}

String _lc(String s) =>
    s.length > 1 && s[1] == s[1].toUpperCase() && s[1] != s[1].toLowerCase() ? s : s[0].toLowerCase() + s.substring(1);

String _num(num v) {
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _yn(String v) => switch (v) {
  kYes => 'yes',
  kNo => 'no',
  kNa => 'n/a',
  _ => v,
};

/// Vital signs from the first vitals field that has any.
Map<String, double> vitalsOf(FormDefinition def, Map<String, Object?> answers) {
  for (final f in def.fields.where((f) => f.type == FieldType.vitals)) {
    final v = answers[f.id];
    if (v is Map) {
      final out = <String, double>{
        for (final e in v.entries)
          if (e.value is num) e.key as String: (e.value as num).toDouble(),
      };
      if (out.isNotEmpty) return out;
    }
  }
  return const {};
}

String vitalsLine(Map<String, double> v) {
  final parts = <String>[
    if (v['hr'] != null) 'HR ${_num(v['hr']!)}',
    if (v['rr'] != null) 'RR ${_num(v['rr']!)}',
    if (v['spo2'] != null) 'SpO₂ ${_num(v['spo2']!)}%',
    if (v['temp'] != null) 'T ${_num(v['temp']!)} °C',
    if (v['sbp'] != null) 'BP ${_num(v['sbp']!)}${v['dbp'] == null ? '' : '/${_num(v['dbp']!)}'}',
    if (v['weight'] != null) 'Wt ${_num(v['weight']!)} kg',
  ];
  return parts.join(', ');
}

FormSummary summariseForm({
  required String formName,
  required FormDefinition definition,
  required Map<String, Object?> answers,
  String? author,
}) {
  final vitals = vitalsOf(definition, answers);
  final normals = <String>[];
  final normalChoices = <String>[];
  final abnormal = <String>[];
  final values = <String>[];
  final texts = <String>[];
  final scores = <String>[];

  for (final section in definition.sections) {
    final sc = section.scoreFor(answers);
    if (sc == null) continue;
    final line = sc.complete ? sc.line : '${sc.line} (incomplete)';
    if (sc.complete && (sc.band?.abnormal ?? false)) {
      abnormal.add(line);
    } else {
      scores.add(line);
    }
  }

  for (final f in definition.fields) {
    final v = answers[f.id];
    final detail = (answers[f.detailKey] as String?)?.trim();
    final withDetail = detail == null || detail.isEmpty ? '' : ' — $detail';
    switch (f.type) {
      case FieldType.vitals || FieldType.score:
        break;
      case FieldType.yesNo:
        if (v is! String || v.isEmpty) break;
        if (f.isAbnormal(v)) {
          abnormal.add(f.normal == kYes ? 'not ${_lc(f.label)}$withDetail' : '${f.label}$withDetail');
        } else if (f.normal == kYes && v == kYes) {
          normals.add(_lc(f.label));
        } else if (f.normal == null) {
          values.add('${f.label}: ${_yn(v)}$withDetail');
        }
      case FieldType.choice:
        if (v is! String || v.isEmpty) break;
        if (f.isAbnormal(v)) {
          abnormal.add('${f.label}: ${_lc(v)}$withDetail');
        } else if (f.hasNormal) {
          normalChoices.add(f.label);
        } else {
          values.add('${f.label}: $v');
        }
      case FieldType.number:
        if (v is num) values.add('${f.label} ${_num(v)}${f.unit == null ? '' : ' ${f.unit}'}');
      case FieldType.date:
        if (v is String && v.isNotEmpty) values.add('${f.label}: $v');
      case FieldType.text:
        if (v is String && v.trim().isNotEmpty) texts.add('${f.label}: ${v.trim()}');
    }
  }

  final clauses = <String>[
    if (vitals.isNotEmpty) vitalsLine(vitals),
    ...scores,
    if (normals.isNotEmpty) normals.join(', '),
    if (normalChoices.isNotEmpty) 'normal: ${normalChoices.join(', ')}',
    for (final a in abnormal) '⚠ $a',
    ...values,
  ];
  final head = author == null || author.isEmpty ? formName : '$formName — $author';
  final body = [
    if (clauses.isNotEmpty) '${clauses.join('; ')}.',
    for (final t in texts) t.endsWith('.') ? t : '$t.',
  ].join(' ');
  return FormSummary(text: body.isEmpty ? '$head.' : '$head: $body', abnormal: abnormal, vitals: vitals);
}
