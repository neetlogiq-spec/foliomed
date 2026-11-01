import '../forms/form_model.dart';
import 'row_parsing.dart';

/// A filled form, with the definition it was filled with.
class PatientForm {
  const PatientForm({
    required this.id,
    required this.patientId,
    required this.templateKey,
    required this.templateName,
    required this.templateVersion,
    required this.definition,
    required this.answers,
    required this.summary,
    required this.abnormalCount,
    required this.createdAt,
    this.createdByName,
  });

  final String id;
  final String patientId;
  final String templateKey;
  final String templateName;
  final int templateVersion;
  final FormDefinition definition;
  final Map<String, Object?> answers;
  final String summary;
  final int abnormalCount;
  final DateTime createdAt;
  final String? createdByName;

  static PatientForm fromRow(DbRow row) => PatientForm(
    id: row['id'] as String? ?? '',
    patientId: row['patient_id'] as String? ?? '',
    templateKey: row['template_key'] as String? ?? '',
    templateName: row['template_name'] as String? ?? '',
    templateVersion: (row['template_version'] as num?)?.toInt() ?? 1,
    definition: FormDefinition.fromJson(row['definition']),
    answers: (row['answers'] as Map?)?.cast<String, Object?>() ?? const {},
    summary: row['summary'] as String? ?? '',
    abnormalCount: (row['abnormal_count'] as num?)?.toInt() ?? 0,
    createdAt: parseTimestamp(row['created_at']),
    createdByName: row['created_by_name'] as String?,
  );
}
