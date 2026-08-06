# Notes: energy_and_emissions.xlsx ↔ io_energy_matrix_format.xlsx

Working notes for the energy data files (2020 vintage). All principles below have
been verified numerically against the actual files (2026-07-27); verification
diffs were at rounding level (~1e-5) unless noted.

Official documentation exists: `GREU data documentation.pdf` (this folder),
read 2026-07-29. Its §2–§5 cover these files; where it and these notes overlap
they agree. Doc-confirmed purpose definitions (§2.1):
- `heating`: room/water heating for non-industrial uses.
- `transport`: transportation.
- `process_special`: very energy-intensive processes (mineralogical,
  metallurgic, electrolysis, chemical reduction); greenhouses >200 m²;
  **non-ETS-covered** input to electricity/district-heating production;
  crude-oil refining.
- `appliances`: households' electrical equipment other than heating/transport.
- `process_normal`: everything else.
The doc's purpose list does NOT include `in_ETS`, and `process_special`
explicitly carves out only the *non*-ETS-covered electricity/heating input —
suggesting `in_ETS` holds the ETS-covered counterpart of that input. Unverified;
still pending colleague confirmation (doc also has a typo: `so2_tax` described
as "co2 tax").

## energy_and_emissions.xlsx (sheet `ems_energy`)

Long format, 907 rows, one row per (year, bal, flow, indu, purp, product).

Dimensions:
- `bal`: supply (`sup`) or use (`use`).
- `flow`: origin/destination. `cons_inter` = firms (intermediate consumption),
  `cons_hh` = households, `other_supply` is likely a bookkeeping device.
- `indu`: industries (Danish IO codes). Special codes (confirmed): `off` =
  offentligt (public sector), `env` = environment, `res` = residual/waste,
  plus `cHouEne`/`cCarEne` (household energy/car-energy consumption groups).
  Trade industries: 45000 = sales and repair of cars, 46000 = engroshandel
  (wholesale), 47000 = detailhandel (retail).
- `purp`: purpose of energy use. **Confirmed mutually exclusive** across all
  categories including `in_ETS` — summing over purposes never double-counts.
  What `in_ETS` precisely covers is still unresolved (colleagues have asked
  onwards; answer pending).
- `product`: 25 energy products.

Value columns:
- Emissions (confirmed: kilotonnes): `ch4`, `co2_bio`, `co2_xbio`, `n2o`,
  `co2_eq` (use side only). `co2_xbio` = all non-biogenic emissions; biogenic
  CO2 (`co2_bio`) is reported separately and never double-counted.
- Energy: `pj` (petajoules). Supply and use each total 2,251.55 PJ in 2020.
- Money (confirmed: billions, DKK): `basic` = basic prices (≈ producer prices);
  `ws_marg`/`ret_marg`/`mvs_marg` = trade margins (gap between producer and
  consumer prices, a surplus); `ener_tax`, `co2_tax`, `so2_tax`, `nox_tax`,
  `pso_tax` = product taxes; `vat` = VAT; `purch` = purchaser (consumer) prices.

## io_energy_matrix_format.xlsx (sheet `2020`)

Matrix format, values in money (prices). Two header rows (`col_l1` = flow,
`col_l2` = industry/consumption group) and two label columns (`row_l1` = block,
`row_l2` = industry code).

- Row blocks: `production` (57 industries), `import` (51 industries),
  `prim_input` (tax_products, tax_vat, tax_other_production,
  subs_other_production, emp_comp, gross_surplus).
- Column blocks: `cons_inter` (57 industries), `cons_hh` (12 groups incl.
  cHouEne, cCarEne), `cons_hh_foreign` (10 groups), plus single columns
  cons_publ, invest_build, invest_trans, invest_other, invent_change, export.
- Beware when reading: `col_l2` industry codes lose leading zeros via Excel
  (e.g. `1012.0` for `01012`) — normalize with zfill(5) after stripping `.0`.

## Verified reconciliation principles

