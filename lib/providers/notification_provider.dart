import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String title;
  final String body;
  final DateTime receivedAt;

  AppNotification({
    required this.title,
    required this.body,
    required this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        receivedAt: DateTime.parse(j['receivedAt']),
      );
}

class NotificationProvider extends ChangeNotifier {
  static const _key = 'notification_inbox_v1';
  static const _maxCount = 30;

  List<AppNotification> _items = [];
  List<AppNotification> get items => _items;

  NotificationProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      _items = list;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(String title, String body) async {
    _items.insert(
      0,
      AppNotification(title: title, body: body, receivedAt: DateTime.now()),
    );
    if (_items.length > _maxCount) _items = _items.sublist(0, _maxCount);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _items = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
