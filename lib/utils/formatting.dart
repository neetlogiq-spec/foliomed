import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';

/// "19 Oct 2026".
String formatDay(DateTime d) => DateFormat('d MMM y').format(d);

/// "9:40 pm" — the clock as people say it.
String formatClock(DateTime d) => DateFormat('h:mm a').format(d).toLowerCase();

/// "Tue 21 Oct, 9:40 pm" — for reminders, births and samples.
String formatDueTime(DateTime d) {
  final l = d.toLocal();
  return '${DateFormat('EEE d MMM').format(l)}, ${formatClock(l)}';
}

/// Up to two letters for an avatar: first letters of the first and last
/// words ("Meera Iyer" → "MI"), or the first two of a single word.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    final w = words.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (words.first[0] + words.last[0]).toUpperCase();
}

/// A stable tint per name, from the app palette, so the same patient
/// always gets the same colour.
Color tintForName(String name) {
  const palette = [
    AppColors.primary,
    AppColors.accent,
    AppColors.doctorColor,
    AppColors.nurseColor,
    AppColors.warning,
    AppColors.secondary,
  ];
  var h = 0;
  for (final c in name.toLowerCase().codeUnits) {
    h = (h * 33 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}
