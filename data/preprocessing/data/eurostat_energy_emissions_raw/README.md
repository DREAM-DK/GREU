# Eurostat energy and air-emissions raw data — Denmark, 2020

> **Not committed to Git.** The raw files described below are excluded by the
> `data/preprocessing/data/*_raw/` rule in `.gitignore`; only this README is
> versioned. Re-create the directory with
> `python data/preprocessing/scripts/download_eurostat_energy_emissions_dk_2020.py`.

Raw JSON-stat responses from the official Eurostat dissemination API, saved
exactly as delivered. Retrieved **2026-07-30** by
`data/preprocessing/scripts/download_eurostat_energy_emissions_dk_2020.py`.

## Files and queries

| File | Dataset | Query URL |
|---|---|---|
| `env_ac_pefasu_DK_2020.json` | Physical energy flow accounts: supply/use by flow table, NACE Rev. 2 activity and energy product; TJ | `https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/env_ac_pefasu?geo=DK&time=2020&lang=en` |
| `env_ac_ainah_r2_DK_2020.json` | Air-emissions accounts by NACE Rev. 2 activity and pollutant | `https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/env_ac_ainah_r2?geo=DK&time=2020&lang=en` |

Filters for both pulls: `geo=DK`, `time=2020`, `lang=en`. The PEFA response has
12,124 non-empty observations; the air-emissions response has 9,904.

The downloader rejects responses unless they are valid JSON, contain the
expected dataset dimensions, are restricted to Denmark and 2020, and contain
observations. This guards against Eurostat's occasional HTML error page returned
with HTTP status 200.

## Units and scope

- PEFA is reported in terajoules (TJ); the reconciliation converts to
  petajoules (PJ) by dividing by 1,000.
- Air emissions offer several units. The reconciliation uses `THS_T` (thousand
  tonnes, equivalent to kt); `GHG` and F-gas CO2-equivalent series are therefore
  kt CO2e.
- Both sources follow the national-accounts **residence principle**: emissions
  from international operations of Danish-resident transport companies are
  included even when they occur abroad.

## Downstream artifact

`data/preprocessing/scripts/reconcile_eurostat_energy_emissions_dk_2020.py`
compares these files with the Danish GREU inputs and writes
`data/preprocessing/data/eurostat_energy_emissions_dk2020_reconciliation.xlsx`.

The later Sweden monetary-energy public core uses a separate preserved pull at
`data/preprocessing/data/eu_core_raw/SE/2020/`. It keeps PEFA as the physical
control but does not allocate total air-account emissions to energy products,
because `env_ac_ainah_r2` combines energy and process emissions.
