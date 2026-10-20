import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/note.dart';
import '../../models/patient.dart';
import '../../providers/account_provider.dart';
import '../../providers/ward_feed.dart';
import '../../services/review_request.dart';
import '../../services/text_scan_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/patient_picker.dart';

/// Write a note for one patient. The patient decides the ward, so there is
/// no separate ward step.
/// [text] and [kind] pre-fill the note (e.g. a score from Tools).
Future<void> showComposeNote(BuildContext context, {Patient? patient, String? text, String? kind}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeNoteSheet(initialPatient: patient, initialText: text, initialKind: kind),
    );

class _ComposeNoteSheet extends StatefulWidget {
  const _ComposeNoteSheet({this.initialPatient, this.initialText, this.initialKind});
  final Patient? initialPatient;
  final String? initialText;
  final String? initialKind;

  @override
  State<_ComposeNoteSheet> createState() => _ComposeNoteSheetState();
}

class _ComposeNoteSheetState extends State<_ComposeNoteSheet> {
  static const _maxLength = 2000;

  late final _text = TextEditingController(text: widget.initialText);
  late Patient? _patient = widget.initialPatient;
  late String _kind = kNoteKinds.contains(widget.initialKind) ? widget.initialKind! : kNoteKinds.first;
  NoteUrgency _urgency = NoteUrgency.normal;
  bool _posting = false;
  bool _reading = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ready => !_posting && _patient != null && _text.text.trim().isNotEmpty;

  Future<void> _choosePatient() async {
    final picked = await showPatientPicker(context);
    if (picked != null) setState(() => _patient = picked);
  }

  Future<void> _scan() async {
    final source = await showOptionSheet<ImageSource>(
      context,
      title: 'Add text from a photo',
      options: const {ImageSource.camera: 'Take photo', ImageSource.gallery: 'Choose photo'},
    );
    if (source == null || !mounted) return;
    setState(() => _reading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final found = await TextScanService().scan(source);
      if (found == null) return;
      final before = _text.text.trimRight();
      final joined = before.isEmpty ? found : '$before\n\n$found';
      _text.value = TextEditingValue(text: joined, selection: TextSelection.collapsed(offset: joined.length));
      setState(() {});
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(e is TextScanException ? e.message : friendlyError(e)),
      ));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _post() async {
    final me = context.read<AccountProvider>().currentUser;
    final p = _patient;
    if (me == null || p == null) return;
    setState(() => _posting = true);
    final feed = context.read<WardFeed>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final ok = await feed.post(Note(
      id: const Uuid().v4(),
      patientId: p.id,
      patientName: p.name,
      wardId: p.wardId,
      authorId: me.uid,
      authorName: me.name,
      authorRole: me.roleLabel,
      text: _text.text.trim(),
      kind: _kind,
      urgency: _urgency,
      createdAt: now,
      updatedAt: now,
    ));
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Posted to ${p.name}’s ward')));
      ReviewRequest.maybeAsk();
    } else {
      setState(() => _posting = false);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text("Couldn't post — ${friendlyError(feed.lastError ?? 'error')}"),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final left = _maxLength - _text.text.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: _posting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text('New Note',
                        textAlign: TextAlign.center,
                        style: AppTypography.headline(color: AppColors.textPrimary)),
                  ),
                  _posting
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: CupertinoActivityIndicator(),
                        )
                      : CupertinoButton(
                          onPressed: _ready ? _post : null,
                          child: const Text('Post', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                ],
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    InsetGroup(
                      dividerIndent: 16,
                      children: [
                        SettingsRow(
                          title: 'Patient',
                          value: p == null ? 'Choose' : p.name,
                          subtitle: p == null ? null : [if (p.bedNumber.isNotEmpty) 'Bed ${p.bedNumber}', p.ageLabel].join(' · '),
                          onTap: widget.initialPatient == null ? _choosePatient : null,
                          showChevron: widget.initialPatient == null,
                        ),
                        SettingsRow(
                          title: 'Kind',
                          value: _kind,
                          onTap: () async {
                            final k = await showOptionSheet<String>(
                              context,
                              title: 'Kind of note',
                              selected: _kind,
                              options: {for (final k in kNoteKinds) k: k},
                            );
                            if (k != null) setState(() => _kind = k);
                          },
                        ),
                        InsetSegmentedRow<NoteUrgency>(
                          label: 'Priority',
                          value: _urgency,
                          options: {for (final u in NoteUrgency.values) u: u.label},
                          onChanged: (u) => setState(() => _urgency = u),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CupertinoTextField.borderless(
                            controller: _text,
                            autofocus: widget.initialPatient != null,
                            placeholder: 'What should the team know?',
                            minLines: 5,
                            maxLines: 12,
                            maxLength: _maxLength,
                            textCapitalization: TextCapitalization.sentences,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            style: AppTypography.body(color: AppColors.textPrimary),
                            onChanged: (_) => setState(() {}),
                          ),
                          Row(
                            children: [
                              if (TextScanService.isSupported)
                                TextButton.icon(
                                  onPressed: _reading ? null : _scan,
                                  icon: _reading
                                      ? const SizedBox(
                                          width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                                      : const Icon(Icons.document_scanner_outlined, size: 18),
                                  label: Text(_reading ? 'Reading…' : 'Scan Text'),
                                ),
                              const Spacer(),
                              if (left < 200)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('$left',
                                      style: AppTypography.footnote(
                                          color: left < 20 ? AppColors.danger : AppColors.textSecondary)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_urgency == NoteUrgency.urgent)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text('Urgent notes alert everyone on the ward straight away.',
                            style: AppTypography.footnote(color: AppColors.danger)),
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
}
