import 'package:flutter/material.dart';

import '../../forms/form_model.dart';
import '../../forms/form_summary.dart';
import '../../models/patient_form.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

/// A filled form, read-only, exactly as it was asked (its own definition).
class FormViewScreen extends StatelessWidget {
  const FormViewScreen({super.key, required this.form});
  final PatientForm form;

  static String _answer(FormFieldDef f, Object? v) => switch (v) {
    null => '—',
    kYes => 'Yes',
    kNo => 'No',
    kNa => 'N/A',
    num n => '${n == n.roundToDouble() ? n.toInt() : n}${f.unit == null ? '' : ' ${f.unit}'}',
    _ => '$v',
  };

  Widget _row(FormFieldDef field) {
    final v = form.answers[field.id];
    switch (field.type) {
      case FieldType.vitals:
        final line = vitalsLine(
          vitalsOf(
            FormDefinition(
              sections: [
                FormSectionDef(id: '', title: '', fields: [field]),
              ],
            ),
            form.answers,
          ),
        );
        return SettingsRow(title: field.label, subtitle: line.isEmpty ? 'Not recorded' : line);
      case FieldType.text:
        final t = (v as String?)?.trim() ?? '';
        return SettingsRow(title: field.label, subtitle: t.isEmpty ? '—' : t);
      default:
        final abnormal = field.isAbnormal(v);
        final detail = (form.answers[field.detailKey] as String?)?.trim() ?? '';
        return SettingsRow(
          icon: abnormal ? Icons.warning_rounded : null,
          iconColor: abnormal ? AppColors.warning : null,
          title: field.label,
          subtitle: abnormal && detail.isNotEmpty ? detail : null,
          value: _answer(field, v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = form;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(title: f.templateName, eyebrow: formatDueTime(f.createdAt), showBackButton: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  'Filled by ${f.createdByName ?? 'someone'}'
                  '${f.abnormalCount == 0 ? '' : ' · ${f.abnormalCount} abnormal'}',
                  style: AppTypography.footnote(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final s in f.definition.sections) ...[
                  InsetGroup(header: s.title, dividerIndent: 16, children: [for (final field in s.fields) _row(field)]),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
