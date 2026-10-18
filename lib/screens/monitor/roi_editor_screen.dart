import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/camera_config.dart';
import '../../models/monitor_vitals.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────
//  ROI Zone Editor
//  Draw/move/resize regions on a camera frame
//  preview to tell FolioMed Edge which part of
//  the camera image contains each vital reading.
// ─────────────────────────────────────────────

class RoiEditorScreen extends StatefulWidget {
  final CameraConfig camera;
  /// Called with updated ROI map when user saves.
  final void Function(Map<VitalType, RoiRect?> updates) onSave;

  const RoiEditorScreen({super.key, required this.camera, required this.onSave});

  @override
  State<RoiEditorScreen> createState() => _RoiEditorScreenState();
}

class _RoiEditorScreenState extends State<RoiEditorScreen> {
  // Local ROI — null means "cleared / not set"
  late Map<VitalType, RoiRect?> _roi;
  VitalType _activeVital = VitalType.hr;

  // Draw state
  Offset? _dragStart;
  Offset? _dragCurrent;

  // Move state
  RoiRect? _moveBase;
  Offset? _moveStart;

  final _frameKey = GlobalKey();

  static const _editableVitals = [
    VitalType.hr,
    VitalType.spo2,
    VitalType.rr,
    VitalType.sbp,
  ];

  static const _vitalLabels = {
    VitalType.hr:   'Heart Rate',
    VitalType.spo2: 'SpO₂',
    VitalType.rr:   'Resp. Rate',
    VitalType.sbp:  'Blood Pressure',
  };

  static const _vitalColors = {
    VitalType.hr:   Color(0xFFE53935),
    VitalType.spo2: Color(0xFF1976D2),
    VitalType.rr:   Color(0xFF388E3C),
    VitalType.sbp:  Color(0xFF7B1FA2),
  };

  @override
  void initState() {
    super.initState();
    _roi = {
      for (final vt in _editableVitals)
        vt: widget.camera.roi[vt],
    };
  }

  Size get _frameSize {
    final rb = _frameKey.currentContext?.findRenderObject() as RenderBox?;
    return rb?.size ?? Size.zero;
  }

  Offset _toNorm(Offset local) {
    final sz = _frameSize;
    if (sz == Size.zero) return Offset.zero;
    return Offset(
      (local.dx / sz.width).clamp(0.0, 1.0),
      (local.dy / sz.height).clamp(0.0, 1.0),
    );
  }

  RoiRect? _rectFromDrag(Offset a, Offset b) {
    final na = _toNorm(a);
    final nb = _toNorm(b);
    final left = na.dx < nb.dx ? na.dx : nb.dx;
    final top = na.dy < nb.dy ? na.dy : nb.dy;
    final w = (nb.dx - na.dx).abs();
    final h = (nb.dy - na.dy).abs();
    if (w < 0.02 || h < 0.02) return null;
    return RoiRect(left: left, top: top, width: w, height: h);
  }

  bool _hitTest(VitalType vt, Offset local) {
    final rect = _roi[vt];
    if (rect == null) return false;
    final sz = _frameSize;
    final r = Rect.fromLTWH(
      rect.left * sz.width,
      rect.top * sz.height,
      rect.width * sz.width,
      rect.height * sz.height,
    ).inflate(12);
    return r.contains(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        title: Text('Define Vital Zones — ${widget.camera.label}',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save Zones',
                style: GoogleFonts.dmSans(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          _instructions(),
          _vitalTabs(),
          Expanded(child: _frameArea()),
          _legend(),
          _actionRow(),
        ],
      ),
    );
  }

