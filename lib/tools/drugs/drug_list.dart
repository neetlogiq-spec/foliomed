/// FolioMed's starter list of emergency and infusion drugs for NICU and
/// PICU. Doses follow the published resuscitation, seizure and DKA
/// guidelines named in each `source`; infusion ranges are the usual
/// ranges in standard neonatal and paediatric practice. Every drug is
/// unchecked until a ward signs it off (see docs/DRUG_VERIFICATION.md),
/// and vials and mixtures can be changed per ward.
library;

import 'drug_model.dart';

const _nrp = 'AHA/AAP neonatal resuscitation guideline 2020 (Circulation 2020;142:S524).';
const _pals = 'AHA paediatric advanced life support guideline 2020 (Circulation 2020;142:S469).';
const _seizures =
    'WHO guidelines on neonatal seizures 2011; American Epilepsy Society status epilepticus '
    'guideline 2016 (Epilepsy Curr 2016;16:48).';
const _usual = 'Usual range in standard neonatal and paediatric practice — set your unit\'s own.';
const _nicu = {CareSetting.nicu};
const _picu = {CareSetting.picu};

const _dilute = 'Glucose 5% or sodium chloride 0.9%';

const List<Drug> kDrugs = [
  // ── Resuscitation ──
  Drug(
    key: 'adrenaline',
    name: 'Adrenaline',
    aka: 'Epinephrine',
    category: 'Resuscitation',
    vial: Strength(1, Amount.mg),
    source: '$_nrp $_pals Anaphylaxis: World Allergy Organization guidance 2020.',
    boluses: [
      BolusUse(
        label: 'Resuscitation',
        route: 'IV / UVC / IO',
        min: 0.01,
        max: 0.03,
        unit: Amount.mg,
        give: Strength(0.1, Amount.mg),
        recipe: '1 mL of 1 mg/mL + 9 mL sodium chloride 0.9% = 0.1 mg/mL (1:10,000)',
        repeat: 'Every 3–5 min',
        note: 'Follow each dose with a saline flush.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Resuscitation',
        route: 'Endotracheal',
        min: 0.05,
        max: 0.1,
        unit: Amount.mg,
        give: Strength(0.1, Amount.mg),
        recipe: '1 mL of 1 mg/mL + 9 mL sodium chloride 0.9% = 0.1 mg/mL (1:10,000)',
        repeat: 'Every 3–5 min',
        note: 'Only while IV access is being set up.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Cardiac arrest',
        route: 'IV / IO',
        min: 0.01,
        max: 0.01,
        unit: Amount.mg,
        give: Strength(0.1, Amount.mg),
        recipe: '1 mL of 1 mg/mL + 9 mL sodium chloride 0.9% = 0.1 mg/mL (1:10,000)',
        maxDose: 1,
        repeat: 'Every 3–5 min',
        settings: _picu,
      ),
      BolusUse(
        label: 'Cardiac arrest',
        route: 'Endotracheal',
        min: 0.1,
        max: 0.1,
        unit: Amount.mg,
        maxDose: 2.5,
        repeat: 'Every 3–5 min',
        note: 'Undiluted 1 mg/mL. Only until IV/IO access.',
        settings: _picu,
      ),
      BolusUse(
        label: 'Anaphylaxis',
        route: 'IM (outer thigh)',
        min: 0.01,
        max: 0.01,
        unit: Amount.mg,
        maxDose: 0.5,
        repeat: 'After 5 min if no better',
        note: 'Undiluted 1 mg/mL.',
        settings: _picu,
      ),
    ],
    infusion: InfusionSpec(
      unit: mcgKgMin,
      ranges: {CareSetting.nicu: (0.05, 1), CareSetting.picu: (0.05, 1)},
      mixAt1MlH: {CareSetting.nicu: 0.5, CareSetting.picu: 0.1},
      diluent: _dilute,
      note: 'Central line preferred.',
    ),
  ),
  Drug(
    key: 'saline',
    name: 'Sodium chloride 0.9%',
    aka: 'Normal saline',
    category: 'Fluids',
    vial: Strength(1, Amount.mL),
    source: '$_nrp $_pals',
    boluses: [
      BolusUse(
        label: 'Volume expansion',
        route: 'IV / UVC / IO',
        min: 10,
        max: 10,
        unit: Amount.mL,
        repeat: 'Reassess; repeat if needed',
        note: 'Over 5–10 min.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Shock',
        route: 'IV / IO',
        min: 10,
        max: 20,
        unit: Amount.mL,
        repeat: 'Reassess after each bolus',
        note: 'Over 5–20 min; stop if signs of fluid overload.',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'glucose10',
    name: 'Glucose 10%',
    aka: 'Dextrose 10%',
    category: 'Metabolic',
    vial: Strength(1, Amount.mL),
    source: 'AAP Committee on Fetus and Newborn, Pediatrics 2011 (newborn). $_pals',
    boluses: [
      BolusUse(
        label: 'Low blood glucose',
        route: 'IV',
        min: 2,
        max: 2,
        unit: Amount.mL,
        note: '200 mg/kg over 5–10 min, then raise the glucose infusion. Recheck in 30 min.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Low blood glucose',
        route: 'IV / IO',
        min: 5,
        max: 10,
        unit: Amount.mL,
        note: '0.5–1 g/kg. Recheck glucose after.',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'calcium_gluconate',
    name: 'Calcium gluconate 10%',
    category: 'Metabolic',
    vial: Strength(100, Amount.mg),
    source: 'Standard neonatal and paediatric dosing — check against your unit formulary.',
    boluses: [
      BolusUse(
        label: 'Symptomatic low calcium',
        route: 'IV',
        min: 100,
        max: 200,
        unit: Amount.mg,
        note:
            'Over at least 5–10 min with heart-rate monitoring, diluted 1:1. Never in the same line as bicarbonate; '
            'watch the cannula — extravasation burns.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Arrest / low calcium / high potassium',
        route: 'IV / IO',
        min: 100,
        max: 100,
        unit: Amount.mg,
        maxDose: 3000,
        note: 'Slowly with ECG monitoring (no faster than 100 mg/min outside arrest).',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'calcium_chloride',
    name: 'Calcium chloride 10%',
    category: 'Metabolic',
    vial: Strength(100, Amount.mg),
    source: _pals,
    boluses: [
      BolusUse(
        label: 'Arrest with low calcium / high potassium',
        route: 'IV / IO',
        min: 20,
        max: 20,
        unit: Amount.mg,
        maxDose: 2000,
        note: 'Slow push; central line preferred.',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'sodium_bicarbonate',
    name: 'Sodium bicarbonate 8.4%',
    category: 'Metabolic',
    vial: Strength(1, Amount.mEq),
    source: '$_nrp $_pals Not routine in resuscitation.',
    boluses: [
      BolusUse(
        label: 'Severe metabolic acidosis',
        route: 'IV',
        min: 1,
        max: 2,
        unit: Amount.mEq,
        give: Strength(0.5, Amount.mEq),
        recipe: 'Equal volumes of 8.4% and water for injection = 4.2% (0.5 mEq/mL)',
        note: 'Slowly over at least 2 min, only once breathing is supported.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Severe acidosis / high potassium',
        route: 'IV / IO',
        min: 1,
        max: 1,
        unit: Amount.mEq,
        maxDose: 50,
        note: 'Slow push; dilute 1:1 for infants. Flush before and after.',
        settings: _picu,
      ),
    ],
  ),
  // ── Rhythm ──
  Drug(
    key: 'atropine',
    name: 'Atropine',
    category: 'Rhythm',
    vial: Strength(0.6, Amount.mg),
    source: _pals,
    boluses: [
      BolusUse(
        label: 'Bradycardia (vagal / AV block)',
        route: 'IV / IM / ET',
        min: 0.01,
        max: 0.03,
        unit: Amount.mg,
        give: Strength(0.1, Amount.mg),
        recipe: '1 mL (0.6 mg) + 5 mL sodium chloride 0.9% = 0.1 mg/mL',
        repeat: 'Every 10–15 min; no more than 0.04 mg/kg in total',
        note: 'IV over 1 min.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Bradycardia (vagal / AV block)',
        route: 'IV / IO',
        min: 0.02,
        max: 0.02,
        unit: Amount.mg,
        maxDose: 0.5,
        repeat: 'Every 5 min, 2–3 doses at most',
        note: 'Adolescents: up to 1 mg per dose.',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'adenosine',
    name: 'Adenosine',
    category: 'Rhythm',
    vial: Strength(3, Amount.mg),
    source: _pals,
    boluses: [
      BolusUse(
        label: 'SVT',
        route: 'IV, rapid push',
        min: 0.05,
        max: 0.1,
        unit: Amount.mg,
        give: Strength(0.3, Amount.mg),
        recipe: '1 mL (3 mg) + 9 mL sodium chloride 0.9% = 0.3 mg/mL',
        repeat: 'Increase by 0.05–0.1 mg/kg every 2 min, up to 0.3 mg/kg',
        note: 'Fast saline flush straight after; ECG running.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'SVT — first dose',
        route: 'IV / IO, rapid push',
        min: 0.1,
        max: 0.1,
        unit: Amount.mg,
        maxDose: 6,
        note: 'Fast saline flush straight after; ECG running.',
        settings: _picu,
      ),
      BolusUse(
        label: 'SVT — second dose',
        route: 'IV / IO, rapid push',
        min: 0.2,
        max: 0.2,
        unit: Amount.mg,
        maxDose: 12,
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'amiodarone',
    name: 'Amiodarone',
    category: 'Rhythm',
    vial: Strength(50, Amount.mg),
    source: _pals,
    boluses: [
      BolusUse(
        label: 'Arrest — VF / pulseless VT',
        route: 'IV / IO',
        min: 5,
        max: 5,
        unit: Amount.mg,
        maxDose: 300,
        repeat: 'Up to 3 doses (15 mg/kg) in total',
        settings: _picu,
      ),
      BolusUse(
        label: 'Tachycardia with a pulse',
        route: 'IV / IO',
        min: 5,
        max: 5,
        unit: Amount.mg,
        maxDose: 300,
        note: 'Over 20–60 min; expert advice first.',
        settings: _picu,
      ),
    ],
    infusion: InfusionSpec(
      unit: mcgKgMin,
      ranges: {CareSetting.picu: (5, 15)},
      mixAt1MlH: {CareSetting.picu: 1},
      diluent: 'Glucose 5% only',
      note: 'Above 2 mg/mL use a central line.',
    ),
  ),
  // ── Inotropes and vasoactives ──
  Drug(
    key: 'dopamine',
    name: 'Dopamine',
    category: 'Inotrope',
    vial: Strength(40, Amount.mg),
    source: _usual,
    infusion: InfusionSpec(
      unit: mcgKgMin,
      ranges: {CareSetting.nicu: (2, 20), CareSetting.picu: (2, 20)},
      mixAt1MlH: {CareSetting.nicu: 10, CareSetting.picu: 2},
      diluent: _dilute,
      note: 'Central line preferred; extravasation causes tissue injury.',
    ),
  ),
  Drug(
    key: 'dobutamine',
    name: 'Dobutamine',
    category: 'Inotrope',
    vial: Strength(50, Amount.mg),
    source: _usual,
    infusion: InfusionSpec(
      unit: mcgKgMin,
      ranges: {CareSetting.nicu: (2, 25), CareSetting.picu: (2.5, 15)},
      mixAt1MlH: {CareSetting.nicu: 10, CareSetting.picu: 2},
      diluent: _dilute,
      note: 'Vials vary (12.5 or 50 mg/mL) — check yours.',
    ),
  ),
  Drug(
    key: 'noradrenaline',
    name: 'Noradrenaline',
    aka: 'Norepinephrine',
    category: 'Vasoactive',
    vial: Strength(1, Amount.mg),
    source: _usual,
    infusion: InfusionSpec(
      unit: mcgKgMin,
      ranges: {CareSetting.nicu: (0.2, 2), CareSetting.picu: (0.05, 2)},
      mixAt1MlH: {CareSetting.nicu: 0.5, CareSetting.picu: 0.1},
      diluent: 'Glucose 5% (or sodium chloride 0.9%)',
      note: 'Vials may be labelled as the salt (2 mg/mL tartrate = 1 mg/mL base). Central line preferred.',
    ),
  ),
  Drug(
    key: 'milrinone',
    name: 'Milrinone',
    category: 'Inotrope',
    vial: Strength(1, Amount.mg),
    source: _usual,
    infusion: InfusionSpec(
      unit: mcgKgMin,
      ranges: {CareSetting.nicu: (0.3, 0.75), CareSetting.picu: (0.25, 0.75)},
      mixAt1MlH: {CareSetting.nicu: 0.5, CareSetting.picu: 0.5},
      diluent: _dilute,
      note: 'Watch blood pressure; reduce in kidney impairment.',
    ),
  ),
  Drug(
    key: 'vasopressin',
    name: 'Vasopressin',
    category: 'Vasoactive',
    vial: Strength(20, Amount.units),
    source: _usual,
    infusion: InfusionSpec(
      unit: milliunitsKgMin,
      ranges: {CareSetting.picu: (0.3, 2)},
      mixAt1MlH: {CareSetting.picu: 0.5},
      diluent: _dilute,
    ),
  ),
  Drug(
    key: 'alprostadil',
    name: 'Alprostadil',
    aka: 'Prostaglandin E1',
    category: 'Duct',
    vial: Strength(500, Amount.mcg),
    source: _usual,
    infusion: InfusionSpec(
      unit: mcgKgMin,
      ranges: {CareSetting.nicu: (0.01, 0.1)},
      mixAt1MlH: {CareSetting.nicu: 0.05},
      diluent: _dilute,
      note: 'Apnoea is common, more so at higher doses — be ready to ventilate.',
    ),
  ),
  // ── Sedation and pain ──
  Drug(
    key: 'morphine',
    name: 'Morphine',
    category: 'Sedation & pain',
    vial: Strength(10, Amount.mg),
    source: _usual,
    infusion: InfusionSpec(
      unit: mcgKgH,
      ranges: {CareSetting.nicu: (10, 20), CareSetting.picu: (10, 40)},
      mixAt1MlH: {CareSetting.nicu: 20, CareSetting.picu: 20},
      diluent: _dilute,
      note: 'Breathing slows — monitor and have naloxone ready.',
    ),
  ),
  Drug(
    key: 'fentanyl',
    name: 'Fentanyl',
    category: 'Sedation & pain',
    vial: Strength(50, Amount.mcg),
    source: _usual,
    boluses: [
      BolusUse(
        label: 'Intubation / procedure',
        route: 'IV, slowly',
        min: 1,
        max: 2,
        unit: Amount.mcg,
        note: 'Over 3–5 min — fast doses cause chest-wall rigidity.',
      ),
    ],
    infusion: InfusionSpec(
      unit: mcgKgH,
      ranges: {CareSetting.nicu: (0.5, 2), CareSetting.picu: (1, 3)},
      mixAt1MlH: {CareSetting.nicu: 1, CareSetting.picu: 1},
      diluent: _dilute,
    ),
  ),
  Drug(
    key: 'midazolam',
    name: 'Midazolam',
    category: 'Sedation & pain',
    vial: Strength(5, Amount.mg),
    source: '$_usual Seizures: $_seizures',
    boluses: [
      BolusUse(
        label: 'Seizures — loading',
        route: 'IV',
        min: 0.15,
        max: 0.15,
        unit: Amount.mg,
        note: 'Then an infusion of 60–400 mcg/kg/h if seizures continue.',
        settings: _nicu,
      ),
      BolusUse(label: 'Sedation', route: 'IV, slowly', min: 0.05, max: 0.15, unit: Amount.mg, settings: _nicu),
      BolusUse(
        label: 'Seizures',
        route: 'IV / IO',
        min: 0.15,
        max: 0.2,
        unit: Amount.mg,
        maxDose: 10,
        repeat: 'Once after 5 min',
        settings: _picu,
      ),
    ],
    infusion: InfusionSpec(
      unit: mcgKgH,
      ranges: {CareSetting.nicu: (10, 60), CareSetting.picu: (60, 240)},
      mixAt1MlH: {CareSetting.nicu: 30, CareSetting.picu: 60},
      diluent: _dilute,
      note:
          'Sedation range shown; seizures need 60–400 mcg/kg/h (NICU). Low blood pressure, especially in preterm babies.',
    ),
  ),
  Drug(
    key: 'dexmedetomidine',
    name: 'Dexmedetomidine',
    category: 'Sedation & pain',
    vial: Strength(100, Amount.mcg),
    source: _usual,
    infusion: InfusionSpec(
      unit: mcgKgH,
      ranges: {CareSetting.picu: (0.2, 1)},
      mixAt1MlH: {CareSetting.picu: 0.2},
      diluent: 'Sodium chloride 0.9%',
      note: 'Slow heart rate and low blood pressure.',
    ),
  ),
  Drug(
    key: 'naloxone',
    name: 'Naloxone',
    category: 'Sedation & pain',
    vial: Strength(0.4, Amount.mg),
    source: _pals,
    boluses: [
      BolusUse(
        label: 'Opioid overdose',
        route: 'IV / IO / IM',
        min: 0.1,
        max: 0.1,
        unit: Amount.mg,
        maxDose: 2,
        repeat: 'Every 2–3 min if needed',
        note: 'Not part of newborn resuscitation.',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'ketamine',
    name: 'Ketamine',
    category: 'Intubation',
    vial: Strength(50, Amount.mg),
    source: 'Standard paediatric intubation dosing — check against your unit formulary.',
    boluses: [BolusUse(label: 'Intubation', route: 'IV', min: 1, max: 2, unit: Amount.mg, settings: _picu)],
  ),
  Drug(
    key: 'rocuronium',
    name: 'Rocuronium',
    category: 'Intubation',
    vial: Strength(10, Amount.mg),
    source: 'Standard paediatric intubation dosing — check against your unit formulary.',
    boluses: [
      BolusUse(
        label: 'Intubation',
        route: 'IV',
        min: 0.6,
        max: 1.2,
        unit: Amount.mg,
        note: 'Only with airway skills and ventilation ready.',
        settings: _picu,
      ),
    ],
  ),
  // ── Seizures ──
  Drug(
    key: 'phenobarbitone',
    name: 'Phenobarbitone',
    aka: 'Phenobarbital',
    category: 'Seizures',
    vial: Strength(200, Amount.mg),
    source: _seizures,
    boluses: [
      BolusUse(
        label: 'Seizures — loading',
        route: 'IV over 20 min',
        min: 20,
        max: 20,
        unit: Amount.mg,
        give: Strength(20, Amount.mg),
        recipe: '1 mL (200 mg) + 9 mL water for injection = 20 mg/mL',
        repeat: 'Further 10 mg/kg doses, up to 40 mg/kg in total',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Status epilepticus',
        route: 'IV over 20 min',
        min: 15,
        max: 20,
        unit: Amount.mg,
        give: Strength(20, Amount.mg),
        recipe: '1 mL (200 mg) + 9 mL water for injection = 20 mg/mL',
        maxDose: 1000,
        repeat: 'Further 5 mg/kg every 15–30 min, up to 40 mg/kg in total',
        note: 'Watch breathing and blood pressure.',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'levetiracetam',
    name: 'Levetiracetam',
    category: 'Seizures',
    vial: Strength(100, Amount.mg),
    source: '$_seizures ESETT trial (N Engl J Med 2019;381:2103).',
    boluses: [
      BolusUse(
        label: 'Seizures — loading',
        route: 'IV over 15 min',
        min: 40,
        max: 40,
        unit: Amount.mg,
        repeat: 'A further 20 mg/kg if seizures continue',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Status epilepticus',
        route: 'IV over 10–15 min',
        min: 60,
        max: 60,
        unit: Amount.mg,
        maxDose: 4500,
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'phenytoin',
    name: 'Phenytoin',
    category: 'Seizures',
    vial: Strength(50, Amount.mg),
    source: _seizures,
    boluses: [
      BolusUse(
        label: 'Seizures — loading',
        route: 'IV, no faster than 1 mg/kg/min',
        min: 15,
        max: 20,
        unit: Amount.mg,
        note: 'Sodium chloride 0.9% only; flush before and after; ECG running.',
        settings: _nicu,
      ),
      BolusUse(
        label: 'Status epilepticus',
        route: 'IV, no faster than 1 mg/kg/min (max 50 mg/min)',
        min: 15,
        max: 20,
        unit: Amount.mg,
        maxDose: 1500,
        note: 'Sodium chloride 0.9% only; ECG running.',
        settings: _picu,
      ),
    ],
  ),
  // ── Other ──
  Drug(
    key: 'insulin',
    name: 'Insulin (soluble)',
    category: 'Metabolic',
    vial: Strength(100, Amount.units),
    source: 'Newborn hyperglycaemia: usual neonatal range. DKA: ISPAD Clinical Practice Consensus Guidelines 2022.',
    infusion: InfusionSpec(
      unit: unitsKgH,
      ranges: {CareSetting.nicu: (0.01, 0.1), CareSetting.picu: (0.05, 0.1)},
      mixAt1MlH: {CareSetting.nicu: 0.05, CareSetting.picu: 0.02},
      diluent: 'Sodium chloride 0.9%',
      dilutedStock: (
        Strength(1, Amount.units),
        '1 mL (100 units) made up to 100 mL with sodium chloride 0.9% = 1 unit/mL',
      ),
      note: 'Prime the line with the solution. Check glucose hourly at first. DKA: start 1–2 h after fluids.',
    ),
  ),
  Drug(
    key: 'hypertonic_saline',
    name: 'Sodium chloride 3%',
    aka: 'Hypertonic saline',
    category: 'Fluids',
    vial: Strength(1, Amount.mL),
    source: 'Brain Trauma Foundation paediatric guidelines 2019.',
    boluses: [
      BolusUse(
        label: 'Raised intracranial pressure',
        route: 'IV over 10–20 min',
        min: 2,
        max: 5,
        unit: Amount.mL,
        note: 'Check sodium after.',
        settings: _picu,
      ),
    ],
  ),
  Drug(
    key: 'magnesium',
    name: 'Magnesium sulphate 50%',
    category: 'Other',
    vial: Strength(500, Amount.mg),
    source: 'Standard paediatric acute asthma dosing (GINA / BTS-SIGN) — check against your unit formulary.',
    boluses: [
      BolusUse(
        label: 'Severe asthma',
        route: 'IV over 20 min',
        min: 25,
        max: 75,
        unit: Amount.mg,
        give: Strength(100, Amount.mg),
        recipe: '1 mL of 50% + 4 mL sodium chloride 0.9% = 100 mg/mL (10%)',
        maxDose: 2000,
        note: 'Watch for low blood pressure.',
        settings: _picu,
      ),
    ],
  ),
];

Drug? drugByKey(String key) {
  for (final d in kDrugs) {
    if (d.key == key) return d;
  }
  return null;
}

/// Drugs with something for [s], in list order.
List<Drug> drugsFor(CareSetting s, {required bool infusions}) => [
  for (final d in kDrugs)
    if (infusions ? d.hasInfusionFor(s) : d.bolusesFor(s).isNotEmpty) d,
];

/// The weight to dose by: the latest recorded weight, else birth weight
/// (grams → kg). Null when neither is known.
double? dosingWeightKg({int? latestGrams, int? birthGrams}) {
  final g = latestGrams ?? birthGrams;
  return g == null ? null : g / 1000;
}

/// FolioMed's default vial strength for [key] (per mL).
double? drugBaseVial(String key) => drugByKey(key)?.vial.perMl;
