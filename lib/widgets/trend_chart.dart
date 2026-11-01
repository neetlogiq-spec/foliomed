import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

class TrendPoint {
  const TrendPoint(this.at, this.value, {this.flagged = false});
  final DateTime at;
  final double value;
  final bool flagged;
}

/// Values over time, with the reference band shaded when known. Points
/// that are flagged are drawn in the warning colour.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points, this.bandLow, this.bandHigh, this.height = 200});
  final List<TrendPoint> points;
  final double? bandLow, bandHigh;
  final double height;

  @override
  Widget build(BuildContext context) {
    final label =
        'Trend of ${points.length} values from ${points.isEmpty ? '' : DateFormat('d MMM').format(points.first.at)}';
    return Semantics(
      label: label,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrendPainter(
            points: points,
            bandLow: bandLow,
            bandHigh: bandHigh,
            line: AppColors.primary,
            warn: AppColors.warning,
            band: AppColors.stable.withValues(alpha: 0.12),
            grid: AppColors.divider,
            text: AppTypography.caption2(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.bandLow,
    required this.bandHigh,
    required this.line,
    required this.warn,
    required this.band,
    required this.grid,
    required this.text,
  });

  final List<TrendPoint> points;
  final double? bandLow, bandHigh;
  final Color line, warn, band, grid;
  final TextStyle text;

  static const _left = 40.0, _bottom = 22.0, _top = 8.0, _right = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = [for (final p in points) p.value, ?bandLow, ?bandHigh];
    var lo = values.reduce(math.min), hi = values.reduce(math.max);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.1;
    lo -= pad;
    hi += pad;
    final t0 = points.first.at.millisecondsSinceEpoch.toDouble();
    var t1 = points.last.at.millisecondsSinceEpoch.toDouble();
    if (t1 - t0 < 1) t1 = t0 + 3600000;
    final w = size.width - _left - _right, h = size.height - _top - _bottom;
    double x(DateTime t) => _left + (t.millisecondsSinceEpoch - t0) / (t1 - t0) * w;
    double y(double v) => _top + (1 - (v - lo) / (hi - lo)) * h;

    if (bandLow != null || bandHigh != null) {
      final top = y(bandHigh ?? hi), bottom = y(bandLow ?? lo);
      canvas.drawRect(Rect.fromLTRB(_left, top, _left + w, bottom), Paint()..color = band);
    }
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final v = lo + (hi - lo) * i / 4;
      final yy = y(v);
      canvas.drawLine(Offset(_left, yy), Offset(_left + w, yy), gridPaint);
      _label(canvas, _fmt(v), Offset(2, yy - 7));
    }
    _label(canvas, DateFormat('d MMM').format(points.first.at), Offset(_left, size.height - 16));
    if (points.length > 1) {
      final last = DateFormat('d MMM').format(points.last.at);
      _label(canvas, last, Offset(_left + w - 40, size.height - 16));
    }
    final path = Path()..moveTo(x(points.first.at), y(points.first.value));
    for (final p in points.skip(1)) {
      path.lineTo(x(p.at), y(p.value));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final p in points) {
      canvas.drawCircle(Offset(x(p.at), y(p.value)), 4, Paint()..color = p.flagged ? warn : line);
    }
  }

  static String _fmt(double v) => v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(v.abs() >= 10 ? 1 : 2);

  void _label(Canvas canvas, String s, Offset at) {
    final tp = TextPainter(text: TextSpan(text: s, style: text), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.points != points || old.bandLow != bandLow || old.bandHigh != bandHigh;
}
