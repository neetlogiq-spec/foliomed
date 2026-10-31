import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/layout.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../tools/newborn_scores.dart';
import 'age_tool.dart';
import 'ballard_tool.dart';
import 'bp_tool.dart';
import 'electrolytes_tool.dart';
import 'hypoglycaemia_tool.dart';
import 'vaccines_tool.dart';
import 'exchange_tool.dart';
import 'fluids_tool.dart';
import 'emergency_drugs_tool.dart';
import 'infusion_tool.dart';
import 'lines_tool.dart';
import 'sarnat_tool.dart';
import 'score_tool.dart';

class _Tool {
  const _Tool(this.title, this.subtitle, this.icon, this.color, this.keywords, this.build);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String keywords;
  final Widget Function() build;
}

class _Group {
  const _Group(this.title, this.tools);
  final String title;
  final List<_Tool> tools;
}

/// Bedside calculators, kept in their own tab so patient pages stay clean.
/// Grouped like Settings; search matches titles and common words.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _q = '';

  static final _groups = [
    _Group('Fluids and glucose', [
      _Tool('Fluids & Glucose', 'Total fluids by day of life, pump rate, GIR, dextrose mixing', Icons.water_drop_outlined,
          AppColors.primary, 'fluid tfr maintenance gir glucose dextrose mix d10 d25 rate', FluidsTool.new),
      _Tool('Low Blood Glucose', 'Dextrose bolus, then the infusion for a GIR', Icons.bloodtype_outlined,
          AppColors.warning, 'hypoglycaemia hypoglycemia sugar glucose bolus d10 gir', HypoglycaemiaTool.new),
      _Tool('Electrolytes', 'Sodium, potassium, calcium, magnesium, phosphate; anion gap', Icons.science_outlined,
          AppColors.secondary, 'electrolyte sodium hyponatraemia potassium calcium magnesium phosphate anion gap osmolality',
          ElectrolytesTool.new),
    ]),
    _Group('Scores', [
      for (final d in kNewbornScores)
        _Tool(d.name, d.purpose, Icons.checklist_rtl, AppColors.secondary, '${d.id} score ${d.purpose}',
            () => ScoreTool(definition: d)),
      _Tool('New Ballard', 'Gestational age from 12 signs', Icons.child_care, AppColors.secondary,
          'ballard gestation gestational age maturity dubowitz', BallardTool.new),
      _Tool('Modified Sarnat', 'HIE staging, with the NICHD moderate/severe criterion', Icons.psychology_outlined,
          AppColors.secondary, 'sarnat hie encephalopathy asphyxia cooling nichd stage', SarnatTool.new),
    ]),
    _Group('Age', [
      _Tool('Corrected Age', 'Postmenstrual and corrected age for preterm babies', Icons.event_outlined,
          AppColors.secondary, 'pma cga gestation corrected preterm weeks', AgeTool.new),
    ]),
    _Group('Monitoring', [
      _Tool('Blood Pressure', 'Newborn to 17 years', Icons.monitor_heart_outlined, AppColors.danger,
          'bp blood pressure hypertension hypotension map centile dionne zubrow aap child height', BpTool.new),
    ]),
    _Group('Prevention', [
      _Tool('Vaccines', 'National schedule: due, past window, upcoming', Icons.vaccines_outlined, AppColors.stable,
          'vaccine vaccination immunisation immunization nis bcg opv hepatitis catch up', VaccinesTool.new),
    ]),
    _Group('Blood', [
      _Tool('Exchange Transfusion', 'Double-volume and partial exchange volumes', Icons.bloodtype_outlined,
          AppColors.danger, 'dvet exchange bilirubin polycythaemia polycythemia hct haematocrit pet blood volume',
          ExchangeTool.new),
    ]),
    _Group('Procedures', [
      _Tool('Lines & Tubes', 'UVC/UAC length, ETT size and depth', Icons.straighten, AppColors.warning,
          'uvc uac umbilical catheter ett endotracheal tube intubation depth', LinesTool.new),
    ]),
    _Group('Drugs', [
      _Tool('Emergency Drugs', 'Weight-based doses and syringes for NICU and PICU', Icons.emergency_outlined,
          AppColors.danger,
          'emergency drugs resuscitation adrenaline epinephrine atropine adenosine bicarbonate calcium seizure '
              'phenobarbitone levetiracetam phenytoin midazolam bolus stat nicu picu',
          EmergencyDrugsTool.new),
      _Tool('Infusion Rate', 'Pick a drug: syringe, strengths, rate table — or your own', Icons.speed,
          AppColors.stable,
          'infusion pump rate mcg/kg/min dopamine dobutamine adrenaline noradrenaline milrinone morphine fentanyl '
              'midazolam insulin prostaglandin syringe inotrope',
          InfusionTool.new),
    ]),
  ];

  bool _matches(_Tool t) {
    if (_q.isEmpty) return true;
    final hay = '${t.title} ${t.subtitle} ${t.keywords}'.toLowerCase();
    return _q.toLowerCase().split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final g in _groups)
        if (g.tools.any(_matches)) _Group(g.title, g.tools.where(_matches).toList()),
    ];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const LargeTitleAppBar(title: 'Tools', eyebrow: 'Bedside calculators'),
            SliverPadding(
              padding: withBottomBarInset(context, const EdgeInsets.fromLTRB(16, 4, 16, 32)),
              sliver: SliverList.list(children: [
                CupertinoSearchTextField(
                  placeholder: 'Search tools',
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
                const SizedBox(height: 20),
                for (final g in groups) ...[
                  InsetGroup(
                    header: g.title,
                    children: [
                      for (final t in g.tools)
                        SettingsRow(
                          icon: t.icon,
                          iconColor: t.color,
                          title: t.title,
                          subtitle: t.subtitle,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => t.build())),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No tool matches “$_q”.',
                        textAlign: TextAlign.center,
                        style: AppTypography.subheadline(color: AppColors.textSecondary)),
                  ),
                Text(
                  'Calculators show their working and source. They are not yet checked by your unit — confirm before acting.',
                  textAlign: TextAlign.center,
                  style: AppTypography.footnote(color: AppColors.textSecondary),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
