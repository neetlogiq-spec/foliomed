import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/monitor_vitals.dart';
import '../../models/monitored_patient.dart';
import '../../utils/app_theme.dart';

class ThresholdPanel extends StatefulWidget {
  final MonitoredPatient patient;
  /// Called with patientId + map of VitalType → changed thresholds when Save is pressed.
  final void Function(String patientId, Map<VitalType, VitalThreshold> changes) onSave;

  const ThresholdPanel({super.key, required this.patient, required this.onSave});

  @override
  State<ThresholdPanel> createState() => _ThresholdPanelState();
}

class _ThresholdPanelState extends State<ThresholdPanel> {
  VitalType _tab = VitalType.hr;

  // Local copies — edited freely, only pushed to provider on Save
  late Map<VitalType, VitalThreshold> _local;

  static const _tabs = [
    {'vt': VitalType.hr,   'label': 'Heart Rate'},
    {'vt': VitalType.spo2, 'label': 'SpO₂'},
    {'vt': VitalType.rr,   'label': 'Resp. Rate'},
    {'vt': VitalType.sbp,  'label': 'Blood Pressure'},
  ];

  @override
  void initState() {
    super.initState();
    // Deep copy so we don't mutate the live provider state
    _local = {
      for (final vt in VitalType.values)
        vt: widget.patient.thresholds[vt] ?? const VitalThreshold(),
    };
  }

  void _set(VitalType vt, String key, double value) {
    setState(() {
      final old = _local[vt]!;
      _local[vt] = VitalThreshold(
        critLow:  key == 'critLow'  ? value : old.critLow,
        critHigh: key == 'critHigh' ? value : old.critHigh,
        warnLow:  old.warnLow,
        warnHigh: old.warnHigh,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vital tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _tabs.map((t) {
              final vt = t['vt'] as VitalType;
              final active = _tab == vt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = vt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      t['label'] as String,
                      style: GoogleFonts.dmSans(
                        color: active ? Colors.white : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Sliders for selected vital(s)
        if (_tab == VitalType.sbp) ...[
          _block(context, VitalType.sbp, 'Systolic (SBP)'),
          const SizedBox(height: 16),
          _block(context, VitalType.dbp, 'Diastolic (DBP)'),
          const SizedBox(height: 16),
          _block(context, VitalType.map, 'Mean Arterial (MAP)'),
        ] else
          _block(context, _tab, null),

        const SizedBox(height: 28),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => widget.onSave(widget.patient.id, _local),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: Text('Save Thresholds',
                style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: Text('Changes are not applied until you tap Save.',
              style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _block(BuildContext context, VitalType vt, String? subtitle) {
    final meta    = vitalMeta[vt]!;
    final thr     = _local[vt]!;
    final current = widget.patient.vitals[vt] ?? 0;
    final isSpo2  = vt == VitalType.spo2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              if (subtitle != null)
                Text(subtitle,
                    style: GoogleFonts.dmSans(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Now: ${current.round()} ${meta.unit}',
                  style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),

          const SizedBox(height: 14),

          // Critical Low
          _sliderRow(
            context,
            label: '🔴  Critical Low',
            sublabel: 'Below this → urgent alert',
            value: thr.critLow,
            min: meta.absMin,
            max: meta.absMax * 0.65,
            unit: meta.unit,
            onChanged: (v) => _set(vt, 'critLow', v),
          ),

          if (!isSpo2) ...[
            const SizedBox(height: 18),
            // Critical High
            _sliderRow(
              context,
              label: '🔴  Critical High',
              sublabel: 'Above this → urgent alert',
              value: thr.critHigh,
              min: meta.absMax * 0.35,
              max: meta.absMax,
              unit: meta.unit,
              onChanged: (v) => _set(vt, 'critHigh', v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context, {
    required String label,
    required String sublabel,
    required double? value,
    required double min,
    required double max,
    required String unit,
    required void Function(double) onChanged,
  }) {
    final current = (value ?? min).clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.dmSans(
                        color: AppColors.critical,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(sublabel,
                    style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.critical.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value != null ? '${value.round()} $unit' : 'Off',
                style: GoogleFonts.dmSans(
                    color: AppColors.critical,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
            activeTrackColor: AppColors.critical,
            inactiveTrackColor: AppColors.critical.withOpacity(0.15),
            thumbColor: AppColors.critical,
            overlayColor: AppColors.critical.withOpacity(0.12),
          ),
          child: Slider(
            value: current,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: (v) => onChanged(v.roundToDouble()),
          ),
        ),
      ],
    );
  }
}
