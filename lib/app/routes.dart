import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/account_provider.dart';
import 'home_shell.dart';
import '../screens/start/alert_setup_screen.dart';
import '../screens/start/launch_screen.dart';
import '../screens/start/role_screen.dart';
import '../screens/start/sign_in_screen.dart';
import '../screens/start/welcome_screen.dart';

/// Top-level destinations. Everything else is pushed as a page from the
/// screen that owns it.
abstract final class Routes {
  static const launch = '/';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const chooseRole = '/role';
  static const alertSetup = '/alert-setup';
  static const home = '/home';

  static Map<String, WidgetBuilder> get table => {
        launch: (_) => const LaunchScreen(),
        welcome: (_) => const WelcomeScreen(),
        signIn: (_) => const SignInScreen(),
        chooseRole: (_) => const RoleScreen(),
        alertSetup: (_) => const AlertSetupScreen(firstRun: true),
        home: (context) => HomeShell(
              role: context.read<AccountProvider>().currentUser?.role ?? UserRole.doctor,
            ),
      };

  /// Clears the stack and starts again from the launch decision.
  static void restart(BuildContext context) =>
      Navigator.of(context).pushNamedAndRemoveUntil(launch, (_) => false);

  static void toSignIn(BuildContext context) =>
      Navigator.of(context).pushNamedAndRemoveUntil(signIn, (_) => false);
}
