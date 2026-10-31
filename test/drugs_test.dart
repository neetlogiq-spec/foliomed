import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/tools/drugs/drug_list.dart';
import 'package:foliomed/models/ward.dart';
import 'package:foliomed/models/ward_drug_setting.dart';
import 'package:foliomed/tools/drugs/drug_model.dart';
import 'package:foliomed/tools/drugs/ward_drugs.dart';

Drug _d(String key) => drugByKey(key)!;
BolusUse _use(String key, CareSetting s, [int i = 0]) => _d(key).bolusesFor(s).elementAt(i);

void main() {
  group('units', () {
    test('convert within a group only', () {
      expect(Amount.mg.to(Amount.mcg, 1.5), 1500);
      expect(Amount.units.to(Amount.milliunits, 0.6), closeTo(600, 1e-9));
      expect(() => Amount.mg.to(Amount.units, 1), throwsArgumentError);
    });
    test('rate units per hour', () {
      expect(mcgKgMin.perHour(10, 2), 1200);
      expect(mcgKgH.perHour(10, 2), 20);
      expect(mcgKgMin.label, 'mcg/kg/min');
    });
  });

  group('one-off doses', () {
    test('newborn adrenaline: 3 kg → 0.03–0.09 mg = 0.3–0.9 mL of 1:10,000', () {
      final d = bolusDose(_use('adrenaline', CareSetting.nicu), _d('adrenaline'), 3);
      expect([d.low, d.high], [closeTo(0.03, 1e-9), closeTo(0.09, 1e-9)]);
      expect([d.volumeLow, d.volumeHigh], [closeTo(0.3, 1e-9), closeTo(0.9, 1e-9)]);
      expect(d.strength.perMl, 0.1);
      expect(d.capped, isFalse);
    });

    test('PICU arrest adrenaline caps at 1 mg', () {
      final d = bolusDose(_use('adrenaline', CareSetting.picu), _d('adrenaline'), 120);
      expect(d.high, 1);
      expect(d.volumeHigh, closeTo(10, 1e-9));
      expect(d.capped, isTrue);
    });

    test('mL-based doses: saline 10 mL/kg', () {
      final d = bolusDose(_use('saline', CareSetting.nicu), _d('saline'), 3);
      expect([d.low, d.volumeLow], [30, 30]);
    });

    test('drawn from the vial when no dilution is given (amiodarone 5 mg/kg of 50 mg/mL)', () {
      final d = bolusDose(_use('amiodarone', CareSetting.picu), _d('amiodarone'), 10);
      expect([d.low, d.volumeLow], [50, closeTo(1, 1e-9)]);
    });
  });

  group('infusions', () {
    test('newborn dopamine: 1 kg, 50 mL, 1 mL/h = 10 mcg/kg/min', () {
      final m = mixture(drug: _d('dopamine'), kg: 1, volumeMl: 50, doseAt1MlH: 10);
      expect(m.totalAmount, closeTo(30, 1e-9)); // mg
      expect(m.drawMl, closeTo(0.75, 1e-9)); // of 40 mg/mL
      expect(m.concentration, closeTo(0.6, 1e-9)); // mg/mL
      expect(rateFor(drug: _d('dopamine'), dose: 5, kg: 1, concentration: m.concentration), closeTo(0.5, 1e-9));
      expect(doseFor(drug: _d('dopamine'), rateMlH: 2, kg: 1, concentration: m.concentration), closeTo(20, 1e-9));
    });

    test('tiny insulin volumes switch to the diluted stock', () {
      final m = mixture(drug: _d('insulin'), kg: 1, volumeMl: 50, doseAt1MlH: 0.05);
      expect(m.totalAmount, closeTo(2.5, 1e-9)); // units
      expect(m.drawFrom.perMl, 1);
      expect(m.drawMl, closeTo(2.5, 1e-9));
      expect(m.stockRecipe, isNotNull);
      final big = mixture(drug: _d('insulin'), kg: 20, volumeMl: 50, doseAt1MlH: 0.02);
      expect(big.drawFrom.perMl, 100);
      expect(big.drawMl, closeTo(0.2, 1e-9));
    });

    test('vasopressin in milliunits from a units vial', () {
      final m = mixture(drug: _d('vasopressin'), kg: 20, volumeMl: 50, doseAt1MlH: 0.5);
      expect(m.totalAmount, closeTo(30, 1e-9)); // units
      expect(m.drawMl, closeTo(1.5, 1e-9));
      expect(rateFor(drug: _d('vasopressin'), dose: 1, kg: 20, concentration: m.concentration), closeTo(2, 1e-9));
    });

    test('mcg/kg/h drugs from a mg vial (morphine 20 mcg/kg/h at 1 mL/h)', () {
      final m = mixture(drug: _d('morphine'), kg: 2, volumeMl: 50, doseAt1MlH: 20);
      expect(m.totalAmount, closeTo(2, 1e-9)); // mg
      expect(m.drawMl, closeTo(0.2, 1e-9));
    });

    test('dose steps land on round numbers', () {
      expect(doseSteps(2, 20), [2, 5, 10, 15, 20]);
      expect(doseSteps(0.05, 1), [0.05, 0.25, 0.5, 0.75, 1]);
      expect(doseSteps(5, 5), [5]);
    });

    test('rounding: pump to 0.1 mL/h, draw to 0.01 mL under 1 mL', () {
      expect(roundRate(0.46), 0.5);
      expect(roundDraw(0.754), 0.75);
      expect(roundDraw(12.34), 12.3);
      expect(trimNum(0.050), '0.05');
      expect(trimNum(12), '12');
    });
  });

  group('list integrity', () {
    test('keys are unique and every drug cites a source', () {
      final keys = kDrugs.map((d) => d.key).toList();
      expect(keys.toSet().length, keys.length);
      for (final d in kDrugs) {
        expect(d.source.trim(), isNotEmpty, reason: d.key);
        expect(d.boluses.isNotEmpty || d.infusion != null, isTrue, reason: d.key);
      }
    });

    test('doses are sane: min ≤ max, dilutions have a recipe, ranges have a mixture', () {
      for (final d in kDrugs) {
        for (final b in d.boluses) {
          expect(b.min <= b.max, isTrue, reason: '${d.key} ${b.label}');
          expect((b.give == null) == (b.recipe == null), isTrue, reason: '${d.key} ${b.label}');
          if (b.give != null) expect(b.give!.unit, d.vial.unit, reason: d.key);
          if (b.unit != Amount.mL) expect(b.unit.to(d.vial.unit, 1), isPositive, reason: d.key);
        }
        final inf = d.infusion;
        if (inf != null) {
          expect(inf.ranges.keys.toSet(), inf.mixAt1MlH.keys.toSet(), reason: d.key);
          for (final r in inf.ranges.values) {
            expect(r.$1 < r.$2, isTrue, reason: d.key);
          }
          expect(inf.unit.amount.to(d.vial.unit, 1), isPositive, reason: d.key);
        }
      }
    });

    test('both settings have something in each mode', () {
      for (final s in CareSetting.values) {
        expect(drugsFor(s, infusions: false), isNotEmpty);
        expect(drugsFor(s, infusions: true), isNotEmpty);
      }
      expect(drugsFor(CareSetting.nicu, infusions: true).map((d) => d.key), contains('alprostadil'));
      expect(drugsFor(CareSetting.nicu, infusions: false).map((d) => d.key), isNot(contains('naloxone')));
    });
  });

  // Values settled against the reference texts (docs/DRUG_VERIFICATION.md).
  group('checked values', () {
    (double, double) r(String k, CareSetting s, [int i = 0]) {
      final b = _use(k, s, i);
      return (b.min, b.max);
    }

    test('newborn', () {
      expect(r('adrenaline', CareSetting.nicu), (0.01, 0.03));
      expect(r('adrenaline', CareSetting.nicu, 1), (0.05, 0.1));
      expect(r('atropine', CareSetting.nicu), (0.01, 0.03));
      expect(r('adenosine', CareSetting.nicu), (0.05, 0.1));
      expect(r('calcium_gluconate', CareSetting.nicu), (100, 200));
      expect(r('phenobarbitone', CareSetting.nicu), (20, 20));
      expect(r('levetiracetam', CareSetting.nicu), (40, 40));
      expect(r('phenytoin', CareSetting.nicu), (15, 20));
      expect(r('midazolam', CareSetting.nicu), (0.15, 0.15));
      final inf = {
        for (final d in kDrugs)
          if (d.infusion != null) d.key: d.infusion!.ranges[CareSetting.nicu],
      };
      expect(inf['dopamine'], (2, 20));
      expect(inf['dobutamine'], (2, 25));
      expect(inf['noradrenaline'], (0.2, 2));
      expect(inf['milrinone'], (0.3, 0.75));
      expect(inf['alprostadil'], (0.01, 0.1));
      expect(inf['morphine'], (10, 20));
      expect(inf['fentanyl'], (0.5, 2));
      expect(inf['midazolam'], (10, 60));
      expect(inf['insulin'], (0.01, 0.1));
    });

    test('PICU', () {
      expect(_use('adrenaline', CareSetting.picu).maxDose, 1);
      expect(_use('adrenaline', CareSetting.picu, 1).maxDose, 2.5);
      expect(_use('adrenaline', CareSetting.picu, 2).maxDose, 0.5);
      expect(_use('atropine', CareSetting.picu).maxDose, 0.5);
      expect(_use('adenosine', CareSetting.picu).maxDose, 6);
      expect(_use('adenosine', CareSetting.picu, 1).maxDose, 12);
      expect(_use('amiodarone', CareSetting.picu).maxDose, 300);
      expect(
        (r('calcium_gluconate', CareSetting.picu), _use('calcium_gluconate', CareSetting.picu).maxDose),
        ((100, 100), 3000),
      );
      expect(_use('calcium_chloride', CareSetting.picu).maxDose, 2000);
      expect(_use('naloxone', CareSetting.picu).maxDose, 2);
      expect(r('magnesium', CareSetting.picu), (25, 75));
      expect(r('rocuronium', CareSetting.picu), (0.6, 1.2));
      expect(r('phenytoin', CareSetting.picu), (15, 20));
      expect(_use('phenobarbitone', CareSetting.picu).maxDose, 1000);
      expect(_use('levetiracetam', CareSetting.picu).maxDose, 4500);
      final inf = {
        for (final d in kDrugs)
          if (d.infusion != null) d.key: d.infusion!.ranges[CareSetting.picu],
      };
      expect(inf['dobutamine'], (2.5, 15));
      expect(inf['noradrenaline'], (0.05, 2));
      expect(inf['milrinone'], (0.25, 0.75));
      expect(inf['fentanyl'], (1, 3));
      expect(inf['dexmedetomidine'], (0.2, 1));
      expect(inf['amiodarone'], (5, 15));
      expect(inf['vasopressin'], (0.3, 2));
    });
  });

  group('ward sign-off', () {
    test('FNV-1a matches the published test vectors (same on web and native)', () {
      expect(fnv1a32(''), 0x811c9dc5);
      expect(fnv1a32('a'), 0xe40c292c);
      expect(fnv1a32('foobar'), 0xbf9cf968);
    });

    WardDrugSetting setting({double? vial, double? mix, String? sig}) =>
        WardDrugSetting(wardId: '11111', drugKey: 'dopamine', vialPerMl: vial, mixAt1MlH: mix, checkedSignature: sig);

    test('a sign-off holds while nothing changes, lapses when the vial or syringe does', () {
      final plain = wardDrug(_d('dopamine'), null);
      expect(plain.isChecked, isFalse);
      final checked = wardDrug(_d('dopamine'), setting(sig: plain.signature));
      expect(checked.isChecked, isTrue);
      expect(checked.checkIsStale, isFalse);
      final newVial = wardDrug(_d('dopamine'), setting(vial: 80, sig: plain.signature));
      expect(newVial.drug.vial.perMl, 80);
      expect(newVial.isChecked, isFalse);
      expect(newVial.checkIsStale, isTrue);
      final newMix = wardDrug(_d('dopamine'), setting(mix: 5, sig: plain.signature));
      expect(newMix.mixFor(CareSetting.nicu), 5);
      expect(newMix.isChecked, isFalse);
    });

    test('every drug has its own signature, and any dose change alters it', () {
      final sigs = kDrugs.map((d) => drugSignature(d, null)).toSet();
      expect(sigs.length, kDrugs.length);
      final d = _d('adenosine');
      final tweaked = Drug(
        key: d.key,
        name: d.name,
        category: d.category,
        vial: d.vial,
        source: d.source,
        boluses: [
          for (final b in d.boluses)
            BolusUse(label: b.label, route: b.route, min: b.min, max: b.max + 0.01, unit: b.unit, settings: b.settings),
        ],
      );
      expect(drugSignature(tweaked, null), isNot(drugSignature(d, null)));
    });

    test('ward types map to a drug setting', () {
      expect(careForWard(WardKind.nicu), CareSetting.nicu);
      expect(careForWard(WardKind.pnc), CareSetting.nicu);
      expect(careForWard(WardKind.picu), CareSetting.picu);
      expect(careForWard(WardKind.paeds), CareSetting.picu);
      expect(careForWard(WardKind.adult), isNull);
    });
  });
}
