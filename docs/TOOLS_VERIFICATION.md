# Tools — clinical sign-off sheet

Every number the Tools tab shows comes from `lib/tools/neonatal_formulas.dart`.
Until a clinician has checked each line below against your unit's protocol,
`kToolsVerified` stays `false` and every tool shows a "not yet checked"
banner. Tick each line, note any change your unit uses, then ask for the
flag to be flipped.

| ☐ | Item | FolioMed uses | Source |
|---|---|---|---|
| ☐ | Total fluid, ≥1500 g | Day 1 60 mL/kg/day, +15/day, max 150 | Day-of-life table (e.g. AIIMS NICU protocols) |
| ☐ | Total fluid, <1500 g | Day 1 80 mL/kg/day, +15/day, max 150 | as above |
| ☐ | GIR | dextrose % × mL/kg/day ÷ 144 | arithmetic |
| ☐ | Dextrose mixing | strong mL = total × (target − weak) ÷ (strong − weak) | arithmetic |
| ☐ | Corrected age | PMA = GA + age; corrected = age − (40 wk − GA), born <37 wk | AAP COFN, Pediatrics 2004 |
| ☐ | Blood volume | 85 mL/kg term, 100 mL/kg preterm | textbook ranges |
| ☐ | Double-volume exchange | 2 × blood volume × weight | standard |
| ☐ | Partial exchange | BV × wt × (obs Hct − target) ÷ obs Hct, target 55% | standard |
| ☐ | High UAC | 3 × kg + 9 cm | Shukla & Ferrara 1986 |
| ☐ | UVC | UAC ÷ 2 + 1 cm | Shukla & Ferrara 1986 |
| ☐ | ETT size | <1 kg 2.5, 1–2 kg 3.0, >2 kg 3.5 mm | NRP |
| ☐ | ETT depth by weight | kg + 6 cm at lip | Tochen 1979 |
| ☐ | ETT depth by gestation | 23–24 wk 5.5 … 41–43 wk 9.0 cm | Kempley et al. 2008 |
| ☐ | Infusion rate | mcg/kg/h × kg ÷ (mg × 1000 ÷ mL) | arithmetic |
| ☐ | Apgar items and bands | 0–3 low, 4–6 moderately abnormal, 7–10 reassuring | Apgar 1953; AAP/ACOG 2015 |
| ☐ | Downes items and bands | 0–3 mild, 4–7 moderate, 8–10 impending failure | Downes 1970 |
| ☐ | Silverman-Anderson items and bands | 0 none, 1–3 mild, 4–6 moderate, 7–10 severe | Silverman & Andersen 1956 |
| ☐ | Thompson items and bands | 0 normal, 1–10 mild, 11–14 moderate, 15–22 severe | Thompson 1997 |
| ☐ | LATCH items and bands | 0–5 needs support, 6–7 some support, 8–10 going well (bands are FolioMed's practical reading) | Jensen 1994 |

| ☐ | Modified Sarnat | 6 areas graded; worst sign per area; stage = most common grade (tie → more severe); NICHD: ≥3 areas moderate/severe | Sarnat 1976; Shankaran 2005 |
| ☐ | Low blood glucose | Bolus default 2 mL/kg of 10% (200 mg/kg); infusion rate = GIR × kg × 6 ÷ % (default GIR 6) | AAP COFN, Pediatrics 2011 |
| ☐ | Sodium | Deficit = (target − Na) × water × kg (water default 0.7, target 135); 3% NaCl 0.513 mmol/mL; free water = water × kg × (Na/140 − 1); Katz correction 1.6 per 100 mg/dL | standard |
| ☐ | Potassium / magnesium / phosphate | Volume = dose/kg × kg ÷ stock; no default doses; KCl 15% = 2 mmol/mL, MgSO₄ 50% = 500 mg/mL | standard |
| ☐ | Calcium gluconate 10% | Default 2 mL/kg; 100 mg/mL salt, 9.3 mg/mL elemental | standard |
| ☐ | Anion gap / osmolality | Na − (Cl + HCO₃) [+ K]; 2Na + glucose/18 + BUN/2.8, BUN = urea/2.14 | standard |
| ☐ | Neonatal BP centiles | Table 2 of Dionne 2012 (26–44 wk, after 2 weeks of age); nearest row, lower on ties; ≥95th high, ≥99th very high. All 90 values re-checked against the published table on 23 Oct 2026 | Dionne, Abitbol, Flynn, Pediatr Nephrol 2012 |
| ☐ | Neonatal BP normal range (day 1 and by PCA) | Zubrow 1995 via EPIQ (2022) Tables 1–2: day 1 by GA at birth 22–42 wk; by post-conceptional age 24–46 wk; completed weeks; below lower limit = low, above upper = high. Transcription checked: mean = (S + 2D)/3 within 1 mmHg, values never fall with age | Zubrow et al., J Perinatol 1995;15:470–9 |
| ☐ | Childhood BP (1–17 y) | AAP 2017 Tables 4–5 by sex, completed years and nearest height column (ends clamp, ties → shorter column); Table 3 staging (<13 y centiles or 120/80, 130/80, 140/90 if lower; ≥13 y adult cut-offs; higher of SBP/DBP). Transcription checked: 95th + 12 row reproduced for every cell, cm = in × 2.54 (three published cells differ by 0.2 cm from rounding). Table 3 was not in the supplied PDF — check it against the guideline | Flynn et al., Pediatrics 2017;140(3):e20171904 |
| ☐ | Vaccines (NIS) | Birth/6/10/14 wk, 9–12 mo, 16–24 mo, 5–6 y; windows: BCG ≤1 y, Hep B ≤24 h, OPV-0 ≤15 d, OPV ≤5 y, Penta & RVV ≤1 y, measles ≤5 y | MoHFW / NHM National Immunization Schedule (check your state: PCV, JE, fIPV-3) |
| ☐ | New Ballard | 12 items; physical wording from the official sheet; arm recoil 180/140–180/110–140/90–110/<90°; popliteal 180…<90°; weeks = (2 × score + 120) ÷ 5 | Ballard 1991; ballardscore.com |

Score wording (`lib/tools/newborn_scores.dart`) is FolioMed's own summary of
each item — check it reads as your unit teaches it.

Checked by: ____________________  Date: __________
