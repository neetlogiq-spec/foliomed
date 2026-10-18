import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/camera_config.dart';
import '../../providers/monitor_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────
//  Monitor Zones Editor
//  One camera often covers 2–3 beds. Draw a box
//  around each bedside monitor in the frame,
//  name it, and assign its patient. The AI reads
//  each zone separately for its own patient.
// ─────────────────────────────────────────────

const int kMaxMonitorZones = 3;

class MonitorZonesScreen extends StatefulWidget {
  final CameraConfig camera;
  final void Function(List<MonitorZone> monitors) onSave;

  const MonitorZonesScreen(
      {super.key, required this.camera, required this.onSave});

  @override
  State<MonitorZonesScreen> createState() => _MonitorZonesScreenState();
}

class _MonitorZonesScreenState extends State<MonitorZonesScreen> {
  late List<MonitorZone> _zones;
  int _active = 0;

  // Draw state
  Offset? _dragStart;
  Offset? _dragCurrent;

  // Move state
  RoiRect? _moveBase;
  Offset? _moveStart;

  final _frameKey = GlobalKey();

  static const _zoneColors = [
    Color(0xFF1976D2), // Monitor 1 — blue
    Color(0xFF00897B), // Monitor 2 — teal
    Color(0xFF7B1FA2), // Monitor 3 — purple
  ];

  @override
  void initState() {
    super.initState();
    _zones = List.of(widget.camera.monitors);
    if (_zones.isEmpty) {
      _zones.add(MonitorZone(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Monitor 1',
        rect: const RoiRect(left: 0.05, top: 0.15, width: 0.42, height: 0.6),
      ));
    }
  }

