/// FolioMed's emergency guides, in our own words from the public
/// guidelines named in each `source`. Decision support only; every guide
/// shows the unit sign-off banner until checked (docs/TOOLS_VERIFICATION.md).
library;

import 'guide_model.dart';

const kGuides = <Guide>[
  // ── Anaphylaxis ──
  Guide(
    key: 'anaphylaxis',
    title: 'Anaphylaxis',
    subtitle: 'IM adrenaline first, then airway, breathing, circulation',
    source:
        'Resuscitation Council UK, Emergency treatment of anaphylaxis (2021); World Allergy Organization '
        'anaphylaxis guidance (2020).',
    redFlags: [
      'Sudden airway swelling, hoarse voice or stridor',
      'Wheeze, breathlessness, SpO₂ falling',
      'Pale, floppy, low blood pressure, collapse',
    ],
    steps: [
      GuideStep(
        'Call for help, remove the trigger',
        points: [
          'Stop any infusion that may be the cause.',
          'Lie flat with legs raised; sit up if breathing is hard. Don’t stand or walk them.',
        ],
      ),
      GuideStep(
        'IM adrenaline — now',
        when: '0 min',
        points: [
          'Undiluted 1 mg/mL (1:1000) into the outer thigh.',
          'By age if the weight is unknown: under 6 months 100–150 mcg; 6 months–6 years 150 mcg; '
              '6–12 years 300 mcg; over 12 years 500 mcg.',
          'Repeat after 5 minutes if not better.',
        ],
        doses: [GuideDose('Adrenaline IM', 0.01, 0.01, 'mg', maxDose: 0.5, how: '1 mg/mL into the thigh')],
      ),
      GuideStep(
        'Oxygen and fluids',
        points: [
          'High-flow oxygen.',
          'IV or IO access; fluid bolus if circulation is poor. Repeat as needed.',
          'Wheeze: give salbutamol as well.',
        ],
        doses: [GuideDose('Crystalloid bolus', 10, 10, 'mL', how: 'IV / IO, reassess')],
      ),
      GuideStep(
        'Not better after two IM doses',
        when: '10 min',
        points: [
          'Refractory anaphylaxis: get senior and critical-care help.',
          'Start an adrenaline infusion (Infusion Rate → Adrenaline) and keep giving fluids.',
        ],
      ),
      GuideStep(
        'Afterwards',
        points: [
          'A non-sedating antihistamine can help skin symptoms; steroids are not first-line treatment.',
          'Mast cell tryptase: soon after, at 1–2 hours and after 24 hours.',
          'Observe (at least 6–12 hours depending on severity); adrenaline auto-injector and allergy referral.',
          'Record the allergy on the patient’s record.',
        ],
      ),
    ],
  ),
  // ── Status epilepticus ──
  Guide(
    key: 'status_epilepticus',
    title: 'Status Epilepticus',
    subtitle: 'Benzodiazepine, then a second-line drug by 20 minutes',
    source:
        'American Epilepsy Society guideline on convulsive status epilepticus (Epilepsy Curr 2016;16:48); '
        'ESETT trial (N Engl J Med 2019;381:2103). Newborns: see NICU Emergency Drugs (phenobarbitone first).',
    redFlags: ['Seizure 5 minutes or longer, or repeated seizures without recovery between them'],
    steps: [
      GuideStep(
        'Stabilise',
        when: '0–5 min',
        points: [
          'Airway, oxygen, recovery position; time the seizure.',
          'Check blood glucose and treat if low (Low Blood Glucose tool).',
          'IV or IO access; send glucose, electrolytes, calcium, magnesium, gas; consider infection and toxins.',
        ],
      ),
      GuideStep(
        'First benzodiazepine',
        when: '5 min',
        points: ['Give one of these; repeat once after 5 minutes if still seizing.'],
        doses: [
          GuideDose('Midazolam IV', 0.15, 0.2, 'mg', maxDose: 10, how: 'IV / IO'),
          GuideDose('Midazolam buccal', 0.5, 0.5, 'mg', maxDose: 10, how: 'buccal, no IV access'),
          GuideDose('Midazolam intranasal', 0.2, 0.2, 'mg', maxDose: 10, how: 'intranasal, no IV access'),
          GuideDose('Lorazepam IV', 0.1, 0.1, 'mg', maxDose: 4, how: 'IV'),
          GuideDose('Diazepam IV', 0.15, 0.2, 'mg', maxDose: 10, how: 'IV'),
          GuideDose('Diazepam rectal', 0.5, 0.5, 'mg', maxDose: 20, how: 'rectal'),
        ],
        caution: 'No more than two benzodiazepine doses in total (count any given before arrival).',
      ),
      GuideStep(
        'Second-line drug',
        when: '20 min',
        points: ['Still seizing after two benzodiazepine doses: give ONE of these.'],
        doses: [
          GuideDose('Levetiracetam', 60, 60, 'mg', maxDose: 4500, how: 'IV over 10–15 min'),
          GuideDose('Phenytoin', 20, 20, 'mg', maxDose: 1500, how: 'IV over 20 min, saline only, ECG on'),
          GuideDose('Sodium valproate', 40, 40, 'mg', maxDose: 3000, how: 'IV over 10 min'),
          GuideDose('Phenobarbitone', 15, 20, 'mg', maxDose: 1000, how: 'IV over 20 min'),
        ],
        caution: 'Avoid valproate under 2 years, in liver disease or a suspected metabolic disorder.',
      ),
      GuideStep(
        'Refractory',
        when: '40 min',
        points: [
          'Give a different second-line drug, and call anaesthesia / PICU.',
          'Rapid-sequence intubation and a midazolam or thiopentone infusion with continuous monitoring.',
          'Look for the cause: CT, lumbar puncture when safe, metabolic tests.',
        ],
      ),
    ],
  ),
  // ── DKA ──
  Guide(
    key: 'dka',
    title: 'Diabetic Ketoacidosis',
    subtitle: 'Careful fluids, insulin after the first hour, watch the brain',
    source:
        'ISPAD Clinical Practice Consensus Guidelines 2022: Diabetic ketoacidosis and hyperglycaemic '
        'hyperosmolar state (Pediatr Diabetes 2022;23:835).',
    redFlags: [
      'Headache, slowing heart rate, rising BP, falling consciousness, vomiting again — cerebral oedema',
      'Shock or pH below 7.1 — severe DKA',
    ],
    steps: [
      GuideStep(
        'Confirm and grade',
        points: [
          'Glucose over 200 mg/dL (11 mmol/L) with pH below 7.3 or bicarbonate below 18, and ketones.',
          'Severity: mild pH < 7.3 or HCO₃ < 18; moderate pH < 7.2 or HCO₃ < 10; severe pH < 7.1 or HCO₃ < 5.',
          'Weigh the child; send gas, electrolytes, glucose, urea, creatinine, ketones.',
        ],
      ),
      GuideStep(
        'First fluids',
        when: '0–1 h',
        points: [
          'Shock: 20 mL/kg 0.9% saline quickly, repeat to restore circulation.',
          'No shock: 10–20 mL/kg 0.9% saline over 20–30 minutes.',
        ],
        doses: [GuideDose('0.9% saline bolus', 10, 20, 'mL', how: 'IV over 20–30 min')],
      ),
      GuideStep(
        'Replace the deficit',
        points: [
          'Assume 5–10% dehydration (mild–moderate 5%, severe 7–10%).',
          'Give the deficit plus maintenance evenly over 24–48 hours with 0.45–0.9% saline (Fluids tool).',
          'Add 40 mmol/L potassium once potassium is below 5.5 and urine is passing.',
        ],
      ),
      GuideStep(
        'Insulin',
        when: 'from 1 h',
        points: [
          'Start the insulin infusion at least 1 hour after fluids began. No insulin bolus.',
          'Aim for glucose to fall by about 50–100 mg/dL per hour.',
        ],
        doses: [GuideDose('Insulin infusion', 0.05, 0.1, 'units', how: 'per kg per hour, IV')],
      ),
      GuideStep(
        'Glucose and monitoring',
        points: [
          'When glucose falls below 250–300 mg/dL (14–17 mmol/L), add 5% (then 10%) dextrose to the fluids; '
              'keep the insulin running until ketoacidosis resolves.',
          'Hourly: glucose, vital signs, neuro checks, fluid balance. Every 2–4 h: gas, electrolytes.',
          'Bicarbonate is not routine.',
        ],
      ),
      GuideStep(
        'Suspected cerebral oedema',
        points: [
          'Treat at once — don’t wait for a scan. Raise the head, reduce fluids by a third, call PICU.',
          'Give mannitol or hypertonic saline (repeat after 30 minutes if no response).',
        ],
        doses: [
          GuideDose('Mannitol 20%', 0.5, 1, 'g', how: 'IV over 10–15 min'),
          GuideDose('Sodium chloride 3%', 2.5, 5, 'mL', how: 'IV over 10–15 min'),
        ],
      ),
    ],
  ),
  // ── Acute severe asthma ──
  Guide(
    key: 'asthma',
    title: 'Acute Severe Asthma',
    subtitle: 'Bronchodilators, steroid early, escalate in steps',
    source: 'BTS/SIGN British guideline on the management of asthma (2019); GINA 2023.',
    redFlags: [
      'Life-threatening: SpO₂ below 92%, silent chest, poor effort, exhaustion, confusion, cyanosis',
      'Too breathless to talk or feed; PEF below 33% best',
    ],
    steps: [
      GuideStep(
        'Oxygen and salbutamol',
        when: '0–20 min',
        points: [
          'Oxygen to keep SpO₂ 94–98%.',
          'Salbutamol by spacer 2–10 puffs, or nebulised 2.5 mg (under 5 years) / 5 mg (5 and over), every '
              '20–30 minutes; back-to-back if life-threatening.',
        ],
      ),
      GuideStep(
        'Add ipratropium and a steroid',
        when: 'first hour',
        points: [
          'Ipratropium 250 mcg nebulised with salbutamol every 20–30 minutes for the first 2 hours.',
          'Prednisolone by mouth, or hydrocortisone IV if vomiting or very unwell.',
        ],
        doses: [
          GuideDose('Prednisolone', 1, 2, 'mg', maxDose: 40, how: 'by mouth, once daily'),
          GuideDose('Hydrocortisone', 4, 4, 'mg', maxDose: 100, how: 'IV every 6 hours'),
        ],
      ),
      GuideStep(
        'Not responding',
        when: '1 h',
        points: ['Single IV magnesium dose; call senior help and PICU.'],
        doses: [GuideDose('Magnesium sulphate', 40, 40, 'mg', maxDose: 2000, how: 'IV over 20 min')],
      ),
      GuideStep(
        'Still not responding',
        points: ['IV salbutamol (bolus then infusion) or aminophylline, in a monitored area.'],
        doses: [
          GuideDose('Salbutamol IV bolus', 15, 15, 'mcg', maxDose: 250, how: 'over 10 min'),
          GuideDose('Aminophylline loading', 5, 5, 'mg', maxDose: 500, how: 'IV over 20 min; omit if on theophylline'),
        ],
        caution: 'Salbutamol infusion 1–2 mcg/kg/min; aminophylline infusion 1 mg/kg/h — check the ECG and potassium.',
      ),
    ],
  ),
  // ── Snakebite ──
  Guide(
    key: 'snakebite',
    title: 'Snakebite',
    subtitle: 'First aid, 20-minute clotting test, antivenom when envenomed',
    source:
        'National Snakebite Management Protocol (India), Ministry of Health & Family Welfare; WHO Guidelines '
        'for the management of snakebites, 2nd ed. (2016). Antivenom and neostigmine dosing: follow the national '
        'protocol and the product insert.',
    redFlags: [
      'Bleeding from gums, wounds or in urine; blood that doesn’t clot in 20 minutes',
      'Drooping eyelids, double vision, trouble swallowing or breathing (neurotoxic)',
      'Shock, little or dark urine',
    ],
    needsWeight: false,
    steps: [
      GuideStep(
        'First aid',
        points: [
          'Reassure; keep the child still and the bitten limb splinted like a fracture.',
          'No tourniquet, cutting, sucking or herbal remedies. Remove rings and tight clothing.',
          'Note the time of the bite; don’t chase the snake (a photo is enough if safe).',
        ],
      ),
      GuideStep(
        'Assess and test',
        points: [
          '20-minute whole blood clotting test (20WBCT): 2 mL of blood in a new, clean, dry glass tube; leave '
              'untouched 20 minutes, then tip — not clotted means the venom has affected clotting.',
          'Check swelling extent, bleeding, ptosis and neck/breathing weakness, blood pressure, urine.',
          'Repeat 20WBCT 6-hourly; check urine output and creatinine.',
        ],
      ),
      GuideStep(
        'Antivenom (ASV) — when envenomed',
        points: [
          'Give for systemic signs (unclotted blood, bleeding, neurotoxic signs, shock, kidney injury) or rapidly '
              'spreading swelling — not for a bite alone.',
          'Children get the same dose as adults: the initial dose is 8–10 vials IV over 1 hour, per the national '
              'protocol and product insert.',
          'If blood is still unclotted 6 hours later, or neurotoxic signs worsen, give a further dose as the '
              'protocol sets out.',
          'Have adrenaline drawn up; watch for reactions (Anaphylaxis guide). Pre-medication is not routine.',
        ],
      ),
      GuideStep(
        'Neurotoxic bites',
        points: [
          'Support breathing early — bag and ventilate; children recover if ventilated.',
          'A neostigmine trial with atropine cover may help: doses as in your unit protocol.',
        ],
      ),
      GuideStep(
        'Supportive care',
        points: [
          'Fluids for shock; blood products don’t replace antivenom.',
          'Tetanus prophylaxis; antibiotics only for an infected wound.',
          'No fasciotomy unless compartment pressure is measured high.',
        ],
      ),
    ],
  ),
  // ── Scorpion sting ──
  Guide(
    key: 'scorpion',
    title: 'Scorpion Sting',
    subtitle: 'Watch for the autonomic storm; prazosin early',
    source:
        'Bawaskar HS, Bawaskar PH. Scorpion antivenom plus prazosin vs prazosin alone: randomised trial. '
        'BMJ 2011;342:c7136; Indian Academy of Pediatrics guidance on scorpion envenomation.',
    redFlags: [
      'Cold, sweaty extremities, vomiting, salivation, priapism',
      'Very fast or slow heart rate, high or low blood pressure',
      'Breathlessness, crackles, pink frothy sputum — pulmonary oedema',
    ],
    steps: [
      GuideStep(
        'Local pain only',
        points: [
          'Paracetamol; local infiltration of 2% lignocaine without adrenaline at the sting.',
          'Observe for at least 6 hours: the autonomic storm can start late.',
        ],
      ),
      GuideStep(
        'Signs of envenomation — prazosin',
        points: [
          'Give prazosin by mouth; repeat every 3 hours until the extremities are warm, dry and pink and the '
              'heart rate and blood pressure settle.',
          'The first dose can drop the blood pressure: keep the child lying down.',
        ],
        doses: [GuideDose('Prazosin', 0.03, 0.03, 'mg', how: 'by mouth every 3 hours')],
      ),
      GuideStep(
        'Scorpion antivenom',
        points: [
          'Where available, give scorpion antivenom with prazosin — recovery is faster. Dose per the product insert.',
        ],
      ),
      GuideStep(
        'Heart failure or pulmonary oedema',
        points: [
          'Oxygen, nurse sitting up, early non-invasive or mechanical ventilation.',
          'Inotrope support (dobutamine) for poor cardiac output; manage in PICU.',
          'Avoid atropine; steroids and antihistamines don’t help.',
        ],
      ),
    ],
  ),
];

Guide? guideByKey(String key) {
  for (final g in kGuides) {
    if (g.key == key) return g;
  }
  return null;
}
