import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/push_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/web_notice.dart';
import 'background_setup_screen.dart';
import 'onboarding_screen.dart';
import '../../providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    await WebNotice.maybeShow(context);
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    // We use a versioned key so a Samsung Smart Switch / Google Auto Backup
    // restore that brings back the *old* flag won't suppress the new
    // tutorial on a fresh install.
    final onboardingDone = prefs.getBool(kOnboardingDoneKey) ?? false;

    if (supabase.auth.currentUser == null) {
      if (!mounted) return;
      if (!onboardingDone) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    await authProvider.loadCurrentUser();
    if (!mounted) return;
    PushService.register();

    if (authProvider.currentUser == null) {
      Navigator.of(context).pushReplacementNamed(
        onboardingDone ? '/login' : '/onboarding',
      );
      return;
    }

    final wizardSkip = BackgroundSetupScreen.shouldSkip();
    final wizardDone = wizardSkip
        ? true
        : await BackgroundSetupScreen.isDone();
    if (!mounted) return;
    if (!wizardDone) {
      Navigator.of(context).pushReplacementNamed('/background-setup');
      return;
    }

    switch (authProvider.currentUser!.role) {
      case UserRole.doctor:
        Navigator.of(context).pushReplacementNamed('/doctor/home');
        break;
      case UserRole.nurse:
        Navigator.of(context).pushReplacementNamed('/nurse/home');
        break;
      case UserRole.admin:
        Navigator.of(context).pushReplacementNamed('/admin/home');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion: show the settled state, no fades or looping dots.
    final reduced = AppMotion.reduced(context);
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'F',
                    style: appText(
                      color: Colors.white,
                      fontSize: 180,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -8,
                    ),
                  )
                      .animate(autoPlay: !reduced, value: reduced ? 1 : 0)
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.85, 0.85)),
                  const SizedBox(height: 8),
                  Text(
                    'FOLIOMED',
                    style: appText(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ).animate(autoPlay: !reduced, value: reduced ? 1 : 0).fadeIn(delay: 200.ms, duration: 600.ms),
                  const SizedBox(height: 10),
                  Text(
                    'Ward, connected',
                    style: appText(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ).animate(autoPlay: !reduced, value: reduced ? 1 : 0).fadeIn(delay: 400.ms, duration: 600.ms),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      )
                          .animate(
                            autoPlay: !reduced,
                            value: reduced ? 1 : 0,
                            onPlay: (c) => c.repeat(reverse: true),
                          )
                          .fadeIn(
                            delay: (i * 200).ms,
                            duration: 600.ms,
                          )
                          .then()
                          .fadeOut(duration: 600.ms),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
