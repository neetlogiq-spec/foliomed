import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/monitor_vitals.dart';
import '../../providers/camera_provider.dart';
import '../../providers/monitor_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/monitor/alert_log.dart';
import '../../widgets/monitor/bp_card.dart';
import '../../widgets/monitor/comment_panel.dart';
import '../../widgets/monitor/edge_camera_viewer.dart';
import '../../widgets/monitor/threshold_panel.dart';
import '../../widgets/monitor/vital_card.dart';
import 'bedside_sender_screen.dart';
import 'vital_trends_screen.dart';

class PatientMonitorScreen extends StatelessWidget {
  final String patientId;
  const PatientMonitorScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorProvider>();
    context.watch<ThemeProvider>();
    final patient = monitor.patientById(patientId);

    if (patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient not found')),
        body: const Center(child: Text('Patient not found')),
      );
    }

    final sev = patient.worstSeverity;
    final sevColor = sev == 'critical'
        ? AppColors.critical
        : sev == 'warning'
            ? AppColors.warningColor
            : AppColors.stable;
    final alerts = monitor.alertsFor(patientId);
    final comments = monitor.commentsFor(patientId);
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Monitor', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: AppColors.primary)),
        actions: [
          TextButton.icon(
            onPressed: () => monitor.toggleSound(),
            icon: Icon(monitor.soundEnabled ? Icons.volume_up : Icons.volume_off, size: 18,
              color: monitor.soundEnabled ? AppColors.primary : AppColors.textSecondary),
            label: Text(monitor.soundEnabled ? 'Sound ON' : 'Sound OFF',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600,
                color: monitor.soundEnabled ? AppColors.primary : AppColors.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => _callWard(patient.dutyPhone),
              icon: const Icon(Icons.phone, size: 16),
              label: const Text('Call Ward'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stable,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Patient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.card,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${patient.name} · ${patient.gender} · ${patient.age}',
                        style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('${patient.diagnosis} · ${patient.support} · ${patient.bed} · ${patient.ward}',
                        style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sev == 'critical' ? '🔴 Critical' : sev == 'warning' ? '🟡 Watch' : '🟢 Stable',
                    style: GoogleFonts.dmSans(color: sevColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isWide
                ? _wideLayout(context, patient, alerts, comments, monitor)
                : _narrowLayout(context, patient, alerts, comments, monitor),
          ),
        ],
      ),
    );
  }

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
       defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux);

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
       defaultTargetPlatform == TargetPlatform.android);

  Widget _videoViewer(BuildContext context, patient) {
    if (_isDesktop) {
      // IP camera takes priority; fall back to Agora phone stream viewer
      final cameras = context.read<CameraProvider>().cameras;
      final hasCamera = cameras.any((c) =>
          (c.patientId == patientId || c.patientName == patient.name) &&
          c.isEnabled);
      if (hasCamera) {
        return EdgeCameraViewer(patientId: patientId, patientName: patient.name);
      }
    }
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.videocam_off, color: Colors.white30, size: 32),
          const SizedBox(height: 8),
          Text('No camera configured',
              style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _streamFromPhoneButton(BuildContext context, patient) {
    if (!_isMobile) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BedsideSenderScreen(
                patientId: patientId,
                patientName: patient.name,
                wardId: patient.ward,
              ),
            ),
          ),
          icon: const Icon(Icons.videocam, size: 18),
          label: Text('Stream from Phone',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context, patient, List alerts, List comments, MonitorProvider monitor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _videoViewer(context, patient),
                const SizedBox(height: 16),
                _vitalsHeader(context, patient),
                const SizedBox(height: 8),
                _vitalsGrid(patient),
                const SizedBox(height: 12),
                _actionButtons(context, patient, monitor),
                _streamFromPhoneButton(context, patient),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AlertLog(alerts: alerts.cast()),
                const SizedBox(height: 12),
                MonitorCommentPanel(
                  comments: comments.cast(),
                  onAdd: (text, type) => monitor.addComment(patient.id, text, type),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context, patient, List alerts, List comments, MonitorProvider monitor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _videoViewer(context, patient),
          const SizedBox(height: 16),
          _vitalsHeader(context, patient),
          const SizedBox(height: 8),
          _vitalsGrid(patient),
          const SizedBox(height: 12),
          _actionButtons(context, patient, monitor),
          _streamFromPhoneButton(context, patient),
          const SizedBox(height: 16),
          AlertLog(alerts: alerts.cast()),
          const SizedBox(height: 12),
          MonitorCommentPanel(
            comments: comments.cast(),
            onAdd: (text, type) => monitor.addComment(patient.id, text, type),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _vitalsHeader(BuildContext context, patient) {
    return Text('LIVE VITALS', style: GoogleFonts.dmSans(
      color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1));
  }

  Widget _actionButtons(BuildContext context, patient, MonitorProvider monitor) {
    final btnStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => VitalTrendsScreen(patientId: patientId, patientName: patient.name),
            )),
            icon: const Icon(Icons.show_chart, size: 18),
            label: Text('Trends', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
            style: btnStyle.copyWith(
              foregroundColor: WidgetStatePropertyAll(AppColors.primary),
              side: WidgetStatePropertyAll(BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openThresholds(context, patient, monitor),
            icon: const Icon(Icons.tune, size: 18),
            label: Text('Thresholds', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
            style: btnStyle.copyWith(
              foregroundColor: WidgetStatePropertyAll(AppColors.warningColor),
              side: WidgetStatePropertyAll(BorderSide(color: AppColors.warningColor, width: 1.5)),
            ),
          ),
        ),
      ],
    );
  }

  void _openThresholds(BuildContext context, patient, MonitorProvider monitor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Alert Thresholds — ${patient.name}',
                        style: GoogleFonts.dmSans(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ThresholdPanel(
                  patient: patient,
                  onSave: (patientId, changes) {
                    for (final entry in changes.entries) {
                      final vt  = entry.key;
                      final thr = entry.value;
                      if (thr.critLow  != null) monitor.setThreshold(patientId, vt, 'critLow',  thr.critLow!);
                      if (thr.critHigh != null) monitor.setThreshold(patientId, vt, 'critHigh', thr.critHigh!);
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vitalsGrid(patient) {
    // Camera-assigned patient with no reading yet — don't show fake numbers.
    if (patient.vitals.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 14),
            Text('Waiting for monitor readings…',
                style: GoogleFonts.dmSans(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'The camera is watching this bed. Vitals appear here after the AI reads the monitor — keep the monitor screen visible in the frame.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 500 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: [
          VitalCard(
            type: VitalType.hr,
            value: patient.vitals[VitalType.hr] ?? 0,
            threshold: patient.thresholds[VitalType.hr] ?? const VitalThreshold(),
          ),
          VitalCard(
            type: VitalType.spo2,
            value: patient.vitals[VitalType.spo2] ?? 0,
            threshold: patient.thresholds[VitalType.spo2] ?? const VitalThreshold(),
          ),
          VitalCard(
            type: VitalType.rr,
            value: patient.vitals[VitalType.rr] ?? 0,
            threshold: patient.thresholds[VitalType.rr] ?? const VitalThreshold(),
          ),
          BPCard(
            vitals: patient.vitals,
            thresholds: patient.thresholds,
          ),
        ],
      );
    });
  }

  void _callWard(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
