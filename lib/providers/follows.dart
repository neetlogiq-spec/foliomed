import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/haptics.dart';

/// The patients I follow ("My patients"). Private to me; the database
/// ends a follow on discharge, or on transfer to a ward I'm not in.
class Follows extends ChangeNotifier {
  Follows({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? supabase;

  Set<String> _ids = const {};
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  String? _uid;

  Set<String> get ids => _ids;
  bool follows(String patientId) => _ids.contains(patientId);

  void watch(String? uid) {
    if (uid == _uid && _sub != null) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    if (uid == null) {
      _ids = const {};
      notifyListeners();
      return;
    }
    _sub = _client
        .from('patient_follows')
        .stream(primaryKey: ['user_id', 'patient_id'])
        .eq('user_id', uid)
        .listen((rows) {
      _ids = {for (final r in rows) r['patient_id'] as String};
      notifyListeners();
    }, onError: (Object _) {});
  }

  /// Follows or unfollows; returns the new state.
  Future<bool> toggle(String patientId) async {
    final uid = _uid;
    if (uid == null) return false;
    final now = !follows(patientId);
    // Show it straight away; the stream confirms.
    _ids = now ? {..._ids, patientId} : ({..._ids}..remove(patientId));
    notifyListeners();
    try {
      if (now) {
        await _client.from('patient_follows').upsert({'user_id': uid, 'patient_id': patientId});
      } else {
        await _client.from('patient_follows').delete().eq('user_id', uid).eq('patient_id', patientId);
      }
      Haptics.selection();
    } catch (_) {
      _ids = !now ? {..._ids, patientId} : ({..._ids}..remove(patientId));
      notifyListeners();
      rethrow;
    }
    return now;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
