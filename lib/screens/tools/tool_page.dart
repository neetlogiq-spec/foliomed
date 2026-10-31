import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/patient.dart';
import '../../tools/neonatal_formulas.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/patient_picker.dart';

/// The frame every tool shares: unverified banner, inputs, a result card,
/// and how the number was worked out (formula + source).
class ToolPage extends StatelessWidget {
  const ToolPage({
    super.key,
    required this.title,
    required this.children,
    required this.method,
    required this.source,
  });

  final String title;
  final List<Widget> children;

  /// Plain-language formula(s), one per line.
  final String method;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            LargeTitleAppBar(title: title, showBackButton: true),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList.list(children: [
                if (!kToolsVerified) ...[const _UnverifiedBanner(), const SizedBox(height: 16)],
                ...children,
                const SizedBox(height: 24),
                InsetGroup(
                  header: 'How it’s worked out',
                  footer: source,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(method, style: AppTypography.subheadline(color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnverifiedBanner extends StatelessWidget {
  const _UnverifiedBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Not yet checked by your unit. Confirm every number against your protocol before acting on it.',
                style: AppTypography.footnote(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );
}

/// "Fill from a baby": picks an admitted patient and hands it back so the
/// tool can prefill weight, day of life and gestation.
class BabyRow extends StatelessWidget {
  const BabyRow({super.key, required this.patient, required this.onPicked});
  final Patient? patient;
  final ValueChanged<Patient> onPicked;

  @override
  Widget build(BuildContext context) => InsetGroup(
        footer: patient == null ? 'Optional — fills in what FolioMed knows about the baby. You can change any value.' : null,
        children: [
          SettingsRow(
            icon: Icons.child_care,
            title: patient == null ? 'Fill from a Baby' : patient!.name,
            subtitle: patient == null ? null : 'Values filled in below — check them',
            onTap: () async {
              final p = await showPatientPicker(context);
              if (p != null) onPicked(p);
            },
          ),
        ],
      );
}

/// A numeric input row with a unit.
class NumberRow extends StatelessWidget {
  const NumberRow({
    super.key,
    required this.label,
    required this.controller,
    required this.unit,
    required this.onChanged,
    this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final String? placeholder;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => InsetTextRow(
        label: label,
        controller: controller,
        placeholder: placeholder ?? '0',
        suffix: unit,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (_) => onChanged(),
      );
}

/// Parses a positive number from a field, or null.
double? readNumber(TextEditingController c) {
  final v = double.tryParse(c.text.trim());
  return v == null || v <= 0 || v.isNaN ? null : v;
}

/// Writes a value into a field without trailing ".0".
void writeNumber(TextEditingController c, num? v) {
  if (v == null) return;
  c.text = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Rounds for display: [digits] decimals, no trailing zeros.
String fmt(double v, [int digits = 1]) {
  final s = v.toStringAsFixed(digits);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// One or more results: the main number large, details beneath.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.lines, this.emptyHint = 'Fill in the values above.'});

  /// (label, value) pairs; the first is shown large. Null → empty hint.
  final List<(String, String)>? lines;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final l = lines;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.card)),
        child: l == null || l.isEmpty
            ? Text(emptyHint, style: AppTypography.subheadline(color: AppColors.textSecondary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.first.$1, style: AppTypography.footnote(color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(l.first.$2, style: AppTypography.largeTitle(color: AppColors.textPrimary)),
                  for (final (label, value) in l.skip(1)) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text(label, style: AppTypography.subheadline(color: AppColors.textSecondary))),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 3,
                          child: Text(value,
                              textAlign: TextAlign.end, style: AppTypography.headline(color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
