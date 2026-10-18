import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_theme.dart';
import '../providers/theme_provider.dart';

// Support tile + daily chai popup both land here. The ?from=foliomed
// query param lets the support page attribute the visitor source.
const String _chaiUrl = 'https://www.foliomed.app/support';
const String _kLastShownKey = 'support_popup_last_shown';
const String _kDisabledKey = 'support_popup_disabled';
const Duration _interval = Duration(hours: 24);

class SupportPrompt {
  /// Returns whether the daily chai popup is enabled.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kDisabledKey) ?? false);
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisabledKey, !enabled);
  }

  /// Shows the popup if more than 24h have passed since the last show
  /// AND the user hasn't disabled it. Safe to call on every home open.
  /// Never shown on iOS (App Store guideline 3.1.1 — no external tip links).
  static Future<void> maybeShowDaily(BuildContext context) async {
    // Apple guideline 3.1.1: no external tip/payment prompts on iOS.
    if (!kIsWeb && Platform.isIOS) return;

    final prefs = await SharedPreferences.getInstance();
    final disabled = prefs.getBool(_kDisabledKey) ?? false;
    if (disabled) return;

    final lastShownMillis = prefs.getInt(_kLastShownKey) ?? 0;
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
    final elapsed = DateTime.now().difference(lastShown);
    if (elapsed < _interval) return;

    if (!context.mounted) return;
    await Future.delayed(const Duration(seconds: 2));
    if (!context.mounted) return;
    await showSupportSheet(context);
    await prefs.setInt(
      _kLastShownKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SupportSheet(),
  );
}

class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.local_cafe_outlined,
                color: Color(0xFFE57F00),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Support FolioMed ☕',
              style: GoogleFonts.dmSans(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "I've poured a lot of late nights into building FolioMed and keeping it free for everyone. Servers, database, and hosting all cost real money.\n\nIf FolioMed helps your ward team, please consider buying me a chai. Even a small contribution keeps the lights on and lets me keep adding features.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 22),
            // On iOS we cannot link to external payments (App Store 3.1.1).
            // Show a "Get Help" contact button instead.
            if (!kIsWeb && Platform.isIOS) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _open(
                      'mailto:kashyap2k007@gmail.com?subject=FolioMed%20Feedback',
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mail_outline, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Send Feedback',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _open(_chaiUrl);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57F00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Buy me a chai',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe later',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '— Kashyap A.',
              style: GoogleFonts.dmSans(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fall back to in-app web view if no external browser available.
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {/* swallow */}
    }
  }
}
