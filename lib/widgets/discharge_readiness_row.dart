import 'package:flutter/material.dart';

import '../clinical/discharge_checklist.dart';
import '../models/patient.dart';
import '../screens/patients/discharge_checklist_screen.dart';
import '../services/discharge_check_service.dart';
import '../utils/app_theme.dart';
import 'inset_group.dart';

/// On a newborn's page: how close they are to going home, live. Opens the
/// full discharge checklist.
class DischargeReadinessRow extends StatefulWidget {
  const DischargeReadinessRow({super.key, required this.patient});
  final Patient patient;

  @override
  State<DischargeReadinessRow> createState() => _DischargeReadinessRowState();
}

class _DischargeReadinessRowState extends State<DischargeReadinessRow> {
  late final Stream<List<CheckLine>> _lines = DischargeCheckService().watch(widget.patient);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CheckLine>>(
      stream: _lines,
      builder: (context, snap) {
        final lines = snap.data;
        final todo = lines == null ? null : outstanding(lines);
        final ready = todo != null && todo.isEmpty;
        final attention = todo?.where((l) => l.state == CheckState.attention).length ?? 0;
        return InsetGroup(
          children: [
            SettingsRow(
              icon: ready ? Icons.verified : Icons.fact_check_outlined,
              iconColor: ready ? AppColors.stable : AppColors.primary,
              title: 'Discharge Checklist',
              subtitle: snap.hasError
                  ? "Couldn't load"
                  : todo == null
                      ? 'Checking…'
                      : ready
                          ? 'Ready to go home'
                          : '${lines!.length - todo.length} of ${lines.length} done'
                              '${attention == 0 ? '' : ' · $attention need a decision'}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DischargeChecklistScreen(patient: widget.patient)),
              ),
            ),
          ],
        );
      },
    );
  }
}
