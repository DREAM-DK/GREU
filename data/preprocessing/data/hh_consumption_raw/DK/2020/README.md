# Eurostat `nama_10_co3_p3` raw downloads — household consumption pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: 2026-08-19. Downloaded by
`data/preprocessing/scripts/download_hh_consumption_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **nama_10_co3_p3** — Final consumption expenditure of households by
consumption purpose (COICOP 1999). Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_co3_p3/default/table

Dimensions: freq (A), unit, coicop, geo, time. There is **no na_item**
dimension — the table is already household FCE (P31_S14 conceptually).
The national total code is `TOTAL`, not `CP00`.

The reconciliation uses `CP_MNAC` (current prices, millions of national
currency), divided by 1,000 to match GREU bn DKK.

## Files

| file | content |
|---|---|
| `nama_10_co3_p3_DK_2020.json` | Denmark 2020, all coicop / units |
| `nama_10_co3_p3_SE_2020.json` | Sweden 2020, same slice |
| `nama_10_co3_p3_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CP_MNAC, all coicop |
| `nama_10_co3_p3_eu27_year_probe_TOTAL.json` | all 27 member states, all years, TOTAL, CP_MNAC |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_hh_consumption_dk_2020.py`,
which writes `data/preprocessing/data/hh_consumption_dk2020_reconciliation.xlsx`.