1. **Row sums = basic prices.** Sum of an IO `production` row for industry *i*
   = sum of `basic` over all supply rows (`bal=sup`) with `indu=i` in
   energy_and_emissions. Verified exactly for 19000, 35011, 0600a.
2. **Column sums = purchaser prices.** Sum of an IO `cons_inter` column for
   industry *i* = sum of `purch` over rows with `bal=use, flow=cons_inter,
   indu=i`. One IO cell corresponds to a whole box of rows (all products/purposes
   for that combination).
   - Households: em `flow=cons_hh, indu=cHouEne/cCarEne` purch = IO `cons_hh`
     column **plus** the `cons_hh_foreign` column for the same group. The em
     file does not split domestic vs foreign (tourist) consumption; the IO does.
3. **tax_products = the five product taxes.** IO `tax_products` cell for a
   column = sum of `ener_tax + co2_tax + so2_tax + nox_tax + pso_tax` over the
   matching box in energy_and_emissions. (Can be negative, e.g. 35011.)
4. **tax_vat = vat.** Same box-mapping as above, exact.
5. **Margins go to trade industries, one-to-one by type:**
   - `mvs_marg` (motor vehicle sales) → IO production row **45000**
   - `ws_marg` (wholesale, engros) → IO production row **46000**
   - `ret_marg` (retail, detail) → IO production row **47000**
   Verified exactly on 2020 totals (0.9073 / 4.9301 / 1.9700). These three
   industries supply no energy products themselves in energy_and_emissions, so
   their production rows in the *energy* IO consist purely of margins.

Further verified facts (2026-07-27):
- **co2_eq = co2_xbio + 28·ch4 + 265·n2o, exactly** (max error 0.0000 across all
  rows). Confirmed: co2_eq is computed from "drivhuspotentialer" (greenhouse
  warming potentials — the factors match AR5 GWP100) and **excludes biogenic
  CO2** (co2_bio is reported separately and not in co2_eq).
- **other_supply** is exactly 5 rows, PJ only, no monetary values: `env` supplies
  heat_pump (13.14 PJ ambient heat) and renewable (66.42 PJ, ≈ wind/solar/hydro
  primary input); `res` supplies waste (35.53), waste_oil (0.002), wood_waste
  (6.93). These products have **no `basic` anywhere** — purely physical flows,
  present so the PJ balance closes. Per-product supply=use verified (waste also
  gets 6.08 PJ from imports; 35.53+6.08 = 41.61 used).
- **Imports**: em import rows (`bal=sup, flow=import`) carry a `product` but **no
  `indu`**. The IO `import` block is by industry. Block totals match exactly
  (63.5772). Confirmed: the by-industry split is made by Statistics Denmark
  under a **proportionality assumption** — foreign production is assumed to have
  the same industry structure as domestic production, so imports of a product
  are allocated to industries in proportion to domestic production shares.
- **Export and invent_change**: IO single columns match em purch totals exactly
  (21.8934 and 1.9001).
- **cons_publ and invest_* columns are all zero** in the energy IO. Public-sector
  energy use sits inside `cons_inter` under industry code `off`.
- The 57 `cons_inter` industries are identical between the two files, and include
  the special codes `env`, `off`, `res`.

Accounting identity implied: for any use column,
`purch = basic (dom + imp) + margins + product taxes + vat`, with margins
rerouted to rows 45000/46000/47000 in the IO representation.

## Open questions

- **What `in_ETS` precisely covers** — colleagues are unsure and have asked
  onwards (as of 2026-07-27). It is confirmed mutually exclusive with the other
  purposes, so calculations summing over `purp` are safe meanwhile.
- Whether more years than 2020 will arrive (build scripts year-generic
  regardless).

Answered 2026-07-27 by colleagues: units (bn DKK / kt), co2_eq method
(drivhuspotentialer, excl. biogenic), import industry split (DST proportionality
assumption), purp mutual exclusivity, meaning of off/env/res, trade industry
names, other_supply as residual/balancing supply.

## Eurostat PEFA / air-emissions pilot (2026-07-30)

