import 'row_parsing.dart';

/// What kind of ward this is; picks the automatic status rules
/// (`lib/clinical/patient_status.dart`). [other] follows the patient's age.
enum WardKind {
  pnc('PNC / Newborn'),
  nicu('NICU'),
  picu('PICU'),
  paeds('Paediatric ward'),
  adult('Adult ward'),
  other('Other');

  const WardKind(this.label);
  final String label;

  static WardKind fromName(String? v) =>
      values.firstWhere((k) => k.name == v, orElse: () => other);

  /// A likely type from the ward's name ("NICU 2" → [nicu]), to
  /// pre-select when setting one up. Null when the name gives no hint.
  static WardKind? guessFrom(String wardName) {
    final n = ' ${wardName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
    bool has(List<String> words) => words.any((w) => n.contains(' $w '));
    if (has(['nicu', 'sncu', 'nnu', 'scbu', 'neonatal'])) return nicu;
    if (has(['picu', 'phdu'])) return picu;
    if (has(['pnc', 'postnatal', 'postpartum', 'maternity', 'newborn', 'rooming'])) return pnc;
    if (has(['paeds', 'peds', 'paediatric', 'paediatrics', 'pediatric', 'pediatrics', 'children', 'childrens', 'child'])) {
      return paeds;
    }
    if (has(['icu', 'micu', 'sicu', 'ccu', 'hdu', 'medical', 'surgical', 'medicine', 'surgery', 'adult', 'male', 'female',
        'ortho', 'orthopaedic', 'orthopedic', 'general'])) {
      return adult;
    }
    return null;
  }
}

/// Starter clinical tags (the database default for new wards).
const List<String> kDefaultTagOptions = [
  'NPO', 'Isolation', 'Fall risk', 'Allergy', 'Awaiting scan', 'Awaiting results', 'For discharge',
];

/// A team space people join with its 5-digit [id] (the code they share).
/// Dart names are FolioMed's; [Ward.fromRow] maps the `wards` columns.
class Ward {
  const Ward({
    required this.id,
    required this.name,
    this.location = '',
    this.beds = 0,
    this.ownerName = '',
    this.ownerId = '',
    this.ownerEmail = '',
    required this.createdAt,
    this.kind = WardKind.other,
    this.tagOptions = kDefaultTagOptions,
    this.shiftStarts = const [480, 840, 1200],
  });

  final String id;
  final String name;
  final String location; // floor, block or building — free text
  final int beds;
  final String ownerName; // captured when the ward was set up
  final String ownerId;
  final String ownerEmail;
  final DateTime createdAt;

  /// Set by the owner (WardService.setKind); [toRow] never writes it.
  final WardKind kind;

  /// The ward's clinical tags (owner edits via WardService.setTagOptions;
  /// [toRow] never writes them).
  final List<String> tagOptions;

  /// Shift start times, minutes after local midnight (workload report).
  /// Owner edits via WardService.setShiftStarts; [toRow] never writes it.
  final List<int> shiftStarts;

  bool ownedBy(String uid) => uid.isNotEmpty && uid == ownerId;

  static Ward fromRow(DbRow row) {
    String text(String column) => row[column] as String? ?? '';
    return Ward(
      id: text('id'),
      name: text('name'),
      location: text('floor'),
      beds: (row['capacity'] as num?)?.toInt() ?? 0,
      ownerName: text('head_doctor_name'),
      ownerId: text('creator_id'),
      ownerEmail: text('creator_email'),
      createdAt: parseTimestamp(row['created_at']),
      kind: WardKind.fromName(row['kind'] as String?),
      tagOptions: (row['tag_options'] as List?)?.cast<String>() ?? kDefaultTagOptions,
      shiftStarts: [for (final m in (row['shift_starts'] as List?) ?? const [480, 840, 1200]) (m as num).toInt()],
    );
  }

  /// The row to insert. It carries [id] because a new ward claims its code
  /// on insert; a code that is already taken fails the primary key.
  DbRow toRow() => {
        'id': id,
        'name': name,
        'floor': location,
        'capacity': beds,
        'head_doctor_name': ownerName,
        'creator_id': ownerId.isEmpty ? null : ownerId,
        'creator_email': ownerEmail,
      };
}
