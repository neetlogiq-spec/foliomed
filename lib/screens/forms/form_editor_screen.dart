import 'package:flutter/material.dart';

import '../../forms/form_model.dart';
import '../../models/ward.dart';
import '../../services/form_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/chip_choice.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

/// A new id for a section or field that won't clash with existing ones.
String newFormId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

/// "Daily NICU check" → "daily_nicu_check".
String formKeyFrom(String name) {
  final s = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return s.isEmpty ? 'form' : (s.length > 30 ? s.substring(0, 30) : s);
}

/// Edit a ward form: a copy of a built-in (same key, so it replaces the
/// built-in on this ward), an existing ward form, or a new one.
class FormEditorScreen extends StatefulWidget {
  const FormEditorScreen({super.key, required this.ward, this.template, this.copyOfBuiltIn = false});
  final Ward ward;

  /// What to start from; null for a blank form.
  final FormTemplate? template;
  final bool copyOfBuiltIn;

  @override
  State<FormEditorScreen> createState() => _FormEditorScreenState();
}

class _FormEditorScreenState extends State<FormEditorScreen> {
  late final _name = TextEditingController(text: widget.template?.name ?? '');
  late final _description = TextEditingController(text: widget.template?.description ?? '');
  late List<FormSectionDef> _sections =
      widget.template?.definition.sections ??
      [FormSectionDef(id: newFormId('s'), title: 'Section 1', fields: const [])];
  late bool _archived = widget.template?.archived ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _updateSection(int i, FormSectionDef s) => setState(() => _sections = [..._sections]..[i] = s);

