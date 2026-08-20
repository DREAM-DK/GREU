# EU data mapping — Danish inputs → Eurostat/FIGARO sources

**Start here.** This is the live working document for making GREU EU-generic:
what every Danish input needs, which EU source replaces it, how good the match
is, and what to do next.

| Looking for | Go to |
|---|---|
| Where the project stands | "Current status" immediately below |
| What to do next, and open decisions | "Open items" and "Handoff" at the end |
| Per-input source and verdict | "Mapping table" below |
| The four things that must be built | "The four structural gaps" below |
| Evidence behind any verdict | `docs/eu_data_pilots.md` |
| Danish energy file semantics | `data/preprocessing/data/energy_data_notes.md` |
| Running a non-Danish country | `data/Modules/energy_money/README.md` |
| Management traffic-light overview | `docs/EU_data_overview.xlsx` |
| What numbers the model uses (plain language + by module) | `docs/What_the_model_uses.xlsx` |
| Non-specialist project overview | `docs/EU_data_roadmap.pdf` |

This file is searched far more often than it is read end to end. Use grep for
the input name or dataset code you care about rather than reading it whole.

## Current status (2026-08-19)

- **Monetary-energy core: architecture chosen and proven.** Sweden 2020 is the
  first accepted non-Danish `public_core` package, built only from public
  European controls with no Danish fallback. It passes its workbook/GDX
  contract. The hard limit is unchanged: **0 monetary cells are directly
  observed** at product × user × purpose; 117 nonzero use cells are modelled.
- **The monetary-residual work stream is closed as a data question.** Sweden's
  unmatched use-side SUT residual was narrowed from 299.131 to 118.844 bn SEK,
  a previously-invisible 102.567 bn SEK supply-side residual was exposed, and
  both remaining pieces are evidence-backed as overwhelmingly non-energy money.
  What is left is a colleague decision, not more data work.
- **The parameterization phase has started:** converting the remaining Danish
  inputs one at a time, smallest first. `employed.xlsx`,
  `emissions_bridge_items.xlsx`, `government_finances.xlsx`,
  `institutional_financial_accounts.xlsx`, `fixed_assets.xlsx`,
  `non_energy_emissions.xlsx` and the household-consumption split of
  `io_long_format.xlsx` are done. The government and fixed-assets
  pilots reconciled **number-exact** at the totals the model uses; the
  financial-accounts pilot (2026-08-18) found the model **never reads that
  Excel** (live Eurostat module already supplies the two load-bearing
  symbols; pension reallocation unimplemented → decision 18). The
  fixed-assets pilot also closed gap-3's *use-margin totals*. The
  non-energy-emissions pilot (2026-08-19) confirmed the Excel is
  **load-bearing** (`qEmmxE`): F-gases copy from `env_ac_ainah_r2` exactly;
  `ainah − energy` is tautological for CH4/N2O (item 9 documented, not a
  missing source); all 27 countries publish 2020 ainah at A64 and CRF
  1/2/3/5. The household-consumption pilot (2026-08-19) closed the last
  unpiloted Danish input: 3-digit `nama_10_co3_p3` uniquely identifies 3
  of 12 GREU groups; the food four-pack and 1999 beverages+tobacco
  clusters pass; `cTou` matches FIGARO `OP_RES` exactly; all 27 countries
  publish 2020 at 3-digit.
- **A colleague's Eurostat-only "EU core" reference implementation was
  received 2026-08-17** and committed under `data/read_eurostat_data/` (see
  its README for provenance and caveats). It is inspiration/concordance
  material, not the deliverable pipeline. **2026-08-18 follow-up:** her model
  is being rewritten in Julia by a second colleague, so only her Python
  data-sourcing scripts remain relevant going forward — see Handoff. The
  fixed-assets pilot rejected her `factor_demand_data.py` asset map (gross
  stocks, no `iT`; Sweden publishes net only).
- **Structural gap 3 was rescoped on 2026-08-07** after a code audit: the model
  needs two investment margins, not the full matrix previously recorded.
  **2026-08-18:** the use-margin *totals* are direct data; remaining work is
  the industry dimension (A64 concordance for 13/27 countries; A21
  disaggregation for 14, with three GREU industries that do not nest in A21).

Full evidence for every claim above is in `docs/eu_data_pilots.md`.

Verdicts used below: **OK** = same concept available; **COARSER** = available
at less detail than the Danish data; **GAP** = needs construction/estimation;
**KEPT** = not a Statistics Denmark dependency, stays as-is.

## Scope and inventory

Scope (confirmed 2026-07-28): **the contents of `data/preprocessing/data/` only** —
the inputs consumed by `read_data.py`. The file count narrows in three steps
(clarified 2026-07-29 — the intermediate numbers are easy to confuse):

