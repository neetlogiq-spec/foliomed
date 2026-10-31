/// Emergency and infusion drugs: the data shape and the arithmetic.
/// The list itself is in `drug_list.dart`; doses are decision support
/// only and every drug is signed off per ward (`WardDrugSettings`).
library;

/// Where a drug or dose applies.
enum CareSetting {
  nicu('NICU'),
  picu('PICU');

  const CareSetting(this.label);
  final String label;
}

/// Amount units. Values convert only within a group (mass, units).
enum Amount {
  mcg('mcg', _Group.mass, 1),
  mg('mg', _Group.mass, 1000),
  g('g', _Group.mass, 1000000),
  milliunits('milliunits', _Group.units, 1),
  units('units', _Group.units, 1000),
  mEq('mEq', _Group.mEq, 1),
  mL('mL', _Group.mL, 1);

  const Amount(this.label, this._group, this._factor);
  final String label;
  final _Group _group;
  final double _factor;

  /// [value] in this unit expressed in [to].
  double to(Amount to, double value) {
    if (to._group != _group) throw ArgumentError('Cannot convert $label to ${to.label}');
    return value * _factor / to._factor;
  }
}

enum _Group { mass, units, mEq, mL }

/// An infusion dose unit: amount per kg per minute or hour.
class RateUnit {
  const RateUnit(this.amount, {this.perMinute = false});
  final Amount amount;
  final bool perMinute;

  String get label => '${amount.label}/kg/${perMinute ? 'min' : 'h'}';

  /// Amount per hour (in [amount]) for [kg] at [dose].
  double perHour(double dose, double kg) => dose * kg * (perMinute ? 60 : 1);
}

const mcgKgMin = RateUnit(Amount.mcg, perMinute: true);
const mcgKgH = RateUnit(Amount.mcg);
const mgKgH = RateUnit(Amount.mg);
const unitsKgH = RateUnit(Amount.units);
const milliunitsKgMin = RateUnit(Amount.milliunits, perMinute: true);

/// A strength: [amount] of drug in 1 mL.
class Strength {
  const Strength(this.perMl, this.unit);
  final double perMl;
  final Amount unit;

  String get label {
    final singular = perMl == 1 && (unit == Amount.units || unit == Amount.milliunits);
    return '${trimNum(perMl)} ${singular ? unit.label.substring(0, unit.label.length - 1) : unit.label}/mL';
  }
}

/// A one-off dose for one use (e.g. "Cardiac arrest, IV/IO").
class BolusUse {
  const BolusUse({
    required this.label,
    required this.route,
    required this.min,
    required this.max,
    required this.unit,
    this.give,
    this.recipe,
    this.maxDose,
    this.repeat,
    this.note,
    this.settings = const {CareSetting.nicu, CareSetting.picu},
  });

  final String label;
  final String route;

  /// Dose range per kg in [unit] (min == max for a single dose).
  final double min, max;
  final Amount unit;

  /// The strength drawn up for this use, when not the vial (e.g. 1:10,000).
  final Strength? give;

  /// How to make [give] from the vial.
  final String? recipe;

  /// Largest single dose, in [unit].
  final double? maxDose;
  final String? repeat;
  final String? note;
  final Set<CareSetting> settings;
}

/// A continuous infusion: usual range and a starting mixture per setting.
class InfusionSpec {
  const InfusionSpec({
    required this.unit,
    required this.ranges,
    required this.mixAt1MlH,
    required this.diluent,
    this.dilutedStock,
    this.note,
  });

  final RateUnit unit;

  /// Usual dose range per setting, in [unit].
  final Map<CareSetting, (double, double)> ranges;

  /// The dose 1 mL/h gives in the 1× mixture, per setting — FolioMed's
  /// starting point; each ward can set its own (`WardDrugSettings`).
  final Map<CareSetting, double> mixAt1MlH;
  final String diluent;

  /// A weaker stock to draw from when the vial volume would be under
  /// 0.1 mL (e.g. insulin diluted to 1 unit/mL first), with its recipe.
  final (Strength, String)? dilutedStock;
  final String? note;
}

class Drug {
  const Drug({
    required this.key,
    required this.name,
    required this.category,
    required this.vial,
    required this.source,
    this.aka,
    this.boluses = const [],
    this.infusion,
  });

  /// Stable id, also stored with ward settings and running infusions.
  final String key;
  final String name;
  final String? aka;
  final String category;

  /// The usual vial; each ward can change it.
  final Strength vial;
  final List<BolusUse> boluses;
  final InfusionSpec? infusion;

  /// Where the doses come from, shown in the drug's details.
  final String source;

  Iterable<BolusUse> bolusesFor(CareSetting s) => boluses.where((b) => b.settings.contains(s));
  bool hasInfusionFor(CareSetting s) => infusion?.ranges.containsKey(s) ?? false;

  Drug withVial(Strength v) => Drug(
    key: key,
    name: name,
    aka: aka,
    category: category,
    vial: v,
    source: source,
    boluses: boluses,
    infusion: infusion,
  );
}

// ── Arithmetic ──────────────────────────────────────────────────────────

