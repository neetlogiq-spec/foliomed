import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// Best-effort counters + activity feed for the admin dashboard and the
/// landing page's live stats. Failures are logged and swallowed —
/// telemetry must never block the user-facing operation.
class UsageCounters {
  UsageCounters._();

  /// type: one of 'note', 'patient', 'ward', 'user', 'ack', 'comment'
  /// (validated by the `bump_metric` SQL function).
  static Future<void> bump(String type, {String summary = ''}) async {
    try {
      await supabase.rpc('bump_metric', params: {
        'p_type': type,
        'p_summary': summary,
      });
    } catch (e) {
      debugPrint('UsageCounters.bump($type) failed: $e');
    }
  }
}
