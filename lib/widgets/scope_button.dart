import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/ward.dart';
import '../models/ward_unit.dart';
import '../providers/account_provider.dart';
import '../providers/unit_provider.dart';
import '../services/ward_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/haptics.dart';
import '../utils/stream_cache.dart';

final _wardStreams = StreamCache<List<Ward>>();

/// The user's wards, streamed once per ward set (shared across screens).
Stream<List<Ward>> myWardsStream(BuildContext context) {
  final ids = context.read<AccountProvider>().currentUser?.wardIds ?? const <String>[];
  if (ids.isEmpty) return Stream.value(const []);
  return _wardStreams.get(ids.join(','), () => WardService().wardsForUser(ids));
}

String scopeLabel(PatientScope s, List<Ward> wards, UnitProvider units) {
  if (s.isAll) return wards.length == 1 ? wards.first.name : 'All wards';
  final ward = wards.where((w) => w.id == s.wardId).firstOrNull?.name ?? 'Ward';
  if (s.unassigned) return '$ward · Unassigned';
  final unit = units.unitById(s.unitId);
  return unit == null ? ward : '$ward · ${unit.name}';
}

/// iOS pull-down button: "All wards ▾" / "PNC · Unit A ▾".
class ScopeButton extends StatelessWidget {
  const ScopeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitProvider>();
    return StreamBuilder<List<Ward>>(
      stream: myWardsStream(context),
      builder: (context, snap) {
        final wards = snap.data ?? const <Ward>[];
        final hasChoice = wards.length > 1 || units.units.isNotEmpty;
        if (!hasChoice) return const SizedBox.shrink();
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          minimumSize: Size.zero,
          onPressed: () => _pick(context, wards, units),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  scopeLabel(units.scope, wards, units),
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subheadline(
                      color: AppColors.primary, weight: FontWeight.w600),
                ),
              ),
              Icon(Icons.expand_more, size: 18, color: AppColors.primary),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _pick(BuildContext context, List<Ward> wards, UnitProvider units) async {
    final options = <PatientScope, String>{
      if (wards.length > 1) const PatientScope.all(): 'All wards',
    };
    for (final w in wards) {
      final list = units.unitsOf(w.id);
      options[PatientScope.ward(w.id)] = list.isEmpty ? w.name : '${w.name} — all units';
      for (final u in list) {
        final mine = units.myUnitFor(w.id) == u.id;
        options[PatientScope.unit(w.id, u.id)] = '${w.name} · ${u.name}${mine ? '  (my unit)' : ''}';
      }
      if (list.isNotEmpty) options[PatientScope.unassigned(w.id)] = '${w.name} · Unassigned';
    }
    final picked = await showCupertinoModalPopup<PatientScope>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Show patients from'),
        actions: [
          for (final e in options.entries)
            CupertinoActionSheetAction(
              isDefaultAction: e.key == units.scope,
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Text(e.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked == null) return;
    Haptics.selection();
    await units.setScope(picked);
  }
}

/// "24 admitted · Unit A 13 · Unit B 10 · Unassigned 1" for the patients
/// of [wardId] (or all patients when null).
class UnitCountsLine extends StatelessWidget {
  const UnitCountsLine({super.key, required this.patients, this.wardId, this.noun = 'admitted'});

  final List<Patient> patients;
  final String? wardId;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitProvider>();
    final inWard = wardId == null ? patients : patients.where((p) => p.wardId == wardId).toList();
    final counts = UnitCounts.of(inWard.map((p) => p.unitId));
    final wardUnits = wardId == null ? const <WardUnit>[] : units.unitsOf(wardId!);
    final parts = <String>[
      '${counts.total} $noun',
      for (final u in wardUnits) '${u.name} ${counts.byUnit[u.id] ?? 0}',
      if (wardUnits.isNotEmpty && counts.unassigned > 0) 'Unassigned ${counts.unassigned}',
    ];
    return Text(
      parts.join(' · '),
      style: AppTypography.footnote(color: AppColors.textSecondary, weight: FontWeight.w600)
          .copyWith(fontFeatures: AppTypography.tabular),
    );
  }
}
