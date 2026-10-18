import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_theme.dart';
import '../../providers/theme_provider.dart';

/// Static FAQ / Help screen. No database reads — everything is hardcoded
/// content the user can read offline. Reachable from Profile.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<_FaqItem> _faqs = [
    _FaqItem(
      icon: Icons.corporate_fare_outlined,
      q: 'How do I create a ward?',
      a: 'Open the Wards tab and tap "Create New Ward" at the bottom. '
          'Enter a name (e.g. "ICU Ward A") and an optional floor — FolioMed '
          'gives you a 5-digit code to share with your team.',
    ),
    _FaqItem(
      icon: Icons.group_add_outlined,
      q: 'How do I invite my team to a ward?',
      a: 'On the ward card, tap the Share button — FolioMed composes a '
          'message with the 5-digit code that you can drop into WhatsApp '
          'or any messaging app. Teammates open FolioMed → Wards → Join Ward '
          'and enter that code.',
    ),
    _FaqItem(
      icon: Icons.priority_high,
      q: 'What do Normal, Urgent and Low priority mean?',
      a: '• Urgent — fires a high-priority push to every ward member.\n'
          '• Normal — standard push.\n'
          '• Low — silently logged for routine updates.\n\n'
          'Use Urgent sparingly so it stays attention-grabbing.',
    ),
    _FaqItem(
      icon: Icons.check_circle_outline,
      q: 'How do I acknowledge a note?',
      a: 'Tap a note to open the thread, then tap the green check icon '
          'next to the reply box. You can also type a reply and acknowledge '
          'in one tap — your reply gets flagged "Acknowledged by you" so '
          'the whole team sees who handled it.',
    ),
    _FaqItem(
      icon: Icons.search,
      q: "I can't find a patient — where are they?",
      a: 'Use the search bar at the top of the Patients tab. It searches '
          'across every ward you\'ve joined and highlights the matching '
          'name, bed or diagnosis.',
    ),
    _FaqItem(
      icon: Icons.person_remove_outlined,
      q: 'How do I remove a patient?',
      a: 'On the patient card, tap the ⋮ menu → "Delete permanently". '
          'This erases the patient and every note tagged to them. There '
          'is no recovery, so be sure before you confirm.',
    ),
    _FaqItem(
      icon: Icons.delete_outline,
      q: 'How do I delete a ward?',
      a: 'Only the ward creator (the person who set it up) can delete the '
          'ward. From Wards, tap Delete on the card you own. Every patient, '
          'note and reply inside is permanently erased; the 5-digit code '
          'becomes available for reuse.',
    ),
    _FaqItem(
      icon: Icons.notifications_active_outlined,
      q: "I'm not getting push notifications. What do I do?",
      a: 'Open Profile → "Notification setup" and run through the wizard. '
          'On Samsung / Xiaomi / OnePlus devices, you also need to allow '
          'autostart and disable battery optimisation for FolioMed — those '
          'OEMs aggressively kill background apps.',
    ),
    _FaqItem(
      icon: Icons.lock_outline,
      q: 'Who can see my notes?',
      a: 'Only members of the same ward. If a teammate hasn\'t joined the '
          'ward via the 5-digit code, they cannot see anything inside — '
          'enforced at the database level by row-level security rules.',
    ),
    _FaqItem(
      icon: Icons.history,
      q: 'Where is patient history stored?',
      a: 'Every note is filed against the patient automatically. Open the '
          'patient → "Notes" tab to see the full timeline. Notes survive '
          'as long as the patient and ward exist.',
    ),
    _FaqItem(
      icon: Icons.format_size,
      q: 'Can I make the text larger?',
      a: 'Yes. Profile → Preferences → Text size. Slide up to 150% — every '
          'screen rescales automatically.',
    ),
    _FaqItem(
      icon: Icons.dark_mode_outlined,
      q: 'Is there a dark mode?',
      a: 'Yes. Profile → Preferences → Dark mode. Tuned for fluorescent '
          'ward lighting and remembered across sessions.',
    ),
    _FaqItem(
      icon: Icons.logout,
      q: 'How do I sign out?',
      a: 'Profile → Danger zone → Sign out. You\'ll need to sign in again '
          'next time. To wipe your account entirely, use "Delete account" '
          'in the same section.',
    ),
    _FaqItem(
      icon: Icons.bug_report_outlined,
      q: 'I found a bug. How do I report it?',
      a: 'Profile → Feedback & support → "Report a bug". The pre-filled '
          'email already includes your app version, platform and account '
          'so we can investigate without going back-and-forth.',
    ),
    _FaqItem(
      icon: Icons.lightbulb_outline,
      q: 'Where do I send feature ideas?',
      a: 'Profile → Feedback & support → "Suggest a feature". Every email '
          'is read — small, considered ideas get built fastest.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Help & FAQs'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.help_outline,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stuck or curious?',
                        style: GoogleFonts.dmSans(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These cover the most common questions. If you '
                        'still need help, use Profile → Feedback & support '
                        '→ Give feedback and we\'ll get back to you.',
                        style: GoogleFonts.dmSans(
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
          const SizedBox(height: 16),
          for (final item in _faqs) _FaqTile(item: item),
        ],
      ),
    );
  }
}

class _FaqItem {
  final IconData icon;
  final String q;
  final String a;
  const _FaqItem({required this.icon, required this.q, required this.a});
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, color: AppColors.primary, size: 18),
        ),
        title: Text(
          item.q,
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        children: [
          Text(
            item.a,
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
