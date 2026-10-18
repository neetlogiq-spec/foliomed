import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SubscriptionProvider extends ChangeNotifier {
  bool _isPro = false;
  bool _isLoading = false;
  DateTime? _expiresAt;

  // TODO: set to false before App Store submission
  static const bool _devUnlocked = true;

  bool get isPro => _devUnlocked || _isPro;
  bool get isLoading => _isLoading;
  DateTime? get expiresAt => _expiresAt;

  static const int priceInr = 2999;
  static const String planName = 'FolioMed Pro';

  Future<void> checkSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _isPro = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final expires = (data['expiresAt'] as Timestamp?)?.toDate();
        _isPro = data['isPro'] == true &&
            (expires == null || expires.isAfter(DateTime.now()));
        _expiresAt = expires;
      } else {
        _isPro = false;
      }
    } catch (_) {
      _isPro = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> activateTrial() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final expires = DateTime.now().add(const Duration(days: 7));
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(uid)
        .set({
      'isPro': true,
      'plan': 'trial',
      'activatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expires),
    });

    _isPro = true;
    _expiresAt = expires;
    notifyListeners();
  }
}
