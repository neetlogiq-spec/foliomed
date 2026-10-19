import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/accessibility_settings.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// "Good morning" / "Good afternoon" / "Good evening".
String timeOfDayGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// iOS large-title navigation bar as a sliver (Settings / Health pattern).
///
/// * Expanded: transparent over the grouped background, an optional small
///   [eyebrow] line (e.g. the greeting) above a 34pt [title].
/// * Collapsing: the large title scrolls up with the content; the 17pt
///   title fades into a frosted bar with a hairline once content passes
///   underneath.
/// * Reduce Transparency / high contrast: solid bar instead of blur.
/// * Text size: the expanded area grows with the user's text scale, and
///   the title scales down rather than overflowing.
class LargeTitleAppBar extends StatelessWidget {
  const LargeTitleAppBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const [],
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  static const double _toolbarHeight = 52;

  @override
  Widget build(BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final expandedExtra = (eyebrow == null ? 44.0 : 64.0) * textScale + 14;
    return ValueListenableBuilder<bool>(
      valueListenable: AccessibilitySettings.reduceTransparency,
      builder: (context, reduceTransparency, _) {
        final solid = reduceTransparency || MediaQuery.highContrastOf(context);
        return SliverAppBar(
          pinned: true,
          toolbarHeight: _toolbarHeight,
          collapsedHeight: _toolbarHeight,
          expandedHeight: _toolbarHeight + expandedExtra,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          actions: [...actions, const SizedBox(width: 8)],
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              final top = MediaQuery.paddingOf(context).top;
              final minH = _toolbarHeight + top;
              final range = expandedExtra;
              final t = ((constraints.maxHeight - minH) / range).clamp(0.0, 1.0);
              // Chrome + small title appear as the large title leaves.
              final chromeOpacity = (1 - t / 0.25).clamp(0.0, 1.0);
              final smallTitleOpacity = (1 - t / 0.35).clamp(0.0, 1.0);
              final largeOpacity = ((t - 0.15) / 0.85).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: chromeOpacity,
                    child: _Chrome(solid: solid),
                  ),
                  Positioned(
                    top: top,
                    left: 72,
                    right: 72,
                    height: _toolbarHeight,
                    child: Center(
                      child: Opacity(
                        opacity: smallTitleOpacity,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headline(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 8,
                    child: Opacity(
                      opacity: largeOpacity,
                      child: Semantics(
                        header: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eyebrow != null)
                              Text(
                                eyebrow!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.subheadline(
                                  color: AppColors.textSecondary,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                title,
                                maxLines: 1,
                                style: AppTypography.largeTitle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.solid});

  final bool solid;

  @override
  Widget build(BuildContext context) {
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: solid
            ? (AppColors.isDark ? AppColors.darkCard : Colors.white)
            : AppColors.chrome,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
    );
    if (solid) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: bar,
      ),
    );
  }
}

/// Navigation-bar action: icon in a tertiarySystemFill circle (how iOS
/// places bar buttons), 44pt touch target, optional unread badge that
/// "pops" when the count goes up.
class ChromeIconButton extends StatelessWidget {
  const ChromeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final tint = color ??
        (AppColors.isDark ? AppColors.darkPrimary : AppColors.primary);
    return Semantics(
      button: true,
      label: badgeCount > 0 ? '$tooltip, $badgeCount new' : tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: tint),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 2,
                    top: 3,
                    child: _Badge(count: badgeCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatefulWidget {
  const _Badge({required this.count});

  final int count;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> {
  int _popKey = 0;

  @override
  void didUpdateWidget(covariant _Badge oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pop only when new items arrive — that's the information worth
    // drawing the eye to. Decreases update silently.
    if (widget.count > oldWidget.count) _popKey++;
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.count > 99 ? '99+' : '${widget.count}',
        style: AppTypography.caption2(
          color: Colors.white,
          weight: FontWeight.w700,
        ).copyWith(fontFeatures: AppTypography.tabular, height: 1.1),
      ),
    );
    if (_popKey == 0 || AppMotion.reduced(context)) return badge;
    return badge
        .animate(key: ValueKey(_popKey))
        .scale(
          begin: const Offset(1.3, 1.3),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 300.ms,
        );
  }
}

/// Grouped-list section header: headline weight, optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.title3(color: AppColors.textPrimary),
              ),
            ),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// First-load entrance for list items: a short fade + 3% rise, 40ms apart,
/// capped at 8 items. Explains that data arrived; never replays on rebuild
/// (the caller passes [animate] = false after the first load) and is
/// skipped under Reduce Motion.
Widget staggeredEntrance(
  BuildContext context, {
  required Widget child,
  required int index,
  required bool animate,
}) {
  if (!animate || index >= 8 || AppMotion.reduced(context)) return child;
  return child
      .animate(delay: (40 * index).ms)
      .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic)
      .slideY(begin: 0.03, end: 0, duration: 200.ms, curve: Curves.easeOutCubic);
}
