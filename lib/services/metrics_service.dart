import 'package:cloud_firestore/cloud_firestore.dart';

/// Best-effort, public-readable counters + live activity feed for the
/// admin dashboard. Failures are swallowed — telemetry must never block
/// the user-facing operation.
class MetricsService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Logs an activity entry and bumps cumulative counters.
  /// type: one of 'note', 'patient', 'ward', 'user', 'ack', 'comment'
  static Future<void> bump(String type, {String summary = ''}) async {
    try {
      final now = Timestamp.now();
      await _fs.collection('recent_activity').add({
        'type': type,
        'summary': summary,
        'at': now,
      });
      await _fs.collection('metrics').doc('totals').set({
        'last${_capitalise(type)}At': now,
        'lastActivityAt': now,
        '${type}Count': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {
      // intentionally silent — metrics are best-effort
    }
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
