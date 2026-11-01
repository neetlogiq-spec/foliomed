import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../forms/builtin_forms.dart';
import '../forms/form_due.dart';
import '../forms/form_model.dart';
import '../models/patient.dart';
import '../models/patient_form.dart';
import '../screens/forms/form_fill_screen.dart';
import '../screens/forms/form_view_screen.dart';
import '../services/form_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import 'inset_group.dart';

/// Forms filled for this patient (newest first) and Fill a Form.
class PatientFormsSection extends StatefulWidget {
  const PatientFormsSection({super.key, required this.patient});
  final Patient patient;

  @override
  State<PatientFormsSection> createState() => _PatientFormsSectionState();
}

class _PatientFormsSectionState extends State<PatientFormsSection> {
  final _service = FormService();
  late final Stream<List<PatientForm>> _forms = _service.watchPatientForms(widget.patient.id);
  late final Stream<List<FormTemplate>> _wardForms = _service.watchWardForms(widget.patient.wardId);
  bool _showAll = false;

  Future<void> _fill(List<FormTemplate> available) async {
    final key = await showOptionSheet<String>(
      context,
      title: 'Fill a form',
      options: {for (final t in available) t.key: t.name},
    );
    if (key != null) await _fillKey(available, key);
  }

  Future<void> _fillKey(List<FormTemplate> available, String key) async {
    final t = available.where((x) => x.key == key).firstOrNull;
    if (t == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    PatientForm? previous;
    try {
      previous = await _service.latest(widget.patient.id, t.key);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't load the last form — ${friendlyError(e)}")));
    }
    if (!mounted) return;
    await nav.push(
      CupertinoPageRoute(
        builder: (_) => FormFillScreen(patient: widget.patient, template: t, previous: previous),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return StreamBuilder<List<FormTemplate>>(
      stream: _wardForms,
      builder: (context, ws) => StreamBuilder<List<PatientForm>>(
        stream: _forms,
        builder: (context, fs) {
          final available = formsForWard(ws.data ?? const []);
          final forms = fs.data ?? const <PatientForm>[];
          final shown = _showAll ? forms : forms.take(5).toList();
          if (!p.isActive && forms.isEmpty) return const SizedBox.shrink();
          return InsetGroup(
            header: 'Forms',
            dividerIndent: 16,
            children: [
              if (fs.hasError) const SettingsRow(icon: Icons.cloud_off_outlined, title: "Couldn't load forms"),
              if (fs.hasData)
                for (final due in admissionFormsDue(p, {for (final f in forms) f.templateKey}))
                  SettingsRow(
                    icon: Icons.assignment_late_outlined,
                    iconColor: due.isOverdueAt(DateTime.now()) ? AppColors.danger : AppColors.warning,
                    title: '${due.name} ${due.isOverdueAt(DateTime.now()) ? 'overdue' : 'due'}',
                    subtitle: 'Within 24 h of admission — by ${formatDueTime(due.dueBy)}',
                    showChevron: true,
                    onTap: () => _fillKey(available, due.key),
                  ),
              for (final f in shown)
                SettingsRow(
                  key: ValueKey(f.id),
                  icon: f.abnormalCount > 0 ? Icons.warning_rounded : Icons.assignment_turned_in_outlined,
                  iconColor: f.abnormalCount > 0 ? AppColors.warning : AppColors.primary,
                  title: f.templateName,
                  subtitle:
                      '${formatDueTime(f.createdAt)}${f.createdByName == null ? '' : ' · ${f.createdByName}'}'
                      '${f.abnormalCount == 0 ? '' : ' · ${f.abnormalCount} abnormal'}',
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => FormViewScreen(form: f))),
                ),
              if (forms.length > 5 && !_showAll)
                SettingsRow(title: 'Show all ${forms.length}', onTap: () => setState(() => _showAll = true)),
              if (p.isActive)
                SettingsRow(
                  icon: Icons.edit_note,
                  title: 'Fill a Form',
                  subtitle: available.map((t) => t.name).take(4).join(' · '),
                  showChevron: true,
                  onTap: () => _fill(available),
                ),
            ],
          );
        },
      ),
    );
  }
}
