import 'package:flutter/material.dart';

import '../../tools/ballard.dart';
import '../../tools/newborn_scores.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// New Ballard Score: pick one option per sign; the total gives the
/// estimated gestation.
class BallardTool extends StatefulWidget {
  const BallardTool({super.key});

  @override
  State<BallardTool> createState() => _BallardToolState();
}

class _BallardToolState extends State<BallardTool> {
  bool _male = true;
  final Map<String, int> _chosen = {}; // item name → points

  List<ScoreItem> get _items => [...kBallardNeuromuscular, ...ballardPhysical(male: _male)];

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final answered = items.where((i) => _chosen.containsKey(i.name)).length;
    final total = items.fold<int>(0, (s, i) => s + (_chosen[i.name] ?? 0));
    final complete = answered == items.length;
    final weeks = ballardWeeks(total);
    return ToolPage(
      title: 'New Ballard',
      method: 'Add the points for the 6 neuromuscular and 6 physical signs.\n'
          'Gestation (weeks) = (2 × total + 120) ÷ 5: −10 = 20 weeks, 0 = 24, 25 = 34, 40 = 40, 50 = 44.',
      source: 'Ballard JL et al., J Pediatr 1991; physical descriptions from the official score sheet '
          '(ballardscore.com). Most accurate within the first 12–20 hours (up to 96 hours); ±2 weeks.',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$total', style: AppTypography.largeTitle(color: AppColors.textPrimary)),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  complete
                      ? 'About ${weeks.toStringAsFixed(weeks == weeks.roundToDouble() ? 0 : 1)} weeks'
                      : '$answered of ${items.length} signs scored',
                  textAlign: TextAlign.end,
                  style: AppTypography.headline(color: complete ? AppColors.primary : AppColors.textSecondary),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        InsetGroup(dividerIndent: 16, children: [
          InsetSegmentedRow<bool>(
            label: 'Baby',
            value: _male,
            options: const {true: 'Boy', false: 'Girl'},
            onChanged: (v) => setState(() => _male = v),
          ),
        ]),
        const SizedBox(height: 24),
        _section('Neuromuscular maturity', kBallardNeuromuscular),
        _section('Physical maturity', ballardPhysical(male: _male)),
      ],
    );
  }

  Widget _section(String title, List<ScoreItem> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title, style: AppTypography.title3(color: AppColors.textPrimary)),
          ),
          for (final item in items) ...[
            InsetGroup(
              header: item.name,
              dividerIndent: 16,
              children: [
                for (final o in item.options)
                  InkWell(
                    onTap: () {
                      Haptics.selection();
                      setState(() => _chosen[item.name] = o.points);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Row(children: [
                        SizedBox(
                          width: 32,
                          child: Text('${o.points}', style: AppTypography.headline(color: AppColors.textSecondary)),
                        ),
                        Expanded(child: Text(o.label, style: AppTypography.body(color: AppColors.textPrimary))),
                        if (_chosen[item.name] == o.points) Icon(Icons.check, color: AppColors.primary),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ],
      );
}
