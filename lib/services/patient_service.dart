import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/patient.dart';
import '../utils/app_constants.dart';
import 'metrics_service.dart';

class PatientService {
  final FirebaseFirestore _firestore;

  PatientService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _patients =>
      _firestore.collection(AppConstants.patientsCollection);

  /// Cap to keep Firestore reads predictable. Even a busy ward rarely has
  /// >100 active patients at a time; 200 is a generous ceiling.
  static const int kPatientsListCap = 200;

  Stream<List<Patient>> getActivePatientsForWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _patients
        .where('wardId', whereIn: wardIds)
        .where('isActive', isEqualTo: true)
        .orderBy('admittedAt', descending: true)
        .limit(kPatientsListCap)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Patient.fromFirestore).toList());
  }

  Stream<List<Patient>> getPatientsByWard(String wardId) {
    return _patients
        .where('wardId', isEqualTo: wardId)
        .where('isActive', isEqualTo: true)
        .orderBy('admittedAt', descending: true)
        .limit(kPatientsListCap)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Patient.fromFirestore).toList());
  }

  Future<Patient?> getPatient(String patientId) async {
    final doc = await _patients.doc(patientId).get();
    if (!doc.exists) return null;
    return Patient.fromFirestore(doc);
  }

  Future<String> addPatient(Patient patient) async {
    final ref = await _patients.add(patient.toMap());
    MetricsService.bump('patient', summary: 'Admitted ${patient.name}');
    return ref.id;
  }

  Future<void> updatePatient(Patient patient) async {
    await _patients.doc(patient.id).update(patient.toMap());
  }

  Future<void> saveHlsUrl(String patientId, String url) async {
    await _patients.doc(patientId).update({'hlsStreamUrl': url.trim()});
  }

  Future<void> deletePatient(String patientId) async {
    await _deleteNotesFor(patientId);
    await _patients.doc(patientId).delete();
  }

  /// Deletes every note tagged to a patient — and the comments inside
  /// each note — using batched writes (max 500 ops per batch). Without
  /// the batch this fired one Firestore call per doc, multiplying both
  /// latency and write cost.
  Future<void> _deleteNotesFor(String patientId) async {
    final notes = await _firestore
        .collection(AppConstants.notesCollection)
        .where('patientId', isEqualTo: patientId)
        .get();

    var batch = _firestore.batch();
    var ops = 0;
    Future<void> flushIfNeeded() async {
      if (ops >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }

    for (final note in notes.docs) {
      // Subcollections don't cascade — schedule comment deletes first.
      final comments = await note.reference.collection('comments').get();
      for (final c in comments.docs) {
        batch.delete(c.reference);
        ops++;
        await flushIfNeeded();
      }
      batch.delete(note.reference);
      ops++;
      await flushIfNeeded();
    }
    if (ops > 0) await batch.commit();
  }

  /// Capped at the same ceiling as the patient list.
  Stream<int> getPatientCount(String wardId) {
    return _patients
        .where('wardId', isEqualTo: wardId)
        .where('isActive', isEqualTo: true)
        .limit(kPatientsListCap)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
