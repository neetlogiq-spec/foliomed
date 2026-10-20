import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/patient.dart';
import '../../providers/account_provider.dart';
import '../../tools/newborn_scores.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import '../notes/compose_note_sheet.dart';
import 'tool_page.dart';

/// Any [ScoreDefinition]: the running total sits at the top, each item is a
/// list of choices, and a finished score can be copied or added as a note.
class ScoreTool extends StatefulWidget {
  const ScoreTool({super.key, required this.definition});
  final ScoreDefinition definition;

  @override
  State<ScoreTool> createState() => _ScoreToolState();
}

class _ScoreToolState extends State<ScoreTool> {
  late ScoreAnswers _answers = ScoreAnswers(widget.definition);
  Patient? _baby;

  void _choose(int item, int option) {
    Haptics.selection();
    setState(() => _answers = _answers.choose(item, option));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _answers.summary()));
    Haptics.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.definition;
    final canPost = context.watch<AccountProvider>().currentUser?.role == UserRole.doctor;
    return ToolPage(
      title: d.name,
      method: '${d.purpose}. Add the points for each item.\n'
          'Ranges: ${d.bands.map((b) => '${b.min}${b.max == b.min ? '' : '–${b.max}'} ${b.label}').join('; ')}.',
      source: d.source,
      children: [
        _Total(answers: _answers),
        const SizedBox(height: 20),
        for (var i = 0; i < d.items.length; i++) ...[
          InsetGroup(
            header: d.items[i].name,
            dividerIndent: 16,
            children: [
              for (var o = 0; o < d.items[i].options.length; o++)
                _OptionRow(
                  option: d.items[i].options[o],
                  selected: _answers.choices[i] == o,
                  onTap: () => _choose(i, o),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (_answers.complete) ...[
          BabyRow(patient: _baby, onPicked: (p) => setState(() => _baby = p)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              if (canPost) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => showComposeNote(context,
                        patient: _baby, text: _answers.summary(), kind: 'Observation'),
                    icon: const Icon(Icons.edit_square, size: 18),
                    label: const Text('Add as Note'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.answers});
  final ScoreAnswers answers;

  @override
  Widget build(BuildContext context) {
    final d = answers.definition;
    final band = answers.band;
    final color = switch (band?.concern) {
      2 => AppColors.danger,
      1 => AppColors.warning,
      0 => AppColors.stable,
      _ => AppColors.textSecondary,
    };
    return Semantics(
      liveRegion: true,
      label: '${d.name} ${answers.total} of ${d.maxTotal}. ${band?.label ?? '${answers.answered} of ${d.items.length} answered'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${answers.total}', style: AppTypography.largeTitle(color: AppColors.textPrimary)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text('/ ${d.maxTotal}', style: AppTypography.headline(color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  band == null ? '${answers.answered} of ${d.items.length} answered' : _capitalised(band.label),
                  textAlign: TextAlign.end,
                  style: AppTypography.headline(color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalised(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.selected, required this.onTap});
  final ScoreOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${option.points}',
                        style: AppTypography.headline(color: AppColors.textSecondary)),
                  ),
                  Expanded(child: Text(option.label, style: AppTypography.body(color: AppColors.textPrimary))),
                  if (selected) Icon(Icons.check, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      );
}
