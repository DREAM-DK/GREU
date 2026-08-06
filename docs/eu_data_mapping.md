# EU data mapping — Danish inputs → Eurostat/FIGARO sources

Goal: make the model EU-generic (see AGENTS.md). This table maps every Danish
input file the model consumes (per `data/preprocessing/read_data.py`) to
candidate EU-wide sources, with a coverage verdict and gap notes.

Latest audit entry (2026-07-30): Sweden 2020 is the first accepted non-Danish
monetary-energy `public_core` package. It implements the approved transparent
calibration method using PEFA quantities, national SUT, tax accounts and public
price/rate evidence, with no Danish values or shares. The hard truth remains:
**0 monetary cells are directly observed** at product × user × purpose. The
package has 177 nonzero modelled use cells and exposes its physical and monetary
residuals rather than hiding them. See the Sweden section below,
`energy_money_se2020_public_core_reconciliation.xlsx`, and the package manifest.

**Independent verification pass (2026-07-31):** three review agents re-derived
the code, the Sweden numbers, and the four earlier pilots (FIGARO, PEFA, IDEES,
EUTL, monetary feasibility) from source. Everything reproduced exactly except
one real gap in the "residuals are never hidden" claim (the CPA_B05/CPA_B06
silent-zero issue described in the Sweden section below, now fixed) and one
overstated roadmap line (financial accounts wrongly called "effectively done";
corrected in the roadmap). See the Sweden section and the Sweden README for the
fix; no other reported number changed.

**Follow-up targeted review (2026-07-31, same day):** a fourth agent
independently re-reviewed only the CPA_B05/CPA_B06 fix itself (line-by-line
code check, independent recomputation of 916.7847 PJ from raw PEFA JSON-stat,
schema-leakage check, merge/NaN check) and confirmed it is correct with one
harmless latent issue — a merged audit column could go stale (`NaN`) on
transient residual rows inside `uses`, never read by anything. Fixed with a
one-line `uses.drop(columns="cp16_has_source_rows")` right after the merge in
`build_energy_money_public_core.py`. Rebuilt Sweden and reran all 10 tests
afterward: identical numbers, all pass. **Sweden public-core package has been
through two independent review passes with every finding addressed.**

**Unmatched-SUT-residual task, completed 2026-07-31 (same day):** the
recommended next task below — narrow/explain Sweden's monetary residual — is
done. Root cause: Swedish PEFA reports USE-side energy consumption for whole
NACE **sections** (manufacturing `C`, agriculture `A`, water/waste `E`,
trade/transport `G`/`H`) and never breaks them into the finer A64
**divisions** (`C16`, `C19`, `E37-E39`, ...) the GREU concordance expects,
while `naio_10_cp16` publishes its purchaser-value controls at that finer
division level. The physical energy was never missing — it already sat in
the explicit `indu=res` reporting-detail residual — but its monetary
counterpart had no matching physical row at the fine level and was booked as
pure unmatched residual. The builder now pools that division-level SUT money
with the same `res` bucket that already holds the matching physical quantity
(see "Sweden section" quantitative update below), which **cut the use-side
unmatched SUT residual from 299.131 to 118.844 bn SEK** (180.287 bn SEK
reclassified, ~60%) with every accounting identity still closing to
floating-point precision. Industries Sweden *does* detail (financial and
business services) were never redirected: what remains for them is genuinely
non-energy money inside a too-broad CPA (e.g. office furniture bought under
`CPA_C16` wood products), which is exactly what the task asked to
distinguish from a data gap. The same pass also found and fixed an
independent, pre-existing disclosure gap: the headline residual metric only
ever read `purch`, which is always `0` on the supply side by construction,
so a comparable **102.567 bn SEK** producer-side (`basic`-value) unmatched
control was invisible; it is now an explicit manifest field and `INFO`
anomaly. All 10 tests and the determinism check pass after rebuilding.

**Residual-characterization pilots, completed 2026-07-31 (same day):** the two
follow-ups recommended below (PRODCOM for `CPA_C16`, waste statistics for
`CPA_E37-E39`) are done. Both confirm the remaining residuals are
overwhelmingly **non-energy money**: PRODCOM shows only ~1.15% of Sweden's
division-16 export value is energy-relevant wood products (≈0.47 of the
40.665 bn SEK export control; ~1.5% of the whole 42.763 bn SEK `CPA_C16`
residual), and the waste-statistics probe bounds the energy-relevant share of
the 60.156 bn SEK `CPA_E37-E39` supply-side control at 1.7%–14.8% (central
estimate 1.0 bn SEK), because Sweden's waste-to-energy revenue accrues to
NACE D35 utility plants, not E38. Neither source enables product-level
*allocation*, so the residuals stay disclosed residuals — but the acceptance
decision for colleagues is now evidence-backed rather than asserted. One
correction: this doc previously named the PRODCOM dataset `prc_stapro`; that
code does not exist (HTTP 404). The working dataset is **`DS-059358`** on the
Eurostat **Comext** dissemination API. See the 2026-07-31 pilot section below.

**Resolution of the three prerequisite questions** (posed at the end of the
previous session, resolved here since no new colleague input was needed to
proceed): (1) *which CPA subproducts count as energy* — unchanged; still
exactly the existing PEFA→CPA product map (`P23`→`CPA_C16`,
`R28`/`R29`→`CPA_E37-E39`, `P10`/`P26`/`P27`→`CPA_D`, remaining
`P14`–`P25`→`CPA_C19`); the fix does not redefine scope, it only stops
conflating "PEFA can't detail this industry" with "this industry has no
energy". (2) *is a zero-quantity monetary residual still acceptable* — yes;
the remaining 118.844 bn SEK (use) and 102.567 bn SEK (supply) residuals stay
as explicit, flagged rows exactly like before, now with a clearer
attribution. (3) *is an additional EU-wide source admissible* — none was
added in this pass; the fix reuses the already-approved `env_ac_pefasu` and
`naio_10_cp15`/`naio_10_cp16` more carefully rather than pulling in a new
dataset, to keep the increment tightly scoped and reviewable. Eurostat
PRODCOM (8-digit product detail; dataset `DS-059358` on the Comext API — the
`prc_stapro` code originally cited here does not exist) was flagged as an
admissible EU-wide source for a *future* pass narrowing what remains of
`CPA_C16` specifically (its largest remaining piece is `export`,
40.665 bn SEK, not industry use) — that pass has since been executed
(2026-07-31, see the PRODCOM/waste pilot section below).

## Architecture decision and first compatibility increment (2026-07-30)

The interface decision is now made: the EU version will use a **coarser
public-EU monetary-energy core**, with an **optional detailed country layer**.
The detailed layer is an auditable override, not an implicit use of Danish
shares. The first backwards-compatible implementation is in
`data/Modules/energy_money/`.

Runtime behavior:

- `country_detail` is the default. For `DK` it resolves to the exact legacy
  `energy_and_emissions.xlsx`, `io_energy_long_format.xlsx`,
  `EU_GR_data.gdx`, and output `data_DK.gdx`.
- `public_core` requires a complete generated package under
  `data/preprocessing/data/eu_core/<CC>/`. Missing artifacts fail before data
  construction; the code never falls back to Danish inputs.
- Both modes keep the existing workbook columns, GDX symbol names and domains.
  `read_data.py` now parameterizes only these three monetary-energy inputs and
  its generated country GDX. All unrelated inputs and transformations are
  unchanged.
- `data_from_GR.gms` accepts the generated GDX through the
  `energy_money_gdx` macro (default `data_DK.gdx`) for both `$gdxin` and the
  marginal-rate `execute_load`.

The package validates sheet names, required columns and unique keys. Its
optional materializer applies deterministic complete-row replacement on the
full energy and energy-IO keys, writes new workbooks with metadata and a hash
manifest, and never overwrites inputs. It deliberately does **not** merge GDX
internals: a selected country layer must provide one complete compatible
marginal-rate GDX containing `tEAFG_REmarg` and `tCO2_REmarg`.

Sweden 2020 now supplies the first complete package under this infrastructure.
It is a calibrated public-data construction, not a claim of direct cell
observation. The other non-energy Danish inputs in `read_data.py` still need
country parameterization, so this is not a full Sweden model run.

## Sweden 2020 — first accepted monetary-energy public core (2026-07-30)

