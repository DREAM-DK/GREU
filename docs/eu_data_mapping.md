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
| Non-specialist project overview | `docs/EU_data_roadmap.pdf` |

This file is searched far more often than it is read end to end. Use grep for
the input name or dataset code you care about rather than reading it whole.

## Current status (2026-08-17)

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
  inputs one at a time, smallest first. `employed.xlsx` and
  `emissions_bridge_items.xlsx` are done and confirmed OK;
  `government_finances.xlsx` is next.
- **Structural gap 3 was rescoped on 2026-08-07** after a code audit: the model
  needs two investment margins, not the full matrix previously recorded.

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
proven end-to-end by the 2026-08-17 emissions-bridge pilot. Four additional
annual energy-price-component codes (`nrg_pc_202_c` through `_205_c`) were
added and tested, and `env_air_gge` (UNFCCC inventory, used as the LULUCF
cross-check) was verified 2026-08-17, bringing the total from 20 to 25. The **3 FIGARO codes**
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
| `non_energy_emissions.xlsx` | Process emissions by indu (incl. HFC/PFC) | `env_ac_ainah_r2` covers **total** emissions by NACE incl. F-gases | COARSER | Energy vs non-energy split not in the accounts → derive: non-energy = total (ainah) − energy-related (PEFA fuel use × emission factors), or use UNFCCC CRF categories / EDGAR. |
| `emissions_bridge_items.xlsx` | Residence adjustments (bord_trade, internat_transp) + LULUCF | `env_ac_aibrid_r2` (air emissions accounts **bridging items**) — one dataset covers all three rows incl. the LULUCF block | OK / PILOT DONE | **DK-2020 pilot (2026-08-17): net residence adjustment matches to ≤0.05% per gas; zero EU-27 coverage gaps** — the first pilot with complete coverage. The Danish two-row split (bord_trade vs internat_transp) is a national definition; Eurostat splits by mode, and the ~362 kt CO2 difference is a quantified internal reclassification (international road hauliers). `internat_transp` is never exported to GAMS. LULUCF: exact concept match (= `env_air_gge` CRF4 cell-for-cell) but Danish level is +17.7% CO2-eq — inventory vintage. Both sides use AR5 GWPs (verified arithmetically). |
| `employed.xlsx` | Employment + hours by indu × employees/self-employed | `nama_10_a64_e` (employment by A64: persons and hours; `SELF_DC` self-employed is published directly, EMP−SAL only needed where suppressed) | OK / PILOT DONE | **DK-2020 pilot (2026-07-31): hours reconcile to <0.001% nationally and exactly in 24 of 28 clusters** — and hours are the only per-industry content `read_data.py` uses (self/employee hours ratio for imputed labour income; head counts collapse to one national scalar). Persons carry a uniform **+3.52%** concept gap (Danish column is a non-standard person concept — colleague question). Known L↔68203 boundary reappears (cluster L hours +180%). Hours not at A64 for DE/FR/BE/BG/LT/EE; SE suppresses 6 A64 codes (pair residuals derivable). |
| `fixed_assets.xlsx` | Capital stock by indu × 7 asset types | `nama_10_nfa_st` (fixed asset stocks by industry × asset) | COARSER | Eurostat side is A21 industries (not A64) and asset detail varies by country; may need capital-stock estimation (PIM) from `nama_10_a64` GFCF for missing countries. |
| `io_invest_long_format.xlsx` | Investment matrices (build/trans/other) by producing indu × investing indu — but **only two margins are load-bearing**, see below | **GAP (reduced scope, 2026-08-07).** No EU source publishes the joint producing × investing matrix, but the model never uses it. The two margins it does use: supply side = FIGARO `P51G` column by supplying product (needs a 3-way asset split); use side = `nama_10_nfa_st` asset × industry at A21 (needs disaggregating to GREU's 57) | GAP | **Reframed 2026-08-07** (verified against `read_data.py:305-311`, `factor_demand.gms:64`, `input_output.gms:209`): `read_data.py` discards the supplying dimension and builds `qI_k_i[k,i,t]` only; the supply side re-enters through the IO investment columns and calibrated `rYM` shares. So the task is two separate margin problems, not a full-matrix RAS. Supply side is mostly a concordance (buildings→F, transport eq.→C29-30). Use side is a genuine A21→57 disaggregation, identified per A21 group only where enough years are available. See the dedicated task record in the Handoff section. |
| `ets.xlsx` | Free/bought allowances, verified emissions, implied tax by indu | **European Commission Union Registry + EEA EU ETS viewer**: anonymous daily installation-level GZIP-CSV plus EEA aggregates, all EU-27 | COARSER | DK 2020 totals reproduce almost exactly: emissions +0.0067%, free allocation +0.0023%, installation shortfall +0.0020%. Emissions/allocation are direct; “bought” is derived as positive installation shortfall, not observed purchases; tax/cost needs an external EUA price. Registry activity codes are not NACE. A public secondary carbon-leakage-list NACE map covers 97.59% of DK emissions but is not authoritative enough to close the industry bridge. |
| `government_finances.xlsx` | Gov exp/rev by ESA transaction (D1, P51c, D3, …) | `gov_10a_main` (main aggregates of general government, full ESA transactions) | OK | **Caveat (2026-07-28):** `read_data.py:428` notes these values come from MAKRO, not raw DST — `gov_10a_main` will match the ESA concepts but not necessarily reproduce the Danish numbers; quantify in the pilot reconciliation. Disagg sheet uses DST statbank; EU equivalent is COFOG (`gov_10a_exp`) if functional detail needed. |
| `institutional_financial_accounts.xlsx` | Net financial positions by sector (hh/corp/gov/row) × instrument groups | `nasa_10_f_bs` (financial balance sheets by sector × instrument F2–F8); flows/interest/dividends: `nasa_10_nf_tr` (D41, D42) | OK | Danish pension-asset reallocation note (metadata `sectors`) must be replicated: move hh pension assets from financial corps to hh — pension detail is in `nasa_10_f_bs` (F6). |
| `metadata.xlsx` | Sets + concordances | Stays; becomes the master EU concordance file | KEPT | Extend maps to: PEFA product list per country availability, EUTL activity→NACE, asset→product bridge. |
| Household consumption detail (12 cGroups) | | `nama_10_co3_p3` (consumption by COICOP) | COARSER | Eurostat publishes 2–3 digit COICOP; the Danish map uses 4-digit. 3-digit is enough to build the 12 GREU groups approximately; check group-by-group. |
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
3. **Investment split** (was "investment matrices"; **rescoped 2026-08-07**):
   the model needs two margins, not the joint producing × investing matrix it
   was previously recorded as needing. Supply side = split FIGARO's single
   `P51G` product column into buildings/transport/other, which is largely a
   concordance question. Use side = disaggregate `nama_10_nfa_st` asset ×
   industry from A21 to GREU's 57 industries, which is the genuinely
   underdetermined part; Danish structure as prior, with per-group
   identification depending on the number of years available. See the task
   record in the Handoff section for the evidence, the identification
   arithmetic and the recommended Denmark back-test.
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

Completed items 1–5, 12, 13 and 15 are archived with their evidence in
`docs/eu_data_pilots.md`; only what is still open is listed here. Item numbers
are kept stable so older notes and the roadmap still resolve.

### Data tasks (no colleague input needed)

- **17 — NEXT.** Pilot the remaining OK-verdict inputs one per increment.
  Done: `emissions_bridge_items.xlsx` vs `env_ac_aibrid_r2` (2026-08-17, see
  `docs/eu_data_pilots.md`). Next: `government_finances.xlsx` vs
  `gov_10a_main` (expect concept-not-number match; the Danish values come
  from MAKRO), then `institutional_financial_accounts.xlsx` reusing the
  financial-accounts module's existing `nasa_10_f_bs` pull (replicate the
  pension-asset reallocation note).
