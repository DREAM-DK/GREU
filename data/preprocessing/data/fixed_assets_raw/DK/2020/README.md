# Eurostat `nama_10_nfa_st` / `nama_10_a64_p5` raw downloads — fixed-assets pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: 2026-08-18. Downloaded by
`data/preprocessing/scripts/download_fixed_assets_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **nama_10_nfa_st** — Capital stocks by industry and detailed asset
type. Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_nfa_st/default/table

Dimensions: freq (A), unit, nace_r2, asset10, geo, time. The DK/SE files
carry all eight valuation units so the Danish input's basis (net vs gross,
current replacement cost vs chain-linked volumes) can be established from
data; the probes use `CRC_MNAC` (current replacement costs, million units of
national currency). The Danish input is bn DKK, so values divide by 1000.

Second dataset: **nama_10_a64_p5** — Capital formation by industry and
detailed asset type, `P51G` GFCF, `CP_MNAC` + `PYP_MNAC`. This is the
structural-gap-3 *use margin* source (investment by asset type x investing
industry). Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_a64_p5/default/table

## Files

| file | content |
|---|---|
| `nama_10_nfa_st_DK_2020.json` | Denmark 2020 stocks, all units / NACE / assets |
| `nama_10_a64_p5_DK_2020.json` | Denmark 2020 GFCF P51G, CP_MNAC+PYP_MNAC |
| `nama_10_nfa_st_SE_2020.json` | Sweden 2020 stocks, same slice (public-core pilot country) |
| `nama_10_a64_p5_SE_2020.json` | Sweden 2020 GFCF, same slice |
| `nama_10_nfa_st_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CRC_MNAC, all NACE / assets |
| `nama_10_a64_p5_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CP_MNAC, P51G, all NACE / assets |
| `nama_10_nfa_st_eu27_year_probe_N11.json` | all 27 member states, all years, TOTAL N11N+N11G |
| `nama_10_a64_p5_eu27_year_probe_N11G.json` | all 27 member states, all years, TOTAL GFCF N11G |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_fixed_assets_dk_2020.py`,
which writes `data/preprocessing/data/fixed_assets_dk2020_reconciliation.xlsx`.
