import 'package:flutter/foundation.dart';

/// FolioMed is currently free: every feature, including the monitoring
/// suite formerly sold as "Pro", is unlocked for everyone.
///
/// The provider is kept so Pro-gated screens keep compiling unchanged and
/// a paid tier can be reintroduced later by flipping [freeForEveryone]
/// and verifying payments server-side (never trust the client).
class SubscriptionProvider extends ChangeNotifier {
  static const bool freeForEveryone = true;

  static const int priceInr = 2999;
  static const String planName = 'FolioMed Pro';

  bool get isPro => freeForEveryone;
  bool get isLoading => false;
  DateTime? get expiresAt => null;

  Future<void> checkSubscription() async {}

  Future<void> activateTrial() async {}
}
