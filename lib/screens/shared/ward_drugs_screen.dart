import 'package:flutter/material.dart';

import '../../models/ward.dart';
import '../../tools/drugs/drug_model.dart';
import '../../tools/drugs/ward_drugs.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../tools/drugs/drug_scope.dart';
import '../tools/drugs/drug_widgets.dart';

/// One ward's drug list: what is checked, and (owner) vials, standard
/// syringes, notes and hidden drugs. Doctors sign drugs off from here.
class WardDrugsScreen extends StatefulWidget {
  const WardDrugsScreen({super.key, required this.ward, this.kind});
  final Ward ward;

  /// The ward type if changed since [ward] was loaded.
  final WardKind? kind;

  @override
  State<WardDrugsScreen> createState() => _WardDrugsScreenState();
}

class _WardDrugsScreenState extends State<WardDrugsScreen> {
  CareSetting? _care;

  @override
  Widget build(BuildContext context) {
    return DrugScopeBuilder(
      preferWardId: widget.ward.id,
      builder: (context, scope, _) {
        final care = _care ?? careForWard(widget.kind ?? widget.ward.kind) ?? CareSetting.nicu;
        final drugs = [
          for (final wd in scope.drugs)
            if (wd.drug.bolusesFor(care).isNotEmpty || wd.drug.hasInfusionFor(care)) wd,
        ];
        final shown = drugs.where((d) => !d.hidden).toList();
        final checked = shown.where((d) => d.isChecked).length;
        final byGroup = <String, List<WardDrug>>{};
        for (final d in drugs) {
          (byGroup[d.drug.category] ??= []).add(d);
        }
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: CustomScrollView(
            slivers: [
              LargeTitleAppBar(title: 'Drug List', eyebrow: widget.ward.name, showBackButton: true),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList.list(
                  children: [
                    InsetGroup(
                      dividerIndent: 16,
                      footer: scope.isOwner
                          ? 'Tap a drug to sign it off or change this ward’s vial, standard syringe or note. '
                                'Changing a vial or syringe clears its sign-off.'
                          : scope.canSignOff
                          ? 'Tap a drug to see it and sign it off for this ward.'
                          : 'Doctors of this ward sign drugs off; the owner sets vials and syringes.',
                      children: [
                        InsetSegmentedRow<CareSetting>(
                          label: 'For',
                          value: care,
                          options: {for (final c in CareSetting.values) c: c.label},
                          onChanged: (c) => setState(() => _care = c),
                        ),
                        SettingsRow(
                          icon: Icons.verified_outlined,
                          iconColor: checked == shown.length ? AppColors.stable : AppColors.warning,
                          title: '$checked of ${shown.length} checked',
                          subtitle: checked == shown.length
                              ? 'Every drug shown is signed off'
                              : 'Unchecked drugs show a warning',
                        ),
                      ],
                    ),
                    for (final e in byGroup.entries) ...[
                      const SizedBox(height: 24),
                      InsetGroup(
                        header: e.key,
                        dividerIndent: 16,
                        children: [
                          for (final wd in e.value)
                            SettingsRow(
                              key: ValueKey(wd.drug.key),
                              title: wd.drug.name,
                              subtitle: [
                                wd.drug.vial.label,
                                if (wd.mixOverride != null && wd.drug.infusion != null)
                                  '1 mL/h = ${doseText(wd.mixOverride!)} ${wd.drug.infusion!.unit.label}',
                                if (wd.hidden) 'Hidden',
                                if (wd.unitNote != null) wd.unitNote!,
                              ].join(' · '),
                              trailing: Opacity(
                                opacity: wd.hidden ? 0.5 : 1,
                                child: DrugCheckChip(drug: wd),
                              ),
                              showChevron: true,
                              onTap: () => showDrugDetails(context, drug: wd, scope: scope),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Each drug’s doses come from the guideline named in its details. Compare them with your unit’s '
                      'reference before signing off; a sign-off covers exactly what is shown and lapses if it changes.',
                      style: AppTypography.footnote(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
