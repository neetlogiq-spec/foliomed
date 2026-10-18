import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/ward.dart';
import '../utils/app_constants.dart';

class WardService {
  final FirebaseFirestore _firestore;

  WardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _wards =>
      _firestore.collection(AppConstants.wardsCollection);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  /// Streams the wards a user is a member of. Pass the user's wardIds list.
  /// An empty list yields an empty stream — no Firestore query, no rule
  /// denial. Caller is responsible for chunking past 30 ids if ever needed.
  Stream<List<Ward>> wardsForUser(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const <Ward>[]);
    final ids = wardIds.length > 30 ? wardIds.sublist(0, 30) : wardIds;
    return _wards
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Ward.fromFirestore).toList());
  }

  /// Legacy admin-only helper — fetches every ward in the system. With the
  /// current Firestore rules this only returns wards the caller is a
  /// member of, so for non-admin paths use [wardsForUser] instead.
  Stream<List<Ward>> getAllWards() {
    return _wards.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map(Ward.fromFirestore).toList(),
        );
  }

  Future<Ward?> getWard(String wardId) async {
    final doc = await _wards.doc(wardId).get();
    if (!doc.exists) return null;
    return Ward.fromFirestore(doc);
  }

  Future<String> addWard(Ward ward) async {
    final ref = await _wards.add(ward.toMap());
    return ref.id;
  }

  Future<void> updateWard(Ward ward) async {
    await _wards.doc(ward.id).update(ward.toMap());
  }

  /// Capped at 100 — even a large hospital ward rarely has more staff
  /// than that. Hard cap stops any runaway live-stream cost.
  Stream<List<AppUser>> getWardStaff(String wardId) {
    return _users
        .where('wardId', isEqualTo: wardId)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AppUser.fromFirestore).toList());
  }
}
