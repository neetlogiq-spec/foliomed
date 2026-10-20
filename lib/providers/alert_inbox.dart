import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One alert that arrived while the app was open.
class AlertItem {
  const AlertItem({required this.title, required this.body, required this.at, this.read = false});

  final String title;
  final String body;
  final DateTime at;
  final bool read;

  AlertItem asRead() => AlertItem(title: title, body: body, at: at, read: true);

  Map<String, dynamic> toJson() =>
      {'t': title, 'b': body, 'at': at.millisecondsSinceEpoch, 'r': read};

  static AlertItem? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = j['at'];
    if (at is! int) return null;
    return AlertItem(
      title: j['t'] as String? ?? '',
      body: j['b'] as String? ?? '',
      at: DateTime.fromMillisecondsSinceEpoch(at),
      read: j['r'] == true,
    );
  }
}

/// The last [capacity] alerts on this device, newest first, with unread
/// tracking. Kept locally — the notes themselves live in the database.
class AlertInbox extends ChangeNotifier {
  AlertInbox() {
    _restore();
  }

  static const _storeKey = 'alert_inbox_v1';
  static const capacity = 40;

  List<AlertItem> _items = const [];

  List<AlertItem> get items => _items;
  int get unread => _items.where((a) => !a.read).length;

  Future<void> _restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_storeKey);
      if (raw == null) return;
      _items = [
        for (final j in jsonDecode(raw) as List)
          if (AlertItem.fromJson(j) case final a?) a,
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('AlertInbox restore: $e');
    }
  }

  Future<void> _persist() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_storeKey, jsonEncode([for (final a in _items) a.toJson()]));
    } catch (_) {}
  }

  Future<void> add(String title, String body) async {
    _items = [AlertItem(title: title, body: body, at: DateTime.now()), ..._items].take(capacity).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    _items = [for (final a in _items) a.asRead()];
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items = const [];
    notifyListeners();
    await _persist();
  }
}
