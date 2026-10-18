import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../utils/app_theme.dart';

/// Apple-style modal sheet. Drop-in replacement for [showModalBottomSheet]
/// (same parameters the app uses).
///
/// * Opens and closes on springs that start from the sheet's current
///   on-screen position, so motion is continuous even when interrupted.
/// * Drags track the finger 1:1. Pulling up past fully open rubber-bands.
/// * Inner lists hand off to the sheet: once a list is scrolled to the top,
///   pulling further down moves the sheet instead.
/// * On release the sheet projects where the flick is heading and
///   dismisses if that point is past the halfway mark; otherwise it springs
///   back carrying the release velocity.
/// * The scrim dims in proportion to how open the sheet is.
/// * Reduce Motion: cross-fade instead of slide.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final navigator = Navigator.of(context);
  return navigator.push(_AppSheetRoute<T>(
    builder: builder,
    backgroundColor: backgroundColor,
    shape: shape,
    isScrollControlled: isScrollControlled,
    dismissible: isDismissible,
    enableDrag: enableDrag,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    capturedThemes:
        InheritedTheme.capture(from: context, to: navigator.context),
  ));
}

/// Apple's "projection" of where a flick will come to rest
/// (Designing Fluid Interfaces, WWDC 2018). Velocity in px/s.
@visibleForTesting
double projectSheetOffset(double velocity, {double decelerationRate = 0.998}) =>
    (velocity / 1000) * decelerationRate / (1 - decelerationRate);

/// Progressive resistance past a boundary (rubber-banding).
@visibleForTesting
double rubberBand(double overshoot, double dimension, [double c = 0.55]) =>
    (overshoot * dimension * c) / (dimension + c * overshoot.abs());

/// Spring from Apple's two designer parameters: damping ratio and
/// response (seconds). Stiffness = (2π / response)².
SpringDescription _spring({required double damping, required double response}) =>
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
      ratio: damping,
    );

final SpringDescription _settleSpring = _spring(damping: 1.0, response: 0.35);
final SpringDescription _flickSpring = _spring(damping: 0.8, response: 0.3);

