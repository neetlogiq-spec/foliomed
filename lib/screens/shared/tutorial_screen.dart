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
          "A 60-second tour of every button so you know what does what. You can re-run this any time from Profile → View tutorial.",
      points: [
        ('Real-time notes', 'See updates from your team instantly'),
        ('Multi-ward', 'Be in any number of wards at once'),
        ('Acknowledge & reply', 'Confirm action, comment in thread'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.dashboard_outlined,
      iconColor: AppColors.primary,
      title: 'The top bar',
      body: "Each icon in the top right has a job:",
      points: [
        ('🔔 Bell', 'Tap it for the notifications panel — every unacked note grouped by urgency'),
        ('☀️ / 🌙', 'Toggle light / dark mode'),
        ('📤 Share', 'Send FolioMed to your teammates'),
        ('☕ Chai', 'Support the app development'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.analytics_outlined,
      iconColor: AppColors.accent,
      title: 'The stat cards',
      body: "The 3 cards at the top of Home are tappable shortcuts:",
      points: [
        ('Patients', 'Tap → full patient list across your wards'),
        ('Notes Today', 'Tap → all of today\'s notes, grouped by date'),
        ('Urgent', 'Glows red when you have urgent notes — tap to filter only urgent'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.people_outline,
      iconColor: AppColors.doctorColor,
      title: 'Active patients',
      body:
          "Horizontal carousel of admitted patients in your wards. Tap any patient card to open their detail page with full note history. The Patients tab in the bottom nav shows the same list grouped by ward.",
      points: [],
    ),
    _TutorialSlide(
      icon: Icons.notes_outlined,
      iconColor: AppColors.primary,
      title: 'Recent notes',
      body:
          "Latest team activity. Each card shows priority, author, patient, and the note text.",
      points: [
        ('Reply', 'Opens the thread — chat-style replies on the note'),
        ('Acknowledge ✓', 'Confirms you\'ve seen and acted on it'),
        ('⋮ menu', 'Delete (only the author can fully erase a note)'),
        ('Tap card', 'Same as Reply — opens the thread'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.add_circle,
      iconColor: AppColors.accent,
      title: 'Posting a new note',
      body:
          "The blue 'New Note' button (bottom-right) opens a sheet where you pick:",
      points: [
        ('Ward', 'Which ward this note belongs to'),
        ('Patient', 'Tap to pick from your ward — or tap "Add new patient" inline'),
        ('Category', 'Medication / Procedure / Observation / Alert / General'),
        ('Priority', 'Low / Normal / Urgent'),
        ('Content', 'Plain text. Be specific — your team relies on it.'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.menu,
      iconColor: AppColors.adminColor,
      title: 'Bottom navigation',
      body: "Up to six tabs, depending on your role:",
      points: [
        ('Home', 'Stats + active patients + recent notes'),
        ('Wards', 'Your wards · share codes · join · create · view members'),
        ('Patients', 'Tabs per ward, full active patient list'),
        ('Notes', 'Every ward note — full feed'),
        ('Profile', 'Your account, theme, daily chai toggle, sign out'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.local_hospital_outlined,
      iconColor: AppColors.accent,
      title: 'Wards — share & join',
      body:
          "In the Wards tab, every ward has a 5-digit code. Tap the code to copy it; tap Share to send it through WhatsApp / SMS / email.\n\nTeammates use Join Ward (top right) and enter the code — they're in.",
      points: [
        ('Members', 'Who else is in this ward'),
        ('Share', 'Send the join code'),
        ('Delete', 'Only the ward creator can delete it (cascades patients + notes)'),
      ],
    ),
    _TutorialSlide(
      icon: Icons.check_circle_outline,
      iconColor: AppColors.accent,
      title: "You're all set",
      body:
          "That's the whole app. Sign in, join a ward, post a note. Your team gets it instantly.",
      points: [
        ('Need help?', 'Profile → View tutorial brings this back any time'),
        ('Notifications missing?', 'Profile → Notification setup walks you through it'),
        ('Thanks!', 'If FolioMed helps your team — buy me a chai ☕'),
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
