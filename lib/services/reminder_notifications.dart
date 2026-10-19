import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/patient_reminder.dart';

/// On-device notifications for patient reminders, so a due "Send 48-hour
/// investigations" alerts even when FolioMed is closed.
///
/// No server is involved: every phone that has opened FolioMed schedules
/// its ward's open reminders locally and re-syncs whenever the list
/// changes. Phones that haven't opened the app since a reminder was added
/// won't know about it (that needs server push — still a TODO).
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

  /// Replaces every scheduled reminder notification with [open].
  Future<void> sync(List<PatientReminder> open) async {
    if (!isSupported) return;
    await init();
    try {
      await _plugin.cancelAllPendingNotifications();
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
