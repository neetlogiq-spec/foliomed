import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/accessibility_settings.dart';
import 'services/reminder_notifications.dart';
import 'services/push_registration.dart';
import 'clinical/bilirubin.dart';
import 'clinical/bilirubin_assess.dart';
import 'utils/app_theme.dart';
import 'app/routes.dart';
import 'widgets/tip_card.dart';
import 'providers/providers.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AccessibilitySettings.init();
  await ReminderNotifications.instance.init();
  await PushRegistration.instance.initFirebase();
  try {
    Aap2022.loadJson(await rootBundle.loadString('assets/clinical/aap2022_bilirubin.json'));
    await GuidelinePreference.load();
    await TipStore.load();
  } catch (e) {
    debugPrint('AAP thresholds not loaded: $e'); // AAP then reports "could not be loaded"
  }
  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const FolioMedApp());
}

/// Shown instead of crashing when the build was made without env.json.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'FolioMed is missing its Supabase configuration.\n\n'
              'Build with: flutter run --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class FolioMedApp extends StatelessWidget {
  const FolioMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WardFeed()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => WardProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => TextScaleProvider()..load()),
        ChangeNotifierProvider(create: (_) => AlertInbox()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => UnitProvider()),
      ],
      child: Consumer2<ThemeProvider, TextScaleProvider>(
        builder: (context, themeProvider, textScale, _) {
          return MaterialApp(
            title: 'FolioMed',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            initialRoute: Routes.launch,
            routes: Routes.table,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(textScale.scale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
