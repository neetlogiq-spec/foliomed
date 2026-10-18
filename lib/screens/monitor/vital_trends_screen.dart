import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/monitor_vitals.dart';
import '../../providers/monitor_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';

class VitalTrendsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const VitalTrendsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<VitalTrendsScreen> createState() => _VitalTrendsScreenState();
}

class _VitalTrendsScreenState extends State<VitalTrendsScreen> {
  String _range = '1h';

  Duration get _duration {
    switch (_range) {
      case '30m': return const Duration(minutes: 30);
      case '1h':  return const Duration(hours: 1);
      case '6h':  return const Duration(hours: 6);
      default:    return const Duration(hours: 1);
    }
  }

  // Vitals to show, in order: HR, SpO₂, RR, then BP as a combined panel
  static const _vitalOrder = [
    VitalType.hr,
    VitalType.spo2,
    VitalType.rr,
  ];

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorProvider>();
    context.watch<ThemeProvider>();
    final patient = monitor.patientById(widget.patientId);

    final cutoff = DateTime.now().subtract(_duration);
    final allHistory = monitor.historyFor(widget.patientId);
    final data = allHistory.where((s) => s.time.isAfter(cutoff)).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text('Vital Trends',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800, color: AppColors.primary)),
      ),
      body: Column(
        children: [
          // Patient name + range selector
          Container(
            color: AppColors.card,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.patientName,
                      style: GoogleFonts.dmSans(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                ..._rangeButtons(),
              ],
            ),
          ),

          // All charts stacked
          Expanded(
            child: data.isEmpty
                ? Center(
                    child: Text('No data yet',
                        style: GoogleFonts.dmSans(
                            color: AppColors.textSecondary, fontSize: 14)))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      ..._vitalOrder.map((vt) {
                        final thr = patient?.thresholds[vt];
                        final snapshots = data
                            .where((s) => s.vitals[vt] != null)
                            .toList();
                        return _VitalChart(
                          vt: vt,
                          data: snapshots,
                          threshold: thr,
                        );
                      }),
                      // BP: SBP + DBP on one chart
                      _BPChart(data: data, patient: patient),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rangeButtons() {
    return ['30m', '1h', '6h'].map((r) {
      final sel = r == _range;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GestureDetector(
          onTap: () => setState(() => _range = r),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Text(r,
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
    }).toList();
  }
}

// ── Single-vital chart panel ──────────────────────────────────────────────────

class _VitalChart extends StatelessWidget {
  final VitalType vt;
  final List<VitalSnapshot> data;
  final VitalThreshold? threshold;

  const _VitalChart({
    required this.vt,
    required this.data,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final meta = vitalMeta[vt]!;
    if (data.isEmpty) return const SizedBox.shrink();

    final values = data.map((s) => s.vitals[vt]!).toList();
    final latest = values.last;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final avg   = values.reduce((a, b) => a + b) / values.length;

    final sev = threshold?.severity(latest) ?? 'stable';
    final color = sev == 'critical'
        ? AppColors.critical
        : sev == 'warning'
            ? AppColors.warningColor
            : AppColors.primary;

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.vitals[vt]!))
        .toList();

    final chartMin = (minV - (maxV - minV) * 0.15).floorToDouble();
    final chartMax = (maxV + (maxV - minV) * 0.15).ceilToDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(meta.stringIcon,
                  style: TextStyle(color: color, fontSize: 14)),
              const SizedBox(width: 6),
              Text(meta.label,
                  style: GoogleFonts.dmSans(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${latest.round()}',
                  style: GoogleFonts.dmSans(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text(meta.unit,
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),

          // Chart
          SizedBox(
            height: 90,
            child: LineChart(
              LineChartData(
                minY: chartMin,
                maxY: chartMax,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (chartMax - chartMin) / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider.withOpacity(0.6),
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: (chartMax - chartMin) / 3,
                      getTitlesWidget: (v, _) => Text(
                        v.round().toString(),
                        style: GoogleFonts.dmSans(
                            color: AppColors.textSecondary, fontSize: 8),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 16,
                      interval:
                          (data.length / 4).ceilToDouble().clamp(1, 9999),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          DateFormat('HH:mm').format(data[i].time),
                          style: GoogleFonts.dmSans(
                              color: AppColors.textSecondary, fontSize: 8),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  if (threshold?.critHigh != null)
                    _thrLine(threshold!.critHigh!, AppColors.critical),
                  if (threshold?.critLow != null)
                    _thrLine(threshold!.critLow!, AppColors.critical),
                  if (threshold?.warnHigh != null)
                    _thrLine(threshold!.warnHigh!, AppColors.warningColor),
                  if (threshold?.warnLow != null)
                    _thrLine(threshold!.warnLow!, AppColors.warningColor),
                ]),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${s.y.round()} ${meta.unit}',
                              GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: color,
                    barWidth: 2,
                    dotData: FlDotData(show: data.length < 30),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.07),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Mini stats
          Row(
            children: [
              _miniStat('Min', minV.round().toString(), meta.unit),
              _miniStat('Avg', avg.round().toString(), meta.unit),
              _miniStat('Max', maxV.round().toString(), meta.unit),
            ],
          ),
        ],
      ),
    );
  }

  HorizontalLine _thrLine(double y, Color c) => HorizontalLine(
        y: y,
        color: c.withOpacity(0.5),
        strokeWidth: 1,
        dashArray: [4, 4],
      );

  Widget _miniStat(String label, String val, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
          Text('$val $unit',
              style: GoogleFonts.dmSans(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── BP chart: SBP + DBP on the same panel ────────────────────────────────────

class _BPChart extends StatelessWidget {
  final List<VitalSnapshot> data;
  final dynamic patient;

  const _BPChart({required this.data, required this.patient});

  @override
  Widget build(BuildContext context) {
    final sbpData =
        data.where((s) => s.vitals[VitalType.sbp] != null).toList();
    final dbpData =
        data.where((s) => s.vitals[VitalType.dbp] != null).toList();
    if (sbpData.isEmpty) return const SizedBox.shrink();

    final sbpVals = sbpData.map((s) => s.vitals[VitalType.sbp]!).toList();
    final dbpVals = dbpData.map((s) => s.vitals[VitalType.dbp]!).toList();
    final allVals = [...sbpVals, ...dbpVals];

    final latestSbp = sbpVals.last;
    final latestDbp = dbpVals.last;
    final latestMap =
        data.last.vitals[VitalType.map]?.round() ?? 0;

    final minV = allVals.reduce((a, b) => a < b ? a : b);
    final maxV = allVals.reduce((a, b) => a > b ? a : b);
    final chartMin = (minV - (maxV - minV) * 0.15).floorToDouble();
    final chartMax = (maxV + (maxV - minV) * 0.15).ceilToDouble();

    final sbpSpots = sbpData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.vitals[VitalType.sbp]!))
        .toList();
    final dbpSpots = dbpData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.vitals[VitalType.dbp]!))
        .toList();

    final sbpThr = patient?.thresholds[VitalType.sbp] as VitalThreshold?;
    final dbpThr = patient?.thresholds[VitalType.dbp] as VitalThreshold?;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('↕',
                  style: TextStyle(color: AppColors.primary, fontSize: 14)),
              const SizedBox(width: 6),
              Text('Blood Pressure',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${latestSbp.round()}/${latestDbp.round()}',
                  style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text('mmHg',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('MAP: $latestMap mmHg',
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary, fontSize: 10)),
          ),
          const SizedBox(height: 10),

          // Legend
          Row(
            children: [
              _dot(AppColors.primary),
              const SizedBox(width: 4),
              Text('SBP',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _dot(AppColors.accent),
              const SizedBox(width: 4),
              Text('DBP',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),

          SizedBox(
            height: 90,
            child: LineChart(
              LineChartData(
                minY: chartMin,
                maxY: chartMax,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (chartMax - chartMin) / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider.withOpacity(0.6),
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: (chartMax - chartMin) / 3,
                      getTitlesWidget: (v, _) => Text(
                        v.round().toString(),
                        style: GoogleFonts.dmSans(
                            color: AppColors.textSecondary, fontSize: 8),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 16,
                      interval: (sbpData.length / 4)
                          .ceilToDouble()
                          .clamp(1, 9999),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= sbpData.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          DateFormat('HH:mm').format(sbpData[i].time),
                          style: GoogleFonts.dmSans(
                              color: AppColors.textSecondary, fontSize: 8),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  if (sbpThr?.critHigh != null)
                    _thrLine(sbpThr!.critHigh!, AppColors.critical),
                  if (sbpThr?.critLow != null)
                    _thrLine(sbpThr!.critLow!, AppColors.critical),
                  if (dbpThr?.critLow != null)
                    _thrLine(dbpThr!.critLow!, AppColors.critical),
                ]),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${s.y.round()} mmHg',
                              GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: sbpSpots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.primary,
                    barWidth: 2,
                    dotData: FlDotData(show: sbpData.length < 30),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.05),
                    ),
                  ),
                  LineChartBarData(
                    spots: dbpSpots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.accent,
                    barWidth: 2,
                    dotData: FlDotData(show: dbpData.length < 30),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.accent.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  HorizontalLine _thrLine(double y, Color c) => HorizontalLine(
        y: y,
        color: c.withOpacity(0.5),
        strokeWidth: 1,
        dashArray: [4, 4],
      );

  Widget _dot(Color c) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
