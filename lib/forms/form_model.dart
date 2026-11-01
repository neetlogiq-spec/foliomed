/// Quick forms: a form is sections of fields; answers are a flat map from
/// field id to value. Definitions are JSON so wards can make their own, and
/// each filled form keeps a copy of the definition it was filled with.
library;

enum FieldType {
  /// Yes / No / N/A. With [FormFieldDef.normal] set, the other answer is
  /// abnormal and asks for a short description.
  yesNo('Yes / No'),

  /// One of [FormFieldDef.options]; with [FormFieldDef.normal], any other
  /// choice is abnormal and asks for a description.
  choice('Choice'),
  number('Number'),
  text('Text'),
  date('Date'),

  /// Weight, temperature, breathing rate, heart rate, BP, SpO₂ — recorded
  /// as an observation as well.
  vitals('Vital signs'),

  /// One item of a scored tool (FLACC, Aldrete…): pick an option, worth
  /// [FormFieldDef.points]. The section adds them up ([ScoreSpec]).
  score('Score item');

  const FieldType(this.label);
  final String label;

  static FieldType fromName(String? v) => values.firstWhere((t) => t.name == v, orElse: () => text);
}

/// Answer values for yes/no fields.
const kYes = 'yes', kNo = 'no', kNa = 'na';

class FormFieldDef {
  const FormFieldDef({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.unit,
    this.normal,
    this.hint,
    this.points = const [],
    this.link,
  });

  final String id;
  final String label;
  final FieldType type;
  final List<String> options;
  final String? unit;

  /// The expected answer ([kYes] / [kNo] for yes/no, an option for choice).
  final String? normal;
  final String? hint;

  /// Score items: points for each of [options], in order.
  final List<int> points;

  /// A record an abnormal answer should also go into: [kLinkAllergy] or
  /// [kLinkDrugHistory]. The app offers to add it after saving.
  final String? link;

  /// Points for a chosen score option, or null when not answered.
  int? pointsFor(Object? value) {
    final i = value is String ? options.indexOf(value) : -1;
    return i < 0 || i >= points.length ? null : points[i];
  }

  int get maxPoints => points.isEmpty ? 0 : points.reduce((a, b) => a > b ? a : b);

  /// Detail text for an abnormal answer is stored under this key.
  String get detailKey => '$id.detail';

  /// Has an expected answer that "All Normal" can fill in.
  bool get hasNormal =>
      normal != null && (type == FieldType.yesNo || type == FieldType.choice || type == FieldType.score);

  /// True when [value] is answered and is not the expected answer. (Score
  /// items are judged by their section's total instead.)
  bool isAbnormal(Object? value) =>
      hasNormal && type != FieldType.score && value is String && value.isNotEmpty && value != kNa && value != normal;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    if (options.isNotEmpty) 'options': options,
    if (unit != null) 'unit': unit,
    if (normal != null) 'normal': normal,
    if (hint != null) 'hint': hint,
    if (points.isNotEmpty) 'points': points,
    if (link != null) 'link': link,
  };

  static FormFieldDef fromJson(Map<String, Object?> j) => FormFieldDef(
    id: j['id'] as String? ?? '',
    label: j['label'] as String? ?? '',
    type: FieldType.fromName(j['type'] as String?),
    options: (j['options'] as List?)?.whereType<String>().toList() ?? const [],
    unit: j['unit'] as String?,
    normal: j['normal'] as String?,
    hint: j['hint'] as String?,
    points: (j['points'] as List?)?.whereType<num>().map((n) => n.toInt()).toList() ?? const [],
    link: j['link'] as String?,
  );

  FormFieldDef copyWith({
    String? label,
    FieldType? type,
    List<String>? options,
    String? unit,
    String? normal,
    bool clearNormal = false,
    bool clearUnit = false,
  }) => FormFieldDef(
    id: id,
    label: label ?? this.label,
    type: type ?? this.type,
    options: options ?? this.options,
    unit: clearUnit ? null : (unit ?? this.unit),
    normal: clearNormal ? null : (normal ?? this.normal),
    hint: hint,
    points: points,
    link: link,
  );
}

const kLinkAllergy = 'allergy', kLinkDrugHistory = 'drug_history';

/// A band of a score: totals from [min] up (to the next band) read [label].
class ScoreBand {
  const ScoreBand(this.min, this.label, {this.abnormal = false});
  final int min;
  final String label;
  final bool abnormal;

  Map<String, Object?> toJson() => {'min': min, 'label': label, if (abnormal) 'abnormal': true};

  static ScoreBand fromJson(Map<String, Object?> j) =>
      ScoreBand((j['min'] as num?)?.toInt() ?? 0, j['label'] as String? ?? '', abnormal: j['abnormal'] == true);
}

/// A section whose score items add up to a named total.
class ScoreSpec {
  const ScoreSpec({required this.name, required this.bands});
  final String name;

  /// Ascending by [ScoreBand.min].
  final List<ScoreBand> bands;

  ScoreBand? bandFor(int total) {
    ScoreBand? out;
    for (final b in bands) {
      if (total >= b.min) out = b;
    }
    return out;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'bands': [for (final b in bands) b.toJson()],
  };

  static ScoreSpec? fromJson(Object? j) => j is Map
      ? ScoreSpec(
          name: j['name'] as String? ?? 'Score',
          bands: [
            for (final b in (j['bands'] as List? ?? const []))
              if (b is Map) ScoreBand.fromJson(b.cast<String, Object?>()),
          ],
        )
      : null;
}

