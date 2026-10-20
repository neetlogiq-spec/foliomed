import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'app_keys.dart';
import 'routes.dart';

/// Live state every screen can read, created once. Each object starts its
/// network work lazily, on first use.
List<SingleChildWidget> sharedState() => [
      ChangeNotifierProvider.value(value: AppearanceProvider()..load()),
      ChangeNotifierProvider.value(value: AccountProvider()),
      ChangeNotifierProvider.value(value: PatientRoster()),
      ChangeNotifierProvider.value(value: WardFeed()),
      ChangeNotifierProvider.value(value: ReminderProvider()),
      ChangeNotifierProvider.value(value: JobBoard()),
      ChangeNotifierProvider.value(value: UnitProvider()),
      ChangeNotifierProvider.value(value: AlertInbox()),
    ];

/// The app: shared state above a MaterialApp that follows the chosen
/// appearance and adds FolioMed's extra text size to the phone's.
class FolioMedApp extends StatefulWidget {
  const FolioMedApp({super.key});

  @override
  State<FolioMedApp> createState() => _FolioMedAppState();
}

class _FolioMedAppState extends State<FolioMedApp> {
  // Created once for the life of the app (not on every rebuild).
  late final List<SingleChildWidget> _state = sharedState();

  @override
  Widget build(BuildContext context) => MultiProvider(providers: _state, child: const _Shell());
}

class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceProvider>();
    return MaterialApp(
      title: 'FolioMed',
      routes: Routes.table,
      initialRoute: Routes.launch,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      themeMode: appearance.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final phone = MediaQuery.of(context);
        return MediaQuery(
          data: phone.copyWith(textScaler: appearance.scalerOver(phone.textScaler)),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
