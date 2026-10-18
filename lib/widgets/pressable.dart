import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../utils/app_theme.dart';

/// Apple-style tap feedback for cards and tiles.
///
/// * Responds on pointer-*down*: the child dims and shrinks to 97% at once,
///   instead of waiting for the tap to complete.
/// * Releases with a critically damped spring (no overshoot) that starts
///   from the current on-screen scale, so a quick tap or a cancel never
///   jumps.
/// * Commits on pointer-up; dragging away (e.g. starting a scroll) cancels.
/// * Reduce Motion: keeps the dim, drops the scale.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final BorderRadius? borderRadius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.borderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  // 0 = at rest, 1 = fully pressed.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  // Damping ratio 1.0, ~0.3s response (Apple's default UI spring).
  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 1.0);

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _animateTo(double target) {
    _press.animateWith(SpringSimulation(
      _spring,
      _press.value, // start from the presentation value
      target,
      _press.velocity,
    ));
  }

  void _down(TapDownDetails _) {
    if (!_enabled) return;
    _press.stop();
    _press.value = 1; // instant response on touch-down
  }

  void _release() {
    if (!_enabled) return;
    _animateTo(0);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _press,
        child: widget.child,
        builder: (context, child) {
          final t = _press.value.clamp(0.0, 1.0);
          final scale = reduced ? 1.0 : 1 - (1 - widget.pressedScale) * t;
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: 1 - 0.15 * t, child: child),
          );
        },
      ),
    );
  }
}
