# Eurostat `nasa_10_f_bs` / `nasa_10_nf_tr` raw downloads — financial accounts pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: 2026-08-18. Downloaded by
`data/preprocessing/scripts/download_financial_accounts_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **nasa_10_f_bs** — Financial balance sheets by sector (stocks).
Source page:
https://ec.europa.eu/eurostat/databrowser/view/nasa_10_f_bs/default/table

Dimensions: freq (A), unit, co_nco, sector, finpos, na_item, geo, time. The
DK/SE files carry both `MIO_NAC` and `MIO_EUR` and both consolidations
(`CO`/`NCO`) so the Danish input's basis can be established from data; the
probes use `MIO_NAC` + `CO` (the live module's convention; the Danish input
is bn DKK, so values divide by 1000).

Second dataset: **nasa_10_nf_tr** — Non-financial transactions by sector
(flows), `CP_MNAC`, directions RECV/PAID. Carries the property-income detail
(D41, D42 incl. D421/D422, D43, D44, D45) behind the Danish flow variables
and the items the government-finances pilot left open (D3/D31/D39, D7x incl.
D74_EUI, D9x, D5/D61/D62/D63). It has **no D51 subitems**, so the Danish PAL
(pension-yield tax) series cannot come from this dataset.
Source page:
https://ec.europa.eu/eurostat/databrowser/view/nasa_10_nf_tr/default/table

## Files

| file | content |
|---|---|
| `nasa_10_f_bs_DK_2020.json` | Denmark 2020, MIO_NAC+MIO_EUR, CO+NCO, pilot sectors, instrument detail incl. F6 subitems |
| `nasa_10_nf_tr_DK_2020.json` | Denmark 2020, CP_MNAC, RECV+PAID, property income + government-gap items |
| `nasa_10_f_bs_SE_2020.json` | Sweden 2020, same balance-sheet slice (public-core pilot country) |
| `nasa_10_nf_tr_SE_2020.json` | Sweden 2020, same transactions slice |
| `nasa_10_f_bs_eu27_coverage_probe_2020.json` | all 27 member states, 2020, MIO_NAC, CO, pilot sectors/instruments |
| `nasa_10_nf_tr_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CP_MNAC, pilot sectors/na_items |
| `nasa_10_f_bs_eu27_year_probe_F.json` | all 27 member states, all years, household total financial assets |
| `nasa_10_nf_tr_eu27_year_probe_D41.json` | all 27 member states, all years, government interest paid |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_financial_accounts_dk_2020.py`,
which writes `data/preprocessing/data/financial_accounts_dk2020_reconciliation.xlsx`.
