# Eurostat `env_ac_ainah_r2` / `env_air_gge` raw downloads — non-energy emissions pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: 2026-08-19. Downloaded by
`data/preprocessing/scripts/download_non_energy_emissions_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **env_ac_ainah_r2** — Air-emissions accounts by NACE Rev. 2 activity
and pollutant (residence principle; energy and process combined). Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_ac_ainah_r2/default/table

Dimensions: freq (A), airpol, nace_r2, unit, geo, time. The reconciliation
uses `THS_T` (thousand tonnes = kt). `GHG` and F-gas CO2-equivalent series
are therefore kt CO2e. National total for the GREU comparison is `TOTAL_HH`
(industries + households).

Second dataset: **env_air_gge** — Greenhouse gas emissions by UNFCCC CRF
source sector (territorial inventory). Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_air_gge/default/table

Used here for CRF1 (energy), CRF2 (IPPU), CRF3 (agriculture) and CRF5
(waste) as an independent process-emissions control. This is a different
slice from the 2026-08-03 emissions-bridge pull, which only used CRF4
(LULUCF).

An earlier DK ainah pull (2026-07-30) is preserved at
`data/preprocessing/data/eurostat_energy_emissions_raw/env_ac_ainah_r2_DK_2020.json`
and is **not** overwritten. The reconcile script compares the two vintages.

## Files

| file | content |
|---|---|
| `env_ac_ainah_r2_DK_2020.json` | Denmark 2020 air accounts, all airpol / NACE / units |
| `env_ac_ainah_r2_SE_2020.json` | Sweden 2020 air accounts, same slice |
| `env_ac_ainah_r2_eu27_coverage_probe_2020.json` | all 27 member states, 2020, THS_T, GHG-relevant airpol |
| `env_ac_ainah_r2_eu27_year_probe_GHG.json` | all 27 member states, all years, GHG THS_T TOTAL_HH |
| `env_air_gge_DK_2020_crf.json` | Denmark 2020 inventory CRF1/2/3/5 (+ children, totals) |
| `env_air_gge_SE_2020_crf.json` | Sweden 2020 inventory, same CRF slice |
| `env_air_gge_eu27_crf_coverage_probe_2020.json` | all 27 member states, 2020, GHG, CRF1/2/3/5 |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_non_energy_emissions_dk_2020.py`,
which writes `data/preprocessing/data/non_energy_emissions_dk2020_reconciliation.xlsx`.