class _AppSheetRoute<T> extends PopupRoute<T> {
  _AppSheetRoute({
    required this.builder,
    required this.backgroundColor,
    required this.shape,
    required this.isScrollControlled,
    required this.dismissible,
    required this.enableDrag,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final WidgetBuilder builder;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final bool isScrollControlled;
  final bool dismissible;
  final bool enableDrag;
  final CapturedThemes capturedThemes;

  @override
  final String? barrierLabel;

  /// Closing velocity (sheet-heights per second) handed over by a flick.
  double pendingCloseVelocity = 0;

  AnimationController get sheetController => controller!;

  @override
  bool get barrierDismissible => dismissible;

  // The sheet paints its own scrim so it can track drags.
  @override
  Color? get barrierColor => Colors.transparent;

  @override
  Duration get transitionDuration => AppMotion.standard;

  @override
  Duration get reverseTransitionDuration => AppMotion.standard;

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    sheetController.animateWith(
      SpringSimulation(_settleSpring, sheetController.value, 1, 0),
    );
    return future;
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    sheetController.animateBackWith(SpringSimulation(
      _settleSpring,
      sheetController.value,
      0,
      pendingCloseVelocity,
    ));
    return popped;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return capturedThemes.wrap(_AppSheet<T>(route: this));
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;
}

class _AppSheet<T> extends StatefulWidget {
  const _AppSheet({required this.route});

  final _AppSheetRoute<T> route;

  @override
  State<_AppSheet<T>> createState() => _AppSheetState<T>();
}

class _AppSheetState<T> extends State<_AppSheet<T>>
    with SingleTickerProviderStateMixin {
  final GlobalKey _sheetKey = GlobalKey();
  late final AnimationController _rubber =
      AnimationController.unbounded(vsync: this)..addListener(_onRubber);

  /// Finger travel past the top edge, in px (drives the rubber band).
  double _overDrag = 0;
  bool _dragging = false;
  bool _scrollDriven = false;
  final VelocityTracker _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);

  _AppSheetRoute<T> get _route => widget.route;
  AnimationController get _c => _route.sheetController;

  double get _height =>
      _sheetKey.currentContext?.size?.height.clamp(1.0, double.infinity) ?? 1;

  /// True while the sheet sits below its open position.
  bool get isLowered => _c.value < 1 - 1e-4 || _overDrag != 0;

  void _onRubber() => setState(() {});

  @override
  void dispose() {
    _rubber.dispose();
    super.dispose();
  }

  // ── Drag API (shared by the gesture detector and the scroll physics) ──

  void _beginDrag() {
    if (!_route.isCurrent) return; // already dismissing
    _dragging = true;
    _c.stop();
    _rubber.stop();
  }

  /// [dy] > 0 means the finger moved down.
  void dragBy(double dy) {
    if (!_dragging) _beginDrag();
    if (!_dragging) return;
    final h = _height;
    var offset = (1 - _c.value) * h - _overDrag + dy;
    // A drag handed over from a list never rubber-bands: once the sheet is
    // back at the top, the list takes over scrolling again.
    if (_scrollDriven) offset = math.max(offset, 0);
    if (offset >= 0) {
      _overDrag = 0;
      _c.value = 1 - offset / h;
    } else {
      _c.value = 1;
      _overDrag = -offset;
    }
    _rubber.value = rubberBand(_overDrag, h);
  }

  /// [velocity] in px/s, positive = downward.
  void endDrag(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    _scrollDriven = false;
    final h = _height;

    if (_overDrag > 0) {
      _overDrag = 0;
      _rubber.animateWith(
        SpringSimulation(_settleSpring, _rubber.value, 0, -velocity),
      );
    }

    final offset = (1 - _c.value) * h;
    final projected = offset + projectSheetOffset(velocity);
    if (_route.dismissible && projected > h / 2) {
      _route.pendingCloseVelocity = -velocity.abs() / h;
      Navigator.of(context).pop();
      return;
    }
    // Back to open. Bounce only if the gesture carried momentum.
    final spring = velocity.abs() > 300 ? _flickSpring : _settleSpring;
    _c.animateWith(SpringSimulation(spring, _c.value, 1, -velocity / h));
  }

  // ── Pointer tracking for scroll-driven drags ──────────────────────────

  void _onPointerMove(PointerMoveEvent e) =>
      _tracker.addPosition(e.timeStamp, e.position);

  void _onPointerDown(PointerDownEvent e) =>
      _tracker.addPosition(e.timeStamp, e.position);

  void _onPointerUp(PointerEvent e) {
    if (_scrollDriven && _dragging) {
      endDrag(_tracker.getVelocity().pixelsPerSecond.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);
    final reduced = AppMotion.reduced(context);
    final maxHeight = _route.isScrollControlled
        ? mq.size.height - mq.padding.top - 10
        : mq.size.height * 9 / 16;
    final shape = _route.shape ?? theme.bottomSheetTheme.shape;
    final background = _route.backgroundColor ??
        theme.bottomSheetTheme.modalBackgroundColor ??
        theme.colorScheme.surface;

    Widget sheet = Material(
      key: _sheetKey,
      color: background,
      shape: shape,
      clipBehavior: shape == null ? Clip.none : Clip.antiAlias,
      child: ScrollConfiguration(
        // Keep the app's scroll behaviour (drag devices, scrollbars) but
        // route vertical pulls to the sheet when a list is at its top.
        behavior: ScrollConfiguration.of(context).copyWith(
          physics: _SheetHandoffPhysics(
            this,
            parent: const ClampingScrollPhysics(),
          ),
          overscroll: false,
        ),
        child: Builder(builder: _route.builder),
      ),
    );

    if (_route.enableDrag) {
      sheet = Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onVerticalDragStart: (_) => _beginDrag(),
          onVerticalDragUpdate: (d) => dragBy(d.delta.dy),
          onVerticalDragEnd: (d) => endDrag(d.velocity.pixelsPerSecond.dy),
          onVerticalDragCancel: () => endDrag(0),
          child: sheet,
        ),
      );
    }

    sheet = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 680),
      child: sheet,
    );

    return AnimatedBuilder(
      animation: _c,
      child: sheet,
      builder: (context, child) {
        final t = _c.value.clamp(0.0, 1.0);
        final Widget positioned = reduced
            ? Opacity(opacity: t, child: child)
            : FractionalTranslation(
                translation: Offset(0, 1 - t),
                child: Transform.translate(
                  offset: Offset(0, -_rubber.value),
                  child: child,
                ),
              );
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.35 * t),
                ),
              ),
            ),
            Align(alignment: Alignment.bottomCenter, child: positioned),
          ],
        );
      },
    );
  }
}

/// Routes the user's drag to the sheet when the list is at its top (or the
/// sheet is already lowered), so pulling down dismisses naturally.
class _SheetHandoffPhysics extends ScrollPhysics {
  const _SheetHandoffPhysics(this.sheet, {super.parent});

  final _AppSheetState sheet;

  @override
  _SheetHandoffPhysics applyTo(ScrollPhysics? ancestor) =>
      _SheetHandoffPhysics(sheet, parent: buildParent(ancestor));

  bool _routesToSheet(ScrollMetrics position, double offset) =>
      position.axis == Axis.vertical &&
      sheet._route.enableDrag &&
      ((sheet.isLowered && sheet._scrollDriven) ||
          (offset > 0 && position.pixels <= position.minScrollExtent));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (_routesToSheet(position, offset)) {
      sheet._scrollDriven = true;
      sheet.dragBy(offset);
      return 0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // The sheet settles itself (on pointer-up); don't fling the list too.
    if (sheet._scrollDriven || sheet.isLowered) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}
