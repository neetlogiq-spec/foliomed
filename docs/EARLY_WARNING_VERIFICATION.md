# Early-warning scores — clinical sign-off sheet

The Observations section scores NEWS2 (16 years and over) and Brighton PEWS
(28 days to under 16 years) with `lib/clinical/early_warning.dart`, and the
score colours the patient's status dot on paediatric, adult and Other wards
(`lib/clinical/patient_status.dart`). Until a clinician has checked each line
below, `kEarlyWarningVerified` stays `false` and the section says the scoring
is not yet checked. Tick each line, note any change your unit uses, then ask
for the flag to be flipped. `test/early_warning_test.dart` pins every value
here — change it together with the code.

## NEWS2 (Royal College of Physicians, 2017)

| ☐ | Parameter | 3 | 2 | 1 | 0 | 1 | 2 | 3 |
|---|---|---|---|---|---|---|---|---|
| ☐ | Respiration rate /min | ≤8 | | 9–11 | 12–20 | | 21–24 | ≥25 |
| ☐ | SpO₂ scale 1 % | ≤91 | 92–93 | 94–95 | ≥96 | | | |
| ☐ | SpO₂ scale 2 % (target 88–92) | ≤83 | 84–85 | 86–87 | 88–92, or ≥93 on air | 93–94 on O₂ | 95–96 on O₂ | ≥97 on O₂ |
| ☐ | Air or oxygen | | Oxygen | | Air | | | |
| ☐ | Systolic BP mmHg | ≤90 | 91–100 | 101–110 | 111–219 | | | ≥220 |
| ☐ | Pulse /min | ≤40 | | 41–50 | 51–90 | 91–110 | 111–130 | ≥131 |
| ☐ | Consciousness | | | | Alert | | | New confusion, V, P or U |
| ☐ | Temperature °C | ≤35.0 | | 35.1–36.0 | 36.1–38.0 | 38.1–39.0 | ≥39.1 | |

| ☐ | Band | FolioMed | Dot |
|---|---|---|---|
| ☐ | Low | total 0–4, no single 3 | green |
| ☐ | Low–medium | any single parameter 3 (total under 5) | amber |
| ☐ | Medium | total 5–6 | red |
| ☐ | High | total 7 or more | red |
| ☐ | Not used in pregnancy or under 16 | message in the section | — |

## Brighton PEWS (Monaghan 2005)

Staff score each part 0–3 from the chart description (FolioMed shows the
descriptions; it has no built-in normal ranges for age).

| ☐ | Item | FolioMed uses |
|---|---|---|
| ☐ | Behaviour | 0 playing/appropriate · 1 sleeping · 2 irritable · 3 lethargic/confused or reduced response to pain |
| ☐ | Cardiovascular | 0 pink or CRT 1–2 s · 1 pale or CRT 3 s · 2 grey or CRT 4 s or HR 20 above normal · 3 grey and mottled or CRT ≥5 s or HR 30 above normal or bradycardia |
| ☐ | Respiratory | 0 normal, no recession · 1 >10 above normal, accessory muscles, 30%+ FiO₂ or 3+ L/min · 2 >20 above normal, recession, tracheal tug, 40%+ FiO₂ or 6+ L/min · 3 5 below normal with sternal recession, tug or grunting, 50%+ FiO₂ or 8+ L/min |
| ☐ | Extra | +2 for ¼-hourly nebulisers or persistent post-operative vomiting |
| ☐ | Bands | 0–2 green · 3 amber (more frequent obs, tell nurse in charge) · 4+ red (doctor review) · any part scoring 3 red |

## Status dot rules

| ☐ | Rule | FolioMed uses |
|---|---|---|
| ☐ | Which score | NEWS2 from 16 years; PEWS from 28 days; none under 28 days |
| ☐ | Wards | Paediatric, Adult and Other — not PICU, NICU or PNC |
| ☐ | How recent | The latest observations count for 12 hours |
| ☐ | Incomplete sets | Scored as a lower bound: can raise the colour, never lower it |
