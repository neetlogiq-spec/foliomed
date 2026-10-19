import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_theme.dart';
import '../../providers/theme_provider.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  // Versioned: bumping re-shows the tour once for existing users after an
  // update that changes the app's layout (same pattern as onboarding).
  static const String prefKey = 'tutorial_done_v2';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey);
  }

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _slides = <_TutorialSlide>[
    _TutorialSlide(
      icon: Icons.waving_hand_outlined,
      iconColor: AppColors.primary,
      title: 'Welcome to FolioMed',
      body:
          "A 60-second tour of every button so you know what does what. You can re-run this any time from Profile → Tutorial.",
      points: [
        ('Real-time notes', 'See updates from your team instantly'),
        ('Multi-ward', 'Be in any number of wards at once'),
        ('Acknowledge & reply', 'Confirm action, comment in thread'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.today_outlined,
      iconColor: AppColors.primary,
      title: 'Today',
      body: "Your home tab shows what needs doing now:",
      points: [
        ('Tiles', 'Admitted patients, pending notes and urgent notes — tap to filter'),
        ('Reminders', 'Due and upcoming tasks such as 48 h / 72 h investigations'),
        ('Ward notes', 'Pending · All · Urgent. The ⇕ button collapses notes to one line each'),
        ('🔔 Bell', 'Notifications panel; the person icon adds a patient'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.add_circle,
      iconColor: AppColors.accent,
      title: 'Posting a note',
      body: "Doctors tap 'New note' (bottom-right) and pick:",
      points: [
        ('Patient', 'From your wards — or add one inline'),
        ('Category & priority', 'Low / Normal / Urgent'),
        ('Scan text', 'Photograph a report and its text is added for you'),
        ('Acknowledge ✓', 'Nurses confirm they have acted on a note'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.people_outline,
      iconColor: AppColors.doctorColor,
      title: 'Patients',
      body:
          "Everyone on your wards, grouped by ward. Search by name, bed, diagnosis or ID, and switch to Discharged to see past patients.",
      points: [
        ('Patient page', 'Timeline, reminders and the ••• menu'),
        ('••• menu', 'Edit details · transfer · discharge or readmit · delete'),
        ('Newborns', 'Set the birth time to see hours of life and 48 h / 72 h reminders'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.local_hospital_outlined,
      iconColor: AppColors.accent,
      title: 'Wards — share & join',
      body:
          "Every ward has a 5-digit code. Tap + in Wards to create one or join with a code, and tap a ward to copy or share its code.",
      points: [
        ('Members', 'Everyone in the ward, with their role'),
        ('Invite', 'Send the code by WhatsApp, SMS or email'),
        ('Leave / Delete', 'Only the owner can delete a ward (erases its patients and notes)'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.check_circle_outline,
      iconColor: AppColors.accent,
      title: "You're all set",
      body:
          "Join a ward, admit a patient, post a note — your team sees it instantly.",
      points: [
        ('Need help?', 'Profile → Tutorial brings this back any time'),
        ('Notifications missing?', 'Profile → Notification setup walks you through it'),
      ],
    ),
  ];

  bool get _isLast => _page >= _slides.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await TutorialScreen.markDone();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            _navBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Text(
            'Tutorial',
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _finish,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Widget _navBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_page > 0)
                OutlinedButton(
                  onPressed: _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('← Back'),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: Text(_isLast ? 'Done' : 'Next →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TutorialSlide {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final List<(String, String)> points;
  const _TutorialSlide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.points,
  });
}

class _SlideView extends StatelessWidget {
  final _TutorialSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: slide.iconColor.withOpacity(0.13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(slide.icon, color: slide.iconColor, size: 42),
          ),
          const SizedBox(height: 24),
          Text(
            slide.title,
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            style: appText(
              color: AppColors.textSecondary,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          if (slide.points.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final p in slide.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.$1,
                            style: appText(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.$2,
                            style: appText(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