| Step | Count | What it is |
|---|---|---|
| Excel files in the folder | **16** | as shipped; excludes artefacts our own work has since added |
| — of which unread duplicate views | 4 | `io_matrix_format`, `io_energy_matrix_format`, `io_invest_matrix_format_2019`, `io_invest_matrix_format_2020` — human-readable pivots of the corresponding `*_long_format` files. **No code in the repo reads them** (verified by grep 2026-07-29); they are referenced only in our own notes because they are far easier to eyeball. |
| Inputs actually consumed | **13** | the remaining 12 `.xlsx` **plus** `EU_GR_data.gdx` (read at line 766 — marginal tax rates `tEAFG_REmarg`/`tCO2_REmarg` from the Danish GreenREFORM model, labelled "temporary solution" in the script's own docstring) |
| Inputs needing an EU source | **12** | = 11 `.xlsx` + the `.gdx`. `metadata.xlsx` is the 12th consumed Excel file but is **kept** as the master concordance rather than replaced. |

Note the two different twelves: *12 Excel files consumed* (incl. `metadata.xlsx`)
and *12 inputs to replace* (11 Excel + the gdx). Same number, different sets.

The 4 matrix-format views are out of the inventory because they are derived from
files already in scope — but if anyone's workflow depends on them, the EU pipeline
should **regenerate** them as outputs rather than silently drop them (it is a pivot).
Caveat: `io_invest_matrix_format_*` is split per year (2019, 2020) where the long
format carries both, so "matrix view" is not a lossless mirror in that case.

Out of scope (separate work streams, listed for completeness only):
`Energy_technology_data.xlsx` (Danish Energy Agency catalogue, own folder + import
script, not DST-dependent) and the financial-accounts module
(`data/Modules/financial_accounts/`, already pulls `nasa_10_f_bs` live from Eurostat).

**Why the table has more rows than there are inputs:** two files split because their
components come from different EU sources — `io_long_format.xlsx` into 3 rows (main IO,
`prim_input`, household consumption detail) and `energy_and_emissions.xlsx` into 2
(physical/emissions, price decomposition). So: 12 inputs to replace + 3 extra split rows
= 15 verdict rows, + 1 `KEPT` row for `metadata.xlsx` = **16 rows** here. The PDF/HTML
version drops the `prim_input` row (its verdict is a hybrid OK/COARSER), leaving
**14 verdict rows = 4 OK + 6 COARSER + 4 GAP**, + the KEPT row = 15 rows shown there.

Status of source codes: **25 dataset codes are now confirmed accessible** —
the **17** Eurostat codes in the table below were verified to exist against the live
Eurostat API on 2026-07-28. Two of those, `env_ac_pefasu` and
`env_ac_ainah_r2`, are now proven end-to-end by the 2026-07-30 pilot; the
national SUT codes `naio_10_cp15`/`cp16` and `env_ac_taxind2` are now also
proven as calibration controls by the monetary pilot; `env_ac_aibrid_r2` is
proven end-to-end by the 2026-08-17 emissions-bridge pilot;
`nasa_10_f_bs` and `nasa_10_nf_tr` are proven end-to-end by the 2026-08-18
financial-accounts pilot. Four additional
annual energy-price-component codes (`nrg_pc_202_c` through `_205_c`) were
added and tested, and `env_air_gge` (UNFCCC inventory) was verified
2026-08-17 as the LULUCF cross-check and 2026-08-19 as the CRF1/2/3/5
process-emissions control, bringing the total from 20 to 25. The **3 FIGARO codes**
`naio_10_fcp_s3` / `_u3` / `_ii3` were proven end-to-end on 2026-07-29.
**Correction (2026-07-29):** this doc originally stated that FIGARO is distributed only
via the Eurostat FIGARO page → CIRCABC (CSV/Excel/Parquet) and not as regular database
codes. That is wrong — FIGARO is also served through the ordinary SDMX dissemination
API under those three codes, which is how the pilot's downloader gets it.
FIGARO 2026 edition covers 2010–2024, 64 industries (NACE Rev. 2) × 64 products
(CPA 2.1), all EU members + 18 partners + RoW.

Verdicts: **OK** = same concept available; **COARSER** = available at less
detail than the Danish data; **GAP** = needs construction/estimation;
**KEPT** = not a Statistics Denmark dependency, stays as-is.

## Existing bridges in `metadata.xlsx` (big head start)

The team has already built concordances to EU classifications:
- `industries_naceA64_map`: 57 GREU industries → NACE A64 (many-to-one from A64
  side; several GREU industries split one NACE code, e.g. organic/conventional
  farming, 5 waste-treatment industries in E38).
- `cons_hh_coicop_map`: 12 GREU consumption groups → 4-digit COICOP (299 lines).
- `energy_products_pefa_map`: 25 GREU energy products → PEFA product codes P08–P27.
- `flows`: GREU flows → ESA-2010 transaction codes (P1, P2, P3, P51g, P52, P6, P7)
  and SEEA codes for nat_input/res_input.
- `sectors`, `financial_vars_map`, `fixed_assets`: → ESA-2010 sector/instrument/
  asset codes.

These maps mean the target structure is already expressed in EU vocabulary; the
work is sourcing EU data on the right-hand side of each map.

## Mapping table

| Danish input (consumed by read_data.py) | Content | EU source candidate | Verdict | Gap notes |
|---|---|---|---|---|
| `io_long_format.xlsx` | Full IO: production+import rows × use columns, 57 indu | **FIGARO** ind-by-ind IO (64×64, incl. import matrices); alt. national tables `naio_10_cp1750` (symmetric ind×ind), `naio_10_cp15`/`naio_10_cp16` (supply/use) | COARSER | NACE A64 vs GREU 57: aggregation is fine via existing map, but GREU industries that *split* one NACE code (organic/conventional agri, waste subdivisions, energy subdivisions 35011/35002) need splitting keys (org_* stats, PRODCOM, or Danish shares as prior). |
| `io_long_format` prim_input rows (tax_products, tax_vat, emp_comp, gross_surplus, …) | Primary inputs by industry | FIGARO valuation layers + `nama_10_a64` (VA components by A64) | OK/COARSER | tax_products split into 5 named taxes not available (see taxes row). |
| `io_energy_long_format.xlsx` | Energy-only IO (money) | **Constructed public core:** PEFA physical supply-use plus a modelled price/tax layer, constrained by SUT and price/tax controls | GAP / PILOT BUILT | Direct coverage remains zero. Sweden 2020 is the first accepted calibrated package: 177 modelled use cells, 610.583 bn SEK purchaser value, with 299.131 bn SEK explicit unmatched SUT residual. |
| `energy_and_emissions.xlsx` | PJ + emissions + full price decomposition by bal/flow/indu/purp/product | Physical: `env_ac_pefasu` (PEFA supply-use, PJ, by NACE); balances `nrg_bal_c` (product detail, no industry dim). Emissions: `env_ac_ainah_r2` (air emissions by NACE A64 + households, all gases). Purpose candidate: **JRC-IDEES-2023** + EUTL | COARSER | **PEFA pilot:** concept-adjusted 2,237.794 vs GREU 2,251.550 PJ (−0.611%); household total +0.039%. **IDEES pilot:** process envelope +3.05%, but exact purposes remain constructed. **EUTL pilot:** proves which installations/emissions are regulated but publishes no fuel or PJ; it cannot populate `in_ETS` without installation→industry plus fuel/emission-factor modelling. Four PEFA product-map issues also need correction (P18, ambient heat, spelling, P10). |
| — price decomposition (basic→purch: 3 margins, 5 taxes, VAT per energy cell) | | `naio_10_cp15`: broad CPA basic/purchaser totals, **combined** trade+transport margins and net product taxes; `cp16`: broad CPA purchaser use; `env_ac_taxind2`: payer totals; Eurostat electricity/gas components; EC Oil Bulletin; TAXUD rates | GAP | None supplies the joint cell. `cp15` does not split GREU's wholesale/retail/motor margins; tax accounts do not identify products/rates; electricity/gas/oil prices lack NACE/purpose and gas is not complete EU-27; VAT rate lacks taxable base/recovery. An explicit tax/price engine or redesigned model interface is required. |
| `non_energy_emissions.xlsx` | Process emissions by indu (incl. HFC/PFC) → model `qEmmxE` | `env_ac_ainah_r2` (residence, combined energy+process) + `env_air_gge` CRF2/3/5 (territorial process control) | COARSER / PILOT DONE | **DK-2020 pilot (2026-08-19):** Excel is load-bearing. Copy ainah F-gases wholly as non-energy (do not substitute CRF2F HFC — that drops SF6/PFC). `ainah − energy` is tautological for CH4/N2O. Item 9 is two stacked A01 gaps, not a missing source. All 27 countries publish 2020 ainah at A64 and CRF1/2/3/5. Do **not** PEFA×EF for DK; do **not** subtract CRF1 from ainah. Figures: `docs/eu_data_pilots.md`. |
| `emissions_bridge_items.xlsx` | Residence adjustments (bord_trade, internat_transp) + LULUCF | `env_ac_aibrid_r2` (air emissions accounts **bridging items**) — one dataset covers all three rows incl. the LULUCF block | OK / PILOT DONE | **DK-2020 pilot (2026-08-17): net residence adjustment matches to ≤0.05% per gas; zero EU-27 coverage gaps** — the first pilot with complete coverage. The Danish two-row split (bord_trade vs internat_transp) is a national definition; Eurostat splits by mode, and the ~362 kt CO2 difference is a quantified internal reclassification (international road hauliers). `internat_transp` is never exported to GAMS. LULUCF: exact concept match (= `env_air_gge` CRF4 cell-for-cell) but Danish level is +17.7% CO2-eq — inventory vintage. Both sides use AR5 GWPs (verified arithmetically). |
| `employed.xlsx` | Employment + hours by indu × employees/self-employed | `nama_10_a64_e` (employment by A64: persons and hours; `SELF_DC` self-employed is published directly, EMP−SAL only needed where suppressed) | OK / PILOT DONE | **DK-2020 pilot (2026-07-31): hours reconcile to <0.001% nationally and exactly in 24 of 28 clusters** — and hours are the only per-industry content `read_data.py` uses (self/employee hours ratio for imputed labour income; head counts collapse to one national scalar). Persons carry a uniform **+3.52%** concept gap (Danish column is a non-standard person concept — colleague question). Known L↔68203 boundary reappears (cluster L hours +180%). Hours not at A64 for DE/FR/BE/BG/LT/EE; SE suppresses 6 A64 codes (pair residuals derivable). |
| `fixed_assets.xlsx` | Capital stock by indu × 7 asset types → model uses 3 GREU types (`iB`/`iT`/`iM`) | `nama_10_nfa_st` (net capital stocks at current replacement cost, `CRC_MNAC`) | OK / PILOT DONE | **DK-2020 pilot (2026-08-18): number-exact** at the net CRC totals the model uses. 24/28 industry clusters exact; the four that differ are the known NACE-L/services boundary (decision 7) and cancel. All 27 countries publish 2020 net stocks including transport (`N1131N`); 9/27 at A64, the rest A21 except Malta (missing B and D). Sweden is A64 and **net-only** (no gross). PIM not needed. Colleague reference uses gross and drops `iT` — rejected. Figures: `docs/eu_data_pilots.md`. |
| `io_invest_long_format.xlsx` | Investment matrices (build/trans/other) by producing indu × investing indu — but **only two margins are load-bearing**, see below | **GAP (reduced scope, 2026-08-07; use-margin *totals* closed 2026-08-18).** No EU source publishes the joint producing × investing matrix, but the model never uses it. Supply side = FIGARO `P51G` column by supplying product (3-way asset split still a concordance). Use side = `nama_10_a64_p5` P51G by asset × industry: **DK 2020 3-type totals number-exact** vs `io_invest_long_format.xlsx` (buildings=`N11KG`, transport=`N1131G`, other=remainder); A64 × 3 assets for 13/27 countries; A21 fallback for 14. Industry split inside clusters is the remaining gap (decision 7 on four clusters; three GREU industries span A21 so the `n_g` identification arithmetic is not a partition) | GAP | **Reframed 2026-08-07** (`read_data.py:305-311`). **2026-08-18:** use-margin *national 3-type totals* are direct data, not an estimation problem. Remaining use-side work is GREU↔A64 concordance (13 countries) / A21 disaggregation (14), blocked on decision 7. Supply side still a concordance. See the task record and `docs/eu_data_pilots.md`. |
| `ets.xlsx` | Free/bought allowances, verified emissions, implied tax by indu | **European Commission Union Registry + EEA EU ETS viewer**: anonymous daily installation-level GZIP-CSV plus EEA aggregates, all EU-27 | COARSER | DK 2020 totals reproduce almost exactly: emissions +0.0067%, free allocation +0.0023%, installation shortfall +0.0020%. Emissions/allocation are direct; “bought” is derived as positive installation shortfall, not observed purchases; tax/cost needs an external EUA price. Registry activity codes are not NACE. A public secondary carbon-leakage-list NACE map covers 97.59% of DK emissions but is not authoritative enough to close the industry bridge. |
| `government_finances.xlsx` | Gov exp/rev by ESA transaction (D1, P51c, D3, …) | `gov_10a_main` + `gov_10a_taxag` (main aggregates of general government + tax detail) | OK / PILOT DONE | **DK-2020 pilot (2026-08-17): number-exact** — every mappable row reconciles to the third decimal (bn DKK) except interest revenue `D41REC` (+0.62%); the MAKRO caveat did not materialize. Four re-readings needed (PAL sits in `D51A_C1`; Danish "D214" row = D212+D214; D42–D45 only as a bundle for DK; disagg sheet is signed). Remaining structural gaps, all with named candidates: 4 dom/RoW counterpart splits, D421/D422/D45 detail, PAL as separate series, EU-paid CAP subsidies (→ `nasa_10_nf_tr` or fixed shares). 14/27 countries complete; gaps are plausibly-zero items plus patchy counterpart memos. |
| `institutional_financial_accounts.xlsx` | Net financial positions by sector (hh/corp/gov/row) × instrument groups | `nasa_10_f_bs` (financial balance sheets by sector × instrument F2–F8); flows/interest/dividends: `nasa_10_nf_tr` (D41, D42) | OK / PILOT DONE | **DK-2020 pilot (2026-08-18): the model never reads this Excel** — all 8 exported symbols are orphaned; `data_from_GR.gms:138-140` loads `vNetFinAssets`/`vNetDebtInstruments` from the live Eurostat module instead, now verified: equity = F5 net matches gov/row exactly; D41/D42 flows exact for gov/row and corp+hh in sum; **all 27 countries complete** incl. S128_S129. The Danish pension reallocation is quantified (equity 2,703.8 bn, hh net wealth +837.3 bn, ≈ the S128_S129 portfolio) and NOT implemented in the module → decision 18. Colleague reference's Equity=F51 does **not** reproduce the Danish file. Open: small gov/row debt-stock gaps (vintage candidates), module hardcodes DK/2019-2020, no raw provenance. |
| `metadata.xlsx` | Sets + concordances | Stays; becomes the master EU concordance file | KEPT | Extend maps to: PEFA product list per country availability, EUTL activity→NACE, asset→product bridge. |
| Household consumption detail (12 cGroups) | | `nama_10_co3_p3` (consumption by COICOP 1999 purpose) | COARSER / PILOT DONE | **DK-2020:** no separate Excel — the 12 groups are `io_long_format` `cons_hh`/`cons_hh_foreign` columns and **are load-bearing** (CES nest `qCHh` from `qD[c]`). 3-digit uniquely identifies 3/12 groups; food cluster and 1999 beverages+tobacco pass; `cTou` matches FIGARO `OP_RES` exactly. All 27 countries publish 2020 at 3-digit. Recipe: collapse the existing map to published digit depth, take `cHouEne`/`cCarEne` from the energy core, treat `cTou` as a tourism residual. Figures: `docs/eu_data_pilots.md`. |
| `EU_GR_data.gdx` | Marginal tax rates `tEAFG_REmarg`, `tCO2_REmarg` from Danish GreenREFORM | **Constructed public-core GDX for Sweden; no direct EU counterpart** | GAP / PILOT BUILT | Sweden uses allocated average `ener_tax/PJ` as an explicit average=marginal assumption and zero separate CO2 rate. Public-core mode bypasses Danish industry surgery. This proves compatibility, not direct marginal-rate observation. |

## The four structural gaps (= the real work of step 2)

1. **Energy IO in money terms** (`io_energy_long_format`): the Sweden public
   core now proves a transparent calibrated construction. It closes PEFA/SUT
   accounting controls but leaves 1,765.088 PJ reporting-detail residual and
   118.844 bn SEK unmatched use-side monetary residual (down from
   299.131 bn SEK, 2026-07-31) plus 102.567 bn SEK newly-exposed supply-side
   residual. The remaining gap is improving those allocations without
   inventing detail, not interface feasibility.
2. **Purpose dimension (`purp`)**: **partly closed, still a construction gap.**
   JRC-IDEES-2023 is public, EU-27-wide, annual for 2000–2023, and supplies
   detailed industrial processes/end uses. The DK pilot shows that it supports a
   credible combined process envelope, but it does not publish GREU's
   normal/special boundary or own-account transport by user industry. The EUTL
   pilot now identifies regulated installations and emissions, but not energy
   use, fuel or PJ. Route: IDEES process codes + PEFA controls + EUTL membership
   and an installation→industry bridge, followed by explicit fuel/emission-factor
   modelling for `in_ETS`; owner-approved concordance and residual rules remain
   essential.
3. **Investment split** (was "investment matrices"; **rescoped 2026-08-07**,
   use-margin totals **closed 2026-08-18**): the model needs two margins, not
   the joint producing × investing matrix. Supply side = split FIGARO's
   single `P51G` product column into buildings/transport/other (still a
   concordance). Use-margin *national 3-type totals* match `nama_10_a64_p5`
   P51G exactly for DK 2020; 13/27 countries publish the same at A64. What
   remains is the industry dimension: A64→GREU concordance for those 13
   (blocked on decision 7), and A21 disaggregation for the other 14 — but
   three GREU industries (`55560`, `71000`, `off`) span several A21 sections,
   so the `n_g` identification arithmetic is not a partition. See the task
   record and `docs/eu_data_pilots.md`.
4. **Marginal tax rates** (`EU_GR_data.gdx`, added 2026-07-28): Denmark still
   imports the GreenREFORM stopgap. Sweden's complete public-core GDX proves the
   compatibility route using explicit average=marginal rates, while recording
   the separate CO2 marginal rate as unavailable/zero. A legal excise/ETS
   engine is still needed before these assumptions can be treated as policy
   rates rather than calibration rates.

Cross-cutting: **industry splits** beyond NACE A64 (organic/conventional,
waste industries, 35011/35002 energy split) need country-specific splitting
keys or a decision to run EU countries at the aggregated level (model detail
question for colleagues).

## Full pipeline (traced end-to-end 2026-07-28)

`run.py` is the entry point; the model reads **only** `data/data.gdx`:

```
run.py
 ├─ financial_accounts_data.py → financial_accounts_data.gdx  ← Eurostat nasa_10_f_bs, LIVE (already EU-sourced, PR #107)
 ├─ energy_money config        → validates selected layer     ← DK detail by default; public core fails closed
 ├─ read_data.py               → data_<CC>.gdx                ← only monetary-energy paths are configurable so far
 ├─ data_from_GR.gms           → data.gdx                     ← selected GDX passed by macro; symbols unchanged
 └─ base_model*.gms            ← data/data.gdx only
      └─ energy_technology.gms ← currently generic dummy data (settings.gms flag=1); Excel route optional
```

`previous_difference.gdx` is model-generated calibration bookkeeping, not input data.
The financial-accounts module (live Eurostat pull with caching, → gdx) is **out of our
scope but the working template** for how each replaced input should be built — and since
it already pulls `nasa_10_f_bs`, the `institutional_financial_accounts.xlsx` replacement
can likely reuse its code directly.

## Audit log & known caveats (2026-07-28, all verified against code/live API)

- **2026-08-04:** a management-facing overview workbook now exists at
  `docs/EU_data_overview.xlsx` (Summary: one traffic-light row per consumed
  input; Detail: one row per variable/component with pilot evidence). It is
  generated — transcribed from this file, no new analysis — by
  `data/preprocessing/scripts/build_eu_data_overview_xlsx.py`; re-run that
  script whenever a verdict or pilot result here changes.
- All 17 original Eurostat codes were re-verified against the live API
  2026-07-28 (HTTP 200). The FIGARO, PEFA/air and monetary pilots have since
  tested the relevant values/dimensions for 8 of those original codes
  (`env_ac_pefasu`, `env_ac_ainah_r2`, 3 FIGARO tables, `naio_10_cp15`/`cp16`,
  and `env_ac_taxind2`). Four newly added price-component codes were also
  tested. The untouched original codes remain existence-only.
- Inventory arithmetic clarified 2026-07-29 (see §Scope): 16 Excel files in the
  folder → 4 are unread `*_matrix_format` views → 12 consumed + 1 gdx = 13 inputs
  → 12 need EU sources (`metadata.xlsx` kept). The two distinct "12"s had been
  used interchangeably.
- `EU_GR_data.gdx` was missing from the original (xlsx-only) inventory; added
  above as gap 4.
- `government_finances.xlsx` values come from MAKRO (`read_data.py:428`), so the
  `gov_10a_main` verdict "OK" means concept-match, not number-match.
- **Code bug** (logged as Q4 in the roadmap, for Asbjørn; not fixed pending his
  answer): `read_data.py:697-699` fills
  `vY_i_d`, `vM_i_d`, `vA_i_d` all from `io_ene_y_onlys`; the `_m_`/`_a_`
  variants built at lines 289-295 are never used. Block is an export "til
  Asbjørn" — check consumer before fixing. Also three no-op `.rename()` calls
  without assignment around lines 562-568.
- NACE Rev. 2 → Rev. 2.1 migration is rolling through Eurostat national
  accounts; the `industries_naceA64_map` may need a Rev. 2.1 variant. Unassessed.
- Historical note: the 2026-07-27 hand checks had no re-runnable scripts.
  All five pilots now leave downloader/reconciliation scripts and auditable
  artifacts in `data/preprocessing/scripts/` and `data/preprocessing/data/`.

## Open items

Completed items 1–5, 9, 12, 13, 15 and 17 are archived with their evidence in
`docs/eu_data_pilots.md`; only what is still open is listed here. Item numbers
are kept stable so older notes and the roadmap still resolve.

### Data tasks (no colleague input needed)

- **17 — DONE (2026-08-19).** Pilot the remaining inputs one per increment.
  Last increment: household consumption detail (`nama_10_co3_p3`) vs the
  12 GREU `c` groups in `io_long_format.xlsx`. 3-digit uniquely identifies
  3/12; food cluster and 1999 beverages+tobacco pass; `cTou` = FIGARO
  `OP_RES` exact; all 27 publish 3-digit. **No remaining unpiloted Danish
  input.** See `docs/eu_data_pilots.md`. Remaining parameterization work
  is item 19 (module hardening) and gap-3 (industry dimension).
- **9 — DONE (2026-08-19).** Two stacked A01 gaps, not a missing source:
  GREU below current CRF3, ainah above CRF3. See Pilot 11 in
  `docs/eu_data_pilots.md`.
- **19 (follow-up task, needs no decision).** Bring
  `Modules/financial_accounts/financial_accounts_data.py` up to repo
  standards: parameterize `geo`/years (currently hardcoded DK/2019-2020),
  add raw-payload provenance (currently a cache without manifest), and —
  once decision 18 lands — implement or explicitly reject the pension
  reallocation. The pilot verified its instrument definitions are correct.
- **14 (optional).** If colleagues want the `CPA_C16` residual annotated rather
  than merely accepted, wire the PRODCOM export share (~1.15% energy-relevant)
  into the builder as an audit annotation — an annotation, not an allocation,
  since PRODCOM values are ex-works/FOB against SUT purchaser prices.
- **Structural gap 3 (investment split).** Rescoped 2026-08-07. The A21→GREU
  lookup is done (2026-08-18): three GREU industries span A21, so the `n_g`
  rule is not a partition; use-margin *totals* are direct data. Remaining:
  supply-side concordance, industry split inside clusters (decision 7), and
  A21 disaggregation for the 14 countries without A64 GFCF. Denmark back-test
  of 3-type totals already passed; the industry-dimension back-test is still
  open (method decisions permitting).

### Decisions needed from colleagues

Each item carries *owner / raised / blocks* tags so the backlog can be
triaged; the same list is transcribed into the `decisions` sheet of
`docs/EU_data_overview.xlsx` (regenerate via
`build_eu_data_overview_xlsx.py` whenever this list changes).

- **13 (remaining part).** Accept the evidence-backed non-energy residuals
  (`CPA_C16` ≥98.5%, `CPA_E37-E39` ≥85%) as permanent disclosed features of the
  public-core method — recommended — optionally annotating `CPA_E37-E39` with
  its ~1.0 bn SEK documented energy ceiling.
  *(owner: energy-money work-stream colleagues; raised 2026-07-31; blocks:
  formally closing the Sweden monetary-residual work stream.)*
- **6.** Which GREU industry splits survive in the EU version? Splits finer than
  NACE A64 (organic/conventional farming, five waste industries, electricity
  35011/35002) need country-specific keys or a decision to run other countries
  at the aggregated level.
  *(owner: model owners; raised 2026-07-28; blocks: the final industry
  dimension of every converted input — every EU package built before this is
  decided may need re-cutting.)*
- **7.** Handling of re-exports, and of the NACE-L ↔ 68203 real-estate split.
  Add a note or split key to `industries_naceA64_map`. **Four separate pilots
  have now hit this** (FIGARO, PEFA, employment, fixed assets); it blocks
  each of them. The fixed-assets diffs cancel across L / 71000 / off / 55560.
  *(owner: `metadata.xlsx` concordance owner; raised 2026-07-29; blocks: exact
  cluster-level reconciliation in the FIGARO, PEFA, employment and
  fixed-assets pilots.)*
- **8.** Review and correct the four energy-product concordance issues the PEFA
  pilot exposed: P18 missing from diesel, heat-pump ambient energy belongs with
  renewable natural inputs, `sem_refin_oil` misspelling, P10 unmapped. The
  pilots applied these as explicit adjustments and did **not** modify
  `metadata.xlsx`; owner review is required first.
  *(owner: `metadata.xlsx` concordance owner; raised 2026-07-30; blocks:
  removing the pilots' ad-hoc adjustment layer from every PEFA-based build.)*
- **10.** Agree the IDEES process-code concordance and the rules for `heating`,
  `process_normal` and `process_special`; keep transport on the PEFA/account
  side.
  *(owner: energy/purpose work-stream colleagues; raised 2026-07-30; blocks:
  structural gap 2, the purpose dimension.)*
- **11.** Decide whether to maintain a reviewed installation→NACE concordance
  or redesign ETS inputs at regulatory-activity level, and specify the
  fuel/emission-factor method needed to construct `in_ETS` PJ without absorbing
  process emissions.
  *(owner: model owners + emissions colleagues; raised 2026-07-30; blocks:
  the `ets.xlsx` industry bridge and the `in_ETS` part of gap 2.)*
- **16.** What person concept does the Danish `employed` column use? It sits a
  uniform +3.52% below Eurostat/DST national-accounts annual-average
  employment while the hours columns match exactly. Only the scalar
  `nEmployed(t)` depends on the answer.
  *(owner: whoever built `employed.xlsx` (MAKRO/DST side); raised 2026-07-31;
  blocks: only the `nEmployed(t)` scalar — low stakes.)*
- **Investment split method.** Denmark-as-prior, and whether time-invariant
  shares are defensible; see the task record at the end of this file (which
  also carries the Julia-toolchain question).
  *(owner: model owners / management; raised 2026-08-07; blocks: starting the
  gap-3 estimator and Denmark back-test.)*
- **18 (new 2026-08-18).** The financial-accounts pilot showed the Danish
  pension-asset reallocation (metadata `sectors` note) is quantitatively
  material — 2,703.8 bn DKK of equity and a non-net-neutral +837.3 bn DKK
  shift in household net financial assets — and the live module
  (`Modules/financial_accounts/financial_accounts_data.py`) does not
  implement it, so the model's household wealth calibration currently runs
  on unadjusted Eurostat numbers. Decide: replicate the reallocation from
  S128_S129 subsector balance sheets (published EU-wide), or accept the
  unadjusted definition as the EU-generic concept.
  *(owner: model owners; raised 2026-08-18; blocks: closing the
  `institutional_financial_accounts.xlsx` row beyond COARSER, and any use of
  household-wealth levels in calibration.)*

## Handoff — stopping point and next session

Where the project stands is summarized in "Current status" at the top of this
file; the evidence behind it is in `docs/eu_data_pilots.md`. This section
records only what the next session needs to act on.

**Next task (do not broaden it):** item 17 is complete — there is no
remaining unpiloted Danish input. Done 2026-08-19 (this session):
household consumption detail (`nama_10_co3_p3`) vs the 12 GREU `c` groups
in `io_long_format.xlsx` `cons_hh`/`cons_hh_foreign`. Headline: **CES nest
is load-bearing; 3-digit uniquely identifies 3/12 groups; food cluster and
1999 beverages+tobacco pass; `cTou` = FIGARO `OP_RES` exact (17.159);
all 27 countries publish 2020 at 3-digit.** Map is COICOP 2018-style
(tobacco=023) against a 1999 table (tobacco=`CP022`); `CP072` mixes car
fuels with maintenance. Recipe: collapse the map to published digit
depth, take `cHouEne`/`cCarEne` from the energy core, treat `cTou` as a
tourism/RoW residual. Evidence: `docs/eu_data_pilots.md`, workbook
`data/preprocessing/data/hh_consumption_dk2020_reconciliation.xlsx`.
**Next: item 19** (harden `Modules/financial_accounts/financial_accounts_data.py`:
parameterize `geo`/years, add raw provenance, then decision 18) **or
gap-3** industry-dimension Denmark back-test (method decisions
permitting; 3-type totals already pass).

**Colleague reference implementation (received 2026-08-17):** an
Eurostat-only "EU core" GREU variant (no energy/emissions/climate), committed
as reference material under `data/read_eurostat_data/` +
`data/data_from_eurostat.gms`. See that folder's README for provenance and
caveats (A19 aggregation, live-API pulls without raw provenance, a
`.gms`-vs-Python parameter-name skew). Use it as concordance seed material —
it is not the deliverable pipeline. Its `factor_demand_data.py` pointed at a
real gap-3 lead: `nama_10_a64_p5` publishes GFCF by `asset10` at (near-)A64
industry detail for 13/27 countries incl. DK and SE (probed 2026-08-17, see
the gap-3 task record below) — the use margin is nearly direct data there.

**Follow-up conversation with the colleague (2026-08-18):** the
`.gms`-vs-Python parameter-name skew is confirmed harmless-but-silent, not a
sign the pipeline is broken — GAMS's `execute_load` (used by her `@load`
macro) zero-fills missing names instead of erroring, so the model solves; it
just means the financial-accounts block runs on zeros. She confirmed this is
an incomplete push, not intentional, and that her own validation checked GDP
only, not financial accounts. Separately, and more decisive for scoping: the
model is being rewritten in Julia by a second colleague (Kristina), which
makes the GAMS `model/` files in `GREU_EU_core` a shrinking asset. **Decision:
do not spend further time reconciling or adopting her GAMS model modules
(`financial_accounts.gms` and the other 11 modified modules).** Keep using
only her Python data-layer scripts as concordance seed material, per the
README — that knowledge is language-independent and is what carries over to
the Julia rewrite too.

**Prerequisites/decisions carried over:** colleague acceptance of the
now-evidence-backed non-energy residuals (`CPA_C16`, `CPA_E37-E39`); do not
infer an allocation from Danish target values. Air-emission allocation,
industrial purposes/`in_ETS`, the investment split and the other Sweden inputs
remain separate later work streams.

**Related finding (2026-07-31, already fixed, does not change the task above):**
the verification audit found and fixed a distinct gap — `CPA_B05`/`CPA_B06`
(coal, crude oil) have no Eurostat SUT breakdown at all for Sweden, so
916.7847 PJ was silently valued at zero. This is now an explicit, flagged
anomaly (see the Sweden section of `docs/eu_data_pilots.md`), not a hidden one, but it is still
**unresolved** in the sense that no monetary value exists for that energy at
all. If a country ever publishes a usable `CPA_B`-level split, or a different
public source can proxy coal/crude value, that would close a real gap — but
this is a separate, lower-priority thread from the CPA_C16/E37-E39 task above,
which concerns misallocation across too-broad controls rather than a missing
control.

**Documentation state (2026-08-20):** `docs/What_the_model_uses.xlsx`
now has three sheets: Read me, an everyday overview, and **By model
module** (one row per data-fed variable, grouped as `model/modules/`).
The module sheet splits **Where to find it** (Eurostat/FIGARO/ETS table
code, e.g. `env_ac_pefasu`) from **Considerations** (same object / only a
total / we construct it). Generated by
`data/preprocessing/scripts/build_what_the_model_uses_xlsx.py`.
Not a status report. Other documents remain as of 2026-08-19. **Safe to
start the next session on item 19 or gap-3, or on any item from the
open-decisions list.**

## Task recorded 2026-08-07 — investment split (structural gap 3), reframed

**Origin:** management discussion framed as a supply-table / use-table drawing.
Denmark publishes investment split by investing industry *and* asset type
(buildings / transport / other); no EU source publishes the equivalent. The
proposal was a small Julia script using Denmark as a prior, with the hope that
additional years would identify stable parameters. This record exists so the
task can be resumed cold.

### Correction to the gap-3 framing used elsewhere in this document

The mapping-table row for `io_invest_long_format.xlsx` and structural gap 3
both previously described the missing object as a full producing-industry ×
investing-industry matrix. **Verified 2026-08-07 that the model never uses
that joint table** (both places are now corrected). Evidence, read directly
from source:

- `read_data.py:305-311` drops the supplying dimension explicitly. The inline
  comment reads: `atm we do not care abt. "sender" of capital, just building
  qI_k_i`. It drops `row_l1`/`row_l2` and groups to `['k','i','year']`.
- `read_data.py:684` writes the result as `qI_k_i` with domain `[k,d,t]` —
  asset type × industry × year. No supplying dimension survives.
- `factor_demand.gms:64` closes the market on that object alone:
  `qD[k,t] =E= sum(i, qI_k_i[k,i,t])`.
- `input_output.gms:209-210` redistributes `qD[k,t]` across supplying
  industries via calibrated shares:
  `qY_i_d[i,d,t] =E= (1-rM[i,d,t]) * rYM[i,d,t] * qD[d,t]`.
- `read_data.py:87` and `read_data.py:204-210` map the IO columns
  `invest_build` / `invest_trans` / `invest_other` to demand codes `iB` /
  `iT` / `iM`.
- `input_output.sets.gms:10` declares `Set k[d<] "Capital types."` — capital
  types are demand components, so investment goods flow through the ordinary
  IO machinery rather than a dedicated matrix.

**Conclusion: GREU requires two margins, not the joint table.** Gap 3 is
materially smaller than previously recorded, and the full-matrix RAS described
in the old text is not needed. The only cross-margin condition is mutual
consistency: the column total of the IO investment column for type `k` must
equal `sum(i, qI_k_i[k,i,t])`.

### The two estimation problems

**1. Supply margin — which industries produce investment goods, by type.**
FIGARO gives a single `P51G` final-demand column broken down by supplying CPA
product (verified: DK 2020 `P51G` = 516.1 bn DKK, matching Danish
`invest_build + invest_trans + invest_other` to ≤0.1%, see
`reconcile_figaro_dk_2020.py:261-263`). This must be split three ways.

This is mostly a concordance problem, not an estimation problem: construction
products → `iB`, CPA C29-C30 → `iT`, machinery / ICT / intellectual property →
`iM`. Only genuinely ambiguous products need estimating. Do **not** treat it as
a free 64×3 estimation — the counting argument below shows that would not be
identified, and it does not need to be.

**2. Use margin — which industries buy investment goods, by type.**
For 13/27 countries (incl. DK and SE) this is `nama_10_a64_p5` P51G at A64
× asset — a concordance to GREU industries, not an estimation. DK 2020
3-type totals match `io_invest_long_format.xlsx` exactly (2026-08-18
pilot). For the other 14 countries the fallback is `nama_10_nfa_st` /
`nama_10_a64_p5` at A21, and that *is* a within-group disaggregation.
**Caveat (lookup 2026-08-18):** three GREU industries do not nest in one
A21 section (`55560` → I,J,N,R,S,T; `71000` → J,M,N; `off` → O,P,Q,R), so
the `n_g` identification arithmetic below is not a partition.

**Probe 2026-08-17, confirmed against saved raw payloads 2026-08-18:**
`nama_10_a64_p5` publishes GFCF (`P51G`, current prices) by `asset10` **at
(near-)A64 industry detail** for 13/27 countries — AT, BG, CY, CZ, **DK**,
EL, FI, HU, LV, PT, RO, **SE**, SK all populate ≥55 A64 industries for the
three key asset groups (N11KG buildings, N1131G transport, N11MG machinery).
The remaining 14 publish A21-level cells. Stocks (`nama_10_nfa_st` net CRC):
all 27 have 2020 `N11N` + `N1131N`; 9/27 at A64 (AT, BG, CZ, DK, EL, FI, LV,
SE, SK). Sweden publishes **net only** (no gross). PIM is not needed.

**Asset concordance already exists for Denmark** at `read_data.py:89`, mapping
7 ESA asset codes to the 3 GREU groups:
`{'N11P':'iM', 'N1121':'iB', 'N1122_3':'iB', 'N1131':'iT', 'N115':'iM',
'N117':'iM', 'N111':'iB'}`. Per the comment block at `read_data.py:90-97`:
N11P = ICT equipment, other machinery, stocks and weapons systems;
N1122_3 = facilities; N1131 = means of transport; N115 = stock of animals;
N117 = intellectual rights; N111 = housing. These are standard ESA codes and
should carry over to any member state unchanged.

### Identification — how many years are actually needed

Let `x[k,i,t]` be investment of type `k` by industry `i` in year `t`. Assume
time-invariant shares: `x[k,i,t] = s[k,i] * A[i,t]`, where `A[i,t]` is the
industry's total investment (known) and `sum_k s[k,i] = 1`.

Under this parameterization the industry totals are satisfied by construction
and place **no** constraint on the shares. The binding constraints are the
observed A21-group-by-asset cells from `nama_10_nfa_st`:
`C[g,k,t] = sum_{i in g} s[k,i] * A[i,t]`.

Within one A21 group `g` containing `n_g` GREU industries:

- free parameters: `2 * n_g` (three shares per industry, summing to one)
- independent constraints per year: 2 (three asset equations, one redundant
  because they sum to the known group total)
- therefore **years required ≈ `n_g`**

**Consequences.** Groups mapping to few GREU industries identify within a few
years. Groups mapping to many — manufacturing above all — will not identify
from time variation alone within the available annual national-accounts span,
and the Danish prior will continue to determine the answer there. The estimator
should report, per group, whether it is data-identified or prior-determined.

**Caveat that applies throughout:** identification requires the `A[i,t]` to
move *differently* across years within a group. If all industries in a group
grow near-proportionally, extra years add near-collinear equations that
contribute no information despite increasing the count.

### Recommended first deliverable — Denmark back-test

Denmark has the true joint table for many years. Withhold it, keep only the
margins Denmark would have if it were an ordinary member state (FIGARO `P51G`
by product; an A21-by-asset table aggregated from the Danish truth; industry
investment totals), run the estimator, and compare the reconstruction against
the withheld Danish table.

This yields, with no new downloads and no dependency on other countries:

- whether the method recovers a known answer at all, and with what error
- how many years are needed in practice, per A21 group, against the `n_g` rule
- whether Danish asset shares are in fact stable over time — the precondition
  for Denmark being a defensible prior for anyone else
- which groups remain prior-determined, quantified rather than assumed

If Danish shares turn out to be unstable over time, the whole
Denmark-as-prior approach needs rethinking, and this test finds that out first
and cheaply.

### Implementation notes

Proposed as a small Julia script (JuMP + Ipopt suits constrained cross-entropy
minimization well). **There is currently no Julia anywhere in this
repository** — all model/script files are `.gms` or Python. Adding Julia is a
new toolchain dependency and needs explicit sign-off; the same estimator is
expressible in Python with SciPy if preferred, at some cost in speed and
expressiveness.

Method: RAS / biproportional fitting for the plain margin case; cross-entropy
minimization against the Danish prior for the general case, which handles
multi-year pooling and lets the prior's weight be set explicitly.

### Codes and facts verified 2026-08-18

- **GFCF by asset type** is `nama_10_a64_p5` `P51G` (not `nama_10_a64`).
  EU-27 coverage: 13/27 A64 × the three GREU types; 14/27 A21. DK 2020
  3-type totals number-exact vs `io_invest_long_format.xlsx`. Year span
  typically 1995–2024 (DK 1975–2025, SE 1993–2024).
- **A21→GREU-57 lookup done.** Wholly-contained `n_g`: A=13, C=13, H=12,
  E=7, G=3, D=2, B=F=K=L=1; I,J,M,N,O,P,Q,R,S,T = 0 because three GREU
  industries span those sections (`55560`, `71000`, `off`). The
  identification arithmetic is not a partition. Manufacturing (C, n_g=13)
  still will not identify from time variation alone.

### Open questions for colleagues

1. Acceptance of Denmark-as-prior (already flagged as a method decision in the
   gap-3 text).
2. Whether time-invariant shares are defensible, or whether a smoothness
   penalty across years is the better assumption.
3. Julia as a new repository dependency.
4. Whether pooling across member states that publish finer investment detail
   could reduce or replace reliance on the Danish prior.
5. How to report prior-determined groups in model output, so downstream users
   know which parts of the investment split are data and which are assumption.

**Resume commands and artifacts:**

```powershell
python data/preprocessing/scripts/download_energy_money_public_core.py --country SE --year 2020 --currency SEK
python data/preprocessing/scripts/build_energy_money_public_core.py --country SE --year 2020 --force --check-determinism
$env:GREU_COUNTRY_CODE = "SE"
$env:GREU_ENERGY_MONEY_MODE = "public_core"
python -c "from data.Modules.energy_money import get_energy_money_config; get_energy_money_config().validate(); print('PASS')"
python -m unittest test_energy_money.py
```

Start from `energy_money_se2020_public_core_reconciliation.xlsx`, especially
`valuation_controls`, `allocation_weights`, `sut_comparison` and `anomalies`;
the source hashes/URLs are in `eu_core_raw/SE/2020/manifest.json`, and the
runtime hashes are in `eu_core/SE/energy_money_manifest.json`.