Re-runnable scripts and detailed cell-level results:
`data/preprocessing/scripts/download_eurostat_energy_emissions_dk_2020.py`,
`reconcile_eurostat_energy_emissions_dk_2020.py`, and
`data/preprocessing/data/eurostat_energy_emissions_dk2020_reconciliation.xlsx`.
Raw official API responses and query provenance are in
`data/preprocessing/data/eurostat_energy_emissions_raw/`.

Verified findings:

- GREU supply/use is 2,251.550 PJ. The like-for-like PEFA product-flow boundary
  (P08–P27 plus selected renewable natural inputs and waste residuals) is
  2,237.794 PJ: −13.756 PJ (−0.611%). Do **not** compare GREU with PEFA's
  published 3,702.820 PJ all-flow total: that also counts upstream natural
  inputs and 1,155.402 PJ of energy losses/dissipative heat (`R30`).
- Household total is exceptionally close: PEFA 253.760 vs GREU 253.662 PJ
  (+0.039%). The broad end uses exist in PEFA, but allocation differs: heating
  −6.932 PJ, transport +0.359 PJ, other/appliances +6.671 PJ.
- Four concordance issues were exposed: `sem_refin_oil` is misspelled relative
  to the data's `semi_refin_oil`; P18 (146.140 PJ) is missing from the diesel
  mapping; environment-supplied `heat_pump` belongs with renewable natural
  inputs rather than P27 output heat; P10 derived gas (0.555 PJ) is unmapped.
  The reconciliation applies these as transparent pilot adjustments but does
  not modify `metadata.xlsx`.
- `env_ac_ainah_r2` is a **total** air-emissions account, not an energy-only
  account. Adding `non_energy_emissions.xlsx` gives the comparable GREU total:
  fossil CO2 matches within −4.607 kt (−0.0069%), biogenic CO2 within +0.078 kt,
  and F-gases within +0.001 kt CO2e. Methane is +26.430 kt and N2O +0.636 kt in
  Eurostat, making Eurostat GHG 82,241.335 vs GREU 81,337.382 kt CO2e
  (+903.953 kt, +1.111%); most of the gap is agriculture methane.
- The residence/bunker question is now resolved conceptually. Both GREU and
  Eurostat use the residence principle. GREU's three bunker products total
  497.799 PJ and 39,138.053 kt CO2e; the official GREU `internat_transp` bridge
  is 39,022.027 kt CO2e. The 116.026 kt difference confirms that bunker
  products and the bridge are close but not identical constructions;
  territorial conversion should use the bridge, not subtract bunker rows ad
  hoc.

## JRC-IDEES purpose pilot (2026-07-30)

Re-runnable scripts and detailed results:
`data/preprocessing/scripts/download_jrc_idees_dk_2023.py`,
`reconcile_jrc_idees_dk_2020.py`, and
`data/preprocessing/data/jrc_idees_dk2020_purpose_reconciliation.xlsx`.
The official DK archive is preserved in
`data/preprocessing/data/jrc_idees_2023_raw/`.

Verified scope:

- Current edition **JRC-IDEES-2023 v1**, annual 2000–2023, all EU-27 Member
  States, direct anonymous ZIP download, CC BY 4.0.
- IDEES Industry is a territorial Eurostat-energy-balance decomposition:
  11 sectors, 21 subsectors, named technical processes and cross-cutting end
  uses. Fine end-use values are JRC estimates constrained to sector fuel totals.
- On mapped DK industries, IDEES FEC is 96.610 PJ versus GREU 129.636 PJ. The
  closer boundary excludes GREU's 20.999 PJ own-account transport:
  96.610 versus 108.637 PJ (−11.07%).
- The robust result is the **combined process envelope**: IDEES 93.116 PJ versus
  GREU `process_normal + process_special + in_ETS` 90.360 PJ (+3.05%).

Purpose verdicts:

- `heating`: IDEES `LOW_ENTH` is the closest direct conceptual proxy, but it is
  only 3.494 PJ versus GREU 18.277 PJ on the mapped industry boundary. It is too
  narrow to use without a rule/adjustment.
