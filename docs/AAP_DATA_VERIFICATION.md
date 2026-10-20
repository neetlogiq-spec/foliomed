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