  Widget _instructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select a vital type below, then drag on the camera frame to draw where that '
              'vital number appears on the monitor screen.',
              style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalTabs() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: _editableVitals.map((vt) {
          final active = _activeVital == vt;
          final color = _vitalColors[vt]!;
          final hasZone = _roi[vt] != null;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeVital = vt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? color : AppColors.divider,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Icon(
                          _vitalIcon(vt),
                          size: 18,
                          color: active ? color : AppColors.textSecondary,
                        ),
                        if (hasZone)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _vitalLabels[vt]!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? color : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _frameArea() {
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: ClipRect(
              child: CustomPaint(
                key: _frameKey,
                painter: _RoiPainter(
                  roi: _roi,
                  activeVital: _activeVital,
                  colors: _vitalColors,
                  labels: _vitalLabels,
                  dragStart: _dragStart,
                  dragCurrent: _dragCurrent,
                ),
                child: Container(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails d) {
    final local = _localPos(d.globalPosition);
    // Check if touching an existing zone for the active vital (move)
    if (_hitTest(_activeVital, local)) {
      setState(() {
        _moveBase = _roi[_activeVital];
        _moveStart = local;
        _dragStart = null;
        _dragCurrent = null;
      });
    } else {
      // Start drawing new zone
      setState(() {
        _dragStart = local;
        _dragCurrent = local;
        _moveBase = null;
        _moveStart = null;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final local = _localPos(d.globalPosition);
    if (_moveBase != null && _moveStart != null) {
      // Move existing zone
      final delta = _toNorm(local) - _toNorm(_moveStart!);
      final base = _moveBase!;
      setState(() {
        _roi[_activeVital] = RoiRect(
          left: (base.left + delta.dx).clamp(0.0, 1.0 - base.width),
          top: (base.top + delta.dy).clamp(0.0, 1.0 - base.height),
          width: base.width,
          height: base.height,
        );
      });
    } else {
      setState(() => _dragCurrent = local);
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_dragStart != null && _dragCurrent != null) {
      final rect = _rectFromDrag(_dragStart!, _dragCurrent!);
      setState(() {
        if (rect != null) _roi[_activeVital] = rect;
        _dragStart = null;
        _dragCurrent = null;
      });
    } else {
      setState(() {
        _moveBase = null;
        _moveStart = null;
      });
    }
  }

  Offset _localPos(Offset global) {
    final rb = _frameKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return global;
    return rb.globalToLocal(global);
  }

  Widget _legend() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: _editableVitals.map((vt) {
          final color = _vitalColors[vt]!;
          final hasZone = _roi[vt] != null;
          return Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: hasZone ? 0.4 : 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: color, width: 1.5),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _vitalLabels[vt]!,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      color: hasZone ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: hasZone ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _actionRow() {
    final hasZone = _roi[_activeVital] != null;
    final color = _vitalColors[_activeVital]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing: ${_vitalLabels[_activeVital]}',
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 13),
                ),
                Text(
                  hasZone
                      ? 'Zone defined. Drag to move it, or drag a new area to redraw.'
                      : 'No zone set. Drag on the camera frame to draw a zone.',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (hasZone)
            TextButton.icon(
              onPressed: () => setState(() => _roi[_activeVital] = null),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear Zone'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.critical,
              ),
            ),
        ],
      ),
    );
  }

  IconData _vitalIcon(VitalType vt) {
    switch (vt) {
      case VitalType.hr:
        return Icons.favorite_border;
      case VitalType.spo2:
        return Icons.water_drop_outlined;
      case VitalType.rr:
        return Icons.air;
      case VitalType.sbp:
        return Icons.speed_outlined;
      default:
        return Icons.monitor_heart_outlined;
    }
  }

  void _save() {
    widget.onSave(_roi);
    Navigator.pop(context);
  }
}

// ─── Custom Painter ───────────────────────────

class _RoiPainter extends CustomPainter {
  final Map<VitalType, RoiRect?> roi;
  final VitalType activeVital;
  final Map<VitalType, Color> colors;
  final Map<VitalType, String> labels;
  final Offset? dragStart;
  final Offset? dragCurrent;

  const _RoiPainter({
    required this.roi,
    required this.activeVital,
    required this.colors,
    required this.labels,
    this.dragStart,
    this.dragCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background: simulated dark monitor screen
    final bgPaint = Paint()..color = const Color(0xFF0D1117);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw a faint monitor screen simulation
    _drawMonitorSim(canvas, size);

    // Draw all defined zones (inactive first, active on top)
    for (final entry in roi.entries) {
      if (entry.key == activeVital) continue;
      if (entry.value == null) continue;
      _drawZone(canvas, size, entry.key, entry.value!, active: false);
    }

    // Draw active vital zone
    final activeRect = roi[activeVital];
    if (activeRect != null) {
      _drawZone(canvas, size, activeVital, activeRect, active: true);
    }

    // Draw drag preview
    if (dragStart != null && dragCurrent != null) {
      final a = dragStart!;
      final b = dragCurrent!;
      final r = Rect.fromPoints(a, b);
      final color = colors[activeVital]!;
      final dashPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      _drawDashedRect(canvas, r, dashPaint);
      canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.1));
    }
  }

  void _drawMonitorSim(Canvas canvas, Size size) {
    // Faint grid overlay to suggest a monitor display
    final gridPaint = Paint()
      ..color = const Color(0xFF1A2A1A)
      ..style = PaintingStyle.fill;

    // Simulated waveform area (left 60%)
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.02, size.height * 0.08, size.width * 0.56, size.height * 0.84),
      gridPaint,
    );

    // Simulated vital number panels (right 40%)
    final panelPaint = Paint()..color = const Color(0xFF0A1A10);
    final panelHeight = size.height * 0.19;
    final panelLeft = size.width * 0.62;
    final panelWidth = size.width * 0.36;
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(panelLeft, size.height * 0.05 + i * (panelHeight + size.height * 0.02), panelWidth, panelHeight),
        panelPaint,
      );
    }

