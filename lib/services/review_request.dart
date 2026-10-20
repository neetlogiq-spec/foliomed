import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for an App Store / Play rating rarely and only after real use:
/// installed for at least 14 days, at least 10 sessions, and not asked in
/// the last 120 days. The OS may still decide not to show the dialog.
class ReviewRequest {
  ReviewRequest._();

  static const _firstSeenKey = 'review_first_seen_v1';
  static const _sessionsKey = 'review_sessions_v1';
  static const _lastAskedKey = 'review_last_asked_v1';

  static const minAge = Duration(days: 14);
  static const minSessions = 10;
  static const cooldown = Duration(days: 120);

  /// Pure rule, for testing.
  static bool shouldAsk({
    required DateTime now,
    required DateTime firstSeen,
    required int sessions,
    DateTime? lastAsked,
  }) =>
      now.difference(firstSeen) >= minAge &&
      sessions >= minSessions &&
      (lastAsked == null || now.difference(lastAsked) >= cooldown);

  static Future<void> recordSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.getInt(_firstSeenKey) ??
          await prefs.setInt(_firstSeenKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_sessionsKey, (prefs.getInt(_sessionsKey) ?? 0) + 1);
    } catch (_) {}
  }

  /// Call right after something went well (e.g. a reminder marked done).
  static Future<void> maybeAsk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final first = prefs.getInt(_firstSeenKey);
      if (first == null) return;
      final last = prefs.getInt(_lastAskedKey);
      if (!shouldAsk(
        now: now,
        firstSeen: DateTime.fromMillisecondsSinceEpoch(first),
        sessions: prefs.getInt(_sessionsKey) ?? 0,
        lastAsked: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
      )) {
        return;
      }
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await prefs.setInt(_lastAskedKey, now.millisecondsSinceEpoch);
      await review.requestReview();
    } catch (_) {}
  }
}
