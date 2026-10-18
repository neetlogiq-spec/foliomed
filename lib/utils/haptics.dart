import 'package:flutter/services.dart';

/// Semantic haptics, reserved for meaningful moments (commit, success,
/// destructive, error) so they stay informative. Fired on the same frame
/// as the state change they confirm. No-ops where unsupported.
class Haptics {
  Haptics._();

  /// Selection changed (tabs, segmented controls, pickers).
  static void selection() => HapticFeedback.selectionClick();

  /// A light confirmation — e.g. acknowledging a note.
  static void commit() => HapticFeedback.lightImpact();

  /// Something was created or completed — e.g. a note was posted.
  static void success() => HapticFeedback.mediumImpact();

  /// Something was removed.
  static void destructive() => HapticFeedback.heavyImpact();

  /// An action failed.
  static void error() => HapticFeedback.vibrate();
}
