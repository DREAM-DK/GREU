# Eurostat `gov_10a_main` raw downloads — government finances pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: 2026-08-17. Downloaded by
`data/preprocessing/scripts/download_government_finances_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **gov_10a_main** — Government revenue, expenditure and main
aggregates. Source page:
https://ec.europa.eu/eurostat/databrowser/view/gov_10a_main/default/table

Dimensions: freq (A), unit, sector, na_item, geo, time. All files use
`unit=MIO_NAC` (million national currency; the Danish input is bn DKK, so
values divide by 1000) and `sector=S13` (general government).

Second dataset: **gov_10a_taxag** — Main national accounts tax aggregates,
same dimensions. Carries the tax detail on the Danish revenue side (D211 VAT,
D214, D51 income-tax subitems, D59, D91, D2122 import duties) including
sector S212 (institutions of the EU) for the Danish `rev_eu`/`exp_eu` rows.
Source page:
https://ec.europa.eu/eurostat/databrowser/view/gov_10a_taxag/default/table

## Files

| file | content |
|---|---|
| `gov_10a_main_DK_2020.json` | Denmark 2020, S13, MIO_NAC, all na_items |
| `gov_10a_taxag_DK_2020.json` | Denmark 2020 tax aggregates, S13 + S212, MIO_NAC, all na_items |
| `gov_10a_main_SE_2020.json` | Sweden 2020, same slice (public-core pilot country) |
| `gov_10a_main_eu27_coverage_probe_2020.json` | all 27 member states, 2020, S13, MIO_NAC, pilot na_items |
| `gov_10a_taxag_eu27_coverage_probe_2020.json` | all 27 member states, 2020, S13 + S212, MIO_NAC, tax-detail na_items |
| `gov_10a_main_eu27_year_probe_TE.json` | all 27 member states, all years, TE |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_government_finances_dk_2020.py`,
which writes `data/preprocessing/data/government_finances_dk2020_reconciliation.xlsx`.
