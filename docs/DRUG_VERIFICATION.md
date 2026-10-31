# Drug list — clinical sign-off

The Emergency Drugs and Infusion Rate tools use FolioMed's starter list
(`lib/tools/drugs/drug_list.dart`). Every value is pinned by
`test/drugs_test.dart` ("checked values"), so a change to the list must
change the tests too.

Sign-off happens **per ward, in the app**: ward page → Drug List → tap a
drug → *Sign Off*. Any doctor of the ward (or the owner) can sign off. A
sign-off covers exactly what was shown (vial, every dose, limit, dilution,
infusion range and standard syringe); if any of these change — in a new
FolioMed version or in the ward's own settings — the drug shows
"Changed — recheck".

## Before signing off a drug

1. Compare every dose, maximum and dilution with your unit's reference.
2. Check the vial strength matches what your pharmacy stocks (owner: set
   the ward's vial under *Ward Settings…* if not).
3. For infusions, check the standard syringe (what 1 mL/h gives) against
   your unit's syringe guide, or set the ward's own.
4. Read the ward note and the drug's notes (extravasation, central line,
   diluent).

## How the starter list was checked

Doses were written from the published guidelines named in each drug's
*Source*, then cross-checked value by value against standard neonatal and
paediatric drug references. Where the references differ, NICU values follow
the neonatal reference and PICU values the paediatric one. Corrections made
in that check: atropine (newborn 0.01–0.03 mg/kg, total ≤ 0.04 mg/kg),
calcium gluconate PICU (100 mg/kg, max 3 g), sodium bicarbonate PICU (max
50 mEq), magnesium (25–75 mg/kg), levetiracetam newborn (40 mg/kg, then
20 mg/kg), midazolam newborn seizures (0.15 mg/kg load), phenytoin
(15–20 mg/kg), phenobarbitone PICU repeats, rocuronium (0.6–1.2 mg/kg),
and the infusion ranges for dobutamine, noradrenaline, milrinone and
fentanyl.

## Judgement calls for your unit

These are reasonable either way; decide and, if needed, set the ward's own:

| Item | FolioMed default | Also used |
|---|---|---|
| Atropine minimum dose | None (newborn 0.01–0.03 mg/kg) | 0.1 mg minimum in some resuscitation courses |
| Atropine max (PICU) | 0.5 mg per dose (adolescents 1 mg) | 1 mg in some protocols |
| Adenosine (newborn) | 0.05–0.1 mg/kg, steps to 0.3 mg/kg | steps of 0.05 to 0.25 mg/kg |
| Calcium gluconate max (PICU) | 3 g | 2 g |
| Alprostadil range | 0.01–0.1 mcg/kg/min | up to 0.4 mcg/kg/min |
| Milrinone (newborn) | 0.3–0.75 mcg/kg/min | 0.5–1 mcg/kg/min |
| Noradrenaline (newborn) | 0.2–2 mcg/kg/min | 0.1–0.3 mcg/kg/min |
| Adrenaline / noradrenaline syringe (NICU) | 1 mL/h = 0.5 mcg/kg/min | 1 mL/h = 1 or 0.1 mcg/kg/min |
| Dopamine / dobutamine syringe (PICU) | 1 mL/h = 2 mcg/kg/min | 1 mL/h = 10 mcg/kg/min (30 mg/kg in 50 mL) |
| Normal saline bolus (preterm) | 10 mL/kg over 5–10 min | slower in very preterm babies |

## Drugs in the list

- **NICU one-off:** adrenaline (IV/UVC/IO and ET), sodium chloride 0.9%,
  glucose 10%, calcium gluconate, sodium bicarbonate, atropine, adenosine,
  fentanyl, midazolam, phenobarbitone, levetiracetam, phenytoin.
- **PICU one-off:** adrenaline (arrest IV/IO, ET, anaphylaxis IM), saline,
  glucose 10%, calcium gluconate, calcium chloride, sodium bicarbonate,
  atropine, adenosine, amiodarone, fentanyl, midazolam, naloxone, ketamine,
  rocuronium, phenobarbitone, levetiracetam, phenytoin, 3% saline,
  magnesium sulphate.
- **Infusions:** dopamine, dobutamine, adrenaline, noradrenaline,
  milrinone, alprostadil (NICU), morphine, fentanyl, midazolam, insulin;
  PICU also vasopressin, dexmedetomidine, amiodarone.