- `transport`: not assignable by user industry from IDEES. Its transport data
  are mode-based; PEFA/GREU account evidence is still needed for own-account
  transport.
- `process_normal`: constructible only as a process-code classification or
  residual. The pilot proxy is 66.626 PJ and contains unknown ETS-covered use.
- `process_special`: constructible from named processes, but the pilot's broad
  metallurgical/mineralogical proxy is 26.489 PJ versus GREU 5.764 PJ. An
  owner-approved concordance is required.
- `in_ETS`: **not an IDEES dimension**. The subsequent EUTL pilot confirms that
  registry data can identify regulated installations and emissions but not
  their energy use in PJ; do not infer ETS status from process names.

Households should continue to use PEFA as the account control. IDEES Residential
adds useful detail and excludes transport: heating is 148.617 PJ versus GREU
147.284 PJ; other/appliances 30.422 versus 32.179 PJ; the non-transport
residential subtotal is 179.040 versus 179.463 PJ (−0.236%). Combining IDEES
residential with PEFA transport gives 253.597 PJ, −0.025% from GREU's household
total, but this remains an explicitly hybrid construction.

New product-label caveat found while building the broad fuel diagnostic:
`energy_and_emissions.xlsx` uses operational labels `natgas_incl_biongas` and
`natgas_extraction`, while the `metadata.xlsx` product list shows `natgas`.
The pilot handles the operational labels explicitly and does not modify the
input concordance.

## Union Registry / EUTL pilot (2026-07-30)

Re-runnable scripts and detailed results:
`data/preprocessing/scripts/download_eea_eutl_2026.py`,
`download_euetsinfo_nace_2026.py`, `reconcile_eutl_dk_2020.py`, and
`data/preprocessing/data/eutl_dk2020_reconciliation.xlsx`. Official raw daily
GZIP-CSV files and the EEA July 2026 bulk release are preserved in
`data/preprocessing/data/eea_eutl_2026_raw/`; the secondary NACE feasibility
package is preserved separately in `euetsinfo_nace_2026_raw/`.

Verified source status:

- The European Commission Union Registry exposes anonymous daily bulk files for
  installations and annual compliance records. The 2026-07-30 snapshot contains
  all EU-27 countries, years 2005–2025 and Denmark 2020. The EEA July 2026
  release is open under CC BY 4.0 and supplies independent aggregates and
  national auction volumes.
- Denmark 2020 verified emissions are 11,039.385 versus GREU 11,038.641 kt CO2e
  (+0.744 kt, +0.0067%). Stationary emissions are identical; the difference is
  a later aviation revision.
- Free allocation is 6,783.620 versus 6,783.462 thousand allowances (+0.158,
  +0.0023%).
- GREU `bought_allowances` is not a direct EUTL purchase field. It is reproduced
  as the installation-level positive shortfall
  `max(verified emissions − free allocation, 0)`: 5,348.399 versus 5,348.293
  thousand (+0.106, +0.0020%). This does not observe banking, transfers or
  sales.
- GREU `emissions_tax` implies a uniform 231.831091 DKK/t applied to that
  shortfall. EUTL reports neither tax nor price. EEA's direct national auction
  volume is 6,845.500 thousand allowances and cannot be allocated to
  installations or substituted for the shortfall.

Industry bridge verdict:

- EUTL regulatory activity codes are **not NACE**. In Denmark, activity 20
  (“combustion of fuels”) alone spans 336 records and 7,244.759 kt, so it cannot
  be assigned to one GREU industry.
- The public EUETS.INFO carbon-leakage-list NACE concordance covers 356 of 375
  relevant records (94.93%) and 10,772.880 of 11,039.385 kt (97.59%).
  The remaining 19 records carry 266.505 kt. This is useful diagnostically but
  remains secondary, historical and partial; it is not an authoritative EU-wide
  production bridge.

`in_ETS` conclusion:

