import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/push_registration.dart';
import '../../services/push_service.dart';
import '../../services/review_request.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/foliomed_brand.dart';
import 'alert_setup_screen.dart';
import 'launch_decision.dart';
import 'welcome_screen.dart';

/// First frame on a cold start. It looks like the app's own background —
/// no branded splash — and only shows a mark and spinner if loading
/// actually takes a while, then hands off to the right destination.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _slow = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _route() async {
    final auth = context.read<AuthProvider>();
    final signedIn = supabase.auth.currentUser != null;
    if (signedIn) {
      await auth.loadCurrentUser();
      PushService.register();
      PushRegistration.instance.register();
      ReviewRequest.recordSession();
    }
    final user = auth.currentUser;
    final step = decideLaunch(
      signedIn: signedIn,
      hasProfile: user != null,
      welcomeSeen: await WelcomeScreen.seen(),
      roleConfirmed: user?.roleConfirmed ?? false,
      alertSetupNeeded: await AlertSetupScreen.needed(),
    );
    if (!mounted) return;
    final route = switch (step) {
      LaunchStep.welcome => Routes.welcome,
      LaunchStep.signIn => Routes.signIn,
      LaunchStep.chooseRole => Routes.chooseRole,
      LaunchStep.alertSetup => Routes.alertSetup,
      LaunchStep.home => Routes.home,
    };
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: AnimatedOpacity(
          opacity: _slow ? 1 : 0,
          duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 250),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FolioMedMark(size: 56),
              SizedBox(height: 20),
              CupertinoActivityIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
