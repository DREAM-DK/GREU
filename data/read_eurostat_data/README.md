# read_eurostat_data — colleague's EU-core reference implementation

**Status: reference implementation / inspiration.** This is **not** the
project's deliverable EU data pipeline; that remains the documented pilot
workflow described in `docs/eu_data_mapping.md`. Code here is kept because it
contains working Eurostat dataset mappings that accelerate the pilots.

## Provenance

- Received 2026-08-17 as a plain folder copy (workspace `GREU_EU_core`, no git
  history) from a colleague who built a "core model" variant of GREU running
  only on Eurostat data — no energy, emissions, or climate data.
- Copied into this repo unchanged: the six `*_data.py` modules plus
  `read_all_data.py` (this directory) and `../data_from_eurostat.gms`
  (model-side loader). Her copies of the model `.gms` files were **not**
  brought over — they are stale copies of GREU itself.

## What it does

`read_all_data.py` builds a GAMSPy container and calls
`{module}_data.load_data(...)` for each module, pulling **live** from the
Eurostat dissemination API via the `eurostat` package, then writes
`../data_eurostat.gdx`. `data_from_eurostat.gms` turns that GDX into model
parameters.

| Module | Eurostat dataset(s) | Notes |
|---|---|---|
| `input_output_data.py` | `naio_10_fcp_ii3` (FIGARO ind-by-ind) | aggregated to 19 NACE sections; P51G split construction→iB, rest→iM |
| `labor_market_data.py` | `nama_10_a64_e` | totals only |
| `factor_demand_data.py` | `nama_10_nfa_st`, `nama_10_a64_p5` | asset concordance N11KG→iB, N11MG/N115G/N117G→iM |
| `government_data.py` | `gov_10a_main` | full `na_item` → model-variable mapping |
| `financial_accounts_balance_data.py` | `nasa_10_f_bs` | Debt/Equity instrument grouping |
| `financial_accounts_flow_data.py` | `nasa_10_nf_tr` | property-income flows, B2A3G Hh→NonFinCorp reallocation |

## Known caveats (as received)

- **Financial-accounts naming mismatch — confirmed harmless-but-silent, not
  intentional (colleague conversation, 2026-08-18):** `../data_from_eurostat.gms`
  declares/loads parameters (`vFinAssets`, `vDebtInstruments`, `vEquity`, ~30
  `*_s` sector flows) that the current financial-accounts Python modules do
  not produce (they write `vFinAL`, `vFinIncome`, matching her rewritten
  `model/modules/financial_accounts.gms`). This does **not** stop the model
  from running: her `@load` macro (`model/functions.gms`) expands to GAMS's
  `execute_load`, which silently leaves a parameter at zero if the requested
  name is missing from the GDX rather than erroring. So the model solves, but
  the financial-accounts block is populated with zeros, not real Eurostat
  data. The colleague confirmed this is an incomplete push (the model module
  was updated, the data-loading `.gms` file was not) rather than a deliberate
  design, and that she validated the run by checking GDP afterward, not the
  financial-accounts numbers specifically — so the zero-fill had gone
  unnoticed. Its header also references `load_eurostat_data.py` /
  `data/modules/`, paths that do not exist here.
- **The model is being rewritten in Julia** (a second colleague, Kristina, as
  of 2026-08-18). This makes every `.gms` file in `GREU_EU_core/model/` a
  shrinking asset regardless of the naming issue above — reconciling or
  adopting her GAMS model modules is not a good use of time. The durable
  value of this folder is the Eurostat dataset-sourcing knowledge in the
  Python modules (which dataset code and filters cover which concept), which
  survives the model-language change; treat it accordingly and do not invest
  further effort in the GAMS-side model files.
- **No raw-data provenance:** modules fetch from the API at run time and keep
  no raw payloads, which conflicts with this repo's provenance rules — fine
  for reference code, not acceptable for deliverables.
- Industry detail is NACE A19 sections, far coarser than the 57-industry GREU
  target, though `naio_10_fcp_ii3` itself is 64-industry and the aggregation
  is a parameter (`i_agg_map`).
