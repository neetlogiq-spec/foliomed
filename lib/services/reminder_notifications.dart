import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/patient_reminder.dart';
import 'push_registration.dart';

/// On-device notifications for patient reminders, so a due "Send 48-hour
/// investigations" alerts even when FolioMed is closed.
///
/// Fallback for when server push isn't live: every phone that has opened
/// FolioMed schedules its ward's open reminders locally and re-syncs
/// whenever the list changes. Once push is live the server sends these
/// instead (see PushRegistration / docs/PUSH_SETUP.md).
class ReminderNotifications {
  ReminderNotifications._();
  static final ReminderNotifications instance = ReminderNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// iOS keeps at most 64 pending notifications per app.
  static const int _maxScheduled = 60;

  static const _channel = AndroidNotificationDetails(
    'patient_reminders',
    'Patient reminders',
    channelDescription: 'Investigations and other timed tasks for your wards',
    importance: Importance.high,
    priority: Priority.high,
  );

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Called with a reminder id when the user taps a notification.
  void Function(String reminderId)? onTap;

  Future<void> init() async {
    if (!isSupported || _ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onTap?.call(id);
      },
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Channels that server pushes (FCM) post into.
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'patient_reminders',
      'Patient reminders',
      description: 'Investigations and other timed tasks for your wards',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'ward_notes',
      'Ward notes',
      description: 'New notes from your ward team',
      importance: Importance.high,
    ));
    _ready = true;
  }

  /// Asks for notification permission (Android 13+ and iOS). Safe to call
  /// repeatedly; the OS only prompts once.
  Future<void> requestPermission() async {
    if (!isSupported) return;
    await init();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Replaces every scheduled reminder notification with [open]. When
  /// server push is live the server alerts instead, so nothing is
  /// scheduled locally (no double alerts).
  Future<void> sync(List<PatientReminder> open) async {
    if (!isSupported) return;
    await init();
    try {
      await _plugin.cancelAllPendingNotifications();
      if (PushRegistration.instance.isLive.value) return;
      final now = DateTime.now();
      final upcoming = open
          .where((r) => !r.isDone && r.nextAlertAt.isAfter(now))
          .toList()
        ..sort((a, b) => a.nextAlertAt.compareTo(b.nextAlertAt));
      for (final r in upcoming.take(_maxScheduled)) {
        await _plugin.zonedSchedule(
          id: notificationId(r.id),
          title: r.title,
          body: notificationBody(r),
          scheduledDate: tz.TZDateTime.from(r.nextAlertAt.toUtc(), tz.UTC),
          notificationDetails: const NotificationDetails(
            android: _channel,
            iOS: DarwinNotificationDetails(),
          ),
          // Battery-friendly: may fire a few minutes late, which is fine
          // for hour-scale clinical reminders and avoids the exact-alarm
          // permission Google Play reviews.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.id,
        );
      }
    } catch (e) {
      debugPrint('ReminderNotifications.sync failed: $e');
    }
  }

  Future<void> clear() async {
    if (!isSupported || !_ready) return;
    await _plugin.cancelAllPendingNotifications();
  }
}

/// What the phone notification says for each kind of reminder.
@visibleForTesting
String notificationBody(PatientReminder r) {
  final who = r.patientName.isEmpty ? 'Patient' : r.patientName;
  return switch (r.kind) {
    'newborn_prep' =>
      '$who — get ready: CBC, TSH, blood grouping, TSB, RFT and OAE.',
    'newborn_send' => '$who — have the investigations been sent?',
    'newborn_results' => '$who — are the investigation results back?',
    _ => '$who — has this been done?',
  };
}

/// Stable 31-bit notification id for a reminder uuid.
@visibleForTesting
int notificationId(String reminderId) {
  var hash = 0;
  for (final unit in reminderId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
