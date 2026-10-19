import 'row_parsing.dart';

/// A unit (consultant team) inside a ward, e.g. "Unit A".
class WardUnit {
  const WardUnit({
    required this.id,
    required this.wardId,
    required this.name,
    this.position = 0,
  });

  final String id;
  final String wardId;
  final String name;
  final int position;

  factory WardUnit.fromRow(DbRow row) => WardUnit(
        id: row['id'] as String? ?? '',
        wardId: row['ward_id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        position: (row['position'] as num?)?.toInt() ?? 0,
      );
}

/// Which patients a list shows: everything, one ward, one unit of a ward,
/// or a ward's unassigned patients.
class PatientScope {
  const PatientScope.all()
      : wardId = null,
        unitId = null,
        unassigned = false;
  const PatientScope.ward(String this.wardId)
      : unitId = null,
        unassigned = false;
  const PatientScope.unit(String this.wardId, String this.unitId)
      : unassigned = false;
  const PatientScope.unassigned(String this.wardId)
      : unitId = null,
        unassigned = true;

  final String? wardId;
  final String? unitId;
  final bool unassigned;

  bool get isAll => wardId == null;

  bool includes({required String wardId, required String? unitId}) {
    if (this.wardId == null) return true;
    if (this.wardId != wardId) return false;
    if (unassigned) return unitId == null;
    if (this.unitId != null) return this.unitId == unitId;
    return true;
  }

  /// "wardId|unitId|u" — for persistence and stream-cache keys.
  String encode() => isAll ? '' : '$wardId|${unitId ?? ''}|${unassigned ? 'u' : ''}';

  static PatientScope decode(String? v) {
    if (v == null || v.isEmpty) return const PatientScope.all();
    final parts = v.split('|');
    if (parts.length != 3 || parts[0].isEmpty) return const PatientScope.all();
    if (parts[2] == 'u') return PatientScope.unassigned(parts[0]);
    if (parts[1].isNotEmpty) return PatientScope.unit(parts[0], parts[1]);
    return PatientScope.ward(parts[0]);
  }

  @override
  bool operator ==(Object other) =>
      other is PatientScope &&
      other.wardId == wardId &&
      other.unitId == unitId &&
      other.unassigned == unassigned;

  @override
  int get hashCode => Object.hash(wardId, unitId, unassigned);
}

/// Head counts for a set of patients: total, per unit, and unassigned.
class UnitCounts {
  UnitCounts(this.total, this.byUnit, this.unassigned);

  final int total;
  final Map<String, int> byUnit;
  final int unassigned;

  static UnitCounts of(Iterable<String?> unitIds) {
    var total = 0, unassigned = 0;
    final by = <String, int>{};
    for (final u in unitIds) {
      total++;
      if (u == null) {
        unassigned++;
      } else {
        by[u] = (by[u] ?? 0) + 1;
      }
    }
    return UnitCounts(total, by, unassigned);
  }
}
