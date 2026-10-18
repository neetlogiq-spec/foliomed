import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';

import '../../models/camera_config.dart';
import '../../models/monitored_patient.dart';
import '../../models/monitor_vitals.dart';
import '../../providers/camera_provider.dart';
import '../../providers/monitor_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/patient_service.dart';
import '../../services/vlm_server_manager.dart';
import '../../utils/app_theme.dart';
import 'edge_setup_screen.dart';
import 'monitor_zones_screen.dart';
import 'patient_monitor_screen.dart';
import 'roi_editor_screen.dart';

// ─────────────────────────────────────────────
//  FolioMed Edge Hub
//  Ward dashboard (live bed tiles) + camera
//  management — add, edit, toggle, ROI, delete.
// ─────────────────────────────────────────────

class FolioMedEdgeScreen extends StatefulWidget {
  const FolioMedEdgeScreen({super.key});

  @override
  State<FolioMedEdgeScreen> createState() => _FolioMedEdgeScreenState();
}

class _FolioMedEdgeScreenState extends State<FolioMedEdgeScreen> {
  bool _dashboard = true;

  @override
  void initState() {
    super.initState();
    // Boot the embedded AI engine with the app — no separate server.
    VlmServerManager.instance.ensureRunning();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final cameras = context.watch<CameraProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Row(
          children: [
            const Icon(Icons.settings_input_antenna,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('FolioMed Edge',
                style: appText(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 18)),
          ],
        ),
        actions: [
          _viewToggle(),
          const SizedBox(width: 8),
          if (!kIsWeb && Platform.isMacOS)
            TextButton.icon(
              onPressed: () => _setupWebcamTest(context),
              icon: const Icon(Icons.photo_camera_front_outlined, size: 18),
              label: const Text('Webcam Test'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: appText(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          TextButton.icon(
            onPressed: () => _openSetup(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Camera'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: appText(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
      body: _dashboard
          ? _EdgeDashboard(onAddCamera: () => _openSetup(context))
          : (cameras.cameras.isEmpty
              ? _emptyState(context)
              : _cameraList(context, cameras)),
      floatingActionButton: !_dashboard && cameras.cameras.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'edge_add_camera',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add Camera'),
              onPressed: () => _openSetup(context),
            )
          : null,
    );
  }

  Widget _viewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleChip('Dashboard', Icons.grid_view_rounded, true),
          _toggleChip('Cameras', Icons.videocam_outlined, false),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, IconData icon, bool forDashboard) {
    final selected = _dashboard == forDashboard;
    final fg = selected ? Colors.white : AppColors.textSecondary;
    return InkWell(
      onTap: () => setState(() => _dashboard = forDashboard),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: appText(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg)),
          ],
        ),
      ),
    );
  }