**EUTL cannot directly populate `energy_and_emissions.purp=in_ETS`.** It proves
regulation and emissions, but has no PJ, fuel, heat-content, energy-product or
purpose field. A construction would need a maintained installation→NACE/GREU
map, fuel-specific emission factors, separation of process from combustion
emissions, PEFA/IDEES controls, and explicit residual/double-counting rules.
The exact GREU meaning of `in_ETS` also still needs owner confirmation. The
purpose gap therefore remains model-side and open.

## Monetary-energy feasibility pilot (2026-07-30)

Re-runnable scripts and audit artifact:
`download_energy_money_sources_dk_2020.py`,
`reconcile_energy_money_dk_2020.py`, raw official files/provenance in
`eurostat_energy_money_raw/`, and
`energy_money_dk2020_feasibility_gap.xlsx`.

### Which monetary distinctions the code actually requires

`read_data.py` stacks every value column from `energy_and_emissions.xlsx` into
`EnergyBalance`. The downstream code makes the operational requirement precise:

- `data_from_GR.gms` defines total energy price as `base` + `EAV`/`DAV`/`CAV`
  (the three margins) + `ener_tax`/`CO2_tax`/`so2_tax`/`nox_tax`/`pso_tax` +
  `vat`;
- its consistency tests compare those components with energy-IO domestic and
  import rows, the three trade-industry margin rows, `TaxSub`, and `Moms`;
- the long-format energy IO is subtracted from the full IO and is also exported
  as energy-specific parameters, so it is a consumed model input;
- `purch` is read/stored but is intentionally absent from the total-price set.
  It is a derived check/presentation field, not an additional amount to sum;
- `io_energy_matrix_format.xlsx` remains an unread pivot view.

So a model-ready country build needs physical product×user flows, basic values,
three margins, the five tax fields (or an explicitly approved replacement), VAT,
derived purchaser values, and the energy-only IO. Supplying only a purchaser
price is not interface-compatible.

### Official public controls tested

All were retrieved anonymously on 2026-07-30; exact URLs, hashes and filters are
in the raw README/manifest and workbook:

- national SUT `naio_10_cp15` provides broad CPA total supply at basic and
  purchaser prices, **combined** trade+transport margins, and net product taxes;
  `naio_10_cp16` provides broad CPA purchaser uses;
- `env_ac_taxind2` provides energy and CO2-related tax totals by NACE payer;
- `nrg_pc_202_c`–`205_c` provide annual gas/electricity supply, network, tax and
  VAT components by household status and consumption band;
- the Commission Weekly Oil Bulletin provides 2005-onward petroleum prices
  with/without tax plus VAT/excise/other-tax histories;
- TAXUD publishes VAT and energy-excise reference material.

Coverage is not uniformly EU-27: SUT has 26/27 countries in 2020 (Bulgaria
missing, also throughout a 2015–2024 probe); gas components have 24/27 household
and 25/27 non-household coverage, with no nearby observations for the missing
combinations. Electricity components and environmental taxes have 27/27.

### Quantitative verdict

The physical PEFA layer remains strongly covered: 2,237.794 / 2,251.550 PJ =
99.389% on the comparable boundary. The monetary result is different:

- **0 / 862 nonzero use rows are directly source-complete** at GREU's required
  product × user × purpose grain.
- Exact-family retail controls (electricity, road petrol, road diesel) cover
  337.775 PJ (15.002%) and 51.438 / 208.562 bn DKK purchaser value (24.663%) in
  the Danish validation target.
- Treating mixed `natgas_incl_biongas` as a near-match raises those envelopes to
  481.430 PJ (21.382%) and 63.794 bn DKK (30.588%), but Eurostat natural gas
  cannot validate the embedded biogas share.
- Broad SUT energy CPA valuation and supply-use identities close, confirming
  their use as calibration totals. They cannot distinguish the three margins or
  five GREU taxes.
- The Danish target component identity closes to floating-point precision; its
  energy-IO totals/rows/columns close within 0.00196 bn DKK rounding.

**Conclusion:** no direct public-data fill is model-ready. A next-stage build
must visibly separate source values, derived identities, owner-approved
allocation/rate rules, calibration residuals and unavailable concepts. Danish
target shares must not be used as production allocation keys while calling the
method EU-generic.