### Acceptance status and reproducibility

**PASS for the monetary-energy compatibility boundary; not a full Sweden GREU
run.** Runtime artifacts are under `data/preprocessing/data/eu_core/SE/`:

- `energy_and_emissions.xlsx` (`ems_energy` first);
- `io_energy_long_format.xlsx` (`io` first);
- complete `EU_GR_data.gdx`;
- `energy_money_manifest.json` and provenance `README.md`.

Raw official deliveries are preserved under
`data/preprocessing/data/eu_core_raw/SE/2020/`. The downloader and builder are
`download_energy_money_public_core.py` and
`build_energy_money_public_core.py`. The latter passed deterministic table/GDX
record comparison, and `EnergyMoneyConfig(public_core, SE).validate()` plus all
10 focused tests pass. Both runtime workbooks have one header row, no merged
cells, unique keys and the required first sheet. No Danish production workbook,
allocation share, purpose share or marginal-tax GDX value is read; only
`metadata.xlsx` classifications define the existing compatibility vocabulary.

### Approved rules as implemented

1. **Industry.** The NACE A64↔GREU concordance is converted to connected
   components. Each whole component gets one representative GREU runtime label.
   No A64 observation is split among finer industries. Sweden's PEFA also
   reports a large part of transformation use only above A64; that difference
   is retained as `indu=res`, not distributed.
2. **Purpose.** Industrial use is `unspecified`. Direct PEFA household
   `HH_HEAT`, `HH_TRA` and `HH_OTH` become heating, transport and appliances.
   No Danish purpose weights, IDEES proxy or inferred `in_ETS` split is used.
3. **Physical account.** PEFA is the control. All selected P08–P27 products,
   renewable natural inputs N03/N04/N05/N07 and waste residuals R28/R29 are
   retained. Connected PEFA↔GREU product clusters prevent one public product
   being split across Danish-style product labels. Unmapped products and
   balance adjustments are named explicitly.
4. **Valuation.** Public gas/electricity components and Commission oil prices
   form initial product-family weights; PEFA PJ is the fallback. One-pass block
   calibration closes Sweden's `naio_10_cp16` CPA×user purchaser controls.
   `naio_10_cp15` supplies basic value, combined margin and net-product-tax
   wedges. Blocks with money but no matched physical quantity become explicit
   `monetary_residual_<CPA>` rows.
5. **Margins and duties.** Eurostat's combined `OTTM` is carried only in
   `ws_marg`/EAV; `ret_marg=mvs_marg=0`. The aggregate non-VAT SUT wedge is
   carried in `ener_tax`; `co2_tax=so2_tax=nox_tax=pso_tax=0`. This is a
   compatibility encoding, not observed wholesale detail or named legal taxes.
   `env_ac_taxind2` payer totals remain a secondary comparison with visible
   residuals because their concept differs from the SUT net product-tax wedge.
6. **VAT.** The exact TAXUD 2020 standard rate for Sweden (25%) is applied to
   non-recovering household purchaser values; business VAT is recoverable and
   exports are zero-rated in the incidence rule. Estimated VAT is capped by the
   SUT tax wedge. The legal-rate estimate, calibrated VAT and difference are
   separate audit columns; statutory rate is not called observed revenue.
7. **Purchaser value and marginal rates.** `purch` is the component identity,
   never an independent fill. `EU_GR_data.gdx` uses allocated average
   `ener_tax/PJ` as an explicit average=marginal assumption. Its
   `tCO2_REmarg` is complete but zero because there is no defensible separate
   product×user CO2 marginal rate. Public-core preprocessing skips the
   Danish-specific domain collapse and detailed-sector cloning.

### Quantitative Sweden result

- PEFA supply = use = **4,611.0794 PJ**.
- Maximum product supply/use residual: **5.68×10⁻14 PJ**.
- Purchaser value: **610.583 bn SEK**.
- Maximum component-identity residual: **7.11×10⁻15 bn SEK**.
- Maximum SUT purchaser-control residual: **2.84×10⁻14 bn SEK**.
- Direct monetary cells: **0**; nonzero modelled/calibrated use cells: **117**
  (was 177 before the 2026-07-31 residual-narrowing fix below reclassified
  many single-industry residual rows into shared `res` rows).
- Explicit PEFA reporting-detail/physical residual: **1,765.088 PJ**. This is
  mainly Sweden reporting transformation use above A64; it is not allocated to
  finer users.
- Explicit unmatched monetary residual (use side): **118.844 bn SEK**, down
  from 299.131 bn SEK (see the 2026-07-31 fix above). This records broad SUT
  CPA controls for which the selected PEFA product/user rows provide no
  defensible physical allocation — mostly `CPA_C16` (42.763 bn SEK, chiefly
  `export`), `CPA_E37-E39` (54.357 bn SEK, chiefly `residual:other_final_use`,
  `export` and government/`off`), `CPA_D` (13.199 bn SEK) and `CPA_C19`
  (3.155 bn SEK); all of it is `residual:other_final_use`/`export`/detailed-
  industry rows, i.e. genuinely non-energy CPA scope or national-accounts
  catch-all categories, not a reporting-detail gap. It is intentionally
  retained and must not be mistaken for measured energy expenditure.
- Explicit unmatched monetary residual (supply/producer side, newly exposed
  2026-07-31): **102.567 bn SEK** in `basic`-value terms — mainly the
  waste/sewerage industry's own broad `CPA_E37-E39` production control
  (60.156 bn SEK) versus its tiny physical waste-fuel byproduct. Previously
  invisible because the headline metric only read `purch`, which supply rows
  never populate; see `explicit_supply_side_monetary_residual_bn_SEK` in the
  manifest.
- The legal-rate household VAT estimate is **29.768 bn SEK**; calibrated VAT is
  **28.393 bn SEK**, leaving a visible **1.375 bn SEK** legal-rate/control
  difference. The allocated non-VAT SUT wedge is **48.508 bn SEK** for mapped
  industries versus **38.063 bn SEK** in the environmental-tax energy category,
  a **10.445 bn SEK** concept/control residual.
- Negative calibrated values occur in inventory-change rows because the
  published SUT inventory control is negative: six flagged basic-value rows sum
  to **−3.115 bn SEK**. They are retained and listed in the audit `anomalies`
  sheet; no negative value is silently clipped.
- Air-account data are audited but not allocated into runtime energy rows:
  `env_ac_ainah_r2` combines energy and process emissions, so product allocation
  would fabricate an energy/non-energy split. Runtime emissions are therefore
  zero in this monetary-core increment.
