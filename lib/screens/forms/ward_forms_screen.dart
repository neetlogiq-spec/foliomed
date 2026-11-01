import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../forms/builtin_forms.dart';
import '../../forms/form_model.dart';
import '../../models/ward.dart';
import '../../services/form_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import 'form_editor_screen.dart';

/// A ward's forms: its own, and the built-in ones it can copy and change.
/// Any doctor of the ward (or the owner) edits; everyone else can look.
class WardFormsScreen extends StatefulWidget {
  const WardFormsScreen({super.key, required this.ward, required this.canEdit});
  final Ward ward;
  final bool canEdit;

  @override
  State<WardFormsScreen> createState() => _WardFormsScreenState();
}

class _WardFormsScreenState extends State<WardFormsScreen> {
  late final Stream<List<FormTemplate>> _stream = FormService().watchWardForms(widget.ward.id);

  void _open(FormTemplate? t, {bool copy = false}) => Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => FormEditorScreen(ward: widget.ward, template: t, copyOfBuiltIn: copy),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<List<FormTemplate>>(
        stream: _stream,
        builder: (context, snap) {
          final own = snap.data ?? const <FormTemplate>[];
          final replaced = {for (final f in own) f.key};
          return CustomScrollView(
            slivers: [
              LargeTitleAppBar(title: 'Forms', eyebrow: widget.ward.name, showBackButton: true),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList.list(
                  children: [
                    InsetGroup(
                      header: 'This ward’s forms',
                      footer: widget.canEdit
                          ? 'Any doctor of this ward can change these. Filled forms keep the version they used.'
                          : 'Doctors of this ward can add and change forms.',
                      dividerIndent: 16,
                      children: [
                        if (snap.hasError)
                          const SettingsRow(icon: Icons.cloud_off_outlined, title: "Couldn't load forms"),
                        for (final f in own)
                          SettingsRow(
                            icon: f.archived ? Icons.visibility_off_outlined : Icons.description_outlined,
                            title: f.name,
                            subtitle: [
                              if (f.description.isNotEmpty) f.description,
                              'version ${f.version}',
                              if (f.archived) 'hidden',
                              if (f.updatedByName != null) f.updatedByName!,
                            ].join(' · '),
                            showChevron: widget.canEdit,
                            onTap: widget.canEdit ? () => _open(f) : null,
                          ),
                        if (own.isEmpty && !snap.hasError)
                          const SettingsRow(title: 'None yet — using the built-in forms'),
                        if (widget.canEdit) SettingsRow(icon: Icons.add, title: 'New Form', onTap: () => _open(null)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    InsetGroup(
                      header: 'Built into FolioMed',
                      footer: widget.canEdit
                          ? 'Copy one to change it for this ward; your copy replaces it here.'
                          : null,
                      dividerIndent: 16,
                      children: [
                        for (final b in kBuiltInForms)
                          SettingsRow(
                            icon: Icons.inventory_2_outlined,
                            title: b.name,
                            subtitle: replaced.contains(b.key) ? 'Replaced by this ward’s copy' : b.description,
                            value: widget.canEdit && !replaced.contains(b.key) ? 'Copy' : null,
                            onTap: widget.canEdit && !replaced.contains(b.key) ? () => _open(b, copy: true) : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
