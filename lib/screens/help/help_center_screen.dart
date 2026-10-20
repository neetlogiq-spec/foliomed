import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import 'help_topics.dart';

const _supportEmail = 'kashyap2k007@gmail.com';

/// Icon and tint for each help section (tints follow light/dark mode).
(IconData, Color) _look(HelpSection s) => switch (s.title) {
      'Getting started' => (Icons.flag_outlined, AppColors.primary),
      'Patients' => (Icons.bed_outlined, AppColors.doctorColor),
      'Newborns' => (Icons.child_care, AppColors.secondary),
      'Tools' || 'Jobs' => (s.title == 'Tools' ? Icons.calculate_outlined : Icons.checklist, AppColors.stable),
      'Notes and reminders' => (Icons.sticky_note_2_outlined, AppColors.warning),
      'Wards and units' => (Icons.corporate_fare, AppColors.accent),
      'Alerts' => (Icons.notifications_outlined, AppColors.danger),
      'Account and privacy' => (Icons.lock_outline, AppColors.textSecondary),
      _ => (Icons.help_outline, AppColors.primary),
    };

/// The questions people ask first, shown above the topic grid.
const _popular = [
  'How do I get my team on FolioMed?',
  'What is the job list?',
  'How do the 48- and 72-hour investigations work?',
  'I’m not getting alerts',
];

/// Help in the style of Apple Support: search, popular questions, topics
/// as tiles, and a way to reach a person.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _query = '';

  void _openSection(HelpSection s, {String? expand}) => Navigator.of(context)
      .push(CupertinoPageRoute(builder: (_) => _SectionPage(section: s, initiallyOpen: expand)));

  @override
  Widget build(BuildContext context) {
    final results = _query.isEmpty ? null : searchHelp(_query);
    final popular = [
      for (final q in _popular)
        for (final s in kHelpSections)
          for (final t in s.topics)
            if (t.question == q) (s, t),
    ];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const LargeTitleAppBar(title: 'Help', eyebrow: 'How FolioMed works', showBackButton: true),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList.list(children: [
                CupertinoSearchTextField(
                  placeholder: 'Search help',
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 20),
                if (results != null)
                  results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No answers match “$_query”. Try fewer words, or email us below.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(color: AppColors.textSecondary)),
                        )
                      : InsetGroup(
                          header: results.length == 1 ? 'One answer' : '${results.length} answers',
                          dividerIndent: 16,
                          children: [for (final (s, t) in results) _Answer(topic: t, section: s.title)],
                        )
                else ...[
                  if (popular.isNotEmpty)
                    InsetGroup(
                      header: 'Popular',
                      dividerIndent: 16,
                      children: [for (final (_, t) in popular) _Answer(topic: t)],
                    ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text('BROWSE BY TOPIC', style: AppTypography.footnote(color: AppColors.textSecondary)),
                  ),
                  _TopicGrid(onOpen: _openSection),
                ],
                const SizedBox(height: 28),
                const _ContactCard(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({required this.onOpen});
  final void Function(HelpSection) onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final width = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in kHelpSections)
            SizedBox(
              width: width,
              child: _TopicTile(section: s, onTap: () => onOpen(s)),
            ),
        ],
      );
    });
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.section, required this.onTap});
  final HelpSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look(section);
    final n = section.topics.length;
    return Semantics(
      button: true,
      label: '${section.title}, $n question${n == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(height: 10),
                Text(section.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600)),
                Text('$n question${n == 1 ? '' : 's'}',
                    style: AppTypography.caption1(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A question that opens in place to show its answer.
class _Answer extends StatefulWidget {
  const _Answer({required this.topic, this.section, this.initiallyOpen = false});
  final HelpTopic topic;
  final String? section;
  final bool initiallyOpen;

  @override
  State<_Answer> createState() => _AnswerState();
}

class _AnswerState extends State<_Answer> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return Semantics(
      button: true,
      expanded: _open,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          setState(() => _open = !_open);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.topic.question, style: AppTypography.body(color: AppColors.textPrimary)),
                    if (widget.section != null)
                      Text(widget.section!, style: AppTypography.footnote(color: AppColors.textSecondary)),
                  ]),
                ),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right, color: AppColors.tertiaryLabel),
                ),
              ]),
              AnimatedSize(
                duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: Text(widget.topic.answer,
                            style: AppTypography.subheadline(color: AppColors.textSecondary).copyWith(height: 1.45)),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One topic's questions, each expanding in place.
class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.section, this.initiallyOpen});
  final HelpSection section;
  final String? initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(title: section.title, eyebrow: 'Help', showBackButton: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(children: [
              InsetGroup(
                dividerIndent: 16,
                children: [
                  for (final t in section.topics)
                    _Answer(topic: t, initiallyOpen: t.question == initiallyOpen || section.topics.length == 1),
                ],
              ),
              const SizedBox(height: 28),
              const _ContactCard(),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(children: [
        Icon(Icons.support_agent, size: 30, color: AppColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Still stuck?', style: AppTypography.headline(color: AppColors.textPrimary)),
            Text('Email us — we usually reply within two working days.',
                style: AppTypography.footnote(color: AppColors.textSecondary)),
          ]),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri(scheme: 'mailto', path: _supportEmail, queryParameters: {'subject': 'FolioMed help'}),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Email'),
        ),
      ]),
    );
  }
}