## Selected compatibility architecture (implemented 2026-07-30)

The monetary-energy interface will use a **coarser public-EU core** with an
**optional detailed country layer**. The first implementation is
`data/Modules/energy_money/`; it changes plumbing and validation only, not the
data verdict above.

- Default `country_detail` + `DK` resolves to the existing
  `energy_and_emissions.xlsx`, `io_energy_long_format.xlsx`,
  `EU_GR_data.gdx`, and generated `data_DK.gdx`. Existing Denmark behavior and
  GDX symbols/domains are preserved.
- `public_core` resolves only under
  `data/preprocessing/data/eu_core/<CC>/` (or an explicit configured root).
  It requires both workbooks and one complete marginal-rate GDX. Missing files
  are a hard error; there is no fallback to Denmark.
- Workbook acceptance validates the first sheet (`ems_energy` or `io`), the
  required columns, and unique full keys. The energy key is
  `year/bal/flow/indu/purp/product`; the energy-IO key is
  `year/row_l1/row_l2/col_l1/col_l2`.
- Optional detail is materialized before runtime. Complete detail rows replace
  matching public-core keys, detail-only keys are added, and output is sorted
  deterministically. New workbooks have one header row plus a metadata sheet;
  an adjacent manifest records provenance and hashes. Inputs and existing
  outputs are not overwritten.
- Marginal-rate GDX files are never merged. The selected layer must supply a
  complete compatible file with `tEAFG_REmarg` and `tCO2_REmarg`; it is copied
  byte-for-byte when an overlay is materialized.

## Sweden 2020 public core (accepted 2026-07-30)

The approved calibrated method has now produced the first non-Danish package at
`data/preprocessing/data/eu_core/SE/`. It passes the monetary-energy workbook
and GDX compatibility checks without a Danish fallback. This supersedes the
earlier statement that no public-core dataset existed, but it does **not**
change the direct-coverage verdict: no product × user × purpose monetary cell is
directly observed.

Implemented distinctions:

- industries use connected NACE A64↔GREU clusters with one representative
  runtime label per whole cluster; A64 categories are never split using Danish
  values;
- industrial purpose is `unspecified`; PEFA's direct household
  heating/transport/other purposes are retained;
- physical supply/use is controlled to PEFA. The selected boundary balances at
  **4,611.0794 PJ** on each side, with maximum product residual
  **5.68×10⁻14 PJ**;
- public electricity/gas and oil prices are initial weights only. Sweden's SUT
  is the hard monetary control. Purchaser value is **610.583 bn SEK** and the
  maximum SUT purchaser residual is **2.84×10⁻14 bn SEK**;
- SUT's one combined margin is encoded in `ws_marg`; `ret_marg` and `mvs_marg`
  are zero. The aggregate non-VAT wedge is encoded in `ener_tax`; the four
  unavailable named taxes are zero;
- Sweden's 25% legal VAT rate is applied only to non-recovering households and
  capped by the SUT tax wedge. Legal estimate, calibrated VAT and residual are
  separate audit fields;
- `purch` is derived from components. Maximum component-identity residual is
  **7.11×10⁻15 bn SEK**;
- the compatible GDX assumes average allocated `ener_tax/PJ` is marginal.
  Separate CO2 marginal rates are unavailable and encoded as zero. Public-core
  mode skips the legacy Danish sector collapse/cloning.

Observed versus modelled:

- PEFA quantities and its three household purposes are direct public fields.
- SUT totals, combined margins/net product taxes, tax-account payer totals and
  price-family observations are direct public controls.
- Every monetary allocation within those controls is modelled/calibrated:
  **0 direct monetary cells; 177 nonzero modelled use cells**.
- The account exposes **1,765.088 PJ** of PEFA reporting-detail residual, mainly
  because Swedish transformation use is not fully reported at A64, and
  **299.131 bn SEK** of broad SUT control with no matched physical allocation.
  These residuals are rows/audit fields, not silently distributed.