- **Found and fixed 2026-07-31 (independent verification audit):** `source_value()`
  could not distinguish "Eurostat reports a genuine zero" from "Eurostat has no
  row at all for this CPA code" — both silently produced `0.0` with no anomaly,
  because both sides of the affected identity were zero. This hid a real gap:
  `naio_10_cp15`/`naio_10_cp16` publish **no rows at all** for `CPA_B05`
  (coal/lignite family: P08/P09/P11) or `CPA_B06` (crude oil: P12/P13) for
  Sweden — **916.7847 PJ** (≈19.9% of Sweden's total energy) was valued at an
  unflagged zero. The builder now checks source-row existence per CPA
  explicitly, adds `cp15_has_source_rows`/`cp16_has_source_rows` columns to the
  `valuation_controls`/`user_controls` audit sheets, raises 4 new `ERROR`
  anomalies (2 CPAs × supply/use), and reports
  `unobserved_no_source_breakdown_use_PJ`/`..._supply_PJ`/`..._cpas` in the
  manifest. **No other quantitative result above changed** — the fix only
  makes an existing silent gap explicit; it does not add or remove any
  allocation. The Sweden package was rebuilt and all 10 tests still pass.

The large residuals are the main substantive finding. They do not break the
compatibility/accounting identities, but they show that an accepted coarse
package is a transparent calibration envelope—not a direct statistical energy
matrix.

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

Status of source codes: **24 dataset codes are now confirmed accessible** —
the **17** Eurostat codes in the table below were verified to exist against the live
Eurostat API on 2026-07-28. Two of those, `env_ac_pefasu` and
`env_ac_ainah_r2`, are now proven end-to-end by the 2026-07-30 pilot; the
national SUT codes `naio_10_cp15`/`cp16` and `env_ac_taxind2` are now also
proven as calibration controls by the monetary pilot. Four additional annual
energy-price-component codes (`nrg_pc_202_c` through `_205_c`) were added and
tested, bringing the total from 20 to 24. The **3 FIGARO codes**
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
| `emissions_bridge_items.xlsx` | Residence adjustments (bord_trade, internat_transp) | `env_ac_aibrid_r2` (air emissions accounts **bridging items**) — exact concept match | OK | Same concept by design (accounts↔inventory bridge). |
| `employed.xlsx` | Employment + hours by indu × employees/self-employed | `nama_10_a64_e` (employment by A64: persons and hours; `SELF_DC` self-employed is published directly, EMP−SAL only needed where suppressed) | OK / PILOT DONE | **DK-2020 pilot (2026-07-31): hours reconcile to <0.001% nationally and exactly in 24 of 28 clusters** — and hours are the only per-industry content `read_data.py` uses (self/employee hours ratio for imputed labour income; head counts collapse to one national scalar). Persons carry a uniform **+3.52%** concept gap (Danish column is a non-standard person concept — colleague question). Known L↔68203 boundary reappears (cluster L hours +180%). Hours not at A64 for DE/FR/BE/BG/LT/EE; SE suppresses 6 A64 codes (pair residuals derivable). |
| `fixed_assets.xlsx` | Capital stock by indu × 7 asset types | `nama_10_nfa_st` (fixed asset stocks by industry × asset) | COARSER | Eurostat side is A21 industries (not A64) and asset detail varies by country; may need capital-stock estimation (PIM) from `nama_10_a64` GFCF for missing countries. |
| `io_invest_long_format.xlsx` | Investment matrices (build/trans/other) by producing indu × investing indu | **GAP — investment matrices are not published EU-wide.** GFCF by asset × industry: `nama_10_nfa_st` flows / national accounts; FIGARO has GFCF column but not by investing industry × asset | GAP | Standard fix: build investment matrix from GFCF by industry × asset-type bridge (asset→supplying-product key is fairly universal — e.g. buildings→F, transport eq.→C29-30). Danish matrix as prior for RAS. |
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
3. **Investment matrices**: build from GFCF by industry × asset bridge; RAS
   with Danish structure as prior.
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

## Official documentation (found 2026-07-29)

`data/preprocessing/data/GREU data documentation.pdf` (9 pp.) is the official
description of the Danish GREU data — read it before touching any input file.
Points that matter for the EU work:

- **§1.2.3 lists the Eurostat databases** where the aggregated versions of the
  underlying Danish data are published (SUTs/IOTs, PEFA energy accounts, air
  emissions, NA aggregates, sector accounts, GFS, and the ETS Union Registry) —
  i.e. the doc itself endorses the Eurostat replacement route this mapping
  pursues, and cites the Union Registry (EUTL) as the source `ets.xlsx` was
  built from, softening the EUTL scope caveat in the roadmap.
- Confirms the GREU-IOT is **industry-by-industry** (pilot's choice was right),
  compiled with the Fixed Product Sales Structure assumption; trade margins go
  to industries 45000/46000/47000.
- **Danish import rows are themselves modelled**: imports are distributed across
  foreign industries by assuming imported products are produced by the same
  industries as in Denmark, proportionally. So the pilot's import-composition
  discrepancy is a difference between two models (DST's proportionality vs
  FIGARO's inter-country structure), not data vs model.
- Confirms `cons_hh_foreign` = foreign tourists'/business travellers'
  consumption in DK (matches the pilot's OP_NRES identity) and the 2020 rate
  100 DKK = 13.415 EUR (≈7.4543, matches the pilot's 7.4542).
- §5: energy/emission accounts follow the SEEA **residence principle**
  (Danish operators' international transport included);
  `emission_bridge_items.xlsx` bridges to UNFCCC territorial — largely answers
  colleague question 2 (bunkers).
- §8/§9 (financial accounts, government finances) are stubs — "[FURTHER
  DESCRIPTION NEEDED]".

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

## Pilot results — FIGARO DK 2020 vs `io_long_format.xlsx` (2026-07-29)

Pilot (next-steps item 1) executed 2026-07-29. Artifacts: scripts
`data/preprocessing/scripts/download_figaro_dk_2020.py` + `reconcile_figaro_dk_2020.py`
(re-runnable), raw SDMX-CSV + provenance in `data/preprocessing/data/figaro_raw/`,
comparison workbook `data/preprocessing/data/figaro_dk2020_reconciliation.xlsx`.
Source: **FIGARO 2026 edition**, industry-by-industry (`naio_10_fcp_s3/u3/ii3`),
Eurostat SDMX API, 64 NACE Rev. 2 industries, MIO_EUR basic prices, converted at
7.4542 DKK/EUR (`ert_bil_eur_a` 2020 average). All figures below in bn DKK.

**Verdict: FIGARO maps on very well at the aggregate level** — it is benchmarked
on the same Danish national accounts. Exact (≤0.1%) matches: total output 4055.4,
D1 1210.4, B2A3G 824.0, D29X39 −13.1, gov. consumption 576.1, GFCF 516.1,
inventories 13.5. Household-consumption identities are exact once FIGARO's
adjustment rows are used: `cons_hh` = P3_S14+P3_S15+OP_RES+OP_NRES (1089.67 both);
`cons_hh_foreign` = −OP_NRES (27.75) — i.e. non-residents' purchases in DK, and
Danish `cons_hh` includes NPISH.

Granularity: reconciliation runs on 28 clusters (corrected 2026-07-31 — this
section originally misstated the count as 24; see the employment-pilot
correction note) (connected components of the
many-to-many GREU↔A64 map); FIGARO is coarser in 7 clusters covering 34 of 57
GREU industries (agriculture 11→A01, food 5→C10-12, waste 5→E37-39, land/water
transport 8→H49+H50, …). FIGARO industry `U` is unmapped/zero.

Main discrepancies:
1. **Re-exports** — Danish import rows send 239.8 to the export column; FIGARO's
   inter-country logic has no re-exports → FIGARO total imports 918.8 vs Danish
   1180.1 (−22%). Excluding re-exports the gap is −21.6 (−2.3%), mostly OP_RES
   treatment (17.2).
2. **Import composition** — FIGARO carries foreign trade/transport/finance
   margins as separate service rows where Danish CIF goods imports embed them:
   goods rows lower (C13-15+C26-C31_32 −140, C21 −56, C10-12 −37, H52 −74),
   services higher (G46 +52, K64-K66 +51, G47 +27).
3. **Real-estate boundary** — output L +94.3 / business-services cluster −96.2
   (mirrored in B2A3G ±45, D1 ±11–12). GREU 68203 "Housing sector" is dwellings
   only; the rest of NACE L sits in GREU 71000 — the `industries_naceA64_map`
   line L↔68203 is **not value-consistent** and needs a note or a split key.
4. **GDP +3.1 (+0.1%)** — entirely taxes on products: FIGARO D21X31 305.3 vs
   Danish tax_products+tax_vat 302.2. FIGARO hits official DK GDP (2326.6).
5. **Cell-level allocations differ even where totals are exact** (hh consumption
   by industry ±16, exports ±8): FIGARO models its own margin/tax/use allocation
   rather than using DST's.

Gotchas for future pulls:
- Eurostat API can return an HTML "Server temporarily unavailable" page **with
  HTTP 200**; the downloader validates content and retries.
- `naio_10_fcp_s3` spells NACE codes differently (`C10-C12`, `E37-E39`) from
  `ii3`/`u3` (`C10-12`, `E37-39`) — normalize before filtering or rows silently
  drop.
- `metadata.xlsx` map row 19 labels GREU 13150 "Manufacture of machines and
  electronics" but maps it to C13-C15 textiles among others — label looks wrong;
  the code mapping itself appears intentional.
- Danish 5-way tax split vs FIGARO's single D21X31 row: matches as a sum only —
  confirms the tax-split gap above.

## Pilot results — Eurostat PEFA / air accounts vs GREU energy data (2026-07-30)

Pilot (next-steps item 2) is complete. Artifacts: re-runnable downloader and
reconciliation scripts in `data/preprocessing/scripts/`, raw official JSON-stat
responses plus provenance in
`data/preprocessing/data/eurostat_energy_emissions_raw/`, and the 16-sheet
workbook
`data/preprocessing/data/eurostat_energy_emissions_dk2020_reconciliation.xlsx`.
Source URLs and filters are recorded in the workbook and raw-data README.

### Physical energy: high aggregate coverage, clear scope boundary

**Verdict: PEFA can reproduce the physical backbone closely, but not the full
GREU detail.** GREU supply/use is 2,251.550 PJ. A like-for-like PEFA boundary —
all energy products P08–P27, renewable natural inputs N03/N04/N05/N07 and
energy-bearing waste residuals R28/R29 — is 2,237.794 PJ: **−13.756 PJ
(−0.611%)**. PEFA supply and use and GREU supply and use each balance internally.

The raw PEFA all-flow total is 3,702.820 PJ and must not be compared directly:
it also counts upstream natural inputs and all energy residuals, including
1,155.402 PJ of `R30` losses/dissipative heat. On the comparable flow mapping:
domestic production is −25.508 PJ (−2.63%), imports +9.724 PJ (+0.84%), and
natural/residual other supply +2.027 PJ (+1.66%). Households (+0.098 PJ),
exports (+0.215 PJ) and inventories (+0.021 PJ) are all within 0.1%. PEFA does
not publish GREU's separate 35.543 PJ transmission-loss use cell.

Product detail is partly reproducible, but the pilot exposed four issues in the
existing `energy_products_pefa_map`:

1. `sem_refin_oil` is misspelled; the data use `semi_refin_oil`.
2. P18 heating/other gasoil (146.140 PJ) is absent from the diesel mapping.
   P17+P18 = 238.361 PJ, matching `diesel_transp`+`bunk_trucks` to rounding.
3. Environment-supplied `heat_pump` belongs with renewable natural inputs:
   PEFA N03+N04+N05+N07 = 79.562 PJ, exactly GREU
   `renewable`+`heat_pump` to rounding, rather than with P27 output heat.
4. P10 derived gas (0.555 PJ) remains unmapped.

The reconciliation applies these as explicit pilot adjustments but does **not**
change `metadata.xlsx`; owner review is needed first.

Industry comparison uses 28 many-to-many concordance clusters (corrected
2026-07-31 from a misstated 24; see the employment-pilot correction note).
PEFA is coarser
in 7 clusters covering 36 of 57 GREU industries. It cannot reproduce GREU's
industry purpose split (`process_normal`, `process_special`, `heating`,
`transport`, `in_ETS`). However, PEFA itself does publish the three broad
household end uses: total household use matches closely (253.760 vs 253.662 PJ,
+0.039%), while the allocation differs (heating −6.932 PJ, transport +0.359,
other/appliances +6.671).

### Air emissions: concept match requires both GREU emissions files

`env_ac_ainah_r2` publishes **total** emissions by activity; it cannot be
compared like-for-like with the energy-only emissions in
`energy_and_emissions.xlsx`. Adding `non_energy_emissions.xlsx` reconstructs the
comparable GREU air-account boundary:

- fossil CO2: Eurostat 67,023.396 vs GREU 67,028.003 kt (**−4.607 kt,
  −0.0069%**);
- biogenic CO2: 17,036.781 vs 17,036.703 kt (+0.078 kt);
- F-gases: 364.427 vs 364.426 kt CO2e (+0.001 kt);
- methane: 334.834 vs 308.405 kt (**+26.430 kt, +8.57%**);
- N2O: 20.672 vs 20.036 kt (**+0.636 kt, +3.17%**);
- total GHG: 82,241.335 vs 81,337.382 kt CO2e (**+903.953 kt,
  +1.111%**).

The GHG gap is almost entirely the CH4/N2O difference; the largest cluster is
agriculture (A01: +811.038 kt CO2e). This is a genuine source/vintage or
national-adjustment discrepancy to investigate, not a unit conversion error:
both sources use kt, AR5 factors 28/265 reproduce the totals, and Eurostat's
component identity closes.

### Residence principle and bunker scope

The scope question is now resolved. Both GREU and Eurostat environmental
accounts use the **residence principle**, so Danish-resident ships/aircraft are
included wherever they operate. GREU's three explicit bunker products total
497.799 PJ and 39,138.053 kt CO2e. The GREU `internat_transp` bridge is
39,022.027 kt CO2e, 116.026 kt lower. The bridge, not an ad-hoc subtraction of
bunker rows, is the correct route to territorial/UNFCCC scope. PEFA preserves
the resident transport-industry total but merges bunker fuels into
P15/P17/P19, so the explicit bunker-product identity is lost.

**Remaining structural losses:** no monetary prices/margins/taxes/VAT, no
industry-purpose split, no energy/non-energy split in the air account, loss of
GREU industry subdivisions and explicit bunker products. These are
classification/model-construction gaps; they do not undermine the strong
aggregate physical match.

## Pilot results — JRC-IDEES for the purpose dimension (2026-07-30)

Pilot (next-steps item 3) is complete. Artifacts:
`data/preprocessing/scripts/download_jrc_idees_dk_2023.py`,
`reconcile_jrc_idees_dk_2020.py`, the preserved country archive and extracted
workbooks in `data/preprocessing/data/jrc_idees_2023_raw/`, and the 14-sheet
comparison workbook
`data/preprocessing/data/jrc_idees_dk2020_purpose_reconciliation.xlsx`.

### Access and coverage verdict

The current edition is **JRC-IDEES-2023 v1**, issued in late 2025 with 2026
technical documentation. It is an official JRC analytical database, open under
**CC BY 4.0**, with direct anonymous country ZIP downloads (no login and no API
query parameters). It covers all EU-27 Member States plus the EU aggregate,
annually for **2000–2023**, so Denmark 2020 is available.

Official sources retrieved 2026-07-30:

- catalogue: https://data.jrc.ec.europa.eu/dataset/1f0b480c-6d21-4d95-897d-20c7ca33df6f
- DK archive: https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/JRC-IDEES/JRC-IDEES-2023_v1/JRC-IDEES-2023_DK.zip
- technical report: https://publications.jrc.ec.europa.eu/repository/handle/JRC144707
- IDEES overview: https://joint-research-centre.ec.europa.eu/scientific-tools-and-databases/potencia-policy-oriented-tool-energy-and-climate-change-impact-assessment/jrc-idees_en

The industry file reports 11 sectors and 21 subsectors mapped to NACE Rev. 2,
with 6–11 processes per subsector. It distinguishes process-specific uses and
five cross-cutting non-process uses: lighting, air compressors, motor drives,
fans/pumps, and low-enthalpy heat. Carriers include solids/coke, petroleum
groups, gas/biogas, derived gases, biomass/waste, distributed steam,
solar/geothermal, ambient heat, and electricity. Crucially, JRC describes the
fine end-use split as an **analytical estimate** constrained to sector-level
Eurostat energy balances, not as independently observed statistics.

### Denmark 2020 reconciliation

On the broad mapped-industry boundary, IDEES reports **96.610 PJ** versus GREU
**129.636 PJ**. This −25.48% headline is not like-for-like because GREU assigns
resident industries' own-account transport to those industries. Excluding
GREU's 20.999 PJ transport purpose gives the closer comparison:
**96.610 vs 108.637 PJ (−12.028 PJ, −11.07%)**. Remaining differences include
territory versus residence accounting and unavoidable industry aggregation.

The useful result appears one level higher than GREU's exact categories:

- **Combined process envelope:** IDEES normal/special proxies total
  **93.116 PJ** versus GREU `process_normal + process_special + in_ETS`
  **90.360 PJ**: +2.756 PJ (**+3.05%**).
- **Heating:** IDEES low-enthalpy heat is only **3.494 PJ** versus GREU
  **18.277 PJ** (−80.88%). It is the closest direct concept, but too narrow to
  use as an exact mapping.
- **Normal process:** 66.626 PJ is a constructed residual, not a source field.
- **Special process:** 26.489 PJ is an assumption-based pilot proxy (process
  energy in metallurgical/mineralogical IDEES sectors, excluding cross-cutting
  uses). GREU has 5.764 PJ, showing that this proxy is far too broad without a
  process-code concordance.
- **Transport:** IDEES has a detailed transport workbook by mode, but cannot
  allocate own-account transport back to the industries using it.
- **`in_ETS`:** IDEES has no ETS-status dimension. Public Union Registry/EUTL
  installation data is still required, followed by installation→NACE/GREU
  mapping. Do not infer ETS status from an IDEES process name.

Sector totals support the underlying source quality: food differs by −1.09%,
chemicals +0.65%, and non-metallic minerals +0.17% on direct broad mappings.
The mismatch is mainly in translating the technical end-use taxonomy into
GREU's policy/accounting taxonomy, not in the main industrial energy totals.

### Household role relative to PEFA

PEFA remains the right household **control total** because it is already on the
physical-account boundary and publishes `HH_HEAT`, `HH_TRA`, and `HH_OTH`.
IDEES Residential excludes household transport but gives richer building/end-use
detail. For Denmark 2020:

- IDEES residential heating = **148.617 PJ** versus GREU 147.284 PJ (+0.91%);
- IDEES other/appliances = **30.422 PJ** versus GREU 32.179 PJ (−5.46%);
- residential subtotal excluding transport = **179.040 PJ** versus GREU
  179.463 PJ (−0.236%);
- IDEES residential + PEFA transport = **253.597 PJ**, only −0.064 PJ
  (−0.025%) from GREU's total.

Recommended design: retain PEFA household totals and use IDEES only as an
optional split key for space/water heating, cooking, cooling, appliances, and
lighting. Do not silently combine the two boundaries without recording the
hybrid construction.

**Verdict:** IDEES passes the hard public-access, EU-wide, vintage and
reproducibility tests. It materially narrows the `purp` gap but does **not**
close it as a direct-download replacement. The next implementation step is an
owner-approved IDEES-process→GREU-purpose concordance, tested with EUTL for ETS
coverage and PEFA as the balancing control.

## Pilot results — Union Registry / EUTL vs `ets.xlsx` (2026-07-30)

Artifacts: `download_eea_eutl_2026.py`,
`download_euetsinfo_nace_2026.py`, `reconcile_eutl_dk_2020.py`, preserved raw
deliveries and provenance under `data/preprocessing/data/eea_eutl_2026_raw/`
and `euetsinfo_nace_2026_raw/`, and the 13-sheet workbook
`data/preprocessing/data/eutl_dk2020_reconciliation.xlsx`.

### Public access, licence and coverage

The current official sources pass the hard feasibility tests:

- The European Commission Union Registry public site exposes stable,
  anonymous daily bulk GZIP-CSV files for the operator master and annual
  installation compliance records. No login, cookie, API key or page scraping
  is required. The files retrieved 2026-07-30 have snapshot date 2026-07-30.
- The EEA **July 2026** EU ETS release was published 2026-07-08, is based on a
  2026-07-01 Union Registry extract, and covers 2005–2025. Its anonymous bulk
  ZIP adds activity-code documentation, quality notes and country-level auction
  volumes. The EEA metadata states **CC BY 4.0**, European Commission/EEA
  copyright, and no limitations on public access.
- The daily files contain all 27 EU Member States (and five other registry
  codes), years 2005–2025, and Denmark 2020. The workbook validates every EU-27
  code and the official installation totals against the independent EEA
  aggregates.

Official URLs (retrieved 2026-07-30; bulk query parameters: none; local filter
`REGISTRY_CODE=DK`, `PERIOD_YEAR=2020`):

- public site: https://union-registry-data.ec.europa.eu/
- operator master: https://dlsclimabi.blob.core.windows.net/public-data/eutlpublic/extracts/_all_extracts/operator/operators_daily.csv.gz
- installation-year data: https://dlsclimabi.blob.core.windows.net/public-data/eutlpublic/extracts/_all_extracts/operators_yearly_activity/operators_yearly_activity_daily.csv.gz
- EEA catalogue: https://www.eea.europa.eu/en/datahub/datahubitem-view/98f04097-26de-4fca-86c4-63834818c0c0/file
- EEA release alias: https://sdi.eea.europa.eu/data/a94a5d68-9973-4e2c-9a7a-fd7690ec3473

### Denmark 2020 reconciliation

The source confirms that `ets.xlsx` was built from installation-level registry
records. Current public data versus GREU:

- **verified emissions:** 11,039.385 vs 11,038.641 kt CO2e, **+0.744 kt
  (+0.0067%)**. Stationary emissions are unchanged at 10,832.424 kt; the whole
  difference is a later aviation revision;
- **free allocation:** 6,783.620 vs 6,783.462 thousand allowances,
  **+0.158 thousand (+0.0023%)**;
- **“bought allowances”:** 5,348.399 vs 5,348.293 thousand,
  **+0.106 thousand (+0.0020%)**. There is no purchase field: the GREU number
  is reproduced by calculating `max(verified emissions − free allocation, 0)`
  per installation and then summing. This is a minimum positive-shortfall
  proxy, not observed buying; banking, transfers and sales are invisible;
- **implied cost:** GREU's 1.2399006 bn DKK implies a uniform
  **231.831091 DKK/t** applied to that shortfall. Applying the same assumption
  to the current source gives 1.239925 bn DKK. The Registry contains no tax,
  transaction-price or annual EUA-price field;
- **auctioned/sold allowances:** EEA reports 6,845.500 thousand for Denmark
  (stationary + aviation). This is a direct country total, not an
  installation/industry allocation and not equivalent to the 5,348.399
  thousand shortfall proxy;
- **surrendered units:** 11,034.625 thousand are directly reported, but surrender
  does not identify whether units were bought, banked or transferred.

The source uses `-1` for missing/not-applicable values; the reconciliation turns
these into zero only in explicit `*_usable` columns. It includes stationary and
aviation records carrying 2020 compliance values, excludes maritime/ETS2
placeholders, and retains historical allocations even where a current aviation
exclusion flag is set. This scope is what reproduces GREU.

### Installation → NACE/GREU verdict

The official Registry publishes **ETS Annex I activity codes, not NACE**. EEA's
4,327-row translation file maps legacy ETS codes 1–9 to newer ETS codes 20–43;
it does not turn activities into NACE. The broad code `20` (“combustion of
fuels”) alone covers 336 Danish records and 7,244.759 kt in 2020, spanning
electricity, heat and many manufacturing users, so using it as an industry code
would be wrong.

The best public EU-wide bridge found is the secondary EUETS.INFO/Zenodo v2
package (https://doi.org/10.5281/zenodo.21414185), CC BY 4.0 for the
compilation. It derives installation NACE from the Commission's 2015/2020
carbon-leakage-list files. For the 375 DK 2020 ETS1 records used here it covers
356 records (**94.93%**) and 10,772.880 of 11,039.385 kt (**97.59%**).
The uncovered 19 records carry 266.505 kt and 377.544 thousand free allowances.
All available NACE codes map to existing A64/GREU connected clusters, but the
bridge remains unsuitable as an authoritative production map: it is secondary,
historical, partial, and the A64→GREU relation is often many-to-many. Diagnostic
cluster differences (e.g. food +64.356 kt, waste −47.039 kt) show why names or
activity codes must not be used to fabricate classifications.

### `in_ETS` verdict

**The purpose gap is not closed.** EUTL proves ETS membership and reports
emissions/allowances, but `energy_and_emissions.purp=in_ETS` requires **PJ by
industry, energy product and mutually exclusive GREU purpose**. EUTL has no fuel
consumption, heat content, product or energy-use field. Building `in_ETS` needs:

1. a maintained installation→NACE/GREU concordance;
2. a way to assign each installation's regulated emissions to fuel/product and
   energy use, using fuel-specific emission factors and process-emission rules;
3. reconciliation to PEFA/IDEES energy controls and explicit treatment of
   non-energy process emissions, biomass and installations with multiple uses;
4. model-side rules preventing double counting with `process_normal` and
   `process_special`.

EUTL is therefore a strong policy/compliance constraint, not a direct physical
energy-purpose dataset.

## Pilot results — monetary energy and basic→purchaser valuation (2026-07-30)

Artifacts: `download_energy_money_sources_dk_2020.py`,
`reconcile_energy_money_dk_2020.py`, preserved raw deliveries and access probes
under `data/preprocessing/data/eurostat_energy_money_raw/`, and the 22-sheet
workbook `energy_money_dk2020_feasibility_gap.xlsx`.

### What the model-ready construction must contain

For each country/year, a full construction must jointly produce physical
energy-product × user flows; basic values; wholesale, retail, and motor-vehicle
sales margins; `ener_tax`, `co2_tax`, `so2_tax`, `nox_tax`, and `pso_tax` (or an
explicitly approved replacement taxonomy); VAT; purchaser values; and the
energy-only long-format IO table. The key distinction from the spreadsheet
presentation is:

- `read_data.py` stacks all component columns into `EnergyBalance`.
  `data_from_GR.gms` explicitly sums `base`, the three margins, five taxes and
  VAT to form total energy value. It also tests the energy IO against basic
  production/imports, rerouted margins, the `TaxSub` primary-input row, and the
  `Moms` VAT row. Those components and the energy IO are therefore **model
  requirements**, not presentation.
- `purch` is read and stored but deliberately excluded from the GAMS
  `ebalitems_totalprice` set to avoid double counting. It is a derived
  reconciliation/presentation field once all components exist.
- The matrix workbook is an unread pivot view. The long-format energy IO is the
  consumed input and must be regenerated.

### Official-source access and EU-27 coverage

All downloads were anonymous and machine-readable except the official TAXUD
reference tables, which are anonymous PDFs. Retrieval date is 2026-07-30.
Eurostat files are subject to its reuse policy; the Commission petroleum and
TAXUD pages do not state a dataset-specific CC licence, so the audit records the
Commission legal notice/reuse policy rather than claiming CC BY.

- `env_ac_taxind2`: 27/27 countries have 2020 observations. It supplies energy
  and CO2-related tax **payer totals** by NACE, not product rates.
- `nrg_pc_204_c`/`205_c`: electricity components have 27/27 coverage.
  `nrg_pc_202_c`/`203_c`: gas components have only 24/27 household and 25/27
  non-household coverage. Missing combinations also have no observations in
  the live 2015–2024 probe.
- `naio_10_cp15`/`cp16`: 26/27 countries have 2020 observations; Bulgaria is
  absent throughout the 2015–2024 probe. This alone prevents a uniform
  all-country pipeline based solely on national SUT valuation tables.
- The EC Weekly Oil Bulletin is a downloadable XLSX with weekly history from
  2005 onward for road fuels and selected petroleum products, including 2020.
  It is product/market-segment evidence, not a complete energy-account price
  table.
- The archived TAXUD energy excise PDF found is situation 2021-07-01 (nearest
  stable rate table, not exact 2020). The VAT PDF is exact at 2020-01-01 and
  confirms Denmark's 25% standard rate. Rate schedules still require taxable
  quantities, exemptions, business/household incidence and VAT recovery rules.

Official URLs and exact query filters are in the raw README, manifest and
workbook `source_register`.

### Denmark-2020 quantitative feasibility result

**Verdict: no model-ready monetary energy input can be produced directly from
public EU-wide fields.** The existing PEFA pilot directly covers 2,237.794 of
2,251.550 PJ (99.389%) on the comparable physical boundary. For money:

- **0 of 862 nonzero GREU use rows (0%)** has all required monetary components
  directly observed at the needed product × user × purpose grain.
- Exact product-family price controls for electricity, road petrol and road
  diesel cover **337.775 PJ (15.002%)** and, as a Danish validation benchmark,
  **51.438 of 208.562 bn DKK purchaser value (24.663%)**.
- Adding GREU's mixed `natgas_incl_biongas` to the natural-gas control raises
  the envelopes to **481.430 PJ (21.382%)** and **63.794 bn DKK (30.588%)**,
  but this is only a near-match because Eurostat natural gas does not include
  the biogas distinction in the GREU product.
- National SUT broad energy CPA products close their published identities:
  `TS_PP = TS_BP + D21X31 + OTTM` and purchaser supply equals use (maximum
  residual effectively zero). This validates them as controls, not as cells:
  `OTTM` combines margins and `D21X31` nets product taxes/subsidies.
- The Danish targets themselves reconcile: purchaser component identity closes
  to 3.6e-15 bn DKK; energy-IO totals, production rows and use columns close
  within 0.00196 bn DKK (source rounding). Detailed differences are retained in
  the workbook rather than hidden.

The only defensible next design is a transparent construction that labels:
direct source fields; derived identities; owner-approved allocation rules;
calibration controls/residuals; and unavailable concepts. Danish target shares
may be used as validation benchmarks, but using them as allocation keys would
make the method Danish-dependent and must not be called EU-generic.

## Pilot results — PRODCOM and waste statistics for Sweden's residuals (2026-07-31)

Two parallel pilots characterized the two largest remaining pieces of Sweden's
unmatched monetary residual. Artifacts:
`data/preprocessing/scripts/download_prodcom_se_2020.py`,
`reconcile_prodcom_se_2020.py`, `probe_prodcom_endpoint_2026_07_31.py`,
`download_waste_stats_se_2020.py`, `analyze_waste_stats_se_2020.py`; raw
deliveries with manifests under `data/preprocessing/data/prodcom_raw/SE/2020/`
and `waste_stats_raw/SE/2020/`; workbooks
`prodcom_se2020_c16_reconciliation.xlsx` and
`waste_stats_se2020_e37e39_feasibility.xlsx`. All EUR→SEK conversion uses the
verified 2020 average 10.4848 from `ert_bil_eur_a` (an earlier note citing
10.4867 was wrong).

### PRODCOM — `CPA_C16` is ≥98.5% non-energy

- **Access correction:** `prc_stapro` returns HTTP 404 on both the main
  statistics API and the SDMX registry; the legacy Comext code `ds-056120` is
  also decommissioned. PRODCOM is served only through the **Comext**
  dissemination API as dataflow **`DS-059358`** ("Sold production, exports and
  imports", PRODCOM list CPA 2.1 vintage — correct for 2020; `DS-059367` is
  the CPA 2.2 successor). Indicators include PRODVAL, EXPVAL, IMPVAL (EUR)
  with explicit confidentiality flags. Export value by 8-digit PRODCOM code is
  directly available.
- **EU-27 coverage:** all 27 member states present (Comext uses `GR` for
  Greece). Pellet *production* value is confidential/suppressed in 5 of 27
  (BE, IE, NL, PT `:C`; SE itself `:U`); export values have no suppression.
- **Sweden 2020, NACE division 16** (63 of 113 codes with data): sold
  production 7.802 bn EUR = 81.807 bn SEK (9 codes suppressed `:U`); exports
  3.799 bn EUR = 39.827 bn SEK (no suppression). Energy-relevant codes
  (16102503/05 wood chips/particles, 16291500 pellets/briquettes; fuel wood is
  CPA 02.20.14 forestry, outside PRODCOM's manufacturing scope): 7.6% of
  observed production (chips-only lower bound — Sweden's pellet production
  value is suppressed, odd for one of Europe's largest producers) and
  **1.15% of exports** (43.5 M EUR ≈ 0.456 bn SEK).
- **Residual verdict:** PRODCOM division-16 exports match the SUT export
  control almost exactly (ratio 0.979), so the export split is credible:
  ~0.47 bn of the 40.665 bn SEK export residual, ~0.63 bn (~1.5%) of the whole
  42.763 bn SEK `CPA_C16` residual, is plausibly energy-relevant — and that
  treats *all* chips as fuel although much Swedish chip output feeds
  pulp/particleboard. **PRODCOM can serve as an EU-wide splitting key for
  `CPA_C16` export/production controls** (use shares, not levels: PRODVAL is
  ex-works, EXPVAL is FOB, vs SUT purchaser prices; list vintages change codes
  between years; production-value confidentiality makes the export split the
  robust one).

### Waste statistics — `CPA_E37-E39` is ≥85% non-energy, and irreducible

Five sources probed (all live-verified 2026-07-31):

- `sbs_na_ind_r2` (SBS, 2008–2020 series; the new `sbs_ovw_act`/`sbs_sc_ovw`
  start only in 2021): SE 2020 down to 4-digit NACE, EU 25/27 (CY, IE suppress
  E38). E37+E38+E39 production = 52.99 bn SEK (88% of the control), split
  sewerage 13.0% / waste 83.6% / remediation 3.4%; inside E38: collection
  18.0, treatment/disposal 6.36, **materials recovery 19.9 bn SEK** (materials
  trading, not energy). Incineration detail E3821/E3822 is suppressed for SE.
- `env_wastrt`: energy recovery (R1) takes 50.0% of Sweden's non-mineral
  treated waste (8.77 Mt); incineration without energy recovery is negligible.
  EU 26/27.
- EPEA (`env_ac_pepsgg1`/`env_ac_pepssp1` — note `env_ac_epneec` does not
  exist): EU 27/27. Waste-management (CEPA3) output: government 26.69 bn,
  specialist producers 32.38 bn SEK — of which 16.06 bn is *secondary*
  activity of firms whose principal business is elsewhere, corroborating that
  waste-to-energy money sits outside E37-E39. Sweden reports **zero**
  observations of `EPS_REC_BYPR` (by-product revenue) — exactly the item that
  would directly measure energy-by-product income.
- `env_ac_egss2` (EGSS): EU 26/27 (LU absent). Within NACE section E,
  renewable-energy production (CReMA 13A) output is **1.004 bn SEK** — the
  only direct monetary measure of energy output inside section E.
- `nrg_bal_c`: 78.3 PJ of waste fuel goes to electricity/heat, but 100% is
  burned in **main-activity producer plants classified in NACE D35** — the
  energy revenue accrues to D35, not E38. This resolves the paradox of huge
  physical energy recovery next to tiny E38 energy revenue.

**Bounded estimate:** energy-relevant share of the 60.156 bn SEK supply-side
control is **1.0 bn SEK central (1.7%) to 8.9 bn SEK deliberately-generous
upper bound (14.8%)** (upper bound double-counts all treatment/disposal gate
fees plus waste fuel valued at 20 SEK/GJ although Swedish waste fuel trades
near zero or negative). **Verdict: characterizable, not allocatable** — no
EU-wide source provides the product-level split needed to move money onto
energy rows, so the recommendation to colleagues is to accept `CPA_E37-E39`
as a permanent disclosed non-energy residual, optionally annotated with the
~1.0 bn SEK documented energy ceiling.

### Gotchas for future pulls

- PRODCOM lives on the Comext API, not the main dissemination API; both
  `prc_stapro` and `ds-056120` are dead.
- Sweden reports chips under 16102503/05, not the 16102303/05 codes some list
  vintages use; 25 legacy codes report zero production but positive exports —
  vintage artifacts, no double counting detected.
- `naio_10_cp15`'s codelist advertises finer `E37`/`E38` industry codes that
  carry no values for Sweden — a codelist mirage.
- EPEA CEPA2+CEPA3 output (72.7 bn SEK) legitimately *exceeds* the 60.156 bn
  SUT control because EPEA counts waste/wastewater services produced outside
  E37-E39.

## Pilot results — `nama_10_a64_e` employment vs `employed.xlsx` (2026-07-31)

First pilot of the post-monetary-core phase (parameterizing the remaining
`read_data.py` inputs, smallest first). Artifacts:
`data/preprocessing/scripts/download_employment_dk_2020.py`,
`reconcile_employment_dk_2020.py`; raw JSON-stat deliveries with manifest and
README under `data/preprocessing/data/employment_raw/DK/2020/` (includes the
SE-2020 pull and the EU-27 coverage probe); 8-sheet workbook
`data/preprocessing/data/employment_dk2020_reconciliation.xlsx`.

### What the model actually consumes (inspected, not assumed)

`employed.xlsx` is one sheet: `year, indu, type, employed, hours` — 57 GREU
industries × employees/self-employed × **2019–2020 only**; `employed` in
persons, `hours` in thousand hours. `read_data.py` uses surprisingly little:

- line 351: only the **hours ratio** self-employed/employees per industry, to
  upscale the wage sum for independents' imputed labour income;
- lines 358–359/686: `employed` summed over all industries and both types to
  a **single national scalar** `nEmployed(t)`.

Per-industry head counts are never used individually; no FTE concept appears.
So the load-bearing requirement is hours × employees/self-employed by
industry, which is exactly what `nama_10_a64_e` publishes (`EMP_DC`,
`SAL_DC`, and directly `SELF_DC`; units THS_PER and THS_HW).

### Denmark 2020 reconciliation (28 concordance clusters)

- **Hours: essentially exact.** National totals 3,982,709 thousand hours both
  sides (−0.000%); employees and self-employed hours totals also exact; 24 of
  28 clusters match to the rounding digit.
- **Persons: uniform +3.52% concept gap** (2,970,850 Eurostat vs 2,869,924
  Danish; employees +3.59%, self-employed +2.35%). Not a unit error — the
  exact hours match proves both sides are DST national accounts. The Danish
  `employed` column is on a non-standard person concept (colleague question);
  it only affects the scalar `nEmployed`, not the wage imputation.
- **Cluster exceptions are boundary issues, not data errors:** cluster L
  hours +180.1% / persons +194.3% — the known L↔68203 real-estate boundary
  (third pilot to hit it), mirrored by business services (−8.9% hours); and
  the public cluster O+P+Q86+Q87_88+R90-92 concentrates the persons-concept
  gap (persons +7.4%, hours only +1.9%). All other clusters: hours within
  ±0.02%.

### EU-27 coverage and Sweden

16 of 27 member states are complete for all six na_item × unit combinations
at A64. Gaps: **DE, FR, BE, BG, LT publish hours only at ~A38 level** (EE
section level; LU/MT partial in both units); HU/FI/LT/EE suppress some
`SELF_DC` cells but always publish `SAL_DC`, so self-employed is recoverable
as EMP−SAL. **Sweden:** 57/63 mapped A64 codes; C20, C21, H52, H53, M71, M72
are suppressed in all combinations, with parent aggregates published, so pair
residuals are derivable (C20+C21 = 29k persons, H52+H53 = 105k,
M71+M72 = 167k) but the within-pair split needs an external key (e.g. SBS
employment). C20/C21/H52/H53 are single-industry GREU clusters, so an SE
build is coarser there.

### Verdict

**The "OK" hypothesis holds, with two qualifications.** For Denmark the
source reproduces the input essentially perfectly on the load-bearing hours
content. A generic EU build needs: (1) the same A64→GREU coarse-cluster
handling as all pilots plus the unresolved L↔68203 split; (2) for the six
hours-at-A38 countries, distributing aggregate hours over A64 persons shares
(mild: only the self/employee hours *ratio* enters the model); (3)
SELF = EMP − SAL where suppressed; (4) SE-style suppressed-code residual
handling. Also noted: `employed.xlsx` covers only 2019–2020, so the EU
replacement only needs those years.

### Correction to earlier entries (2026-07-31)

Earlier pilot sections say the concordance yields "24 clusters". The FIGARO
pilot's own mapping artifact contains **28 mapped clusters** (+1 unmapped
`U`), and this pilot's 28 match that artifact exactly. The "24" in the FIGARO
and PEFA prose is a doc inaccuracy, not a methodology difference; the numbers
of *coarser* clusters (7) and covered industries quoted there are unaffected.

## Suggested next steps

1. ~~Download FIGARO 2022 (or 2020 for comparability with Danish data) supply,
   use, ind-by-ind IO for one pilot country~~ — **DONE 2026-07-29**, see pilot
   results above.
2. ~~Pull PEFA + air emissions accounts for DK 2020 and reconcile against
   `energy_and_emissions.xlsx` totals~~ — **DONE 2026-07-30**, see pilot results
   above.
3. ~~Verify JRC-IDEES coverage for the purpose split~~ — **DONE 2026-07-30**;
   public and EU-wide, with a strong combined process envelope, but exact
   categories require construction and EUTL.
4. ~~Pilot public Union Registry/EUTL for `ets.xlsx` and `in_ETS`~~ —
   **DONE 2026-07-30**. `ets.xlsx` totals reproduce; the physical `in_ETS` purpose
   still needs fuel/emission-factor modelling and a maintained industry bridge.
5. ~~Audit the monetary energy layer and public valuation controls~~ —
**DONE 2026-07-30 as a feasibility/gap pilot**. Direct monetary cell coverage is
0%; public controls are sufficient for calibration but not direct population.
**Architecture selected and first Sweden package implemented:** the approved
coarse public-EU core plus optional detailed country layer now has a complete
SE-2020 runtime package. Its large explicit residuals show where public control
tables remain broader than PEFA allocation evidence.
6. Decide (with colleagues) which GREU industry splits survive in the EU version.
7. NEW (from pilot): decide handling of re-exports and of the L↔68203 real-estate
   split; add a note or split key to `industries_naceA64_map`.
8. NEW (from PEFA pilot): review and correct the four energy-product concordance
   issues (P18, heat-pump ambient energy, `semi_refin_oil` spelling, P10).
9. NEW (from emissions pilot): investigate the +26.430 kt CH4 / +0.636 kt N2O
   Eurostat gaps (mostly agriculture) and document whether they are vintage or
   national-adjustment differences.
10. Agree the IDEES process-code concordance and rules for `heating`,
   `process_normal`, and `process_special`; keep transport on the PEFA/account
   side.
11. NEW (from EUTL pilot): decide whether to maintain a reviewed
    installation→NACE concordance or redesign ETS inputs at regulatory-activity
    level; specify the fuel/emission-factor method needed to construct `in_ETS`
    PJ without absorbing process emissions.
12. ~~Reduce/explain Sweden's unmatched monetary residual (CPA_C16/E37-E39
    audit)~~ — **DONE 2026-07-31**: root-caused to a PEFA section-vs-division
    reporting-granularity mismatch, not a data gap; use-side residual cut from
    299.131 to 118.844 bn SEK; a comparable 102.567 bn SEK supply-side
    residual was found to be silently unmeasured and is now disclosed. See the
    Sweden section and Handoff above.
13. ~~Pull Eurostat PRODCOM for `CPA_C16` and investigate waste-management
    statistics for `CPA_E37-E39`~~ — **DONE 2026-07-31**, see the PRODCOM/waste
    pilot section above: `CPA_C16` is ≥98.5% non-energy (PRODCOM `DS-059358`
    is a viable EU-wide splitting key), `CPA_E37-E39` is ≥85% non-energy and
    not narrowable with public EU-wide data. The remaining piece of item 13 is
    the colleague decision: accept these evidence-backed non-energy residuals
    as permanent disclosed features of the public-core method (recommended),
    optionally annotating `CPA_E37-E39` with its ~1.0 bn SEK documented energy
    ceiling.
14. NEW (optional, from the PRODCOM pilot): if colleagues want the `CPA_C16`
    residual annotated rather than merely accepted, wire the PRODCOM export
    share (~1.15% energy-relevant) into the builder as an audit annotation —
    an annotation, not an allocation, since PRODCOM values are ex-works/FOB
    vs SUT purchaser prices.
15. ~~Pilot `nama_10_a64_e` against `employed.xlsx` (first OK-verdict input of
    the parameterization phase)~~ — **DONE 2026-07-31**, see the employment
    pilot section above. Hours reconcile essentially exactly; verdict OK with
    known construction caveats (hours-at-A38 countries, SE suppressed codes,
    L↔68203).
16. NEW (from the employment pilot, for colleagues): what person concept does
    the Danish `employed` column use? It sits a uniform +3.52% below
    Eurostat/DST national-accounts annual-average employment while the hours
    columns match exactly. Only the scalar `nEmployed(t)` depends on the
    answer.
17. NEXT (data task, no colleague input needed): pilot the remaining
    OK-verdict inputs the same way, one per increment —
    `emissions_bridge_items.xlsx` vs `env_ac_aibrid_r2` (smallest),
    `government_finances.xlsx` vs `gov_10a_main` (expect concept-not-number
    match; values come from MAKRO), `institutional_financial_accounts.xlsx`
    reusing the financial-accounts module's `nasa_10_f_bs` pull (replicate
    the pension-asset reallocation note).

## Handoff — stopping point and next session

**Current stopping point:** Sweden 2020 monetary-energy `public_core` is built,
audited and accepted at the compatibility boundary. All three runtime artifacts
validate with no Danish fallback. Physical/product and monetary component/SUT
identities close numerically. The deliverable is not a full Sweden GREU model
because all unrelated inputs in `read_data.py` remain Danish. **The
previously-recommended residual-narrowing task is now done** (2026-07-31, see
above): the use-side unmatched SUT residual fell from 299.131 to
118.844 bn SEK, and a comparable, previously-invisible 102.567 bn SEK
supply-side residual is now explicitly disclosed instead of hidden.

**Both residual follow-ups are now also done (2026-07-31, two parallel
pilots — see the PRODCOM/waste pilot section above):** `CPA_C16` is ≥98.5%
non-energy per PRODCOM `DS-059358` (the `prc_stapro` code previously cited
here was wrong/dead), and `CPA_E37-E39` is ≥85% non-energy per
SBS/EPEA/EGSS/`nrg_bal_c` — Sweden's waste-to-energy revenue sits in NACE
D35, not E38, and no EU-wide source supports product-level allocation. **The
monetary-residual work stream is closed as a data question.** What remains of
it is only the colleague decision: accept the evidence-backed non-energy
residuals as permanent disclosed features (recommended), optionally with the
PRODCOM/EGSS annotations from next-steps items 13–14.

**The parameterization phase has started:** the first OK-verdict input pilot,
`employed.xlsx` vs `nama_10_a64_e`, is **done (2026-07-31**, see the
employment pilot section above): hours — the only load-bearing per-industry
content — reconcile essentially exactly for DK 2020; persons carry a uniform
+3.52% concept gap that only affects the scalar `nEmployed` (new colleague
question, item 16); 16/27 countries are complete at A64, with documented,
mild construction rules for the rest.

**New recommended next task (do not broaden it):** continue the OK-verdict
pilots one input per increment (item 17): `emissions_bridge_items.xlsx` vs
`env_ac_aibrid_r2` first (smallest, exact concept match by design), then
`government_finances.xlsx` vs `gov_10a_main` (expect concept-not-number
match; the Danish values come from MAKRO), then
`institutional_financial_accounts.xlsx` reusing the financial-accounts
module's existing `nasa_10_f_bs` code (replicate the pension-asset
reallocation note). Alternative if blocked: start structural gap 3
(investment matrices from GFCF × asset bridge), but note its
RAS-with-Danish-prior step is itself a method decision for colleagues.

**Prerequisites/decisions carried over:** colleague acceptance of the
now-evidence-backed non-energy residuals (`CPA_C16`, `CPA_E37-E39`); do not
infer an allocation from Danish target values. Air-emission allocation,
industrial purposes/`in_ETS`, investment matrices and the other Sweden inputs
remain separate later work streams.

**Related finding (2026-07-31, already fixed, does not change the task above):**
the verification audit found and fixed a distinct gap — `CPA_B05`/`CPA_B06`
(coal, crude oil) have no Eurostat SUT breakdown at all for Sweden, so
916.7847 PJ was silently valued at zero. This is now an explicit, flagged
anomaly (see the Sweden section above), not a hidden one, but it is still
**unresolved** in the sense that no monetary value exists for that energy at
all. If a country ever publishes a usable `CPA_B`-level split, or a different
public source can proxy coal/crude value, that would close a real gap — but
this is a separate, lower-priority thread from the CPA_C16/E37-E39 task above,
which concerns misallocation across too-broad controls rather than a missing
control.

**Verification status at handoff (2026-07-31, updated after the employment
pilot):** the CPA_B05/CPA_B06 fix, the overstated-roadmap correction, the
FIGARO README typo, the CPA_C16/E37-E39 residual-narrowing task with its
supply-side disclosure fix, the two residual-characterization pilots, and now
the `nama_10_a64_e` employment pilot have all been applied. Neither the
Sweden package nor any code was rebuilt/changed by the three 2026-07-31
pilots — they are read-only evidence. A doc inaccuracy was corrected this
pass: the concordance yields **28** mapped clusters, not the "24" stated in
the FIGARO/PEFA prose (see the employment pilot section).
`docs/EU_data_roadmap.html`/`.pdf` are synchronized with this file as of this
entry; `energy_data_notes.md` received a short residual-characterization
results note (its residual narrative previously pointed to the PRODCOM/waste
follow-ups as open ideas); `data/Modules/energy_money/README.md` needed no
change (its residual figures are unchanged and it defers to this file for
interpretation). The two stale "24 clusters" statements in the FIGARO and
PEFA pilot prose were corrected inline to 28. **No pending doc updates; safe
to start the next session directly on item 17 (`emissions_bridge_items.xlsx`
vs `env_ac_aibrid_r2`), or on a different item from the open-decisions
list.**

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
