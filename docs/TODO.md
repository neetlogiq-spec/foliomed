# FolioMed to-do

## Later (Phase 3, parked 2026-10-20)
- Alerts only for my unit
- Admitting-unit rotation per day
- Discharge summary as PDF / share to WhatsApp
- Offline mode (poor signal)
- Weekly ward data export / backup

## Tools — next candidates (from the pediaid-flutter inventory, 2026-10-20)
Write from primary sources only; never copy pediaid code, text or data.
- Fenton 2013 growth chart → automatic AGA/SGA/LGA (check data terms of use)
- Scores still to do: Modified Sarnat (staging table), New Ballard (needs pictures). Done: Apgar, Downes, Silverman-Anderson, Thompson, LATCH
- Hypoglycaemia bolus (unit protocol), neonatal BP centiles (Zubrow 1995), blood volume, ponderal index
- Electrolyte corrections (Na, K, Ca, Mg, PO4), anion gap, osmolality, TPN
- Vaccine schedule (NIS / IAP) and catch-up
- Do NOT use: pediaid formulary (NeoFax / Harriet Lane), NRP/PALS PDFs

## Waiting on Kashyap
- Clinical sign-off of the Tools numbers (`docs/TOOLS_VERIFICATION.md`)
- Push setup (`docs/PUSH_SETUP.md`) and Firebase values in env.json
- Verify AAP table values against the supplement (`docs/AAP_DATA_VERIFICATION.md`)
- Two-phone test of the main flows
- Install iOS 26.2 platform in Xcode (for iPhone builds)
- Permission from Wardly's and pediaid's authors
- Delete stale `claude/*` branches on GitHub
