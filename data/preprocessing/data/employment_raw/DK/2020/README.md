# Eurostat `nama_10_a64_e` raw downloads — employment pilot (DK 2020)

> **Not committed to Git.** The per-country JSON-stat responses are excluded by
> the `data/preprocessing/data/*_raw/` rule in `.gitignore`; only this README,
> `manifest.json` and the EU-27 coverage probe are versioned. Re-create the
> directory with
> `python data/preprocessing/scripts/download_employment_dk_2020.py`.

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: 2026-07-31. Downloaded by
`data/preprocessing/scripts/download_employment_dk_2020.py` (re-runnable; it
skips files that already exist and validate).

Dataset: **nama_10_a64_e** — National accounts employment data by industry
(up to NACE A*64). Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_a64_e/default/table

Dimensions: freq (A), unit, nace_r2 (A64 + aggregates), na_item, geo, time.

- `na_item`: `EMP_DC` total employment, `SAL_DC` employees, `SELF_DC`
  self-employed — all domestic concept (matches national-accounts IO wage data).
- `unit`: `THS_PER` thousand persons, `THS_HW` thousand hours worked,
  `THS_JOB` thousand jobs, plus percentage-change units.

## Files

| file | content |
|---|---|
| `nama_10_a64_e_DK_2020.json` | Denmark 2020, all units/na_item/nace_r2 |
| `nama_10_a64_e_SE_2020.json` | Sweden 2020, same slice (public-core pilot country) |
| `nama_10_a64_e_eu27_coverage_probe_2020.json` | all 27 member states, 2020, THS_PER + THS_HW, all na_item/nace_r2 |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_employment_dk_2020.py`, which
writes `data/preprocessing/data/employment_dk2020_reconciliation.xlsx`.