- The 25% household legal-rate calculation gives 29.768 bn SEK versus
  28.393 bn SEK calibrated VAT, a visible 1.375 bn SEK difference. The mapped
  non-VAT SUT wedge is 48.508 bn SEK versus 38.063 bn SEK in the energy-tax
  account, leaving a 10.445 bn SEK concept/control residual.
- Negative inventory-change values inherited from the public SUT control are
  retained: six flagged basic-value rows sum to −3.115 bn SEK and are listed in
  the audit `anomalies` sheet.
- Air-account totals are not allocated to products: `env_ac_ainah_r2` includes
  energy plus process emissions and no defensible public split exists. Runtime
  emission fields are therefore zero in this monetary-core package.
- **Found and fixed 2026-07-31:** `naio_10_cp15`/`naio_10_cp16` publish no rows
  at all for `CPA_B05` (coal/lignite: P08/P09/P11) or `CPA_B06` (crude oil:
  P12/P13) for Sweden — a "no data" case that previously collapsed to the same
  `0.0` as a genuine published zero, so **916.7847 PJ** (≈19.9% of Sweden's
  total energy) was silently unflagged. The builder now checks per-CPA source-
  row existence before valuing anything, adds `cp15_has_source_rows`/
  `cp16_has_source_rows` audit columns, and raises 4 explicit `ERROR` anomalies.
  No other Sweden number in this section changed — the fix only converts a
  hidden zero into a disclosed "unobserved" gap.

Reproduce with
`download_energy_money_public_core.py` and
`build_energy_money_public_core.py`; inspect
`energy_money_se2020_public_core_reconciliation.xlsx` and the package/raw
manifests for exact URLs, hashes, weights, controls and residuals.

Remaining blocker: `read_data.py` still reads Danish non-energy inputs, so a
full Sweden GREU run would mix countries and is intentionally not attempted.

**Unmatched-SUT-residual narrowed 2026-07-31.** Root cause: Sweden's PEFA
USE table reports whole NACE sections (manufacturing `C`, agriculture `A`,
water/waste `E`, trade/transport `G`/`H`) without ever breaking them into the
finer A64 divisions (`C16`, `C19`, `E37-E39`, ...) the GREU concordance
expects, while `naio_10_cp16`'s money is published at that finer level. The
energy was never missing — it already sat in the explicit `indu=res`
reporting-detail residual — its money just had no matching physical row at
the fine level and was booked as pure unmatched residual instead. The
builder now pools that money into the same `res` bucket that already holds
the matching physical quantity, cutting the use-side unmatched SUT residual
from **299.131 to 118.844 bn SEK** (180.287 bn SEK reclassified) with every
identity still closing exactly. Industries PEFA *does* detail (financial and
business services) were never redirected — their remaining residual is
genuinely non-energy money inside a too-broad CPA, not a reporting gap. The
same pass exposed a second, independent, pre-existing gap: the headline
residual metric only ever read `purch`, which is `0` on every supply row by
construction, hiding a comparable **102.567 bn SEK** producer-side
(`basic`-value) unmatched control — mainly the waste/sewerage industry's own
broad `CPA_E37-E39` production total (60.156 bn SEK) versus its tiny
physical waste-fuel byproduct. Both figures are now explicit manifest fields
and `INFO` anomalies. See `docs/eu_data_mapping.md` for the full breakdown
and the resolved prerequisite questions.

**Residuals characterized 2026-07-31 (read-only evidence pilots; no package
change):** the two follow-up ideas above were executed the same day. PRODCOM
(`DS-059358` on the Comext API) shows only ~1.15% of Sweden's division-16
export value is energy-relevant wood products, so the `CPA_C16` residual is
≥98.5% genuinely non-energy. SBS/EPEA/EGSS/`nrg_bal_c` bound the
energy-relevant share of the `CPA_E37-E39` supply-side control at 1.7%–14.8%
(central 1.0 bn SEK): Sweden's waste-to-energy revenue accrues to NACE D35
plants, not E38. Neither source supports product-level allocation, so both
residuals remain disclosed residuals — now evidence-backed as non-energy.
See the PRODCOM/waste pilot section of `docs/eu_data_mapping.md`.
