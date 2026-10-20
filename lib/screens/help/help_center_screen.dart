import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import 'help_topics.dart';

/// Searchable help: sections of questions, each opening a short answer.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(HelpSection s, HelpTopic t) => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => _TopicPage(section: s, topic: t)),
      );

  @override
  Widget build(BuildContext context) {
    final results = _query.isEmpty ? null : searchHelp(_query);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          const LargeTitleAppBar(title: 'Help', showBackButton: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(
              children: [
                CupertinoSearchTextField(
                  controller: _search,
                  placeholder: 'Search help',
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 20),
                if (results != null) ...[
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No answers match “$_query”.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(color: AppColors.textSecondary)),
                    )
                  else
                    InsetGroup(
                      header: '${results.length} result${results.length == 1 ? '' : 's'}',
                      dividerIndent: 16,
                      children: [
                        for (final (s, t) in results)
                          SettingsRow(title: t.question, subtitle: s.title, onTap: () => _open(s, t)),
                      ],
                    ),
                ] else
                  for (final s in kHelpSections) ...[
                    InsetGroup(
                      header: s.title,
                      dividerIndent: 16,
                      children: [
                        for (final t in s.topics) SettingsRow(title: t.question, onTap: () => _open(s, t)),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                const SizedBox(height: 8),
                InsetGroup(
                  footer: 'We usually reply within two working days.',
                  children: [
                    SettingsRow(
                      icon: Icons.mail_outline,
                      title: 'Still stuck? Email us',
                      onTap: () => launchUrl(
                        Uri(scheme: 'mailto', path: 'kashyap2k007@gmail.com', queryParameters: {
                          'subject': 'FolioMed help',
                        }),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicPage extends StatelessWidget {
  const _TopicPage({required this.section, required this.topic});
  final HelpSection section;
  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(title: section.title, showBackButton: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList.list(
              children: [
                Text(topic.question, style: AppTypography.title2(color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Text(topic.answer,
                    style: AppTypography.body(color: AppColors.textPrimary).copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