  void _openSetup(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const EdgeSetupScreen()));
  }

  /// Webcam test phase — point the laptop's camera at a monitor (or a
  /// monitor photo) and run the full capture → AI pipeline without any
  /// IP-camera hardware.
  Future<void> _setupWebcamTest(BuildContext context) async {
    final monitor = context.read<MonitorProvider>();
    final cp = context.read<CameraProvider>();
    final patients = monitor.patients;

    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No monitored patients yet — add a patient first.')));
      return;
    }

    final selected = await showDialog<MonitoredPatient>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Row(
          children: [
            Icon(Icons.photo_camera_front_outlined,
                color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Webcam Test',
                style: appText(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uses this laptop\'s camera as a test bedside camera. Point '
                'it at a patient monitor (or a monitor photo on your phone) '
                'and the AI will read the vitals.\n\nWhich patient should '
                'the readings go to?',
                style: appText(
                    color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in patients)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.person_outline,
                            color: AppColors.primary, size: 20),
                        title: Text(p.name,
                            style: appText(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        subtitle: p.bed.isEmpty
                            ? null
                            : Text(p.bed,
                                style: appText(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                        onTap: () => Navigator.pop(ctx, p),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;

    const camId = 'webcam_test';
    final existing = cp.cameras.where((c) => c.id == camId).toList();
    if (existing.isEmpty) {
      cp.add(CameraConfig(
        id: camId,
        label: 'Laptop Webcam (test)',
        brand: CameraConfig.webcamBrand,
        ip: 'built-in',
        password: '',
        patientId: selected.id,
        patientName: selected.name,
        bedLabel: selected.bed,
      ));
    } else {
      cp.update(existing.first.copyWith(
        patientId: selected.id,
        patientName: selected.name,
        bedLabel: selected.bed,
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Webcam test ready — open ${selected.name} in the Monitor tab. '
          'macOS will ask for camera permission on first use.'),
      duration: const Duration(seconds: 5),
    ));
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.videocam_off_outlined,
                  color: AppColors.primary, size: 38),
            ),
            const SizedBox(height: 20),
            Text('No cameras configured',
                style: appText(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Connect an IP CCTV camera to automatically read '
              'vitals from your bedside monitors.',
              textAlign: TextAlign.center,
              style: appText(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openSetup(context),
                icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                label: Text('Set Up First Camera',
                    style: appText(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _HowItWorksCard(),
          ],
        ),
      ),
    );
  }

  Widget _cameraList(BuildContext context, CameraProvider cameras) {
    final list = cameras.cameras;
    return CustomScrollView(
      slivers: [
        // Stats header
        SliverToBoxAdapter(
          child: _StatsHeader(cameras: cameras),
        ),

        // How it works (collapsed)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _HowItWorksCard(collapsed: true),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CameraCard(camera: list[i]),
              childCount: list.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ─── Ward Dashboard (station view) ────────────

class _EdgeDashboard extends StatelessWidget {
  final VoidCallback onAddCamera;
  const _EdgeDashboard({required this.onAddCamera});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final monitor = context.watch<MonitorProvider>();
    final cameras = context.watch<CameraProvider>();
    final patients = monitor.patients;
    // Camera-assigned patients show real readings only — no simulation.
    monitor.syncLiveOnly({
      for (final p in patients)
        if (cameras.cameras.any((c) => c.watchesPatient(p.id, p.name))) p.id,
    });

    // Most common ward name among monitored patients, for the header.
    String wardName = 'Ward Dashboard';
    if (patients.isNotEmpty) {
      final counts = <String, int>{};
      for (final p in patients) {
        if (p.ward.isEmpty) continue;
        counts[p.ward] = (counts[p.ward] ?? 0) + 1;
      }
      if (counts.isNotEmpty) {
        wardName = (counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('FolioMed Edge · $wardName',
                    overflow: TextOverflow.ellipsis,
                    style: appText(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
              ),
              const _AiEngineChip(),
              const SizedBox(width: 8),
              _LiveCamerasChip(activeCount: cameras.activeCount),
            ],
          ),
        ),
        Expanded(
          child: patients.isEmpty
              ? Center(
                  child: Text(
                    'No monitored patients yet.\nAdd patients in the Monitor tab of the FolioMed app.',
                    textAlign: TextAlign.center,
                    style: appText(
                        color: AppColors.textSecondary, fontSize: 13, height: 1.6),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 130,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: patients.length + 1,
                  itemBuilder: (context, i) {
                    if (i == patients.length) {
                      return _AddCameraTile(onTap: onAddCamera);
                    }
                    final p = patients[i];
                    final hasCamera = cameras.cameras
                        .any((c) => c.watchesPatient(p.id, p.name));
                    return _BedTile(patient: p, hasCamera: hasCamera);
                  },
                ),
        ),
      ],
    );
  }
}

class _AiEngineChip extends StatelessWidget {
  const _AiEngineChip();

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return ValueListenableBuilder<VlmEngineStatus>(
      valueListenable: VlmServerManager.instance.status,
      builder: (context, status, _) {
        final (label, color, pulsing) = switch (status) {
          VlmEngineStatus.running ||
          VlmEngineStatus.external =>
            ('AI ONLINE', AppColors.accent, false),
          VlmEngineStatus.starting =>
            ('AI STARTING…', AppColors.warningColor, true),
          VlmEngineStatus.error => ('AI ERROR', AppColors.danger, false),
          VlmEngineStatus.off => ('AI OFF', AppColors.textSecondary, false),
        };
        return Tooltip(
          message: status == VlmEngineStatus.error
              ? (VlmServerManager.instance.errorDetail ?? 'AI engine error')
              : 'Vitals read by the built-in FolioMed Vision AI',
          child: InkWell(
            onTap: status == VlmEngineStatus.error ||
                    status == VlmEngineStatus.off
                ? () => VlmServerManager.instance.ensureRunning()
                : null,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                border: Border.all(color: color.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pulsing) ...[
                    _PulsingDot(color: color),
                    const SizedBox(width: 6),
                  ] else ...[
                    Icon(Icons.auto_awesome, size: 10, color: color),
                    const SizedBox(width: 5),
                  ],
                  Text(label,
                      style: appText(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: color)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveCamerasChip extends StatelessWidget {
  final int activeCount;
  const _LiveCamerasChip({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final live = activeCount > 0;
    final color = live ? AppColors.danger : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) const _PulsingDot(color: AppColors.danger),
          if (live) const SizedBox(width: 6),
          Text(
            live
                ? '$activeCount CAMERA${activeCount == 1 ? '' : 'S'} LIVE'
                : 'NO CAMERAS',
            style: appText(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: live ? AppColors.danger : AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 6,
        height: 6,
        decoration:
            BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _BedTile extends StatelessWidget {
  final MonitoredPatient patient;
  final bool hasCamera;
  const _BedTile({required this.patient, required this.hasCamera});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final sev = patient.worstSeverity;
    final isCrit = sev == 'critical';
    final isWarn = sev == 'warning';
    final borderColor = isCrit
        ? AppColors.danger.withValues(alpha: 0.55)
        : isWarn
            ? AppColors.warningColor.withValues(alpha: 0.45)
            : AppColors.divider;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PatientMonitorScreen(patientId: patient.id)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: isCrit
              ? [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.18),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (patient.bed.isNotEmpty) ...[
                  Text(patient.bed,
                      style: appText(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(patient.name,
                      overflow: TextOverflow.ellipsis,
                      style: appText(
                          color: AppColors.textSecondary, fontSize: 11)),
                ),
                if (hasCamera)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.videocam,
                        size: 12, color: AppColors.accent),
                  ),
                _sevChip(sev),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _vital('HR', patient.vitals[VitalType.hr],
                    _vitalColor(VitalType.hr)),
                _vital('SpO₂', patient.vitals[VitalType.spo2],
                    _vitalColor(VitalType.spo2)),
                _vital('RR', patient.vitals[VitalType.rr],
                    _vitalColor(VitalType.rr)),
                _bpVital(),
              ],
            ),
            if (isCrit) ...[
              const SizedBox(height: 8),
              Text('⚠ ${_critLabel()}',
                  style: appText(
                      color: AppColors.danger,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ],
          ],
        ),
      ),
    );
  }

  Color _vitalColor(VitalType vt) {
    final t = patient.thresholds[vt];
    final v = patient.vitals[vt];
    if (t == null || v == null) return AppColors.textPrimary;
    switch (t.severity(v)) {
      case 'critical':
        return AppColors.danger;
      case 'warning':
        return AppColors.warningColor;
      default:
        return AppColors.textPrimary;
    }
  }

  String _critLabel() {
    const labels = {
      VitalType.hr: 'HR',
      VitalType.spo2: 'SpO₂',
      VitalType.rr: 'RR',
      VitalType.sbp: 'BP',
      VitalType.dbp: 'BP',
      VitalType.map: 'MAP',
    };
    for (final vt in labels.keys) {
      final t = patient.thresholds[vt];
      final v = patient.vitals[vt];
      if (t != null && v != null && t.severity(v) == 'critical') {
        return '${labels[vt]} CRITICAL';
      }
    }
    return 'ALERT';
  }

  Widget _sevChip(String sev) {
    final waiting = patient.vitals.isEmpty;
    final label = waiting
        ? 'WAITING'
        : sev == 'critical'
            ? 'CRIT'
            : sev == 'warning'
                ? 'WARN'
                : 'STABLE';
    final color = waiting
        ? AppColors.textSecondary
        : sev == 'critical'
            ? AppColors.danger
            : sev == 'warning'
                ? AppColors.warningColor
                : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: appText(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: color)),
    );
  }

  Widget _vital(String label, double? value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: appText(
                  color: AppColors.textSecondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600)),
          Text(value == null ? '--' : '${value.round()}',
              style: appText(
                  color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _bpVital() {
    final sbp = patient.vitals[VitalType.sbp];
    final dbp = patient.vitals[VitalType.dbp];
    final sbpColor = _vitalColor(VitalType.sbp);
    final dbpColor = _vitalColor(VitalType.dbp);
    final worst = sbpColor == AppColors.danger || dbpColor == AppColors.danger
        ? AppColors.danger
        : sbpColor == AppColors.warningColor || dbpColor == AppColors.warningColor
            ? AppColors.warningColor
            : AppColors.textPrimary;
    final text = (sbp == null || dbp == null)
        ? '--'
        : '${sbp.round()}/${dbp.round()}';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BP',
              style: appText(
                  color: AppColors.textSecondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600)),
          Text(text,
              style: appText(
                  color: worst, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _AddCameraTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCameraTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.divider,
            width: 1.4,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Add camera',
                  style: appText(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stats Header ─────────────────────────────

class _StatsHeader extends StatelessWidget {
  final CameraProvider cameras;
  const _StatsHeader({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A5C8A), Color(0xFF0E7C5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _chip('${cameras.cameras.length}', 'Total'),
          _chip('${cameras.activeCount}', 'Active'),
          _chip('${cameras.withRoiCount}', 'ROI Set'),
          _chip('${cameras.cameras.length - cameras.withRoiCount}', 'ROI Needed'),
        ],
      ),
    );
  }

  Widget _chip(String num, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(num,
              style: appText(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: appText(
                  color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Camera Card ──────────────────────────────

class _CameraCard extends StatelessWidget {
  final CameraConfig camera;
  const _CameraCard({required this.camera});

  @override
  Widget build(BuildContext context) {
    final cp = context.read<CameraProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Main info row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Camera icon with brand color
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (camera.isEnabled ? AppColors.primary : AppColors.textSecondary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.videocam_outlined,
                    color: camera.isEnabled ? AppColors.primary : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              camera.label.isEmpty ? 'Unnamed Camera' : camera.label,
                              style: appText(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontSize: 14),
                            ),
                          ),
                          _statusPill(camera.isEnabled),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${camera.brand} · ${camera.ip}:${camera.port}',
                        style: appText(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                      if (camera.patientName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(camera.patientName,
                                style: appText(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            if (camera.bedLabel.isNotEmpty) ...[
                              Text(' · ${camera.bedLabel}',
                                  style: appText(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                            ],
                          ],
                        ),
                      ],
                      if (camera.hasMonitorZones) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final m in camera.monitors)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  m.patientName.isEmpty
                                      ? m.name
                                      : '${m.name} → ${m.patientName}',
                                  style: appText(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ROI zones row
          _roiZonesRow(context, camera, cp),

          // Actions row
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                _actionBtn(
                  context,
                  icon: Icons.crop_free,
                  label: camera.hasRoi ? 'Edit Zones' : 'Define Zones',
                  color: camera.hasRoi ? AppColors.stable : AppColors.warningColor,
                  onTap: () => _openRoiEditor(context, camera, cp),
                ),
                _divider(),
                _actionBtn(
                  context,
                  icon: Icons.monitor_outlined,
                  label: camera.hasMonitorZones
                      ? 'Monitors (${camera.monitors.length})'
                      : 'Monitors',
                  color: camera.hasMonitorZones
                      ? AppColors.stable
                      : AppColors.primary,
                  onTap: () => _openMonitorZones(context, camera, cp),
                ),
                _divider(),
                _actionBtn(
                  context,
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: AppColors.primary,
                  onTap: () => _openEdit(context, camera, cp),
                ),
                _divider(),
                _actionBtn(
                  context,
                  icon: Icons.cast_outlined,
                  label: 'Remote',
                  color: const Color(0xFF7B1FA2),
                  onTap: () => _setRemoteUrl(context, camera),
                ),
                _divider(),
                _actionBtn(
                  context,
                  icon: camera.isEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  label: camera.isEnabled ? 'Pause' : 'Enable',
                  color: AppColors.textSecondary,
                  onTap: () => cp.toggleEnabled(camera.id),
                ),
                _divider(),
                _actionBtn(
                  context,
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: AppColors.danger,
                  onTap: () => _confirmDelete(context, camera, cp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roiZonesRow(BuildContext context, CameraConfig cam, CameraProvider cp) {
    if (!cam.hasRoi) {
      return GestureDetector(
        onTap: () => _openRoiEditor(context, cam, cp),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warningColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.warningColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  size: 14, color: AppColors.warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No vital zones defined — tap to draw zones for auto-reading',
                  style: appText(
                      color: AppColors.warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppColors.warningColor),
            ],
          ),
        ),
      );
    }

    const vitalColors = {
      VitalType.hr:   Color(0xFFE53935),
      VitalType.spo2: Color(0xFF1976D2),
      VitalType.rr:   Color(0xFF388E3C),
      VitalType.sbp:  Color(0xFF7B1FA2),
    };
    const vitalLabels = {
      VitalType.hr:   'HR',
      VitalType.spo2: 'SpO₂',
      VitalType.rr:   'RR',
      VitalType.sbp:  'BP',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Icon(Icons.crop_free, size: 13, color: AppColors.stable),
          const SizedBox(width: 6),
          Text('Zones: ',
              style: appText(
                  color: AppColors.textSecondary, fontSize: 11)),
          Expanded(
            child: Wrap(
              spacing: 4,
              children: [
                VitalType.hr, VitalType.spo2, VitalType.rr, VitalType.sbp,
              ].map((vt) {
                final defined = cam.roi.containsKey(vt);
                final color = vitalColors[vt]!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: defined ? color.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: defined ? color : AppColors.divider),
                  ),
                  child: Text(
                    vitalLabels[vt]!,
                    style: appText(
                        fontSize: 10,
                        color: defined ? color : AppColors.textSecondary,
                        fontWeight:
                            defined ? FontWeight.w700 : FontWeight.w400),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (enabled ? AppColors.stable : AppColors.textSecondary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: enabled ? AppColors.stable : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            enabled ? 'Active' : 'Paused',
            style: appText(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: enabled ? AppColors.stable : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(label,
                  style: appText(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: AppColors.divider);

  Future<void> _setRemoteUrl(BuildContext context, CameraConfig cam) async {
    if (cam.patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assign this camera to a patient first (Edit → patient).')),
      );
      return;
    }
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remote Stream URL',
            style: appText(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste the HLS URL from your Cloudflare tunnel + MediaMTX.\n\n'
              'Format: https://your-tunnel.trycloudflare.com/stream/index.m3u8',
              style: appText(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: appText(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://…/stream/index.m3u8',
                hintStyle: appText(color: AppColors.textSecondary),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('Clear URL', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (url == null) return;
    try {
      await PatientService().saveHlsUrl(cam.patientId, url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(url.isEmpty ? 'Remote URL cleared.' : 'Remote stream URL saved.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _openMonitorZones(
      BuildContext context, CameraConfig cam, CameraProvider cp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonitorZonesScreen(
          camera: cam,
          onSave: (monitors) => cp.update(cam.copyWith(monitors: monitors)),
        ),
      ),
    );
  }

  void _openRoiEditor(BuildContext context, CameraConfig cam, CameraProvider cp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoiEditorScreen(
          camera: cam,
          onSave: (updates) => cp.saveRoi(cam.id, updates),
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, CameraConfig cam, CameraProvider cp) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _EditCameraSheet(camera: cam, onSave: cp.update)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, CameraConfig cam, CameraProvider cp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete camera?',
            style: appText(fontWeight: FontWeight.w700)),
        content: Text(
            'This will remove "${cam.label.isEmpty ? "Unnamed Camera" : cam.label}" '
            'and all its zone definitions.',
            style: appText()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) cp.remove(cam.id);
  }
}

// ─── Edit Camera Sheet ────────────────────────

class _EditCameraSheet extends StatefulWidget {
  final CameraConfig camera;
  final void Function(CameraConfig) onSave;
  const _EditCameraSheet({required this.camera, required this.onSave});

  @override
  State<_EditCameraSheet> createState() => _EditCameraSheetState();
}

class _EditCameraSheetState extends State<_EditCameraSheet> {
  late final TextEditingController _label;
  late final TextEditingController _ip;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _bed;
  bool _passVisible = false;

  @override
  void initState() {
    super.initState();
    final c = widget.camera;
    _label = TextEditingController(text: c.label);
    _ip = TextEditingController(text: c.ip);
    _port = TextEditingController(text: '${c.port}');
    _user = TextEditingController(text: c.username);
    _pass = TextEditingController(text: c.password);
    _bed = TextEditingController(text: c.bedLabel);
  }

  @override
  void dispose() {
    for (final c in [_label, _ip, _port, _user, _pass, _bed]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        title: Text('Edit Camera',
            style: appText(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: appText(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field('Camera Label', _label, Icons.label_outline),
            const SizedBox(height: 12),
            _field('IP Address', _ip, Icons.router_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _field('Port', _port, Icons.settings_ethernet,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _field('Username', _user, Icons.person_outline),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: !_passVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_passVisible ? Icons.visibility_off : Icons.visibility,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _passVisible = !_passVisible),
                ),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                labelStyle: appText(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            _field('Bed / Location', _bed, Icons.bed_outlined),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: appText(color: AppColors.textSecondary),
      ),
    );
  }

  void _save() {
    widget.onSave(widget.camera.copyWith(
      label: _label.text.trim(),
      ip: _ip.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 554,
      username: _user.text.trim(),
      password: _pass.text,
      bedLabel: _bed.text.trim(),
    ));
    Navigator.pop(context);
  }
}

// ─── How It Works Card ─────────────────────────

class _HowItWorksCard extends StatefulWidget {
  final bool collapsed;
  const _HowItWorksCard({this.collapsed = false});

  @override
  State<_HowItWorksCard> createState() => _HowItWorksCardState();
}

class _HowItWorksCardState extends State<_HowItWorksCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.collapsed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('How FolioMed Edge works',
                        style: appText(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: 13)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _step(Icons.videocam_outlined, 'Camera captures',
                      'CCTV camera streams RTSP video of the bedside monitor screen'),
                  _step(Icons.crop_free, 'Zones define where',
                      'You draw boxes around each vital number on the monitor screen'),
                  _step(Icons.computer, 'Edge PC processes',
                      'This PC (FolioMed Edge) captures a frame every 30 seconds, crops the zones'),
                  _step(Icons.cloud_upload_outlined, 'Cloud reads the numbers',
                      'Cropped images go to Cloud Vision API → extracts vital values'),
                  _step(Icons.monitor_heart_outlined, 'FolioMed shows results',
                      'Values appear in your Monitor dashboard — no manual charting needed'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _step(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: appText(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 12)),
                Text(body,
                    style: appText(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
