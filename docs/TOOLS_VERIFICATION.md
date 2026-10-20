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

Score wording (`lib/tools/newborn_scores.dart`) is FolioMed's own summary of
each item — check it reads as your unit teaches it.

Checked by: ____________________  Date: __________
