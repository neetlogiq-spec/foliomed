import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../clinical/bilirubin.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'app_sheet.dart';
import 'inset_group.dart';

/// Picks the AAP 2022 neurotoxicity risk factors. Returns the ticked
/// factor names (empty = "none"), or null if cancelled.
Future<List<String>?> showRiskFactorsSheet(BuildContext context, List<String>? current) async {
  final selected = await showAppSheet<Set<NeuroRiskFactor>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => RiskFactorsSheet(
      initial: {
        for (final f in current ?? const <String>[])
          if (NeuroRiskFactor.fromName(f) != null) NeuroRiskFactor.fromName(f)!,
      },
    ),
  );
  return selected == null ? null : [for (final f in selected) f.name];
}

/// "None", "Sepsis, G6PD deficiency", or null when not assessed.
String? riskFactorsLabel(List<String>? factors) => factors == null
    ? null
    : factors.isEmpty
        ? 'None'
        : factors.map((f) => NeuroRiskFactor.fromName(f)?.label ?? f).join(', ');

class RiskFactorsSheet extends StatefulWidget {
  const RiskFactorsSheet({super.key, required this.initial});
  final Set<NeuroRiskFactor> initial;

  @override
  State<RiskFactorsSheet> createState() => RiskFactorsSheetState();
}

class RiskFactorsSheetState extends State<RiskFactorsSheet> {
  late final Set<NeuroRiskFactor> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text('Risk factors',
                      textAlign: TextAlign.center,
                      style: AppTypography.headline(color: AppColors.textPrimary)),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context, _sel),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            InsetGroup(
              footer: 'Gestation is accounted for by the curve itself. Save with nothing '
                  'ticked to record "none". AAP 2022 neurotoxicity risk factors.',
              dividerIndent: 16,
              children: [
                for (final f in NeuroRiskFactor.values)
                  SettingsRow(
                    title: f.label,
                    trailing: Icon(
                      _sel.contains(f) ? Icons.check_circle : Icons.circle_outlined,
                      color: _sel.contains(f) ? AppColors.primary : AppColors.textSecondary,
                    ),
                    showChevron: false,
                    onTap: () => setState(
                        () => _sel.contains(f) ? _sel.remove(f) : _sel.add(f)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
