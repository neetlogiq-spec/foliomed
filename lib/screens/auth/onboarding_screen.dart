import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_theme.dart';
import '../../providers/theme_provider.dart';

/// Bumping this string forces the tutorial to re-show for everyone, even
/// users whose SharedPreferences got restored by a phone-cloning tool
/// (Samsung Smart Switch in particular).
const String kOnboardingDoneKey = 'onboarding_complete_v3';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const int _slideCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingDoneKey, true);
    // Clean up the legacy key so we're not left with two flags around.
    await prefs.remove('onboarding_complete');
  }

  Future<void> _goLogin() async {
    await _markDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _skip() {
    _pageController.animateToPage(
      _slideCount - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _SlideProblem(),
                  _SlideSolution(),
                  _SlideHowItWorks(),
                  _SlideMonitoring(),
                  _SlideGetStarted(),
                ],
              ),
            ),
            _NavBar(
              page: _page,
              total: _slideCount,
              onBack: _back,
              onNext: _next,
              onSkip: _skip,
              onSignIn: _goLogin,
              onRegister: _goLogin,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Slide 1 — The problem ───────────────────────────

class _SlideProblem extends StatelessWidget {
  const _SlideProblem();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SlideEyebrow(
            icon: Icons.warning_amber_rounded,
            label: 'THE PROBLEM',
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          Text(
            'Ward updates get lost in the chaos.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Every shift, critical patient information slips through the cracks. Notes get scribbled on paper, plans get verbal-only, and the next team comes in blind.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextSecondary,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          const _PainPoint(
            icon: Icons.chat_bubble_outline,
            text:
                'Urgent updates buried under hundreds of WhatsApp messages',
          ),
          const _PainPoint(
            icon: Icons.note_alt_outlined,
            text:
                'Paper notes lost, illegible, or never reach the next shift',
          ),
          const _PainPoint(
            icon: Icons.help_outline,
            text:
                "Nobody knows who's seen what — was the plan acknowledged?",
          ),
          const _PainPoint(
            icon: Icons.access_time,
            text:
                'Phone calls back-and-forth eat minutes that patients don\'t have',
          ),
          const _PainPoint(
            icon: Icons.history_toggle_off,
            text:
                'No clean record of decisions when handover happens',
          ),
          const _PainPoint(
            icon: Icons.monitor_heart_outlined,
            text:
                "Nurses cover 4–6 beds — vitals change while they're with another patient",
          ),
        ],
      ),
    );
  }
}

