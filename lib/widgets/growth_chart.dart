import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clinical/growth.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

class GrowthPoint {
  const GrowthPoint(this.months, this.value);
  final double months;
  final double value;
}

const _zLines = [-3.0, -2.0, 0.0, 2.0, 3.0];

/// WHO curves (−3, −2, 0, +2, +3 SD) with the child's points.
class GrowthChart extends StatelessWidget {
  const GrowthChart({super.key, required this.indicator, required this.male, required this.points, this.height = 260});
  final GrowthIndicator indicator;
  final bool male;
  final List<GrowthPoint> points;
  final double height;

  /// The months to show: around the points, inside the table.
  (double, double)? get window {
    final r = WhoGrowth.range(indicator, male);
    if (r == null) return null;
    if (points.isEmpty) return (r.$1, math.min(r.$2, r.$1 + 24));
    final lo = points.map((p) => p.months).reduce(math.min), hi = points.map((p) => p.months).reduce(math.max);
    final span = math.max(6.0, (hi - lo) * 1.3);
    final start = math.max(r.$1, lo - span * 0.15);
    return (start, math.min(r.$2, math.max(hi + span * 0.15, start + 6)));
  }

  @override
  Widget build(BuildContext context) {
    final w = window;
    if (w == null) return const SizedBox.shrink();
    return Semantics(
      label: '${indicator.title} chart with ${points.length} measurement${points.length == 1 ? '' : 's'}',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _GrowthPainter(
            indicator: indicator,
            male: male,
            points: points,
            from: w.$1,
            to: w.$2,
            median: AppColors.stable,
            sd2: AppColors.warning,
            sd3: AppColors.danger,
            point: AppColors.primary,
            grid: AppColors.divider,
            text: AppTypography.caption2(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.indicator,
    required this.male,
    required this.points,
    required this.from,
    required this.to,
    required this.median,
    required this.sd2,
    required this.sd3,
    required this.point,
    required this.grid,
    required this.text,
  });

  final GrowthIndicator indicator;
  final bool male;
  final List<GrowthPoint> points;
  final double from, to;
  final Color median, sd2, sd3, point, grid;
  final TextStyle text;

  static const _left = 36.0, _bottom = 22.0, _top = 8.0, _right = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    double v(double m, double z) => WhoGrowth.valueAt(indicator, male, m, z) ?? double.nan;
    final samples = [for (var i = 0; i <= 60; i++) from + (to - from) * i / 60];
    var lo = samples.map((m) => v(m, -3)).where((x) => !x.isNaN).fold(double.infinity, math.min);
    var hi = samples.map((m) => v(m, 3)).where((x) => !x.isNaN).fold(-double.infinity, math.max);
    for (final p in points) {
      lo = math.min(lo, p.value);
      hi = math.max(hi, p.value);
    }
    if (!lo.isFinite || !hi.isFinite) return;
    final pad = (hi - lo) * 0.05;
    lo -= pad;
    hi += pad;
    final w = size.width - _left - _right, h = size.height - _top - _bottom;
    double x(double m) => _left + (m - from) / (to - from) * w;
    double y(double val) => _top + (1 - (val - lo) / (hi - lo)) * h;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final val = lo + (hi - lo) * i / 4;
      canvas.drawLine(Offset(_left, y(val)), Offset(_left + w, y(val)), gridPaint);
      _label(canvas, val.toStringAsFixed(val.abs() >= 100 ? 0 : 1), Offset(2, y(val) - 7));
    }
    String age(double m) => m >= 24 ? '${(m / 12).toStringAsFixed(m % 12 == 0 ? 0 : 1)} y' : '${m.round()} mo';
    for (final m in [from, (from + to) / 2, to]) {
      _label(canvas, age(m), Offset((x(m) - 14).clamp(_left, size.width - 40), size.height - 16));
    }
    for (final z in _zLines) {
      final path = Path();
      var started = false;
      for (final m in samples) {
        final val = v(m, z);
        if (val.isNaN) continue;
        started ? path.lineTo(x(m), y(val)) : path.moveTo(x(m), y(val));
        started = true;
      }
      final color = z == 0 ? median : (z.abs() == 2 ? sd2 : sd3);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = z == 0 ? 2 : 1.2,
      );
      final end = v(to, z);
      if (!end.isNaN)
        _label(canvas, z == 0 ? '0' : (z > 0 ? '+${z.toInt()}' : '${z.toInt()}'), Offset(_left + w + 3, y(end) - 7));
    }
    final dots = [...points]..sort((a, b) => a.months.compareTo(b.months));
    if (dots.length > 1) {
      final path = Path()..moveTo(x(dots.first.months), y(dots.first.value));
      for (final d in dots.skip(1)) {
        path.lineTo(x(d.months), y(d.value));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = point
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (final d in dots) {
      canvas.drawCircle(Offset(x(d.months), y(d.value)), 4, Paint()..color = point);
    }
  }

  void _label(Canvas canvas, String s, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: text),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_GrowthPainter old) =>
      old.points != points || old.indicator != indicator || old.male != male || old.from != from || old.to != to;
}