  Color get _activeColor => _zoneColors[_active % _zoneColors.length];

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

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Monitors in View — ${widget.camera.label}',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: GoogleFonts.dmSans(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          _instructions(),
          _zoneTabs(),
          Expanded(child: _frameArea()),
          _zoneDetails(),
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
          const Icon(Icons.touch_app_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Drag a box around each bedside monitor this camera can see '
              '(up to $kMaxMonitorZones). Then name it and pick which patient '
              'it belongs to — the AI reads each monitor separately.',
              style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneTabs() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < _zones.length; i++) _zoneTab(i),
          if (_zones.length < kMaxMonitorZones)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: OutlinedButton.icon(
                onPressed: _addZone,
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _zoneTab(int i) {
    final active = _active == i;
    final color = _zoneColors[i % _zoneColors.length];
    final z = _zones[i];
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _active = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
              Icon(Icons.monitor_outlined,
                  size: 18, color: active ? color : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                z.name.isEmpty ? 'Monitor ${i + 1}' : z.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? color : AppColors.textSecondary,
                ),
              ),
              if (z.patientName.isNotEmpty)
                Text(
                  z.patientName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                      fontSize: 9, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
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
                painter: _MonitorZonesPainter(
                  zones: _zones,
                  active: _active,
                  colors: _zoneColors,
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

  Widget _zoneDetails() {
    final monitor = context.watch<MonitorProvider>();
    final z = _zones[_active];
    final color = _activeColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('name_${z.id}'),
                  initialValue: z.name,
                  onChanged: (v) => _zones[_active] = z.copyWith(name: v),
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Monitor name',
                    labelStyle: GoogleFonts.dmSans(
                        color: AppColors.textSecondary, fontSize: 12),
                    prefixIcon:
                        Icon(Icons.monitor_outlined, size: 18, color: color),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('patient_${z.id}'),
                  initialValue: z.patientId.isEmpty ? null : z.patientId,
                  isExpanded: true,
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textPrimary),
                  dropdownColor: AppColors.card,
                  decoration: InputDecoration(
                    labelText: 'Patient',
                    labelStyle: GoogleFonts.dmSans(
                        color: AppColors.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.person_outline,
                        size: 18, color: AppColors.primary),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text('— none —',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                    for (final p in monitor.patients)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.name}${p.bed.isNotEmpty ? ' · ${p.bed}' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: (pid) {
                    final p = monitor.patients
                        .where((p) => p.id == pid)
                        .toList();
                    setState(() {
                      _zones[_active] = z.copyWith(
                        patientId: pid ?? '',
                        patientName: p.isEmpty ? '' : p.first.name,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Drag on the frame to redraw ${z.name.isEmpty ? "this zone" : z.name}, or drag the box to move it.',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
              if (_zones.length > 1)
                TextButton.icon(
                  onPressed: _removeActive,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _addZone() {
    if (_zones.length >= kMaxMonitorZones) return;
    final i = _zones.length;
    setState(() {
      _zones.add(MonitorZone(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        name: 'Monitor ${i + 1}',
        rect: RoiRect(
            left: (0.05 + i * 0.32).clamp(0.0, 0.6),
            top: 0.15,
            width: 0.3,
            height: 0.6),
      ));
      _active = i;
    });
  }

  void _removeActive() {
    setState(() {
      _zones.removeAt(_active);
      if (_active >= _zones.length) _active = _zones.length - 1;
    });
  }

  bool _hitActive(Offset local) {
    final rect = _zones[_active].rect;
    final sz = _frameSize;
    final r = Rect.fromLTWH(
      rect.left * sz.width,
      rect.top * sz.height,
      rect.width * sz.width,
      rect.height * sz.height,
    ).inflate(12);
    return r.contains(local);
  }

  void _onPanStart(DragStartDetails d) {
    final local = _localPos(d.globalPosition);
    if (_hitActive(local)) {
      setState(() {
        _moveBase = _zones[_active].rect;
        _moveStart = local;
        _dragStart = null;
        _dragCurrent = null;
      });
    } else {
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
      final delta = _toNorm(local) - _toNorm(_moveStart!);
      final base = _moveBase!;
      setState(() {
        _zones[_active] = _zones[_active].copyWith(
          rect: RoiRect(
            left: (base.left + delta.dx).clamp(0.0, 1.0 - base.width),
            top: (base.top + delta.dy).clamp(0.0, 1.0 - base.height),
            width: base.width,
            height: base.height,
          ),
        );
      });
    } else {
      setState(() => _dragCurrent = local);
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_dragStart != null && _dragCurrent != null) {
      final na = _toNorm(_dragStart!);
      final nb = _toNorm(_dragCurrent!);
      final left = na.dx < nb.dx ? na.dx : nb.dx;
      final top = na.dy < nb.dy ? na.dy : nb.dy;
      final w = (nb.dx - na.dx).abs();
      final h = (nb.dy - na.dy).abs();
      setState(() {
        if (w >= 0.05 && h >= 0.05) {
          _zones[_active] = _zones[_active].copyWith(
              rect: RoiRect(left: left, top: top, width: w, height: h));
        }
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

  void _save() {
    widget.onSave(List.of(_zones));
    Navigator.pop(context);
  }
}

// ─── Painter ──────────────────────────────────

class _MonitorZonesPainter extends CustomPainter {
  final List<MonitorZone> zones;
  final int active;
  final List<Color> colors;
  final Offset? dragStart;
  final Offset? dragCurrent;

  const _MonitorZonesPainter({
    required this.zones,
    required this.active,
    required this.colors,
    this.dragStart,
    this.dragCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0D1117));

    // Simulated ward view: 3 faint monitor screens side by side.
    for (int i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(size.width * (0.06 + i * 0.32),
          size.height * 0.22, size.width * 0.26, size.height * 0.45);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = const Color(0xFF12241A));
      _text(canvas, 'bed ${i + 1}', r.topLeft + const Offset(4, 4),
          const Color(0xFF3A5A46), 8);
    }

    for (var i = 0; i < zones.length; i++) {
      if (i == active) continue;
      _drawZone(canvas, size, zones[i], colors[i % colors.length],
          active: false);
    }
    if (active < zones.length) {
      _drawZone(canvas, size, zones[active],
          colors[active % colors.length],
          active: true);
    }

    if (dragStart != null && dragCurrent != null) {
      final r = Rect.fromPoints(dragStart!, dragCurrent!);
      final color = colors[active % colors.length];
      canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.1));
      canvas.drawRect(
          r,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void _drawZone(Canvas canvas, Size size, MonitorZone z, Color color,
      {required bool active}) {
    final rect = Rect.fromLTWH(
      z.rect.left * size.width,
      z.rect.top * size.height,
      z.rect.width * size.width,
      z.rect.height * size.height,
    );
    canvas.drawRect(
        rect, Paint()..color = color.withValues(alpha: active ? 0.2 : 0.1));
    canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: active ? 1.0 : 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.5 : 1.5);

    final label = z.patientName.isEmpty
        ? z.name
        : '${z.name} · ${z.patientName}';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pos = rect.topLeft + const Offset(4, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(pos.dx, pos.dy, tp.width + 8, tp.height + 4),
          const Radius.circular(3)),
      Paint()..color = color.withValues(alpha: 0.85),
    );
    tp.paint(canvas, pos + const Offset(4, 2));
  }

  void _text(
      Canvas canvas, String s, Offset pos, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_MonitorZonesPainter old) => true;
}
