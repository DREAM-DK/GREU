# FIGARO raw data — Denmark, reference year 2020

> **Not committed to Git.** The raw files described below are excluded by the
> `data/preprocessing/data/*_raw/` rule in `.gitignore`; only this README is
> versioned. Re-create the directory with
> `python data/preprocessing/scripts/download_figaro_dk_2020.py`.

Raw SDMX-CSV extractions from the Eurostat dissemination API, saved as
delivered (no transformation). Downloaded **2026-07-29** by
`data/preprocessing/scripts/download_figaro_dk_2020.py` (re-runnable).

## Edition / vintage

FIGARO **2026 edition** (the current release of the Eurostat `naio_10_fcp_*`
datasets): last update stamps 18–20 July 2026, coverage 2010–2024,
64 NACE Rev. 2 industries × 64 CPA 2.1 products, 46 areas
(EU-27 + 18 partners + `WRL_REST`; value-added rows carry `c_orig=DOM`).
All values in MIO_EUR at basic prices. The 2018–2021 blocks (`*_s3/u3/ii3`)
contain reference year 2020.

Official FIGARO page:
https://joint-research-centre.ec.europa.eu/projects-and-activities/trade-and-industrial-policy-analysis/input-output-accounts/figaro-tables_en
API base: https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data

## Files (all with `?format=SDMX-CSV&startPeriod=2020&endPeriod=2020`)

| File | Dataset | Key (dimension filter) | Content |
|---|---|---|---|
| `naio_10_fcp_s3_DK_2020.csv` | naio_10_fcp_s3 | `A....DK` | National supply table DK, industry (nace_r2) × product (cpa2_1) |
| `naio_10_fcp_u3_DKdest_2020.csv` | naio_10_fcp_u3 | `A...DK..` | Use table, all rows (products × origin country, incl. VA rows) into DK columns |
| `naio_10_fcp_u3_DKorig_2020.csv` | naio_10_fcp_u3 | `A.....DK` | Use table, DK-origin product rows into all destination countries |
| `naio_10_fcp_ii3_DKdest_2020.csv` | naio_10_fcp_ii3 | `A...DK..` | Ind-by-ind IO, all rows into DK columns (imports by origin + VA rows) |
| `naio_10_fcp_ii3_DKorig_2020.csv` | naio_10_fcp_ii3 | `A.....DK` | Ind-by-ind IO, DK-origin rows to all destinations (domestic + exports) |
| `ert_bil_eur_a_DKK_2020.csv` | ert_bil_eur_a | `A.AVG.NAC.DKK` | Annual average DKK per EUR exchange rate, 2020 |

Key positions: `naio_10_fcp_s3` = freq.nace_r2.cpa2_1.unit.geo;
`naio_10_fcp_u3` = freq.ind_use.prd_ava.c_dest.unit.c_orig;
`naio_10_fcp_ii3` = freq.ind_use.ind_ava.c_dest.unit.c_orig.

Row/column vocabulary of the use/IO tables: 64 industry (or `CPA_*` product)
codes; use columns add `P3_S13, P3_S14, P3_S15, P51G, P5M`; value-added rows
(`c_orig=DOM`): `D1, D21X31, D29X39, B2A3G, OP_RES, OP_NRES`.

## Downstream

Reconciled against the Danish IO input `io_long_format.xlsx` by
`data/preprocessing/scripts/reconcile_figaro_dk_2020.py`, output:
`data/preprocessing/data/figaro_dk2020_reconciliation.xlsx`.