class _PainPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PainPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.danger, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                text,
                style: GoogleFonts.dmSans(
                  color: AppColors.lightTextPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Slide 2 — The solution ──────────────────────────

class _SlideSolution extends StatelessWidget {
  const _SlideSolution();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand block.
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'W',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOLIOMED',
                      style: GoogleFonts.dmSans(
                        color: AppColors.lightTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      'Ward, connected.',
                      style: GoogleFonts.dmSans(
                        color: AppColors.lightTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SlideEyebrow(
            icon: Icons.lightbulb_outline,
            label: 'THE FIX',
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'One live feed for the whole ward team.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'FolioMed puts every patient note, plan and alert in one shared timeline. Anyone on your ward — senior or junior, doctor or nurse — sees the same updates the moment they happen.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextSecondary,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          const _BenefitTile(
            icon: Icons.bolt_outlined,
            title: 'Real-time, every device',
            body:
                'Post once — the whole team gets it instantly with a push notification.',
          ),
          const _BenefitTile(
            icon: Icons.check_circle_outline,
            title: 'Acknowledged, on the record',
            body:
                'See exactly who has seen and acted on every note. No more guessing.',
          ),
          const _BenefitTile(
            icon: Icons.lock_outline,
            title: 'Ward-private by design',
            body:
                'Members of your ward see your ward — nothing more, nothing else.',
          ),
          const _BenefitTile(
            icon: Icons.history,
            title: 'Permanent patient history',
            body:
                'Every note is filed against the patient, ready when handover hits.',
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: AppColors.lightTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    color: AppColors.lightTextSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Slide 3 — How it works ──────────────────────────

class _SlideHowItWorks extends StatelessWidget {
  const _SlideHowItWorks();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SlideEyebrow(
            icon: Icons.touch_app_outlined,
            label: 'HOW IT WORKS',
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Four taps from chaos\nto coordinated.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 18),

          // Step 1 — ward code chip
          _NumberedStep(
            number: 1,
            title: 'Create or join your ward',
            body:
                "One person creates the ward — FolioMed hands them a 5-digit code. Share it with the team and they're in.",
            child: _wardCodeMock(),
          ),

          // Step 2 — patient
          _NumberedStep(
            number: 2,
            title: 'Add a patient',
            body:
                "Add the patients on your ward once. Notes get filed against the right person automatically.",
            child: _patientChipMock(),
          ),

          // Step 3 — note card mock
          _NumberedStep(
            number: 3,
            title: 'Post a note',
            body:
                "Write the update, set Normal, Urgent or Low priority, hit post. Done.",
            child: _noteCardMock(),
          ),

          // Step 4 — acknowledged note
          _NumberedStep(
            number: 4,
            title: 'Team sees it & acknowledges',
            body:
                "Push notifications fire across the ward. A teammate taps Acknowledge — the whole team sees who, when, and what they replied.",
            child: _ackedNoteMock(),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _wardCodeMock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F1FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_box_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ICU Ward A',
                  style: GoogleFonts.dmSans(
                    color: AppColors.lightTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Code: 47291 · tap to copy',
                  style: GoogleFonts.dmSans(
                    color: AppColors.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.copy, size: 16, color: AppColors.lightTextSecondary),
        ],
      ),
    );
  }

  Widget _patientChipMock() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _miniPatient('Bed 12', 'Mr. R. Kumar'),
        _miniPatient('Bed 18', 'Ms. A. Shah'),
        _miniPatient('Bed 24', 'Mr. S. Iyer'),
      ],
    );
  }

  Widget _miniPatient(String bed, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              bed,
              style: GoogleFonts.dmSans(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCardMock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Urgent',
                      style: GoogleFonts.dmSans(
                        color: AppColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bed 12 · Mr. R. Kumar',
                style: GoogleFonts.dmSans(
                  color: AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'BP dropping — please review. Started fluids, awaiting cardiology callback.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dr. Pew Pew · 2 min ago',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ackedNoteMock() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    'SM',
                    style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Kashyap Anand',
                  style: GoogleFonts.dmSans(
                    color: AppColors.lightTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Doctor',
                    style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'now',
                  style: GoogleFonts.dmSans(
                    color: AppColors.lightTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  'Acknowledged by Kashyap Anand',
                  style: GoogleFonts.dmSans(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: Text(
              "On it — calling cardiology now.",
              style: GoogleFonts.dmSans(
                color: AppColors.lightTextPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final Widget child;
  final bool last;

  const _NumberedStep({
    required this.number,
    required this.title,
    required this.body,
    required this.child,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.primary.withOpacity(0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: AppColors.lightTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.dmSans(
                      color: AppColors.lightTextSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Slide 4 — FolioMed Pro monitoring ─────────────────

class _SlideMonitoring extends StatelessWidget {
  const _SlideMonitoring();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SlideEyebrow(
            icon: Icons.monitor_heart_outlined,
            label: 'FOLIOMED PRO',
            color: AppColors.accent,
          ),
          const SizedBox(height: 14),
          Text(
            'Add live patient monitoring. Powered by AI.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upgrade your ward to FolioMed Pro and every monitored bed streams live vitals into the Monitor tab — with instant alerts the moment a reading crosses your limits.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextSecondary,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          _vitalsMock(),
          const SizedBox(height: 18),
          const _BenefitTile(
            icon: Icons.dashboard_outlined,
            title: 'Ward vitals dashboard',
            body:
                'HR, SpO₂, RR and BP for every monitored patient — live, in one place.',
          ),
          const _BenefitTile(
            icon: Icons.notifications_active_outlined,
            title: 'Smart alerts',
            body:
                'Set thresholds per patient. Breaches alert the whole ward team instantly.',
          ),
          const _BenefitTile(
            icon: Icons.videocam_outlined,
            title: 'Works with your existing monitors',
            body:
                'A camera watches the monitor screen and our AI reads the numbers — no expensive integrations.',
          ),
          const _BenefitTile(
            icon: Icons.desktop_windows_outlined,
            title: 'FolioMed Edge',
            body:
                'The hospital desktop that runs the cameras and relays live vitals to the team.',
          ),
          const SizedBox(height: 8),
          Text(
            'FolioMed core stays as it is — Pro is an optional upgrade per ward.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextSecondary,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalsMock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Bed 12 · Mr. R. Kumar',
                style: GoogleFonts.dmSans(
                  color: AppColors.lightTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ALERT',
                  style: GoogleFonts.dmSans(
                    color: AppColors.danger,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniVital('HR', '128', AppColors.danger),
              _miniVital('SpO₂', '94', AppColors.lightTextPrimary),
              _miniVital('RR', '22', AppColors.lightTextPrimary),
              _miniVital('BP', '82/45', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniVital(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Slide 5 — Get started ───────────────────────────

class _SlideGetStarted extends StatelessWidget {
  const _SlideGetStarted();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SlideEyebrow(
            icon: Icons.rocket_launch_outlined,
            label: 'GET STARTED',
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Your ward, your data,\nyour rules.',
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "FolioMed is private by ward. Only your ward's members see your notes and patients. Owners can delete the ward at any time — when they do, every note, patient and reply inside is permanently erased.",
            style: GoogleFonts.dmSans(
              color: AppColors.lightTextSecondary,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          _trustCard(),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sign in to begin. New here? Tap "Create a new account" on the next screen.',
                    style: GoogleFonts.dmSans(
                      color: AppColors.lightTextPrimary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Column(
        children: [
          for (final t in const [
            ('Ward-private', 'Only members of your ward can read your data.'),
            ('Real-time', 'Notes, replies and acks sync across devices live.'),
            ('Erasable', 'Owner deletes the ward → everything inside is gone.'),
            ('Reusable codes', 'Deleted ward codes free up for the next team.'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.dmSans(
                          color: AppColors.lightTextPrimary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(
                            text: '${t.$1}. ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: t.$2,
                            style: TextStyle(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Shared widgets ──────────────────────────────────

class _SlideEyebrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SlideEyebrow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  final int page;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  const _NavBar({
    required this.page,
    required this.total,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onSignIn,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final isLast = page == total - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              final active = i == page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          if (!isLast)
            Row(
              children: [
                if (page == 0)
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.dmSans(
                        color: AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('← Back'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Next →'),
                ),
              ],
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign in to FolioMed',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRegister,
                  child: Text(
                    'Create a new account',
                    style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
