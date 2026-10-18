import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';

import '../../models/monitor_alert.dart';
import '../../models/monitor_comment.dart';
import '../../models/monitor_vitals.dart';
import '../../models/monitored_patient.dart';
import '../../providers/camera_provider.dart';
import '../../providers/monitor_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/support_action.dart';
import '../subscription/paywall_screen.dart';
import 'bedside_sender_screen.dart';
import 'patient_monitor_screen.dart';
import 'foliomed_edge_screen.dart';
import '../../widgets/app_sheet.dart';

class MonitorDashboardScreen extends StatelessWidget {
  const MonitorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();

    if (!sub.isPro) {
      return _lockedState(context);
    }

    return _dashboard(context);
  }

  Widget _lockedState(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Monitor', style: appText(fontWeight: FontWeight.w800)),
        actions: const [SupportAppBarAction()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.monitor_heart, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Live Patient Monitoring',
                style: appText(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Watch your patients\' vitals in real time.\nGet alerted when thresholds are breached.',
                textAlign: TextAlign.center,
                style: appText(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  ),
                  icon: const Icon(Icons.star, size: 20),
                  label: const Text('Upgrade to FolioMed Pro'),
                  style: ElevatedButton.styleFrom(
                    textStyle: appText(fontSize: 15, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboard(BuildContext context) {
    final monitor = context.watch<MonitorProvider>();
    final cameraProv = context.watch<CameraProvider>();
    context.watch<ThemeProvider>();
    final patients = monitor.patients;
    // Camera-assigned patients show real readings only — no simulation.
    monitor.syncLiveOnly({
      for (final p in patients)
        if (cameraProv.cameras.any((c) => c.watchesPatient(p.id, p.name)))
          p.id,
    });
    final wardActivity = _buildWardActivity(monitor, patients);
    final critCount = patients.where((p) => p.worstSeverity == 'critical').length;
    final warnCount = patients.where((p) => p.worstSeverity == 'warning').length;
    final stableCount = patients.where((p) => p.worstSeverity == 'stable').length;
    final critAlerts = monitor.alerts.where((a) => a.severity == 'critical').length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bedside_cam_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.videocam),
        label: const Text('Bedside Camera'),
        onPressed: () => _showBedsideSetup(context, patients),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.appBarBg,
            title: Row(
              children: [
                Text('Monitor', style: appText(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('PRO', style: appText(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ),
              ],
            ),
            actions: [
              if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.linux))
                IconButton(
                  icon: const Icon(Icons.settings_input_antenna, size: 22),
                  color: AppColors.textSecondary,
                  tooltip: 'FolioMed Edge',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FolioMedEdgeScreen())),
                ),
              Stack(
                children: [
                  IconButton(icon: Icon(Icons.notifications_outlined, color: AppColors.textSecondary), onPressed: () {}),
                  if (critAlerts > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                        child: Text('$critAlerts', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SupportAppBarAction(),
            ],
          ),

          // Demo / dev mode disclaimer
          const SliverToBoxAdapter(child: _MonitorDevBanner()),

          // Stats row
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                  _statChip('${patients.length}', 'Patients', Colors.white),
                  if (critCount > 0) _statChip('$critCount', 'Critical', AppColors.danger),
                  if (warnCount > 0) _statChip('$warnCount', 'Watch', AppColors.warning),
                  _statChip('$stableCount', 'Stable', AppColors.accent),
                ],
              ),
            ),
          ),

          // Edge cameras section (desktop only)
          if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux))
            SliverToBoxAdapter(
              child: _EdgeSection(context: context),
            ),

          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Monitored Patients', style: appText(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          // Patient cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _patientCard(context, patients[index], monitor),
                childCount: patients.length,
              ),
            ),
          ),

          // Ward Activity — alerts, orders & notes grouped per patient
          if (wardActivity.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.space_dashboard_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Ward Activity', style: appText(
                      color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('alerts · orders · notes, per patient',
                        overflow: TextOverflow.ellipsis,
                        style: appText(
                          color: AppColors.textSecondary, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _PatientActivityCard(activity: wardActivity[index]),
                  childCount: wardActivity.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
          // Lets the last card scroll clear of the translucent tab bar.
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String num, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(num, style: appText(color: color == Colors.white ? Colors.white : color, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: appText(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _patientCard(BuildContext context, MonitoredPatient p, MonitorProvider monitor) {
    final waiting = p.vitals.isEmpty;
    final sev = p.worstSeverity;
    final sevColor = waiting
        ? AppColors.textSecondary
        : sev == 'critical' ? AppColors.danger : sev == 'warning' ? AppColors.warning : AppColors.accent;
    final alerts = monitor.alertsFor(p.id);
    final lastAlert = alerts.isNotEmpty ? alerts.first : null;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientMonitorScreen(patientId: p.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: sevColor, width: 4)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: appText(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('${p.gender} · ${p.age} · ${p.ward}', style: appText(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: sevColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    waiting
                        ? 'Waiting'
                        : sev == 'critical' ? 'Critical' : sev == 'warning' ? 'Watch' : 'Stable',
                    style: appText(color: sevColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${p.diagnosis} · ${p.support} · ${p.bed}', style: appText(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 10),
            if (waiting)
              Row(
                children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator.adaptive(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary.withValues(alpha: 0.6))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Waiting for monitor readings from the camera…',
                        style: appText(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              )
            else
              Row(
                children: [
                  _miniVital('HR', p.vitals[VitalType.hr]?.round().toString() ?? '-', p.thresholds[VitalType.hr]?.severity(p.vitals[VitalType.hr] ?? 0) ?? 'stable'),
                  _miniVital('SpO₂', '${p.vitals[VitalType.spo2]?.round() ?? '-'}%', p.thresholds[VitalType.spo2]?.severity(p.vitals[VitalType.spo2] ?? 0) ?? 'stable'),
                  _miniVital('RR', p.vitals[VitalType.rr]?.round().toString() ?? '-', p.thresholds[VitalType.rr]?.severity(p.vitals[VitalType.rr] ?? 0) ?? 'stable'),
                  _miniVitalBP(p),
                ],
              ),
            if (lastAlert != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber, size: 12, color: lastAlert.severity == 'critical' ? AppColors.danger : AppColors.warning),
                  const SizedBox(width: 4),
                  Expanded(child: Text(lastAlert.message, style: appText(color: lastAlert.severity == 'critical' ? AppColors.danger : AppColors.warning, fontSize: 11), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text('Tap to monitor →', style: appText(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _miniVital(String label, String value, String sev) {
    final color = sev == 'critical' ? AppColors.danger : sev == 'warning' ? AppColors.warning : AppColors.textPrimary;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: appText(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: appText(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  void _showBedsideSetup(BuildContext context, List<MonitoredPatient> patients) {
    showAppSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set up bedside camera', style: appText(
              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Select a patient to start streaming vitals from their bedside monitor.',
              style: appText(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ...patients.map((p) => ListTile(
              leading: Icon(Icons.person, color: AppColors.primary),
              title: Text(p.name, style: appText(fontWeight: FontWeight.w600)),
              subtitle: Text('${p.ward} · ${p.bed}', style: appText(fontSize: 12)),
              trailing: const Icon(Icons.videocam, color: AppColors.accent),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BedsideSenderScreen(
                    patientId: p.id,
                    patientName: p.name,
                    wardId: p.wardId,
                  ),
                ));
              },
            )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _miniVitalBP(MonitoredPatient p) {
    final sbp = p.vitals[VitalType.sbp]?.round() ?? 0;
    final dbp = p.vitals[VitalType.dbp]?.round() ?? 0;
    final map = p.vitals[VitalType.map]?.round() ?? 0;
    String bpSev = 'stable';
    for (final vt in [VitalType.sbp, VitalType.dbp, VitalType.map]) {
      final s = p.thresholds[vt]?.severity(p.vitals[vt] ?? 0) ?? 'stable';
      if (s == 'critical') { bpSev = 'critical'; break; }
      if (s == 'warning') bpSev = 'warning';
    }
    final color = bpSev == 'critical' ? AppColors.danger : bpSev == 'warning' ? AppColors.warning : AppColors.textPrimary;
    return Expanded(
      child: Column(
        children: [
          Text('BP', style: appText(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$sbp/$dbp', style: appText(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          Text('MAP $map', style: appText(color: AppColors.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─── Edge Section (provider-aware) ───────────

class _EdgeSection extends StatelessWidget {
  final BuildContext context;
  const _EdgeSection({required this.context});

  @override
  Widget build(BuildContext ctx) {
    final cameras = ctx.watch<CameraProvider>();
    final hasAny = cameras.hasAny;

    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const FolioMedEdgeScreen())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              const Color(0xFF0E7C5F).withValues(alpha: 0.06)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_input_antenna,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FolioMed Edge',
                      style: appText(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  Text(
                    hasAny
                        ? '${cameras.cameras.length} camera${cameras.cameras.length > 1 ? 's' : ''} · '
                          '${cameras.activeCount} active · ${cameras.withRoiCount} with zones'
                        : 'No cameras yet — tap to connect your first CCTV camera',
                    style: appText(
                        color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: hasAny ? AppColors.surface : AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                border: hasAny
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                    : null,
              ),
              child: Text(
                hasAny ? 'Manage' : 'Setup',
                style: appText(
                    color: hasAny ? AppColors.primary : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorDevBanner extends StatefulWidget {
  const _MonitorDevBanner();

  @override
  State<_MonitorDevBanner> createState() => _MonitorDevBannerState();
}

class _MonitorDevBannerState extends State<_MonitorDevBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFB71C1C),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DEMO / DEVELOPMENT MODE',
                      style: appText(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                  const SizedBox(height: 2),
                  Text(
                    'Vitals shown are simulated. Do NOT use for real clinical decisions.',
                    style: appText(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ward Activity (per-patient) ───────────────

/// One patient's recent activity: deduplicated alerts (with repeat counts)
/// and their latest orders/notes.
class _PatientActivity {
  final MonitoredPatient patient;
  final List<(MonitorAlert, int)> alerts;
  final List<MonitorComment> comments;

  const _PatientActivity({
    required this.patient,
    required this.alerts,
    required this.comments,
  });

  DateTime get latest {
    var t = DateTime.fromMillisecondsSinceEpoch(0);
    if (alerts.isNotEmpty && alerts.first.$1.time.isAfter(t)) {
      t = alerts.first.$1.time;
    }
    if (comments.isNotEmpty && comments.first.time.isAfter(t)) {
      t = comments.first.time;
    }
    return t;
  }
}

/// Build the per-patient activity feed: identical repeated alerts collapse
/// into one row with a ×N badge; max 3 alert rows + 2 orders/notes each.
/// Critical patients first, then warning, then most recent activity.
List<_PatientActivity> _buildWardActivity(
    MonitorProvider monitor, List<MonitoredPatient> patients) {
  final result = <_PatientActivity>[];
  for (final p in patients) {
    final counts = <String, int>{};
    final firstSeen = <MonitorAlert>[];
    for (final a in monitor.alertsFor(p.id)) {
      // Newest first — keep the newest of each message, count the rest.
      if (counts.containsKey(a.message)) {
        counts[a.message] = counts[a.message]! + 1;
      } else {
        counts[a.message] = 1;
        firstSeen.add(a);
      }
    }
    final alerts = [
      for (final a in firstSeen.take(3)) (a, counts[a.message]!),
    ];
    final comments = monitor.commentsFor(p.id).take(2).toList();
    if (alerts.isEmpty && comments.isEmpty) continue;
    result.add(
        _PatientActivity(patient: p, alerts: alerts, comments: comments));
  }
  int sevRank(String s) => s == 'critical' ? 0 : (s == 'warning' ? 1 : 2);
  result.sort((a, b) {
    final r = sevRank(a.patient.worstSeverity)
        .compareTo(sevRank(b.patient.worstSeverity));
    if (r != 0) return r;
    return b.latest.compareTo(a.latest);
  });
  return result;
}

class _PatientActivityCard extends StatelessWidget {
  final _PatientActivity activity;
  const _PatientActivityCard({required this.activity});

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    final p = activity.patient;
    final sev = p.worstSeverity;
    final sevColor = sev == 'critical'
        ? AppColors.danger
        : sev == 'warning'
            ? AppColors.warning
            : AppColors.stable;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: sev == 'critical'
              ? AppColors.danger.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PatientMonitorScreen(patientId: p.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient header — always know who this belongs to
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: sevColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(p.name,
                        overflow: TextOverflow.ellipsis,
                        style: appText(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (p.bed.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('· ${p.bed}',
                        style: appText(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      sev == 'critical'
                          ? 'CRITICAL'
                          : sev == 'warning'
                              ? 'WATCH'
                              : 'STABLE',
                      style: appText(
                          color: sevColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),

              // Alerts for this patient
              for (final (alert, count) in activity.alerts) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: (alert.severity == 'critical'
                            ? AppColors.danger
                            : AppColors.warning)
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          size: 14,
                          color: alert.severity == 'critical'
                              ? AppColors.danger
                              : AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(alert.message,
                            style: appText(
                                color: alert.severity == 'critical'
                                    ? AppColors.danger
                                    : AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (count > 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (alert.severity == 'critical'
                                    ? AppColors.danger
                                    : AppColors.warning)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('×$count',
                              style: appText(
                                  color: alert.severity == 'critical'
                                      ? AppColors.danger
                                      : AppColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(_ago(alert.time),
                          style: appText(
                              color: AppColors.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              ],

              // Orders & notes for this patient
              for (final c in activity.comments) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (c.type == 'order'
                                ? AppColors.primary
                                : AppColors.accent)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(c.type == 'order' ? 'Order' : 'Note',
                          style: appText(
                              color: c.type == 'order'
                                  ? AppColors.primary
                                  : AppColors.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: appText(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.5,
                                  height: 1.35)),
                          const SizedBox(height: 2),
                          Text('${c.author} · ${_ago(c.time)}',
                              style: appText(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
