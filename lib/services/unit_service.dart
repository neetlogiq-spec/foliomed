import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ward_unit.dart';
import 'supabase_service.dart';

/// Units inside wards. Members read; only the ward owner writes (RLS).
class UnitService {
  UnitService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _units => _client.from('ward_units');

  Stream<List<WardUnit>> forWards(List<String> wardIds) {
    if (wardIds.isEmpty) return Stream.value(const []);
    return _units
        .stream(primaryKey: ['id'])
        .inFilter('ward_id', wardIds)
        .order('position', ascending: true)
        .map((rows) => rows.map(WardUnit.fromRow).toList()
          ..sort((a, b) => a.position != b.position
              ? a.position.compareTo(b.position)
              : a.name.toLowerCase().compareTo(b.name.toLowerCase())));
  }

  Future<void> add(String wardId, String name, {required int position}) =>
      _checked(_units.insert({
        'ward_id': wardId,
        'name': name.trim(),
        'position': position,
      }).select('id'));

  Future<void> rename(String unitId, String name) =>
      _checked(_units.update({'name': name.trim()}).eq('id', unitId).select('id'));

  Future<void> setPosition(String unitId, int position) =>
      _checked(_units.update({'position': position}).eq('id', unitId).select('id'));

  /// Patients in the unit become unassigned.
  Future<void> delete(String unitId) =>
      _checked(_units.delete().eq('id', unitId).select('id'));

  /// RLS blocks silently with zero rows — surface that as an error.
  static Future<void> _checked(Future<List<Map<String, dynamic>>> q) async {
    final rows = await q;
    if (rows.isEmpty) {
      throw const PostgrestException(
          message: 'Only the ward owner can change its units.', code: '42501');
    }
  }
}