  String? _problem() {
    if (_name.text.trim().isEmpty) return 'Give the form a name.';
    if (_sections.every((s) => s.fields.isEmpty)) return 'Add at least one field.';
    for (final s in _sections) {
      if (s.title.trim().isEmpty) return 'Every section needs a title.';
      for (final f in s.fields) {
        if (f.label.trim().isEmpty) return 'Every field needs a label.';
        if (f.type == FieldType.choice && f.options.length < 2) return '“${f.label}” needs at least two choices.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    final messenger = ScaffoldMessenger.of(context);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final t = widget.template;
    final key = t != null && (widget.copyOfBuiltIn || !t.isBuiltIn)
        ? t.key
        : '${formKeyFrom(_name.text)}_${newFormId('')}';
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final v = await FormService().saveTemplate(
        wardId: widget.ward.id,
        key: key.length > 40 ? key.substring(0, 40) : key,
        name: _name.text.trim(),
        description: _description.text.trim(),
        definition: FormDefinition(sections: _sections),
        basedOn: widget.copyOfBuiltIn ? t?.key : t?.basedOn,
        archived: _archived,
      );
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('${_name.text.trim()} saved (version $v)')));
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  Future<void> _sectionMenu(int i) async {
    final s = _sections[i];
    final choice = await showOptionSheet<String>(
      context,
      title: s.title,
      options: {
        'rename': 'Rename',
        if (i > 0) 'up': 'Move Up',
        if (i < _sections.length - 1) 'down': 'Move Down',
        'delete': 'Delete Section',
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        final t = await _askText('Section title', s.title);
        if (t != null) _updateSection(i, FormSectionDef(id: s.id, title: t, fields: s.fields));
      case 'up' || 'down':
        final j = choice == 'up' ? i - 1 : i + 1;
        setState(() {
          final l = [..._sections];
          l[i] = _sections[j];
          l[j] = s;
          _sections = l;
        });
      case 'delete':
        setState(() => _sections = [..._sections]..removeAt(i));
    }
  }

  Future<String?> _askText(String title, String initial) {
    final c = TextEditingController(text: initial);
    return showAppSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.title3(color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              InsetGroup(
                children: [InsetTextRow(label: 'Title', controller: c, autofocus: true)],
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Done')),
            ],
          ),
        ),
      ),
    ).whenComplete(c.dispose);
  }

  Future<void> _editField(int si, int? fi) async {
    final s = _sections[si];
    final existing = fi == null ? null : s.fields[fi];
    final result = await showAppSheet<_FieldEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FieldSheet(field: existing),
    );
    if (result == null || !mounted) return;
    final fields = [...s.fields];
    switch (result.action) {
      case _FieldAction.save:
        if (fi == null) {
          fields.add(result.field!);
        } else {
          fields[fi] = result.field!;
        }
      case _FieldAction.delete:
        fields.removeAt(fi!);
      case _FieldAction.up:
        if (fi! > 0) fields.insert(fi - 1, fields.removeAt(fi));
      case _FieldAction.down:
        if (fi! < fields.length - 1) fields.insert(fi + 1, fields.removeAt(fi));
    }
    _updateSection(si, FormSectionDef(id: s.id, title: s.title, fields: fields));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          LargeTitleAppBar(
            title: t == null ? 'New Form' : (widget.copyOfBuiltIn ? 'Copy of ${t.name}' : t.name),
            eyebrow: widget.ward.name,
            showBackButton: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(
              children: [
                InsetGroup(
                  dividerIndent: 16,
                  footer: widget.copyOfBuiltIn
                      ? 'Saving replaces the built-in “${t!.name}” on ${widget.ward.name}.'
                      : 'Filled forms keep the version they were filled with.',
                  children: [
                    InsetTextRow(label: 'Name', controller: _name, textCapitalization: TextCapitalization.sentences),
                    InsetTextRow(label: 'About', controller: _description, placeholder: 'Optional'),
                    if (t != null && !t.isBuiltIn)
                      SwitchListTile.adaptive(
                        value: _archived,
                        onChanged: (v) => setState(() => _archived = v),
                        title: Text('Hide from Fill a Form', style: AppTypography.body(color: AppColors.textPrimary)),
                      ),
                  ],
                ),
                for (final (si, s) in _sections.indexed) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 0, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.title.toUpperCase(),
                            style: AppTypography.footnote(color: AppColors.textSecondary, weight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Section options',
                          onPressed: () => _sectionMenu(si),
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ],
                    ),
                  ),
                  InsetGroup(
                    dividerIndent: 16,
                    children: [
                      for (final (fi, f) in s.fields.indexed)
                        SettingsRow(
                          title: f.label,
                          subtitle: [
                            f.type.label,
                            if (f.options.isNotEmpty) f.options.join(' / '),
                            if (f.unit != null) f.unit!,
                            if (f.normal != null)
                              'expected: ${f.normal == kYes
                                  ? 'Yes'
                                  : f.normal == kNo
                                  ? 'No'
                                  : f.normal}',
                          ].join(' · '),
                          showChevron: true,
                          onTap: () => _editField(si, fi),
                        ),
                      SettingsRow(icon: Icons.add, title: 'Add Field', onTap: () => _editField(si, null)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(
                    () => _sections = [
                      ..._sections,
                      FormSectionDef(id: newFormId('s'), title: 'Section ${_sections.length + 1}', fields: const []),
                    ],
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Section'),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _saving ? null : _save, child: const Text('Save Form')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _FieldAction { save, delete, up, down }

class _FieldEdit {
  const _FieldEdit(this.action, [this.field]);
  final _FieldAction action;
  final FormFieldDef? field;
}

class _FieldSheet extends StatefulWidget {
  const _FieldSheet({this.field});
  final FormFieldDef? field;

  @override
  State<_FieldSheet> createState() => _FieldSheetState();
}

class _FieldSheetState extends State<_FieldSheet> {
  late final _label = TextEditingController(text: widget.field?.label ?? '');
  late final _options = TextEditingController(text: widget.field?.options.join(', ') ?? '');
  late final _unit = TextEditingController(text: widget.field?.unit ?? '');
  late FieldType _type = widget.field?.type ?? FieldType.yesNo;
  late String? _normal = widget.field?.normal;

  @override
  void dispose() {
    for (final c in [_label, _options, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _optionList =>
      _options.text.split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toSet().toList();

  FormFieldDef _build() => FormFieldDef(
    id: widget.field?.id ?? newFormId('f'),
    label: _label.text.trim(),
    type: _type,
    options: _type == FieldType.choice ? _optionList : const [],
    unit: _type == FieldType.number && _unit.text.trim().isNotEmpty ? _unit.text.trim() : null,
    normal: switch (_type) {
      FieldType.yesNo => _normal == kYes || _normal == kNo ? _normal : null,
      FieldType.choice => _optionList.contains(_normal) ? _normal : null,
      _ => null,
    },
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.field != null;
    final expected = switch (_type) {
      FieldType.yesNo => ['Yes', 'No'],
      FieldType.choice => _optionList,
      _ => const <String>[],
    };
    String? shownNormal() => _type == FieldType.yesNo
        ? (_normal == kYes
              ? 'Yes'
              : _normal == kNo
              ? 'No'
              : null)
        : _normal;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editing ? 'Edit Field' : 'New Field', style: AppTypography.title3(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            InsetGroup(
              dividerIndent: 16,
              children: [
                InsetTextRow(
                  label: 'Label',
                  controller: _label,
                  placeholder: 'e.g. Pain controlled',
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),
                if (_type == FieldType.choice)
                  InsetTextRow(
                    label: 'Choices',
                    controller: _options,
                    placeholder: 'Comma-separated',
                    onChanged: (_) => setState(() {}),
                  ),
                if (_type == FieldType.number) InsetTextRow(label: 'Unit', controller: _unit, placeholder: 'e.g. mL'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'TYPE',
              style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ChipChoice(
              options: [for (final t in FieldType.values) t.label],
              value: _type.label,
              optional: false,
              onChanged: (v) => setState(() => _type = FieldType.values.firstWhere((t) => t.label == v)),
            ),
            if (expected.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'EXPECTED ANSWER (OPTIONAL)',
                style: AppTypography.caption1(color: AppColors.textSecondary, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ChipChoice(
                options: expected,
                value: shownNormal(),
                onChanged: (v) => setState(
                  () => _normal = _type == FieldType.yesNo
                      ? (v == 'Yes'
                            ? kYes
                            : v == 'No'
                            ? kNo
                            : null)
                      : v,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Any other answer is marked abnormal and asks for details. “All Normal” fills the expected answers.',
                style: AppTypography.footnote(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _label.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, _FieldEdit(_FieldAction.save, _build())),
              child: const Text('Done'),
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const _FieldEdit(_FieldAction.up)),
                      child: const Text('Move Up'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const _FieldEdit(_FieldAction.down)),
                      child: const Text('Move Down'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, const _FieldEdit(_FieldAction.delete)),
                child: Text('Delete Field', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
