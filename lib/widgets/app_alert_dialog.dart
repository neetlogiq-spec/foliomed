import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// Drop-in for [AlertDialog] (the parameters FolioMed uses) that renders a
/// native [CupertinoAlertDialog] on iOS and macOS and a Material dialog
/// elsewhere. Pair it with [showAdaptiveDialog].
///
/// On Apple platforms the existing Material action buttons are converted:
/// * a filled button (Elevated / Filled) becomes the bold default action,
/// * a button styled in the danger colour becomes a destructive action,
/// * a disabled button (null `onPressed`) stays disabled,
/// * button text loses any hard-coded colour so the system tint applies.
/// The content keeps working with Material inputs (TextField etc.).
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
    this.shape,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  /// Overridable in tests; defaults to the real platform check.
  @visibleForTesting
  static bool Function() useCupertino = () => AppTypography.isApple;

  @override
  Widget build(BuildContext context) {
    if (!useCupertino()) {
      return AlertDialog(
        title: title,
        content: content,
        actions: [
          for (final action in actions ?? const <Widget>[])
            toMaterialAction(action),
        ],
        backgroundColor: backgroundColor,
        shape: shape,
      );
    }
    return CupertinoAlertDialog(
      title: title,
      content: content == null
          ? null
          : Material(
              // TextFields and ListTiles inside need a Material ancestor.
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: content,
              ),
            ),
      actions: [for (final action in actions ?? const <Widget>[]) toCupertinoAction(action)],
    );
  }

  /// Converts a Material button into a [CupertinoDialogAction]; anything
  /// else is returned unchanged.
  @visibleForTesting
  static Widget toCupertinoAction(Widget action) {
    if (action is! ButtonStyleButton) return action;
    final destructive = _isDanger(action.style);
    final filled = action is ElevatedButton || action is FilledButton;
    return CupertinoDialogAction(
      onPressed: action.onPressed,
      isDefaultAction: filled && !destructive,
      isDestructiveAction: destructive,
      child: _plainLabel(action.child) ?? const SizedBox.shrink(),
    );
  }

  /// Material: a destructive action is red *text* on a plain button — a
  /// red-filled button would read as the recommended action (HIG).
  @visibleForTesting
  static Widget toMaterialAction(Widget action) {
    if (action is! ButtonStyleButton || !_isDanger(action.style)) return action;
    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.danger,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      child: _plainLabel(action.child) ?? const SizedBox.shrink(),
    );
  }

  static bool _isDanger(ButtonStyle? style) {
    if (style == null) return false;
    const states = <WidgetState>{};
    final colors = [
      style.backgroundColor?.resolve(states),
      style.foregroundColor?.resolve(states),
    ];
    return colors.any((c) =>
        c != null && (c.value == AppColors.danger.value || c.value == AppColors.critical.value));
  }

  /// Strips explicit colours (e.g. white text meant for a filled button)
  /// so the Cupertino action's own tint/red applies.
  static Widget? _plainLabel(Widget? child) {
    if (child is Text && child.data != null) {
      return Text(
        child.data!,
        textAlign: child.textAlign,
        maxLines: child.maxLines,
        overflow: child.overflow,
        style: child.style?.fontWeight == null
            ? null
            : TextStyle(fontWeight: child.style!.fontWeight),
      );
    }
    return child;
  }
}