    // Simulated waveform line
    final wavePaint = Paint()
      ..color = const Color(0xFF00FF41).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path();
    path.moveTo(size.width * 0.04, size.height * 0.45);
    for (double x = 0.04; x < 0.58; x += 0.02) {
      final y = 0.45 + 0.18 * (x * 13).remainder(1.0) * (x * 7).remainder(1.0);
      path.lineTo(size.width * x, size.height * y);
    }
    canvas.drawPath(path, wavePaint);

    // Labels hint
    _drawText(canvas, 'HR', Offset(size.width * 0.64, size.height * 0.07),
               const Color(0xFF00FF41), 9);
    _drawText(canvas, 'SpO₂', Offset(size.width * 0.64, size.height * 0.30),
               const Color(0xFF00BFFF), 9);
    _drawText(canvas, 'RR', Offset(size.width * 0.64, size.height * 0.52),
               const Color(0xFFFFFF00), 9);
    _drawText(canvas, 'BP', Offset(size.width * 0.64, size.height * 0.74),
               const Color(0xFFFF4500), 9);
  }

  void _drawZone(Canvas canvas, Size size, VitalType vt, RoiRect r, {required bool active}) {
    final color = colors[vt]!;
    final rect = Rect.fromLTWH(
      r.left * size.width,
      r.top * size.height,
      r.width * size.width,
      r.height * size.height,
    );

    // Fill
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: active ? 0.22 : 0.12));

    // Border
    canvas.drawRect(rect, Paint()
      ..color = color.withValues(alpha: active ? 1.0 : 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2.5 : 1.5);

    // Label
    _drawLabelPill(canvas, labels[vt]!, rect.topLeft + const Offset(4, 4), color);

    // Corner handles (active only)
    if (active) {
      _drawHandle(canvas, rect.topLeft, color);
      _drawHandle(canvas, rect.topRight, color);
      _drawHandle(canvas, rect.bottomLeft, color);
      _drawHandle(canvas, rect.bottomRight, color);
    }
  }

  void _drawHandle(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 5, Paint()..color = AppColors.surface);
    canvas.drawCircle(center, 5, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(center, 3, Paint()..color = color);
  }

  void _drawLabelPill(Canvas canvas, String text, Offset pos, Color color) {
    final tp = _buildTextPainter(text, color, 9);
    tp.layout();
    final pillRect = Rect.fromLTWH(pos.dx, pos.dy, tp.width + 8, tp.height + 4);
    canvas.drawRRect(
        RRect.fromRectAndRadius(pillRect, const Radius.circular(3)),
        Paint()..color = color.withValues(alpha: 0.85));
    tp.paint(canvas, pos + const Offset(4, 2));
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = _buildTextPainter(text, color, size);
    tp.layout();
    tp.paint(canvas, pos);
  }

  TextPainter _buildTextPainter(String text, Color color, double size) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    void drawDashedLine(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      double drawn = 0;
      while (drawn < total) {
        final end = drawn + dashLen;
        canvas.drawLine(
          a + dir * drawn,
          a + dir * (end < total ? end : total),
          paint,
        );
        drawn += dashLen + gapLen;
      }
    }
    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_RoiPainter old) =>
      old.roi != roi ||
      old.activeVital != activeVital ||
      old.dragStart != dragStart ||
      old.dragCurrent != dragCurrent;
}
