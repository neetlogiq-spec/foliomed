import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_user.dart';
import '../../../models/ward.dart';
import '../../../models/ward_drug_setting.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/unit_provider.dart';
import '../../../services/drug_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/ward_service.dart';
import '../../../tools/drugs/drug_model.dart';
import '../../../tools/drugs/ward_drugs.dart';
import '../../../utils/stream_cache.dart';

/// Which ward's drug settings apply, and the list as that ward sees it.
class DrugScope {
  const DrugScope({required this.wards, required this.ward, required this.settings, required this.canSignOff});
  const DrugScope.none() : this(wards: const [], ward: null, settings: const {}, canSignOff: false);

  final List<Ward> wards;
  final Ward? ward;
  final Map<String, WardDrugSetting> settings;

  /// The user may sign drugs off for [ward] (its doctors and owner).
  final bool canSignOff;

  List<WardDrug> get drugs => wardDrugs(settings);
  WardDrug drug(Drug d) => wardDrug(d, settings[d.key]);
  bool get isOwner => ward != null && ward!.ownedBy(supabase.auth.currentUser?.id ?? '');
  CareSetting? get care => ward == null ? null : careForWard(ward!.kind);
}

/// Loads the user's wards and the chosen ward's drug settings. Starts with
/// [preferWardId] (e.g. the picked baby's ward), else the ward in scope,
/// else the primary ward. Works without a signed-in account (tests,
/// configuration screens): then there are no ward settings.
class DrugScopeBuilder extends StatefulWidget {
  const DrugScopeBuilder({super.key, required this.builder, this.preferWardId});
  final String? preferWardId;
  final Widget Function(BuildContext context, DrugScope scope, ValueChanged<Ward> pickWard) builder;

  @override
  State<DrugScopeBuilder> createState() => _DrugScopeBuilderState();
}

class _DrugScopeBuilderState extends State<DrugScopeBuilder> {
  final _wardStreams = StreamCache<List<Ward>>();
  final _settingStreams = StreamCache<Map<String, WardDrugSetting>>();
  String? _picked;

  AppUser? _user() {
    try {
      return context.watch<AccountProvider>().currentUser;
    } on ProviderNotFoundException {
      return null;
    }
  }

  String? _scopeWard() {
    try {
      return context.read<UnitProvider>().scope.wardId;
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user();
    final ids = user?.wards ?? const <String>[];
    if (user == null || ids.isEmpty) return widget.builder(context, const DrugScope.none(), (_) {});
    return StreamBuilder<List<Ward>>(
      stream: _wardStreams.get(ids.join(','), () => WardService().wardsForUser(ids)),
      builder: (context, ws) {
        final wards = [...?ws.data]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (wards.isEmpty) return widget.builder(context, const DrugScope.none(), (_) {});
        Ward? find(String? id) => id == null ? null : wards.where((w) => w.id == id).firstOrNull;
        final ward =
            find(_picked) ?? find(widget.preferWardId) ?? find(_scopeWard()) ?? find(user.primaryWard) ?? wards.first;
        void pick(Ward w) => setState(() => _picked = w.id);
        return StreamBuilder<Map<String, WardDrugSetting>>(
          stream: _settingStreams.get(ward.id, () => DrugService().watchWard(ward.id)),
          builder: (context, ss) => widget.builder(
            context,
            DrugScope(
              wards: wards,
              ward: ward,
              settings: ss.data ?? const {},
              canSignOff: user.role == UserRole.doctor || ward.ownedBy(user.uid),
            ),
            pick,
          ),
        );
      },
    );
  }
}
