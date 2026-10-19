import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/accessibility_settings.dart';
import 'services/vlm_server_manager.dart';
import 'utils/app_theme.dart';
import 'utils/app_routes.dart';
import 'providers/providers.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AccessibilitySettings.init();
  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const FolioMedApp());
  // Desktop (FolioMed Edge station): boot the embedded vitals AI engine with
  // the app. No-op on mobile/web; never blocks startup.
  VlmServerManager.instance.ensureRunning();
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
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => WardProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => TextScaleProvider()..load()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider2<PatientProvider, WardProvider, MonitorProvider>(
          create: (_) {
            final m = MonitorProvider();
            m.init();
            return m;
          },
          update: (_, patientProvider, wardProvider, monitor) {
            monitor!.syncFromPatients(patientProvider.patients, wardProvider.wards);
            return monitor;
          },
        ),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()..checkSubscription()),
        ChangeNotifierProvider(create: (_) => CameraProvider()..load()),
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
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.generateRoute,
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
