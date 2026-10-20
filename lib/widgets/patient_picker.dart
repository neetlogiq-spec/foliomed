import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../providers/patient_roster.dart';
import '../screens/patients/patient_form_screen.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'app_sheet.dart';
import 'inset_group.dart';

/// Pick one admitted patient from your wards (searchable), or admit one.
Future<Patient?> showPatientPicker(BuildContext context) => showAppSheet<Patient>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PatientPicker(),
    );

/// Search the admitted patients on your wards; or admit someone new.
class _PatientPicker extends StatefulWidget {
  const _PatientPicker();

  @override
  State<_PatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends State<_PatientPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = context.watch<PatientRoster>().patients;
    final q = _q.toLowerCase();
    final shown = [
      for (final p in all)
        if (q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.bedNumber.toLowerCase().contains(q) ||
            p.patientCode.toLowerCase().contains(q) ||
            (p.motherName?.toLowerCase().contains(q) ?? false))
          p,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSearchTextField(
                autofocus: true,
                placeholder: 'Name, bed, mother or ID',
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  InsetGroup(
                    dividerIndent: 16,
                    children: [
                      for (final p in shown)
                        SettingsRow(
                          title: p.name,
                          subtitle: [if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}', p.ageLabel, p.patientCode]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          onTap: () => Navigator.pop(context, p),
                          showChevron: false,
                        ),
                      SettingsRow(
                        icon: Icons.person_add_alt,
                        title: 'Admit a new patient',
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await navigator.push(MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const PatientFormScreen(),
                          ));
                        },
                      ),
                    ],
                  ),
                  if (shown.isEmpty && q.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nobody matches “$_q”.',
                          textAlign: TextAlign.center,
                          style: AppTypography.footnote(color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