/// A worked one-off dose for a weight.
class BolusDose {
  const BolusDose({
    required this.low,
    required this.high,
    required this.unit,
    required this.volumeLow,
    required this.volumeHigh,
    required this.strength,
    required this.capped,
  });

  final double low, high;
  final Amount unit;

  /// mL of [strength] to give.
  final double volumeLow, volumeHigh;
  final Strength strength;

  /// The maximum single dose limited the result.
  final bool capped;

  bool get isRange => (high - low).abs() > 1e-9;
}

BolusDose bolusDose(BolusUse use, Drug drug, double kg) {
  final strength = use.give ?? drug.vial;
  double cap(double v) => use.maxDose == null || v <= use.maxDose! ? v : use.maxDose!;
  final low = cap(use.min * kg), high = cap(use.max * kg);
  final capped = use.maxDose != null && use.max * kg > use.maxDose! + 1e-9;
  double ml(double amount) => use.unit == Amount.mL ? amount : use.unit.to(strength.unit, amount) / strength.perMl;
  return BolusDose(
    low: low,
    high: high,
    unit: use.unit,
    volumeLow: ml(low),
    volumeHigh: ml(high),
    strength: strength,
    capped: capped,
  );
}

/// How a syringe is made up for one weight.
class Mixture {
  const Mixture({
    required this.totalAmount,
    required this.amountUnit,
    required this.drawMl,
    required this.drawFrom,
    required this.volumeMl,
    required this.concentration,
    required this.doseAt1MlH,
    this.stockRecipe,
  });

  /// Drug in the syringe, in [amountUnit] (the vial's unit).
  final double totalAmount;
  final Amount amountUnit;

  /// mL to draw from [drawFrom], then make up to [volumeMl].
  final double drawMl;
  final Strength drawFrom;
  final double volumeMl;

  /// Drug per mL of the finished syringe, in [amountUnit].
  final double concentration;
  final double doseAt1MlH;

  /// Set when the draw comes from a diluted stock rather than the vial.
  final String? stockRecipe;
}

/// The syringe for [kg] when 1 mL/h should give [doseAt1MlH] (in the
/// infusion's dose unit) in [volumeMl].
Mixture mixture({required Drug drug, required double kg, required double volumeMl, required double doseAt1MlH}) {
  final spec = drug.infusion!;
  final perHour = spec.unit.perHour(doseAt1MlH, kg); // dose unit per mL
  final conc = spec.unit.amount.to(drug.vial.unit, perHour);
  final total = conc * volumeMl;
  var from = drug.vial;
  String? recipe;
  var draw = total / from.perMl;
  final stock = spec.dilutedStock;
  if (draw < 0.1 && stock != null) {
    from = stock.$1;
    recipe = stock.$2;
    draw = drug.vial.unit.to(from.unit, total) / from.perMl;
  }
  return Mixture(
    totalAmount: total,
    amountUnit: drug.vial.unit,
    drawMl: draw,
    drawFrom: from,
    volumeMl: volumeMl,
    concentration: conc,
    doseAt1MlH: doseAt1MlH,
    stockRecipe: recipe,
  );
}

/// Pump rate (mL/h) for [dose] with a syringe of [concentration]
/// (vial unit per mL).
double rateFor({required Drug drug, required double dose, required double kg, required double concentration}) {
  final spec = drug.infusion!;
  final perHour = spec.unit.amount.to(drug.vial.unit, spec.unit.perHour(dose, kg));
  return perHour / concentration;
}

/// The dose a pump rate gives — the reverse of [rateFor].
double doseFor({required Drug drug, required double rateMlH, required double kg, required double concentration}) {
  final spec = drug.infusion!;
  final perHourVialUnit = rateMlH * concentration;
  final perHour = drug.vial.unit.to(spec.unit.amount, perHourVialUnit);
  return perHour / (kg * (spec.unit.perMinute ? 60 : 1));
}

/// Dose steps across a range for the rate table (about 5 rows, on round
/// numbers where the range allows).
List<double> doseSteps(double min, double max) {
  if (max <= min) return [min];
  final raw = (max - min) / 4;
  final mag = _pow10((raw).abs());
  final step = [1, 2, 2.5, 5, 10].map((m) => m * mag).firstWhere((s) => s >= raw * 0.999);
  final out = <double>[min];
  var v = (min / step).floor() * step + step;
  while (v < max - 1e-9) {
    if (v > min + 1e-9) out.add(_tidy(v));
    v += step;
  }
  out.add(max);
  return out;
}

double _pow10(double x) {
  var p = 1.0;
  while (p > x) {
    p /= 10;
  }
  while (p * 10 <= x) {
    p *= 10;
  }
  return p;
}

double _tidy(double v) => double.parse(v.toStringAsFixed(6));

/// Pump rates round to 0.1 mL/h; volumes to draw to 0.01 mL under 1 mL,
/// else 0.1 mL.
double roundRate(double mlH) => (mlH * 10).round() / 10;
double roundDraw(double ml) => ml < 1 ? (ml * 100).round() / 100 : (ml * 10).round() / 10;

/// "0.5", "12", "0.025" — no trailing zeros.
String trimNum(double v, [int maxDecimals = 3]) {
  var s = v.toStringAsFixed(maxDecimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}