/// A section's score: total, the most it could be, and whether every item
/// is answered.
class SectionScore {
  const SectionScore(this.spec, this.total, this.max, {required this.complete});
  final ScoreSpec spec;
  final int total, max;
  final bool complete;

  ScoreBand? get band => spec.bandFor(total);

  /// "FLACC 6/10 — moderate pain".
  String get line => '${spec.name} $total/$max${band == null ? '' : ' — ${band!.label}'}';
}

class FormSectionDef {
  const FormSectionDef({required this.id, required this.title, required this.fields, this.score});
  final String id;
  final String title;
  final List<FormFieldDef> fields;

  /// Set when the section's score items add up to a named total.
  final ScoreSpec? score;

  bool get hasNormals => fields.any((f) => f.hasNormal);

  FormSectionDef copyWith({String? title, List<FormFieldDef>? fields}) =>
      FormSectionDef(id: id, title: title ?? this.title, fields: fields ?? this.fields, score: score);

  /// The total so far, or null for an unscored section or no answers yet.
  SectionScore? scoreFor(Map<String, Object?> answers) {
    final spec = score;
    if (spec == null) return null;
    final items = fields.where((f) => f.type == FieldType.score).toList();
    final got = [for (final f in items) f.pointsFor(answers[f.id])];
    if (got.every((p) => p == null)) return null;
    return SectionScore(
      spec,
      got.whereType<int>().fold(0, (a, b) => a + b),
      items.fold(0, (a, f) => a + f.maxPoints),
      complete: got.every((p) => p != null),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'fields': [for (final f in fields) f.toJson()],
    if (score != null) 'score': score!.toJson(),
  };

  static FormSectionDef fromJson(Map<String, Object?> j) => FormSectionDef(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    fields: [
      for (final f in (j['fields'] as List? ?? const []))
        if (f is Map) FormFieldDef.fromJson(f.cast<String, Object?>()),
    ],
    score: ScoreSpec.fromJson(j['score']),
  );
}

class FormDefinition {
  const FormDefinition({required this.sections});
  final List<FormSectionDef> sections;

  Iterable<FormFieldDef> get fields => sections.expand((s) => s.fields);

  Map<String, Object?> toJson() => {
    'sections': [for (final s in sections) s.toJson()],
  };

  static FormDefinition fromJson(Object? j) => FormDefinition(
    sections: [
      if (j is Map)
        for (final s in (j['sections'] as List? ?? const []))
          if (s is Map) FormSectionDef.fromJson(s.cast<String, Object?>()),
    ],
  );
}

/// A form people can fill: built into FolioMed, or a ward's own.
class FormTemplate {
  const FormTemplate({
    required this.key,
    required this.name,
    required this.description,
    required this.definition,
    this.version = 1,
    this.id,
    this.wardId,
    this.basedOn,
    this.archived = false,
    this.updatedByName,
  });

  /// Stable key; a ward form with a built-in's key replaces it on that ward.
  final String key;
  final String name;
  final String description;
  final FormDefinition definition;
  final int version;

  /// Database id; null for built-in forms.
  final String? id;
  final String? wardId;
  final String? basedOn;
  final bool archived;
  final String? updatedByName;

  bool get isBuiltIn => id == null;

  static FormTemplate fromRow(Map<String, dynamic> row) => FormTemplate(
    id: row['id'] as String?,
    wardId: row['ward_id'] as String?,
    key: row['key'] as String? ?? '',
    name: row['name'] as String? ?? '',
    description: row['description'] as String? ?? '',
    version: (row['version'] as num?)?.toInt() ?? 1,
    definition: FormDefinition.fromJson(row['definition']),
    basedOn: row['based_on'] as String?,
    archived: row['archived'] as bool? ?? false,
    updatedByName: row['updated_by_name'] as String?,
  );
}

/// The vital-sign keys inside a vitals answer, with labels and units.
const kVitals = <(String, String, String)>[
  ('weight', 'Weight', 'kg'),
  ('temp', 'Temperature', '°C'),
  ('rr', 'Breathing rate', '/min'),
  ('hr', 'Heart rate', '/min'),
  ('sbp', 'BP systolic', 'mmHg'),
  ('dbp', 'BP diastolic', 'mmHg'),
  ('spo2', 'SpO₂', '%'),
];

/// Sets every field in [section] that has an expected answer to it, and
/// drops their abnormal details. Returns a new map.
Map<String, Object?> markSectionNormal(Map<String, Object?> answers, FormSectionDef section) {
  final out = Map<String, Object?>.of(answers);
  for (final f in section.fields) {
    if (!f.hasNormal) continue;
    out[f.id] = f.normal;
    out.remove(f.detailKey);
  }
  return out;
}

/// Answers worth carrying into the next form of the same kind ("copy from
/// last time"): everything except vital signs, dates and scores, which are
/// measured afresh each time.
Map<String, Object?> carryForward(Map<String, Object?> previous, FormDefinition def) {
  final skip = {
    for (final f in def.fields)
      if (f.type == FieldType.vitals || f.type == FieldType.date || f.type == FieldType.score) f.id,
  };
  return {
    for (final e in previous.entries)
      if (!skip.contains(e.key.split('.').first)) e.key: e.value,
  };
}

/// Abnormal answers that still need a description.
List<FormFieldDef> missingDetails(FormDefinition def, Map<String, Object?> answers) => [
  for (final f in def.fields)
    if (f.isAbnormal(answers[f.id]) && ((answers[f.detailKey] as String?)?.trim().isEmpty ?? true)) f,
];
