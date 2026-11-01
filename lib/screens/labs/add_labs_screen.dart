import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../clinical/lab_parser.dart';
import '../../clinical/labs.dart';
import '../../models/lab_result.dart';
import '../../models/patient.dart';
import '../../services/lab_service.dart';
import '../../services/text_scan_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/formatting.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';

/// Panels shown open by default; the rest open with "More tests".
const _openPanels = {'Blood count', 'Inflammation', 'Kidney and salts'};

/// Enter results sampled together, typed or read from a photo of the
/// report. High / low comes from the report's own reference range.
class AddLabsScreen extends StatefulWidget {
  const AddLabsScreen({super.key, required this.patient});
  final Patient patient;

  @override
  State<AddLabsScreen> createState() => _AddLabsScreenState();
}

class _AddLabsScreenState extends State<AddLabsScreen> {
  final _values = {for (final t in kLabTests) t.key: TextEditingController()};
  final _refs = <String, (double?, double?)>{};
  DateTime _sampledAt = DateTime.now();
  bool _allPanels = false;
  bool _scanned = false;
  bool _scanning = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<LabEntry> get _entries => [
    for (final t in kLabTests)
      if (_values[t.key]!.text.trim().isNotEmpty)
        t.text
            ? LabEntry(test: t, text: _values[t.key]!.text.trim())
            : LabEntry(
                test: t,
                value: double.tryParse(_values[t.key]!.text.trim()),
                refLow: _refs[t.key]?.$1,
                refHigh: _refs[t.key]?.$2,
              ),
  ].where((e) => e.value != null || e.text != null).toList();

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _sampledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_sampledAt));
    setState(() => _sampledAt = DateTime(d.year, d.month, d.day, t?.hour ?? _sampledAt.hour, t?.minute ?? 0));
  }

  Future<void> _scan() async {
    final source = await showOptionSheet<ImageSource>(
      context,
      title: 'Scan lab report',
      options: const {ImageSource.camera: 'Take Photo', ImageSource.gallery: 'Choose Photo'},
    );
    if (source == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _scanning = true);
    try {
      final text = await TextScanService().scan(source);
      if (text == null) return;
      final parsed = parseLabText(text);
      var filled = 0;
      for (final p in parsed) {
        final c = _values[p.test.key]!;
        if (c.text.trim().isNotEmpty) continue;
        c.text = p.text ?? _num(p.value!);
        _refs[p.test.key] = (p.refLow, p.refHigh);
        filled++;
      }
      setState(() {
        _scanned = filled > 0 || _scanned;
        if (parsed.any((p) => !_openPanels.contains(p.test.panel))) _allPanels = true;
      });
      Haptics.success();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            filled == 0
                ? 'No results recognised — type them in.'
                : 'Filled $filled result${filled == 1 ? '' : 's'} — check each against the report.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't read the photo — ${friendlyError(e)}")));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

  Future<void> _save() async {
    final entries = _entries;
    if (entries.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await LabService().add(patientId: widget.patient.id, sampledAt: _sampledAt, entries: entries, scanned: _scanned);
      Haptics.success();
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${entries.length} result${entries.length == 1 ? '' : 's'} saved')),
      );
    } catch (e) {
      Haptics.error();
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save — ${friendlyError(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final panels = [
      for (final p in kLabPanels)
        if (_allPanels || _openPanels.contains(p)) p,
    ];
    final count = _entries.length;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            LargeTitleAppBar(title: 'Add Results', eyebrow: widget.patient.name, showBackButton: true),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList.list(
                children: [
                  InsetGroup(
                    dividerIndent: 16,
                    children: [
                      SettingsRow(
                        icon: Icons.schedule,
                        title: 'Sampled',
                        value: formatDueTime(_sampledAt),
                        showChevron: true,
                        onTap: _pickTime,
                      ),
                      if (TextScanService.isSupported)
                        SettingsRow(
                          icon: Icons.document_scanner_outlined,
                          title: _scanning ? 'Reading the report…' : 'Scan Report',
                          subtitle: 'Fills results and reference ranges from a photo',
                          onTap: _scanning ? null : _scan,
                        ),
                    ],
                  ),
                  for (final panel in panels) ...[
                    const SizedBox(height: 20),
                    InsetGroup(
                      header: panel,
                      dividerIndent: 16,
                      children: [
                        for (final t in kLabTests.where((t) => t.panel == panel))
                          InsetTextRow(
                            label: _refs[t.key] == null || (_refs[t.key]!.$1 == null && _refs[t.key]!.$2 == null)
                                ? t.name
                                : '${t.name} (${_refText(_refs[t.key]!)})',
                            controller: _values[t.key]!,
                            placeholder: t.text ? 'Result' : '—',
                            suffix: t.unit.isEmpty ? null : t.unit,
                            keyboardType: t.text
                                ? TextInputType.text
                                : const TextInputType.numberWithOptions(decimal: true, signed: true),
                            inputFormatters: t.text ? null : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                            onChanged: (_) => setState(() {}),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (!_allPanels)
                    TextButton(onPressed: () => setState(() => _allPanels = true), child: const Text('More Tests')),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving || count == 0 ? null : _save,
                    child: Text(count == 0 ? 'Save' : 'Save $count Result${count == 1 ? '' : 's'}'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'High and low follow the reference range printed on the report. Critically abnormal values are '
                    'always flagged. Check scanned values against the report.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _refText((double?, double?) r) =>
      r.$1 == null ? '< ${_num(r.$2!)}' : (r.$2 == null ? '> ${_num(r.$1!)}' : '${_num(r.$1!)}–${_num(r.$2!)}');
}
