import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';

class WebNotice {
  static const _prefKey = 'web_notice_shown';
  static const _playStore =
      'https://play.google.com/store/apps/details?id=com.foliomed.app';
  static const _appStore =
      'https://apps.apple.com/app/foliomed/idYOUR_APP_STORE_ID';

  static Future<void> maybeShow(BuildContext context) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return;
    if (!context.mounted) return;
    await _show(context);
    await prefs.setBool(_prefKey, true);
  }

  static Future<void> _show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone_iphone,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Best on the app',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FolioMed is built for live ward updates — push notifications, instant alerts, smoother UI. The mobile app gives you the full experience.',
              style: GoogleFonts.dmSans(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _storeButton(
              icon: Icons.android,
              label: 'Get on Play Store',
              onTap: () => _open(_playStore),
            ),
            const SizedBox(height: 8),
            _storeButton(
              icon: Icons.apple,
              label: 'Get on App Store',
              onTap: () => _open(_appStore),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Continuing on web? Allow browser notifications so urgent alerts reach you.',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _requestNotificationPermission();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Continue on web'),
          ),
        ],
      ),
    );
  }

  static Widget _storeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* swallow */}
  }

  static Future<void> _requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // user dismissed or unsupported
    }
  }
}
