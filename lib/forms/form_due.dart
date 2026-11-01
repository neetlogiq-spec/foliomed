/// Admission forms each patient should have within 24 hours (the usual
/// accreditation expectation for the initial doctor and nursing
/// assessments).
library;

import '../models/patient.dart';
import 'builtin_forms.dart';

const kAdmissionFormWindow = Duration(hours: 24);

class FormDue {
  const FormDue({required this.key, required this.name, required this.dueBy});
  final String key;
  final String name;
  final DateTime dueBy;

  bool isOverdueAt(DateTime now) => now.isAfter(dueBy);
}

/// Admission forms not yet filled for an admitted [patient] ([filledKeys]
/// are the template keys already filled; a ward copy keeps the key).
List<FormDue> admissionFormsDue(Patient patient, Set<String> filledKeys) => [
  if (patient.isActive)
    for (final e in kAdmissionFormKeys.entries)
      if (!filledKeys.contains(e.key))
        FormDue(key: e.key, name: e.value, dueBy: patient.admittedAt.add(kAdmissionFormWindow)),
];