- **9.** Investigate the +26.430 kt CH4 / +0.636 kt N2O Eurostat gaps found by
  the PEFA/air pilot (mostly agriculture) and document whether they are
  vintage or national-adjustment differences.
- **14 (optional).** If colleagues want the `CPA_C16` residual annotated rather
  than merely accepted, wire the PRODCOM export share (~1.15% energy-relevant)
  into the builder as an audit annotation — an annotation, not an allocation,
  since PRODCOM values are ex-works/FOB against SUT purchaser prices.
- **Structural gap 3 (investment split).** Rescoped 2026-08-07; see the task
  record at the end of this file. First step is a cheap lookup, not modelling:
  map the 21 Eurostat industry groups onto GREU's 57 to find which groups are
  estimable at all.

### Decisions needed from colleagues

- **13 (remaining part).** Accept the evidence-backed non-energy residuals
  (`CPA_C16` ≥98.5%, `CPA_E37-E39` ≥85%) as permanent disclosed features of the
  public-core method — recommended — optionally annotating `CPA_E37-E39` with
  its ~1.0 bn SEK documented energy ceiling.
- **6.** Which GREU industry splits survive in the EU version? Splits finer than
  NACE A64 (organic/conventional farming, five waste industries, electricity
  35011/35002) need country-specific keys or a decision to run other countries
  at the aggregated level.
