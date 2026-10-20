import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/foliomed_brand.dart';

/// First-launch welcome, in the iOS "what this app does" pattern: a title,
/// four feature rows, one button. Shown once per install.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const _seenKey = 'welcome_seen_v1';

  static Future<bool> seen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Feature {
  const _Feature(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _features = [
  _Feature(Icons.forum_outlined, AppColors.primary, 'One feed for the whole ward',
      'Post an update once. Everyone on the team sees it straight away and can mark it as done.'),
  _Feature(Icons.folder_shared_outlined, AppColors.accent, 'A record that follows the patient',
      'Permanent patient IDs, transfers between wards, and every event on one timeline — through to discharge.'),
  _Feature(Icons.child_friendly_outlined, AppColors.nurseColor, 'Made for newborn care',
      'Hours of life, 48- and 72-hour investigations, and bilirubin plotted against AAP and NICE lines.'),
  _Feature(Icons.alarm_on_outlined, AppColors.warning, 'Follow-ups that don’t slip',
      'Set a reminder and FolioMed checks back with the ward until someone confirms it’s done.'),
];

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.reduced(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    Haptics.commit();
    await WelcomeScreen.markSeen();
    if (mounted) Routes.toSignIn(context);
  }

  /// Rows arrive one after another, rising a few points — the motion says
  /// "here is a list", it doesn't perform.
  Widget _staggered(int index, Widget child) {
    final start = 0.1 + index * 0.12;
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start.clamp(0, 0.8), (start + 0.4).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - curve.value)), child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _staggered(0, const Center(child: FolioMedMark(size: 72))),
                        const SizedBox(height: 24),
                        _staggered(
                          0,
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              'Your ward,\nin your pocket',
                              textAlign: TextAlign.center,
                              style: AppTypography.largeTitle(color: AppColors.textPrimary)
                                  .copyWith(height: 1.1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        for (final (i, f) in _features.indexed) ...[
                          _staggered(i + 1, _FeatureRow(feature: f)),
                          const SizedBox(height: 22),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Patient information stays inside your ward team. ',
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () => launchUrl(Uri.parse('https://www.foliomed.app/privacy.html'),
                                  mode: LaunchMode.externalApplication),
                              child: Text('How we handle data',
                                  style: AppTypography.footnote(color: AppColors.primary)),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.footnote(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _continue,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.control)),
                        ),
                        child: Text('Continue',
                            style: AppTypography.headline(color: AppColors.onPrimary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Icon(feature.icon, size: 34, color: feature.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.title,
                    style: AppTypography.headline(color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(feature.body,
                    style: AppTypography.subheadline(color: AppColors.textSecondary)
                        .copyWith(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
