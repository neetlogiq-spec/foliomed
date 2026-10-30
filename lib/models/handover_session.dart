import 'row_parsing.dart';

/// "If … then …" line for a patient (I-PASS situation awareness).
class Contingency {
  const Contingency({
    required this.id,
    required this.patientId,
    required this.ifText,
    required this.thenText,
    this.createdByName,
    required this.createdAt,
  });

  final String id;
  final String patientId;
  final String ifText;
  final String thenText;
  final String? createdByName;
  final DateTime createdAt;

  /// "If SpO₂ below 92% → call PICU registrar".
  String get line => 'If $ifText → $thenText';

  factory Contingency.fromRow(DbRow r) => Contingency(
        id: r['id'] as String? ?? '',
        patientId: r['patient_id'] as String? ?? '',
        ifText: r['if_text'] as String? ?? '',
        thenText: r['then_text'] as String? ?? '',
        createdByName: r['created_by_name'] as String?,
        createdAt: parseTimestamp(r['created_at']),
      );
}

/// One shift-change handover (`handovers` row).
class HandoverSession {
  const HandoverSession({
    required this.id,
    required this.wardId,
    this.unitId,
    required this.scopeLabel,
    required this.startedAt,
    this.givenBy,
    required this.givenByName,
    this.finishedAt,
    this.finishedByName,
  });

  final String id;
  final String wardId;
  final String? unitId;
  final String scopeLabel;
  final DateTime startedAt;
  final String? givenBy;
  final String givenByName;
  final DateTime? finishedAt;
  final String? finishedByName;

  bool get isOpen => finishedAt == null;

  factory HandoverSession.fromRow(DbRow r) => HandoverSession(
        id: r['id'] as String? ?? '',
        wardId: r['ward_id'] as String? ?? '',
        unitId: r['unit_id'] as String?,
        scopeLabel: r['scope_label'] as String? ?? '',
        startedAt: parseTimestamp(r['started_at']),
        givenBy: r['given_by'] as String?,
        givenByName: r['given_by_name'] as String? ?? '',
        finishedAt: parseTimestampOrNull(r['finished_at']),
        finishedByName: r['finished_by_name'] as String?,
      );
}

/// One patient in a handover (`handover_entries` row).
class HandoverEntry {
  const HandoverEntry({
    required this.id,
    required this.handoverId,
    this.patientId,
    required this.patientName,
    required this.bedNumber,
    required this.position,
    this.receivedAt,
    this.receivedByName,
    this.question,
  });

  final String id;
  final String handoverId;

  /// Null if the patient record was deleted since.
  final String? patientId;
  final String patientName;
  final String bedNumber;
  final int position;
  final DateTime? receivedAt;
  final String? receivedByName;
  final String? question;

  bool get received => receivedAt != null;

  factory HandoverEntry.fromRow(DbRow r) => HandoverEntry(
        id: r['id'] as String? ?? '',
        handoverId: r['handover_id'] as String? ?? '',
        patientId: r['patient_id'] as String?,
        patientName: r['patient_name'] as String? ?? '',
        bedNumber: r['bed_number'] as String? ?? '',
        position: (r['position'] as num?)?.toInt() ?? 0,
        receivedAt: parseTimestampOrNull(r['received_at']),
        receivedByName: r['received_by_name'] as String?,
        question: r['question'] as String?,
      );
}
