import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
String formatTime(DateTime date) => DateFormat('hh:mm a').format(date);
String formatDateShort(DateTime date) => DateFormat('dd MMM').format(date);

String getInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '';
  final first = parts.first[0];
  final last =
      parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

const List<Color> _avatarColors = [
  Color(0xFF1565C0),
  Color(0xFF00838F),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF2E7D32),
];

Color getAvatarColor(String name) {
  return _avatarColors[name.hashCode.abs() % _avatarColors.length];
}

bool isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool isUrgent(String priority) => priority == 'Urgent';

String truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}
