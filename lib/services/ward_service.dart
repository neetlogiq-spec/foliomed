import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/ward.dart';
import 'usage_counters.dart';
import 'supabase_service.dart';

class WardService {
  final SupabaseClient _client;

  WardService({SupabaseClient? client}) : _client = client ?? supabase;

  SupabaseQueryBuilder get _wards => _client.from(Tables.wards);
  SupabaseQueryBuilder get _profiles => _client.from(Tables.profiles);

  /// Postgres error code for a primary-key collision.
  static const String _uniqueViolation = '23505';
  static const int _maxCodeAttempts = 8;

  /// Streams the wards a user is a member of. An empty list yields an
  /// empty stream without touching the network.
  Stream<List<Ward>> wardsForUser(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const <Ward>[]);
    return _wards
        .stream(primaryKey: ['id'])
        .inFilter('id', wardIds)
        .map((rows) => rows.map(Ward.fromRow).toList());
  }

  /// Every ward the caller can see (RLS limits this to their own wards).
  Stream<List<Ward>> getAllWards() {
    return _wards
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((rows) => rows.map(Ward.fromRow).toList());
  }

  Future<Ward?> getWard(String wardId) async {
    final row = await _wards.select().eq('id', wardId).maybeSingle();
    return row == null ? null : Ward.fromRow(row);
  }

  /// Sets up a ward and returns its code. Codes are random 5-digit numbers;
  /// if one is already taken the insert fails and another is drawn.
  Future<String> createWard({required String name, String location = '', String ownerName = ''}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    final random = Random.secure();
    for (var attempt = 0; attempt < _maxCodeAttempts; attempt++) {
      final code = '${10000 + random.nextInt(90000)}';
      final row = Ward(
        id: code,
        name: name,
        location: location,
        ownerName: ownerName,
        ownerId: user.id,
        ownerEmail: user.email ?? '',
        createdAt: DateTime.now(),
      ).toRow();
      try {
        await _wards.insert(row);
      } on PostgrestException catch (e) {
        if (e.code == _uniqueViolation) continue;
        rethrow;
      }
      await joinWard(code);
      UsageCounters.bump('ward', summary: 'New ward: $name');
      return code;
    }
    throw StateError('Every code tried was taken. Please try once more.');
  }

  Future<void> updateWard(Ward ward) async {
    await _wards.update(ward.toRow()).eq('id', ward.id);
  }

  /// Owner only; throws when RLS blocks it (zero rows updated).
  Future<void> setKind(String wardId, WardKind kind) async {
    final rows = await _wards.update({'kind': kind.name}).eq('id', wardId).select('id');
    if (rows.isEmpty) {
      throw const PostgrestException(
          message: 'Only the ward owner can change the ward type.', code: '42501');
    }
  }

  /// Joins by code. Returns false when no ward has that code.
  Future<bool> joinWard(String wardId) async {
    final ok = await _client.rpc('join_ward', params: {'p_ward_id': wardId});
    return ok == true;
  }

  Future<void> leaveWard(String wardId) async {
    await _client.rpc('leave_ward', params: {'p_ward_id': wardId});
  }

  /// Creator-only. Patients, notes and comments cascade in Postgres and a
  /// trigger strips the code from every member's profile.
  Future<void> deleteWard(String wardId) async {
    await _wards.delete().eq('id', wardId);
  }

  Future<int> memberCount(String wardId) async {
    final count =
        await _client.rpc('ward_member_count', params: {'p_ward_id': wardId});
    return (count as num?)?.toInt() ?? 0;
  }

  /// Members of a ward (anyone whose `ward_ids` contains it), capped at 100.
  Future<List<AppUser>> getWardMembers(String wardId) async {
    final rows = await _profiles
        .select()
        .contains('ward_ids', [wardId])
        .order('name')
        .limit(100);
    return rows.map(AppUser.fromRow).toList();
  }

  /// Staff whose primary ward is [wardId], capped at 100.
  Stream<List<AppUser>> getWardStaff(String wardId) {
    return _profiles
        .stream(primaryKey: ['id'])
        .eq('ward_id', wardId)
        .limit(100)
        .map((rows) => rows.map(AppUser.fromRow).toList());
  }
}
