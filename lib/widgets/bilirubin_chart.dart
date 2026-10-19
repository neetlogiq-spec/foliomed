import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clinical/bilirubin.dart';
import '../models/newborn_tracking.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// Bilirubin against hours of life: NICE phototherapy and exchange lines
/// (≥38 weeks), each reading (serum filled, transcutaneous hollow), and
/// phototherapy periods shaded. Values are plotted in µmol/L; the axis
/// also labels mg/dL.
class BilirubinChart extends StatelessWidget {
  const BilirubinChart({
    super.key,
    required this.bornAt,
    required this.readings,
    required this.sessions,
    required this.showNiceLines,
  });

  final DateTime bornAt;
  final List<BilirubinReading> readings;
  final List<PhototherapySession> sessions;
  final bool showNiceLines;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final r in readings)
        (hours: r.measuredAt.difference(bornAt).inMinutes / 60, umol: r.umol, tcb: r.transcutaneous),
    ];
    final now = DateTime.now().difference(bornAt).inMinutes / 60;
    final maxHours = math.max(
      120.0,
      [now, ...points.map((p) => p.hours)].reduce(math.max) + 12,
    ).clamp(24.0, 336.0);
    final maxUmol = math.max(
      showNiceLines ? 500.0 : 300.0,
      points.isEmpty ? 0.0 : points.map((p) => p.umol).reduce(math.max) * 1.15,
    );
    final semantics = points.isEmpty
        ? 'Bilirubin chart, no readings yet'
        : 'Bilirubin chart with ${points.length} readings. Latest '
            '${points.last.umol.round()} micromoles per litre at ${points.last.hours.round()} hours.';
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.6,
        child: CustomPaint(
          painter: _ChartPainter(
            points: points,
            bands: [
              for (final s in sessions)
                (
                  from: s.startedAt.difference(bornAt).inMinutes / 60,
                  to: (s.stoppedAt ?? DateTime.now()).difference(bornAt).inMinutes / 60,
                ),
            ],
            maxHours: maxHours.toDouble(),
            maxUmol: maxUmol,
            showNice: showNiceLines,
            nowHours: now,
            colors: _ChartColors(
              grid: AppColors.divider,
              label: AppColors.textSecondary,
              point: AppColors.primary,
              photo: AppColors.warning,
              exchange: AppColors.danger,
              band: AppColors.warning.withValues(alpha: 0.12),
              now: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            labelStyle: AppTypography.caption2(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ChartColors {
  const _ChartColors({
    required this.grid,
    required this.label,
    required this.point,
    required this.photo,
    required this.exchange,
    required this.band,
    required this.now,
  });
  final Color grid, label, point, photo, exchange, band, now;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.bands,
    required this.maxHours,
    required this.maxUmol,
    required this.showNice,
    required this.nowHours,
    required this.colors,
    required this.labelStyle,
  });

  final List<({double hours, double umol, bool tcb})> points;
  final List<({double from, double to})> bands;
  final double maxHours;
  final double maxUmol;
  final bool showNice;
  final double nowHours;
  final _ChartColors colors;
  final TextStyle labelStyle;

  static const _left = 34.0, _bottom = 20.0, _top = 6.0, _right = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom);
    Offset at(double h, double u) => Offset(
          plot.left + (h / maxHours).clamp(0, 1) * plot.width,
          plot.bottom - (u / maxUmol).clamp(0, 1) * plot.height,
        );

    // Phototherapy bands.
    final bandPaint = Paint()..color = colors.band;
    for (final b in bands) {
      final l = at(b.from, 0).dx, r = at(b.to, 0).dx;
      if (r > l) canvas.drawRect(Rect.fromLTRB(l, plot.top, r, plot.bottom), bandPaint);
    }

    // Grid + labels.
    final grid = Paint()
      ..color = colors.grid
      ..strokeWidth = 0.5;
    final hourStep = maxHours > 168 ? 48.0 : 24.0;
    for (var h = 0.0; h <= maxHours + 0.1; h += hourStep) {
      final x = at(h, 0).dx;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      _text(canvas, '${h.round()}h', Offset(x, plot.bottom + 3), center: true);
    }
    final umolStep = maxUmol > 400 ? 100.0 : 50.0;
    for (var u = 0.0; u <= maxUmol + 0.1; u += umolStep) {
      final y = at(0, u).dy;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, '${u.round()}', Offset(plot.left - 4, y - 6), alignRight: true);
    }

    // "Now" marker.
    if (nowHours > 0 && nowHours < maxHours) {
      final x = at(nowHours, 0).dx;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom),
          Paint()
            ..color = colors.now
            ..strokeWidth = 1);
    }

    // NICE lines.
    if (showNice) {
      Path line(double Function(BiliThresholds) pick) {
        final p = Path();
        for (var h = 0.0; h <= maxHours; h += 2) {
          final o = at(h, pick(NiceCg98.thresholdsAt(h)));
          h == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        return p;
      }

      canvas.drawPath(
          line((t) => t.phototherapy),
          Paint()
            ..color = colors.photo
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawPath(
          line((t) => t.exchange),
          Paint()
            ..color = colors.exchange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Readings, joined in time order.
    final sorted = [...points]..sort((a, b) => a.hours.compareTo(b.hours));
    if (sorted.length > 1) {
      final trend = Path()..moveTo(at(sorted.first.hours, sorted.first.umol).dx,
          at(sorted.first.hours, sorted.first.umol).dy);
      for (final p in sorted.skip(1)) {
        final o = at(p.hours, p.umol);
        trend.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          trend,
          Paint()
            ..color = colors.point.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    for (final p in sorted) {
      final o = at(p.hours, p.umol);
      canvas.drawCircle(o, 4.5, Paint()..color = colors.point);
      if (p.tcb) canvas.drawCircle(o, 2.5, Paint()..color = Colors.white);
    }

    _text(canvas, 'µmol/L', Offset(plot.left + 4, plot.top));
  }

  void _text(Canvas c, String s, Offset o, {bool center = false, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = o.dx;
    if (center) dx -= tp.width / 2;
    if (alignRight) dx -= tp.width;
    tp.paint(c, Offset(dx, o.dy));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.bands != bands || old.maxHours != maxHours ||
      old.showNice != showNice || old.colors.point != colors.point;
}
