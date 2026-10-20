import '../models/note.dart';
import '../models/patient.dart';
import '../models/patient_reminder.dart';
import '../models/ward_job.dart';
import '../models/ward_unit.dart';

/// Applies a [PatientScope] to notes and reminders, which carry a ward but
/// not a unit: the unit comes from the patient they're about.
class ScopeFilter {
  ScopeFilter(this.scope, Iterable<Patient> patients)
      : _byId = {for (final p in patients) p.id: p};

  final PatientScope scope;
  final Map<String, Patient> _byId;

  bool patient(Patient p) => scope.includes(wardId: p.wardId, unitId: p.unitId);

  bool _about(String patientId, String wardId) {
    if (scope.isAll) return true;
    final p = _byId[patientId];
    if (p != null) return patient(p);
    // Patient not in the admitted list (e.g. discharged): ward-level scopes
    // still show it; unit scopes can't place it, so they don't.
    return scope.wardId == wardId && scope.unitId == null && !scope.unassigned;
  }

  bool note(Note n) => _about(n.patientId, n.wardId);

  bool reminder(PatientReminder r) => _about(r.patientId, r.wardId);

  /// Jobs only count while their patient is admitted.
  bool job(WardJob j) {
    final p = _byId[j.patientId];
    return p != null && patient(p);
  }
}
