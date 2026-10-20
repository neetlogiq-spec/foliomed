# Verifying the AAP 2022 bilirubin thresholds

`assets/clinical/aap2022_bilirubin.json` holds the hourly AAP 2022
phototherapy and exchange-transfusion thresholds (mg/dL). It was imported
from a third-party app and is marked `"verified": false`, so FolioMed shows
"AAP data not yet verified" next to every AAP result.

Before switching it to `true`, a clinician should check it against the
official tables:

- Kemper AR, Newman TB, et al. *Pediatrics* 2022;150(3):e2022058859 —
  Supplemental Tables 1–4 (phototherapy / exchange, without / with
  neurotoxicity risk factors).

## Checks done so far (2026-10-20)

- **AAP:** 120 anchor values (every gestation 35 to ≥40 weeks, with and
  without risk factors, at 24/48/72/96/120 h, phototherapy and exchange)
  compared with the PediTools-derived AAP 2022 table published at
  pabau.com. 118/120 matched exactly; the 2 misses were one defect (the
  ≥40-week no-risk phototherapy curve stopped at 95 h on 21.7 instead of
  plateauing at 21.8) — fixed, now 120/120. Pinned in
  `test/guideline_reference_test.dart`.
- **NICE:** every cell of the CG98 threshold table (17 rows × 4 columns)
  compared with the guideline PDF. Phototherapy, exchange and
  "consider phototherapy" all matched; the "repeat bilirubin" column was
  wrong at birth and from 78 h (NICE leaves those cells blank) — fixed and
  pinned in the same test file.
- Still to do: the AAP supplemental tables themselves (PediTools is a
  secondary source), at every hour rather than 5 anchors per curve.

## How the file is laid out

- `phototherapy.no_risk` keys `35`…`39` and `40` (= 40 weeks or more).
- `phototherapy.with_risk`, `exchange.no_risk`, `exchange.with_risk` keys
  `35`, `36`, `37` and `38` (= 38 weeks or more).
- Each value is a list where index *i* = the threshold at *i* completed
  hours of age. Index 0 is `null`. After the last value the threshold stays
  flat.

## Suggested check

1. For every curve, compare at least hours 1, 6, 12, 24, 36, 48, 60, 72, 84,
   96, and the last tabulated hour against the supplemental table.
2. Spot-check 10 random hours per curve.
3. Confirm the known filled gap: phototherapy, with risk factors, 35 weeks,
   hour 215 (set to 16.7, the adjacent value).
4. If anything differs, fix the JSON from the official table, run
   `flutter test test/aap_bilirubin_test.dart` (it checks shape, ordering
   and a few anchor values), then set `"verified": true` with the checker's
   name and date in `"provenance"`.

The import source has no licence file; ask its author for permission, or
re-transcribe the values from the AAP tables, before a public release.
