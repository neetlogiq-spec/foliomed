import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'app_keys.dart';
import 'routes.dart';

/// App-wide state, theme and navigation.
class FolioMedApp extends StatelessWidget {
  const FolioMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppearanceProvider()..load()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => PatientRoster()),
        ChangeNotifierProvider(create: (_) => WardFeed()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => UnitProvider()),
        ChangeNotifierProvider(create: (_) => AlertInbox()),
      ],
      child: Consumer<AppearanceProvider>(
        builder: (context, look, _) => MaterialApp(
          title: 'FolioMed',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: look.themeMode,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          initialRoute: Routes.launch,
          routes: Routes.table,
          // The phone's text size, plus FolioMed's optional extra step.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: look.scalerOver(mq.textScaler)),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}

/// Shown when a build was made without `env.json` (no backend settings).
class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'This build of FolioMed has no server settings.\n\n'
                'Developers: run with --dart-define-from-file=env.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
