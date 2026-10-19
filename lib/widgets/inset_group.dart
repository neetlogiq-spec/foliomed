import 'package:flutter/material.dart';

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
