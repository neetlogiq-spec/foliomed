import 'package:flutter/material.dart';

enum VitalType { hr, spo2, rr, sbp, dbp, map }

class VitalMeta {
  final String label;
  final String unit;
  final IconData icon;
  final String stringIcon;
  final double absMin;
  final double absMax;

  const VitalMeta(this.label, this.unit, this.icon, this.absMin, this.absMax, [this.stringIcon = '']);

  double get min => absMin;
  double get max => absMax;
}

const vitalMeta = {
  VitalType.hr: VitalMeta('Heart Rate', 'bpm', Icons.favorite, 30, 220, '♥'),
  VitalType.spo2: VitalMeta('SpO₂', '%', Icons.circle, 50, 100, '◉'),
  VitalType.rr: VitalMeta('Resp. Rate', 'br/min', Icons.air, 4, 60, '≈'),
  VitalType.sbp: VitalMeta('SBP', 'mmHg', Icons.swap_vert, 30, 250, '↑'),
  VitalType.dbp: VitalMeta('DBP', 'mmHg', Icons.swap_vert, 15, 150, '↓'),
  VitalType.map: VitalMeta('MAP', 'mmHg', Icons.swap_vert, 20, 180, '~'),
};

class VitalThreshold {
  final double? warnLow;
  final double? critLow;
  final double? warnHigh;
  final double? critHigh;

  const VitalThreshold({this.warnLow, this.critLow, this.warnHigh, this.critHigh});

  String severity(double value) {
    if (critLow != null && value < critLow!) return 'critical';
    if (critHigh != null && value > critHigh!) return 'critical';
    if (warnLow != null && value < warnLow!) return 'warning';
    if (warnHigh != null && value > warnHigh!) return 'warning';
    return 'stable';
  }

  VitalThreshold copyWith({double? warnLow, double? critLow, double? warnHigh, double? critHigh}) {
    return VitalThreshold(
      warnLow: warnLow ?? this.warnLow,
      critLow: critLow ?? this.critLow,
      warnHigh: warnHigh ?? this.warnHigh,
      critHigh: critHigh ?? this.critHigh,
    );
  }

  Map<String, dynamic> toMap() => {
    'warnLow': warnLow,
    'critLow': critLow,
    'warnHigh': warnHigh,
    'critHigh': critHigh,
  };

  factory VitalThreshold.fromMap(Map<String, dynamic> m) => VitalThreshold(
    warnLow: (m['warnLow'] as num?)?.toDouble(),
    critLow: (m['critLow'] as num?)?.toDouble(),
    warnHigh: (m['warnHigh'] as num?)?.toDouble(),
    critHigh: (m['critHigh'] as num?)?.toDouble(),
  );
}

class SimConfig {
  final double base;
  final double range;
  final double maxDrift;

  const SimConfig({required this.base, this.range = 3, this.maxDrift = 10});
}

const defaultAdultThresholds = {
  VitalType.hr: VitalThreshold(warnLow: 55, critLow: 45, warnHigh: 110, critHigh: 130),
  VitalType.spo2: VitalThreshold(warnLow: 92, critLow: 88),
  VitalType.rr: VitalThreshold(warnLow: 10, critLow: 6, warnHigh: 24, critHigh: 32),
  VitalType.sbp: VitalThreshold(warnLow: 90, critLow: 80, warnHigh: 160, critHigh: 180),
  VitalType.dbp: VitalThreshold(warnLow: 55, critLow: 45, warnHigh: 95, critHigh: 110),
  VitalType.map: VitalThreshold(warnLow: 65, critLow: 55, warnHigh: 110, critHigh: 125),
};
