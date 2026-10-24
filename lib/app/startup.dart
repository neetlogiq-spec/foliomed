import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../clinical/bilirubin.dart';
import '../config/supabase_config.dart';
import '../services/accessibility_settings.dart';
import '../services/push_registration.dart';
import '../services/reminder_notifications.dart';
import '../widgets/tip_card.dart';

/// Everything that must be ready before the first frame. Each step is
/// independent: one failing (say, the AAP data) never skips the others.
/// Returns false when the build has no backend configuration.
Future<bool> prepareApp() async {
  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      debugPrint('Start-up step "$name" failed: $e');
    }
  }

  await step('accessibility', AccessibilitySettings.init);
  await step('local notifications', ReminderNotifications.instance.init);
  await step('push', PushRegistration.instance.initFirebase);
  await step('AAP thresholds', () async {
    Aap2022.loadJson(await rootBundle.loadString('assets/clinical/aap2022_bilirubin.json'));
  });
  await step('tips', TipStore.load);

  if (!SupabaseConfig.isConfigured) return false;
  await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  return true;
}
