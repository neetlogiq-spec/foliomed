/// The drug list as one ward sees it: FolioMed's starter values with the
/// ward's own vial, mixture and note applied, and whether the dose content
/// shown now is what the ward signed off.
library;

import '../../models/ward.dart';
import '../../models/ward_drug_setting.dart';
import 'drug_list.dart';
import 'drug_model.dart';

/// The drug setting a ward type implies; null for wards with no default.
CareSetting? careForWard(WardKind kind) => switch (kind) {
  WardKind.nicu || WardKind.pnc => CareSetting.nicu,
  WardKind.picu || WardKind.paeds => CareSetting.picu,
  WardKind.adult || WardKind.other => null,
};

class WardDrug {
  const WardDrug({required this.drug, required this.setting, required this.signature, this.mixOverride});

  /// With the ward's vial applied.
  final Drug drug;
  final WardDrugSetting? setting;

  /// The ward's standard mixture (dose at 1 mL/h), if set.
  final double? mixOverride;

  /// Signature of the dose content shown (see [drugSignature]).
  final String signature;

  bool get hidden => setting?.hidden ?? false;
  String? get unitNote => setting?.unitNote;
  bool get isChecked => setting?.checkedSignature != null && setting!.checkedSignature == signature;

  /// Signed off once, but the list or the ward's settings changed since.
  bool get checkIsStale => setting?.checkedSignature != null && !isChecked;

  /// The 1× mixture for [s]: the ward's own, else FolioMed's.
  double? mixFor(CareSetting s) => mixOverride ?? drug.infusion?.mixAt1MlH[s];
}

WardDrug wardDrug(Drug base, WardDrugSetting? s) {
  final drug = s?.vialPerMl == null ? base : base.withVial(Strength(s!.vialPerMl!, base.vial.unit));
  return WardDrug(drug: drug, setting: s, mixOverride: s?.mixAt1MlH, signature: drugSignature(drug, s?.mixAt1MlH));
}

/// Every drug in the list for one ward ([settings] by drug key).
List<WardDrug> wardDrugs(Map<String, WardDrugSetting> settings) => [
  for (final d in kDrugs) wardDrug(d, settings[d.key]),
];

/// A short, stable fingerprint of everything a sign-off covers: vial, every
/// dose, limit, dilution and infusion range, and the mixture. FNV-1a over a
/// canonical text, so it is the same on every device and app build.
String drugSignature(Drug d, double? mixOverride) {
  String n(double v) => trimNum(v, 6);
  final b = StringBuffer('${d.key}|${n(d.vial.perMl)}${d.vial.unit.name}');
  for (final u in d.boluses) {
    b.write(
      '|${u.label}/${u.route}/${n(u.min)}-${n(u.max)}${u.unit.name}'
      '/${u.give == null ? '' : n(u.give!.perMl)}/${u.maxDose == null ? '' : n(u.maxDose!)}'
      '/${u.settings.map((s) => s.name).join(',')}',
    );
  }
  final inf = d.infusion;
  if (inf != null) {
    b.write('|inf/${inf.unit.label}');
    for (final s in CareSetting.values) {
      final r = inf.ranges[s];
      if (r != null) b.write('/${s.name}:${n(r.$1)}-${n(r.$2)}@${n(mixOverride ?? inf.mixAt1MlH[s]!)}');
    }
  }
  return 'v1-${fnv1a32(b.toString()).toRadixString(16).padLeft(8, '0')}';
}

/// 32-bit FNV-1a over UTF-16 code units. Every step stays under 2⁵³ (the
/// prime 16777619 = 2²⁴ + 403 is applied in two parts), so the web build,
/// where ints are JS numbers, gives the same result as native.
int fnv1a32(String text) {
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h = (h ^ c) % 0x100000000;
    h = ((h % 0x100) * 0x1000000 + h * 0x193) % 0x100000000;
  }
  return h;
}
