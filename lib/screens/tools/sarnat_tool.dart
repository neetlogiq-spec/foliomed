import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/patient.dart';
import '../../providers/account_provider.dart';
import '../../tools/sarnat.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import '../notes/compose_note_sheet.dart';
import 'tool_page.dart';

/// Modified Sarnat staging: grade each sign, see the stage and whether the
/// NICHD moderate/severe criterion is met.
class SarnatTool extends StatefulWidget {
  const SarnatTool({super.key});

  @override
  State<SarnatTool> createState() => _SarnatToolState();
}

class _SarnatToolState extends State<SarnatTool> {
  SarnatAnswers _a = const SarnatAnswers();
  Patient? _baby;

  @override
  Widget build(BuildContext context) {
    final canPost = context.watch<AccountProvider>().currentUser?.role == UserRole.doctor;
    return ToolPage(
      title: 'Modified Sarnat',
      method: 'Grade each sign. An area with several signs takes its worst one.\n'
          'Stage = the grade most of the 6 areas share (a tie counts as the more severe).\n'
          'Moderate or severe encephalopathy (NICHD): 3 or more of the 6 areas moderate or severe.',
      source: 'Sarnat & Sarnat, Arch Neurol 1976; modified form from Shankaran et al., NEJM 2005 (NICHD). Use with '
          'your unit’s cooling criteria (timing, gestation, blood gas and history), not on its own.',
      children: [
        _StageCard(answers: _a),
        const SizedBox(height: 20),
        for (var area = 0; area < kSarnatAreas.length; area++)
          for (var s = 0; s < kSarnatAreas[area].signs.length; s++) ...[
            InsetGroup(
              header: kSarnatAreas[area].signs.length == 1
                  ? kSarnatAreas[area].name
                  : '${kSarnatAreas[area].name} · ${kSarnatAreas[area].signs[s].name}',
              dividerIndent: 16,
              children: [
                for (final g in SarnatGrade.values)
                  _GradeRow(
                    grade: g,
                    look: kSarnatAreas[area].signs[s].looks[g.index],
                    selected: _a.grades[(area, s)] == g,
                    onTap: () {
                      Haptics.selection();
                      setState(() => _a = _a.set(area, s, g));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        if (_a.complete) ...[
          BabyRow(patient: _baby, onPicked: (p) => setState(() => _baby = p)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _a.summary()));
                  Haptics.success();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ),
            if (canPost) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showComposeNote(context, patient: _baby, text: _a.summary(), kind: 'Observation'),
                  icon: const Icon(Icons.edit_square, size: 18),
                  label: const Text('Add as Note'),
                ),
              ),
            ],
          ]),
        ],
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.answers});
  final SarnatAnswers answers;

  @override
  Widget build(BuildContext context) {
    final stage = answers.stage;
    final color = switch (stage) {
      SarnatGrade.severe => AppColors.danger,
      SarnatGrade.moderate => AppColors.warning,
      null => AppColors.textSecondary,
      _ => AppColors.stable,
    };
    final graded = answers.grades.length, total = answers.signCount;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stage == null ? '$graded of $total signs graded' : '${stage.label} encephalopathy',
                style: AppTypography.title2(color: stage == null ? AppColors.textPrimary : color)),
            const SizedBox(height: 4),
            Text('${answers.moderateOrWorse} of 6 areas moderate or severe',
                style: AppTypography.subheadline(color: AppColors.textSecondary)),
            if (answers.meetsNichdCriterion) ...[
              const SizedBox(height: 8),
              Text('Meets the NICHD criterion for moderate or severe encephalopathy',
                  style: AppTypography.subheadline(color: AppColors.danger, weight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.grade, required this.look, required this.selected, required this.onTap});
  final SarnatGrade grade;
  final String look;
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
              child: Row(children: [
                SizedBox(
                  width: 84,
                  child: Text(grade.label, style: AppTypography.subheadline(color: AppColors.textSecondary)),
                ),
                Expanded(child: Text(look, style: AppTypography.body(color: AppColors.textPrimary))),
                if (selected) Icon(Icons.check, color: AppColors.primary),
              ]),
            ),
          ),
        ),
      );
}
