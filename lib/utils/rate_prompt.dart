import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Periodic in-app review nudge.
///
/// Calls Google Play's in-app review dialog (the one that overlays the
/// running app — no Play Store switch) once every 7 days. We never see
/// whether the dialog actually rendered: Google rate-limits the prompt
/// per user (typically a handful of times per year), so even if we ask
/// weekly the user only sees it occasionally — exactly the cadence Play
/// recommends.
///
/// We also gate by:
///  - Don't prompt on web (no Play Services).
///  - Don't prompt before the user has had the app for at least 3 days
///    so brand-new installs don't get a rating popup the moment they
///    open the home screen.
///  - User can disable it from Profile → Preferences (key
///    `_kDisabledKey` below).
class RatePrompt {
  static const String _kLastShownKey = 'rate_prompt_last_shown';
  static const String _kFirstLaunchKey = 'rate_prompt_first_launch';
  static const String _kDisabledKey = 'rate_prompt_disabled';

  static const Duration _interval = Duration(days: 7);
  static const Duration _minAppAgeBeforeFirstPrompt = Duration(days: 3);

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kDisabledKey) ?? false);
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisabledKey, !enabled);
  }

  /// Stamps "first launch" the first time we ever see this install.
  /// Cheap, safe to call on every home open.
  static Future<void> _ensureFirstLaunchStamped(
    SharedPreferences prefs,
  ) async {
    if (prefs.getInt(_kFirstLaunchKey) != null) return;
    await prefs.setInt(
      _kFirstLaunchKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Fires the in-app review request if all of the following are true:
  ///  - not on web
  ///  - prompt isn't disabled by the user
  ///  - install is at least 3 days old
  ///  - it's been at least 7 days since the last attempt
  ///  - InAppReview reports availability on this device
  ///
  /// Safe to call on every home open. Cheap when conditions aren't met.
  static Future<void> maybeShowWeekly() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await _ensureFirstLaunchStamped(prefs);

    if (prefs.getBool(_kDisabledKey) ?? false) return;

    final firstLaunchMs = prefs.getInt(_kFirstLaunchKey);
    if (firstLaunchMs != null) {
      final firstLaunch = DateTime.fromMillisecondsSinceEpoch(firstLaunchMs);
      if (DateTime.now().difference(firstLaunch) <
          _minAppAgeBeforeFirstPrompt) {
        return;
      }
    }

    final lastShownMs = prefs.getInt(_kLastShownKey) ?? 0;
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    if (DateTime.now().difference(lastShown) < _interval) return;

    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await review.requestReview();
    } catch (_) {
      // Never let a review failure crash the app or block the user.
      return;
    }

    await prefs.setInt(
      _kLastShownKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
