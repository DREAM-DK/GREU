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

## `env_ac_pefasu` response structure (recorded 2026-08-27)

Dimensions: `freq`, `stk_flow`, `nace_r2`, `prod_nrg`, `unit`, `geo`, `time`.

- **`stk_flow`** has five members. Use `SUP` and `USE` only: `USE_TRS`,
  `USE_END` and `ER_USE` re-cut the same use flow and would double count.
- **`nace_r2`** carries the 21 clean NACE sections `A`–`U`, their subsections,
  the three household activities `HH_HEAT`/`HH_TRA`/`HH_OTH`, and several
  non-NACE accounts: `TOTAL`, `HH`, `ENV`, `ROW_ACT`, `SD_SU`, `NRG_FLOW`,
  `CH_INV_PA`, `G-U_X_H`. Only the sections and the three household activities
  partition the resident economy. Select them with a **positive list**; Eurostat
  adds codes over time and a negative filter would admit new ones silently.
- **`prod_nrg`** numbers products in one continuous 01–31 sequence across three
  groups — `N01`–`N07` natural inputs, `P08`–`P27` energy products, `R28`–`R31`
  residuals — with the letter a redundant group label and `00` reserved per
  letter for the group aggregate. Exclude `N00`, `P00`, `R00`, `N00_P00_R00`,
  `EPRD_OUSE` and `SD_IO` from the cells.

**Balance invariant:** supply equals use **per activity**, because PEFA is a
physical flow account and every resident activity conserves energy. Worst case
0.3 TJ across all 24 activities for DK 2020. It does **not** hold per product —
transformation and trade break that.

**Absence is not zero.** For DK 2020 all 31 product codes are present and five
are explicit zeros (`N02`, `N07`, `P08`, `P16`, `P22`). Other countries may not
publish a code at all, in which case it is simply missing from the response. Do
not filter `prod_nrg` server-side, or the two cases become indistinguishable.

**Open anomaly:** `P08` hard coal is zero for DK 2020 while `P09` brown coal and
peat carries 33,175.8 TJ, though Denmark has no brown coal. Unresolved — see
`docs/eu_data_pilots.md`, entry "PEFA as Julia build source".

**Year coverage:** the live API offers DK 2000–2024 (checked 2026-08-27), so the
preserved 2020 pull is a convenience snapshot, not the limit of the source.

## Downstream artifact

`data/preprocessing/scripts/reconcile_eurostat_energy_emissions_dk_2020.py`
compares these files with the Danish GREU inputs and writes
`data/preprocessing/data/eurostat_energy_emissions_dk2020_reconciliation.xlsx`.

The later Sweden monetary-energy public core uses a separate preserved pull at
`data/preprocessing/data/eu_core_raw/SE/2020/`. It keeps PEFA as the physical
control but does not allocate total air-account emissions to energy products,
because `env_ac_ainah_r2` combines energy and process emissions.
