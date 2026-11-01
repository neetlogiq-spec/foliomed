import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../forms/form_model.dart';
import '../../forms/form_summary.dart';
import '../../models/patient.dart';
import '../../models/patient_form.dart';
import '../../providers/account_provider.dart';
import '../../services/form_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/chip_choice.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

/// Fill one form for a patient. Taps for yes/no and choices, "All normal"
/// per section, copy from the last one of the same kind; saving writes the
/// summary on the timeline and records any vital signs.
class FormFillScreen extends StatefulWidget {
  const FormFillScreen({super.key, required this.patient, required this.template, this.previous});
  final Patient patient;
  final FormTemplate template;

  /// The last filled form of this kind, offered as "Copy from last time".
  final PatientForm? previous;

  @override
  State<FormFillScreen> createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  Map<String, Object?> _answers = {};
  final _controllers = <String, TextEditingController>{};
  int _generation = 0;
  bool _saving = false;
  bool _dirty = false;

  FormDefinition get _def => widget.template.definition;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// A text controller for an answer key ("field", "field.detail", or
  /// "vitals.hr" inside a vitals block), created from the current answer.
  TextEditingController _ctrl(String key) => _controllers.putIfAbsent(key, () {
    final dot = key.indexOf('.');
    final block = dot < 0 ? null : _answers[key.substring(0, dot)];
    final v = _answers[key] ?? (block is Map ? block[key.substring(dot + 1)] : null);
    return TextEditingController(text: v == null ? '' : (v is num ? _numText(v) : '$v'));
  });

  static String _numText(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Replaces all answers (copy / all normal) and rebuilds the text fields.
  void _replace(Map<String, Object?> next) => setState(() {
    _answers = next;
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _generation++;
    _dirty = true;
  });

  void _set(String key, Object? value) => setState(() {
    _answers = {..._answers};
    if (value == null || (value is String && value.isEmpty)) {
      _answers.remove(key);
    } else {
      _answers[key] = value;
    }
    _dirty = true;
  });

  void _setVital(String fieldId, String key, String text) {
    final m = Map<String, Object?>.of((_answers[fieldId] as Map?)?.cast<String, Object?>() ?? const {});
    final v = double.tryParse(text.trim());
    if (v == null) {
      m.remove(key);
    } else {
      m[key] = v;
    }
    _set(fieldId, m.isEmpty ? null : m);
  }

  Future<void> _save() async {
    final missing = missingDetails(_def, _answers);
    if (missing.isNotEmpty) {
      await showAdaptiveDialog<void>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: const Text('Describe what’s abnormal'),
          content: Text(missing.map((f) => '• ${f.label}').join('\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final author = context.read<AccountProvider>().currentUser?.name;
    final s = summariseForm(formName: widget.template.name, definition: _def, answers: _answers, author: author);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await FormService().save(
        patientId: widget.patient.id,
        template: widget.template,
        answers: _answers,
        summary: s.text,
        abnormalCount: s.abnormal.length,
        vitals: s.vitals,
      );
      Haptics.success();
      _dirty = false;
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('${widget.template.name} saved — on the timeline')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Discard this form?'),
        content: const Text('Your answers haven’t been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final prev = widget.previous;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) {
          _dirty = false;
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              LargeTitleAppBar(title: widget.template.name, eyebrow: widget.patient.name, showBackButton: true),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList.list(
                  children: [
                    if (prev != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => _replace(carryForward(prev.answers, _def)),
                        icon: const Icon(Icons.content_copy, size: 18),
                        label: Text('Copy from last time (${formatDueTime(prev.createdAt)})'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (final s in _def.sections) ...[_section(s), const SizedBox(height: 20)],
                    FilledButton(onPressed: _saving ? null : _save, child: const Text('Save Form')),
                    const SizedBox(height: 8),
                    Text(
                      'Saving adds a short summary to the timeline${_def.fields.any((f) => f.type == FieldType.vitals) ? ' and records the vital signs' : ''}.',
                      textAlign: TextAlign.center,
                      style: AppTypography.footnote(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(FormSectionDef s) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s.title.toUpperCase(),
                style: AppTypography.footnote(color: AppColors.textSecondary, weight: FontWeight.w600),
              ),
            ),
            if (s.hasNormals)
              TextButton(
                onPressed: () {
                  Haptics.selection();
                  _replace(markSectionNormal(_answers, s));
                },
                child: const Text('All Normal'),
              ),
          ],
        ),
      ),
      InsetGroup(dividerIndent: 16, children: [for (final f in s.fields) _field(f)]),
    ],
  );

  Widget _field(FormFieldDef f) {
    final key = ValueKey('${f.id}-$_generation');
    return switch (f.type) {
      FieldType.yesNo => _YesNoField(
        key: key,
        field: f,
        value: _answers[f.id] as String?,
        onChanged: (v) => _set(f.id, v),
        detail: f.isAbnormal(_answers[f.id]) ? _detail(f) : null,
      ),
      FieldType.choice => Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(f.label, style: AppTypography.body(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ChipChoice(options: f.options, value: _answers[f.id] as String?, onChanged: (v) => _set(f.id, v)),
            if (f.isAbnormal(_answers[f.id])) ...[const SizedBox(height: 8), _detail(f)],
          ],
        ),
      ),
      FieldType.number => InsetTextRow(
        key: key,
        label: f.label,
        controller: _ctrl(f.id),
        placeholder: f.hint ?? '—',
        suffix: f.unit,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (t) => _set(f.id, double.tryParse(t.trim())),
      ),
      FieldType.text => InsetTextRow(
        key: key,
        label: f.label,
        controller: _ctrl(f.id),
        placeholder: f.hint ?? 'Type or dictate',
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (t) => _set(f.id, t),
      ),
      FieldType.date => SettingsRow(
        key: key,
        title: f.label,
        value: _answers[f.id] as String? ?? 'Choose',
        showChevron: true,
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year + 2),
            initialDate: now,
          );
          if (d != null) _set(f.id, DateFormat('yyyy-MM-dd').format(d));
        },
      ),
      FieldType.vitals => Column(
        key: key,
        children: [
          for (final (k, label, unit) in kVitals)
            InsetTextRow(
              label: label,
              controller: _ctrl('${f.id}.$k'),
              placeholder: '—',
              suffix: unit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (t) => _setVital(f.id, k, t),
            ),
        ],
      ),
    };
  }

  Widget _detail(FormFieldDef f) => Container(
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: InsetTextRow(
      label: 'Details',
      controller: _ctrl(f.detailKey),
      placeholder: 'What’s abnormal (required)',
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (t) => _set(f.detailKey, t),
    ),
  );
}

class _YesNoField extends StatelessWidget {
  const _YesNoField({super.key, required this.field, required this.value, required this.onChanged, this.detail});
  final FormFieldDef field;
  final String? value;
  final ValueChanged<String?> onChanged;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final abnormal = field.isAbnormal(value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (abnormal) ...[
                Icon(Icons.warning_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(field.label, style: AppTypography.body(color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: value,
            onValueChanged: (v) {
              Haptics.selection();
              onChanged(v == value ? null : v);
            },
            children: {
              for (final (k, t) in const [(kYes, 'Yes'), (kNo, 'No'), (kNa, 'N/A')])
                k: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    t,
                    style: AppTypography.subheadline(color: AppColors.textPrimary, weight: FontWeight.w600),
                  ),
                ),
            },
          ),
          if (detail != null) ...[const SizedBox(height: 8), detail!],
        ],
      ),
    );
  }
}
