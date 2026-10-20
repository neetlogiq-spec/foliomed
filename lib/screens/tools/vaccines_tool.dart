import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../tools/vaccines.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import 'tool_page.dart';

/// The National Immunization Schedule for a date of birth: what's due now,
/// what's past its window, and what's coming. Tick doses already given to
/// see what's left (ticks aren't saved).
class VaccinesTool extends StatefulWidget {
  const VaccinesTool({super.key});

  @override
  State<VaccinesTool> createState() => _VaccinesToolState();
}

class _VaccinesToolState extends State<VaccinesTool> {
  Patient? _baby;
  DateTime? _born;
  final Set<String> _given = {};

  Future<void> _pickBirth() async {
    var chosen = _born ?? DateTime.now();
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(onPressed: () => Navigator.pop(ctx, chosen), child: const Text('Done')),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: chosen,
                maximumDate: DateTime.now(),
                minimumDate: DateTime.now().subtract(const Duration(days: 7 * 365)),
                onDateTimeChanged: (d) => chosen = d,
              ),
            ),
          ]),
        ),
      ),
    );
    if (picked != null) setState(() => _born = picked);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _born == null ? null : vaccinePlan(born: _born!, today: DateTime.now(), given: _given);
    List<DosePlan> of(DoseStatus s) => plan == null ? const [] : plan.where((p) => p.status == s).toList();
    return ToolPage(
      title: 'Vaccines',
      method: 'Due dates count from the date of birth (weeks for the first doses, months after). '
          '“Past its window” means the national schedule says it can no longer be given at this age.',
      source: 'National Immunization Schedule, Ministry of Health and Family Welfare / National Health Mission, '
          'India. PCV and JE depend on your state or district. Check the current state schedule (some states '
          'add doses, e.g. a third fIPV).',
      children: [
        BabyRow(
          patient: _baby,
          onPicked: (p) => setState(() {
            _baby = p;
            if (p.bornAt != null) _born = p.bornAt!.toLocal();
          }),
        ),
        const SizedBox(height: 16),
        InsetGroup(children: [
          SettingsRow(title: 'Date of birth', value: _born == null ? 'Choose' : formatDay(_born!), onTap: _pickBirth),
        ]),
        const SizedBox(height: 20),
        if (plan == null)
          Text('Choose a date of birth to see the schedule.',
              style: AppTypography.subheadline(color: AppColors.textSecondary))
        else ...[
          _group('Due now', of(DoseStatus.overdue), AppColors.warning),
          _group('Past its window', of(DoseStatus.missedWindow), AppColors.danger),
          _group('Upcoming', of(DoseStatus.upcoming), AppColors.textSecondary),
          _group('Given', of(DoseStatus.given), AppColors.stable),
        ],
      ],
    );
  }

  Widget _group(String title, List<DosePlan> doses, Color color) {
    if (doses.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: InsetGroup(
        header: '$title · ${doses.length}',
        footer: title == 'Due now' ? 'Tap a dose once it’s given.' : null,
        dividerIndent: 16,
        children: [
          for (final p in doses)
            InkWell(
              onTap: () {
                Haptics.selection();
                setState(() => _given.contains(p.dose.name) ? _given.remove(p.dose.name) : _given.add(p.dose.name));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(
                    p.status == DoseStatus.given ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.dose.name, style: AppTypography.body(color: AppColors.textPrimary)),
                      Text(
                        [
                          'Due ${formatDay(p.dueOn)}',
                          if (p.lastDay != null && p.status != DoseStatus.given) 'until ${formatDay(p.lastDay!)}',
                          if (p.dose.note != null) p.dose.note!,
                        ].join(' · '),
                        style: AppTypography.footnote(
                            color: p.status == DoseStatus.missedWindow ? AppColors.danger : AppColors.textSecondary),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
