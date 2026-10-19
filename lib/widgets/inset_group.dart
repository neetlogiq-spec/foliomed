import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// iOS "inset grouped" table section: optional header, rounded card of
/// rows separated by inset hairlines, optional footer.
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.dividerIndent = 60,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  /// Hairline inset — aligns with the row text after a 28pt icon tile.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(height: 0.5, thickness: 0.5, indent: dividerIndent));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              header!.toUpperCase(),
              style: AppTypography.footnote(color: AppColors.textSecondary)
                  .copyWith(letterSpacing: 0.4),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              footer!,
              style: AppTypography.footnote(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// A Settings-style row: coloured icon tile, title (+ subtitle), and a
/// trailing value, custom widget or disclosure chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Defaults to true when the row is tappable and has no custom trailing.
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.danger : (iconColor ?? AppColors.primary);
    final chevron = showChevron ?? (onTap != null && trailing == null && !destructive);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      color: destructive ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle!,
                        style: AppTypography.footnote(
                            color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  value!,
                  style: AppTypography.body(color: AppColors.textSecondary),
                ),
              ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: trailing!,
              ),
            if (chevron)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// A text-entry row for an [InsetGroup] form: label on the left, value on
/// the right (iOS Settings / Contacts style). Multiline fields stack the
/// label above the input.
class InsetTextRow extends StatelessWidget {
  const InsetTextRow({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final int maxLines;

  /// Unit shown after the value, e.g. "mg/dL".
  final String? suffix;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      minLines: maxLines > 1 ? 2 : 1,
      maxLines: maxLines,
      textAlign: maxLines > 1 ? TextAlign.start : TextAlign.end,
      style: AppTypography.body(
          color: enabled ? AppColors.textPrimary : AppColors.textSecondary),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        hintText: placeholder,
        hintStyle: AppTypography.body(color: AppColors.tertiaryLabel),
        suffixText: suffix,
        suffixStyle: AppTypography.body(color: AppColors.textSecondary),
      ),
    );
    final labelText = Text(label,
        style: AppTypography.body(
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: maxLines > 1
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, field],
            )
          : Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 96),
                  child: labelText,
                ),
                const SizedBox(width: 12),
                Expanded(child: field),
              ],
            ),
    );
  }
}

/// A row holding a segmented control (iOS: Settings → choice rows).
class InsetSegmentedRow<T extends Object> extends StatelessWidget {
  const InsetSegmentedRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTypography.body(color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<T>(
            groupValue: value,
            onValueChanged: (v) {
              if (v != null) onChanged(v);
            },
            children: {
              for (final e in options.entries)
                e.key: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(e.value,
                      style: AppTypography.subheadline(
                          color: AppColors.textPrimary, weight: FontWeight.w600)),
                ),
            },
          ),
        ],
      ),
    );
  }
}

/// Picks one of [options] from an action sheet — the iOS pop-up button
/// pattern for short lists (blood group, ward, OAE result).
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  T? selected,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final e in options.entries)
          CupertinoActionSheetAction(
            isDefaultAction: e.key == selected,
            onPressed: () => Navigator.pop(ctx, e.key),
            child: Text(e.value),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
}
