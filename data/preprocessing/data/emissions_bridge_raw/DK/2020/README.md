# Eurostat `env_ac_aibrid_r2` raw downloads — emissions bridge pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: 2026-08-17. Downloaded by
`data/preprocessing/scripts/download_emissions_bridge_dk_2020.py` (re-runnable;
it skips files that already exist and validate).

Dataset: **env_ac_aibrid_r2** — Air emissions accounts totals bridging to
emission inventory totals. Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_ac_aibrid_r2/default/table

Dimensions: freq (A), airpol, indic_env, unit, geo, time.

- `indic_env`: `AEMIS_RES` accounts total; `AEMIS_RES_ABR` (+ `_FWTR`, `_LTR`,
  `_WTR`, `_ATR`) residents' emissions from fuel purchased abroad;
  `AEMIS_TER_NRES` (+ `_LTR`, `_WTR`, `_ATR`) non-residents' emissions from
  fuel purchased on the territory; `ADJ_SD` other adjustments; `AEMIS_TER`
  inventory total; `AEMIS_TER_LULUCF`; `LULUCF`, `FORL`, `CRL_GRL`,
  `LULUCF_OTH`.
- `airpol`: `GHG` (CO2-eq incl. F-gases), `CO2` (fossil), `CO2_BIO`, `CH4`,
  `N2O`, F-gas groups in CO2-eq, plus non-GHG air pollutants.
- `unit`: `T` tonnes, `THS_T` thousand tonnes, `G_HAB`/`KG_HAB` per capita.

Second dataset: **env_air_gge** — Greenhouse gas emissions by source sector
(EEA/UNFCCC inventory), used only as an independent cross-check of the aibrid
LULUCF figure (`src_crf` `CRF4` = LULUCF sector; `TOTXMEMO`/`TOTX4_MEMO` =
totals with/without LULUCF). Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_air_gge/default/table

## Files

| file | content |
|---|---|
| `env_ac_aibrid_r2_DK_2020.json` | Denmark 2020, all airpol/indic_env/units |
| `env_ac_aibrid_r2_SE_2020.json` | Sweden 2020, same slice (public-core pilot country) |
| `env_ac_aibrid_r2_eu27_coverage_probe_2020.json` | all 27 member states, 2020, THS_T, GHG/CO2/CO2_BIO/CH4/N2O, all indic_env |
| `env_ac_aibrid_r2_eu27_year_probe_GHG.json` | all 27 member states, all years, GHG in THS_T, all indic_env |
| `env_air_gge_DK_2020_lulucf.json` | inventory DK 2020: CRF4 + totals with/without LULUCF, GHG gases |
| `env_air_gge_eu27_lulucf_coverage_probe_2020.json` | all 27 member states, 2020, CRF4 GHG |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_emissions_bridge_dk_2020.py`,
which writes `data/preprocessing/data/emissions_bridge_dk2020_reconciliation.xlsx`.