- **7.** Handling of re-exports, and of the NACE-L ↔ 68203 real-estate split.
  Add a note or split key to `industries_naceA64_map`. **Three separate pilots
  have now hit this** (FIGARO, PEFA, employment); it blocks each of them.
- **8.** Review and correct the four energy-product concordance issues the PEFA
  pilot exposed: P18 missing from diesel, heat-pump ambient energy belongs with
  renewable natural inputs, `sem_refin_oil` misspelling, P10 unmapped. The
  pilots applied these as explicit adjustments and did **not** modify
  `metadata.xlsx`; owner review is required first.
- **10.** Agree the IDEES process-code concordance and the rules for `heating`,
  `process_normal` and `process_special`; keep transport on the PEFA/account
  side.
- **11.** Decide whether to maintain a reviewed installation→NACE concordance
  or redesign ETS inputs at regulatory-activity level, and specify the
  fuel/emission-factor method needed to construct `in_ETS` PJ without absorbing
  process emissions.
- **16.** What person concept does the Danish `employed` column use? It sits a
  uniform +3.52% below Eurostat/DST national-accounts annual-average
  employment while the hours columns match exactly. Only the scalar
  `nEmployed(t)` depends on the answer.
- **Investment split method.** Denmark-as-prior, and whether time-invariant
  shares are defensible; see the task record at the end of this file.

## Handoff — stopping point and next session

Where the project stands is summarized in "Current status" at the top of this
file; the evidence behind it is in `docs/eu_data_pilots.md`. This section
records only what the next session needs to act on.

**Next task (do not broaden it):** continue the OK-verdict
pilots one input per increment (item 17). `emissions_bridge_items.xlsx` vs
`env_ac_aibrid_r2` is **done (2026-08-17)** — see the pilot section in
`docs/eu_data_pilots.md`; zero EU-27 coverage gaps, net adjustment ≤0.05%.
Next: `government_finances.xlsx` vs `gov_10a_main` (expect concept-not-number
match; the Danish values come from MAKRO — the emissions-bridge pilot's
LULUCF vintage gap of +17.7% is a live example of that phenomenon), then
`institutional_financial_accounts.xlsx` reusing the financial-accounts
module's existing `nasa_10_f_bs` code (replicate the pension-asset
reallocation note). Alternative if blocked: start structural gap 3, now
rescoped to the two-margin investment split — see the dedicated task record
below, and note that Denmark-as-prior remains a method decision for
colleagues.

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

**Documentation state (2026-08-17):** all documents are synchronized —
`docs/EU_data_roadmap.html`/`.pdf`, `docs/EU_data_overview.xlsx`,
`docs/eu_data_pilots.md`, `energy_data_notes.md` and
`data/Modules/energy_money/README.md`. **No pending doc updates; safe to start
the next session directly on the `government_finances.xlsx` pilot, or on any
item from the open-decisions list.**

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
`nama_10_nfa_st` gives assets by type and industry at A21; GREU needs 57
industries. This is a within-group disaggregation from A21 to the GREU
industry list, holding asset type fixed, and it is the genuinely
underdetermined part where the prior and the extra years matter.

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

### Codes and facts still to verify

- **GFCF by asset type**: the Eurostat dataset code and its EU-27 coverage are
  **not** verified in this repo. Do not cite a code until checked against the
  dissemination API. (`nama_10_a64` carries `P51G` by industry, not by asset —
  an earlier draft of this note conflated the two.)
- Whether `nama_10_a64` `P51G` (GFCF by A64 industry) is complete for the
  target countries, and for which years.
- **Do this first:** the exact A21→GREU-57 correspondence and the resulting
  `n_g` per group. It is a cheap lookup against `metadata.xlsx` and it decides,
  group by group, how much of the use margin is identifiable at all before any
  estimator is written.

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
