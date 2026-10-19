import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show navigatorKey, scaffoldMessengerKey;
import '../models/note.dart';
import '../providers/notification_provider.dart';
import '../utils/app_theme.dart';
import 'supabase_service.dart';

/// In-app note alerts over Supabase Realtime.
///
/// While the app is open, every note a teammate posts in one of the
/// user's wards (row-level security filters the feed server-side) lands in
/// the notification inbox and shows a banner.
///
/// Closed-app alerts come from server push (PushRegistration + the
/// push-dispatch Edge Function).
class PushService {
  PushService._();

  static RealtimeChannel? _channel;

  /// Call once after sign-in / sign-up. Safe to call repeatedly.
  static Future<void> register() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await _unsubscribe();
    _channel = supabase
        .channel('note-alerts-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: Tables.notes,
          callback: (payload) => _onNoteInserted(payload.newRecord, uid),
        )
        .subscribe((status, [error]) {
      if (error != null) debugPrint('PushService realtime: $status $error');
    });
  }

  static void _onNoteInserted(Map<String, dynamic> row, String myUid) {
    final note = Note.fromRow(row);
    if (note.authorId == myUid) return; // don't alert the author
    final isUrgent = note.priority.toLowerCase() == 'urgent';
    final title = isUrgent
        ? '🚨 Urgent · ${note.patientName.isEmpty ? 'patient' : note.patientName}'
        : 'Note · ${note.patientName.isEmpty ? 'patient' : note.patientName}';
    final preview = note.content.length > 140
        ? '${note.content.substring(0, 140)}…'
        : note.content;
    final body =
        '${note.authorName.isEmpty ? 'Someone' : note.authorName}: $preview';
    _showInApp(title, body);
  }

  static void _showInApp(String title, String body) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ctx.read<NotificationProvider>().add(title, body);
    }
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.white)),
            Text(body,
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static Future<void> _unsubscribe() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await supabase.removeChannel(channel);
  }

  /// Call on sign-out.
  static Future<void> unregister(String uid) => _unsubscribe();
}
