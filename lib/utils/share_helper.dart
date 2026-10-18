import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../services/supabase_service.dart';

/// Centralised share text. Returns a download/use link appropriate
/// for the current platform. When the app is published these links
/// can be swapped without changing call sites.
class ShareHelper {
  static const String _webUrl = 'https://www.foliomed.com/app/';

  // Switch to Play / App Store URLs once published.
  static String _platformLink() => _webUrl;

  static String _baseMessage() =>
      'Try FolioMed — real-time clinical notes for ward teams.';

  static String message() => '${_baseMessage()}\n\n${_platformLink()}';

  /// Returns a personalised share message including the signed-in user's
  /// name and (if set) specialty.
  static Future<String> personalisedMessage() async {
    final uid = supabase.auth.currentUser?.id;
    String? name;
    String? specialty;
    if (uid != null) {
      try {
        final row = await supabase
            .from(Tables.profiles)
            .select('name, specialty')
            .eq('id', uid)
            .maybeSingle();
        name = row?['name'] as String?;
        specialty = row?['specialty'] as String?;
      } catch (e) {
        debugPrint('ShareHelper: profile lookup failed: $e');
      }
    }
    final byLine = (name != null && name.trim().isNotEmpty)
        ? (specialty != null && specialty.trim().isNotEmpty
            ? '\nFrom Dr. ${name.trim()} · ${specialty.trim()}'
            : '\nFrom ${name.trim()}')
        : '';
    return '${_baseMessage()}$byLine\n\n${_platformLink()}';
  }

  static Future<void> shareApp() async {
    try {
      final msg = await personalisedMessage().timeout(
        const Duration(seconds: 3),
        onTimeout: () => message(),
      );
      await Share.share(msg, subject: 'Check out FolioMed');
    } catch (_) {
      await Share.share(message(), subject: 'Check out FolioMed');
    }
  }
}
