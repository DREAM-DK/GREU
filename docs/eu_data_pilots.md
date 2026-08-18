# EU data — pilot evidence archive

Completed reconciliation pilots, the Sweden 2020 public-core package, and
background reference. **This file is history: append when a pilot finishes,
but do not look here for current status.**

- Current status, verdicts and next task → `docs/eu_data_mapping.md`
- Management-facing overview → `docs/EU_data_overview.xlsx`
- Non-specialist project overview → `docs/EU_data_roadmap.pdf`

Every number in this file is reproducible from the scripts in
`data/preprocessing/scripts/` and the reconciliation workbooks in
`data/preprocessing/data/`. Numbers here are the single source of truth for
pilot results — do not copy them into other documents; link to this file.

## What is in here

| Section | Date | One-line verdict |
|---|---|---|
| Architecture decision | 2026-07-30 | Coarse public-EU core + optional country detail layer |
| Sweden 2020 public core | 2026-07-30/31 | First non-Danish package; passes contract; 0 direct monetary cells |
| Review and decision record | 2026-07-31 | Two independent review passes; three scope questions resolved |
| Official Danish documentation | 2026-07-29 | `GREU data documentation.pdf` endorses the Eurostat route |
| Pilot 1 — FIGARO | 2026-07-29 | Aggregates match ≤0.1%; re-exports and NACE-L boundary differ |
| Pilot 2 — PEFA / air emissions | 2026-07-30 | Physical −0.611%; CH4/N2O gaps; 4 concordance errors found |
| Pilot 3 — JRC-IDEES | 2026-07-30 | Process envelope +3.05%; exact purposes still constructed |
| Pilot 4 — Union Registry / EUTL | 2026-07-30 | ETS totals reproduce; no PJ, so `in_ETS` stays open |
| Pilot 5 — monetary energy feasibility | 2026-07-30 | 0 of 862 rows source-complete; controls usable, cells not |
| Pilot 6 — PRODCOM / waste statistics | 2026-07-31 | Residuals are ≥98.5% and ≥85% non-energy money |
| Pilot 7 — employment | 2026-07-31 | Hours essentially exact; persons +3.52% concept gap |
| Emissions bridge (`env_ac_aibrid_r2`) | 2026-08-17 | Net residence adjustment ≤0.05% per gas; zero EU-27 gaps |
| Government finances (`gov_10a_main`) | 2026-08-17 | Number-exact except D41REC +0.62%; splits/PAL structural |
| Financial accounts (`nasa_10_f_bs`/`nf_tr`) | 2026-08-18 | Model never reads the Excel; F5 equity exact; pension move quantified (2,703.8 bn); EU-27 complete |

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

## Review and decision record (2026-07-31)

Preserved from the changelog that used to head `eu_data_mapping.md`. These are
QA and scope decisions, not measurements.

**Independent verification passes.** Three review agents re-derived the code,
the Sweden numbers and the first five pilots (FIGARO, PEFA, IDEES, EUTL,
monetary feasibility) from source. Everything reproduced exactly except two
findings: the `CPA_B05`/`CPA_B06` silent-zero gap in the "residuals are never
hidden" claim (described in the Sweden section above, now fixed), and one
overstated roadmap line calling financial accounts "effectively done" (also
corrected). A fourth agent then re-reviewed only the `CPA_B05`/`CPA_B06` fix —
line-by-line code check, independent recomputation of 916.7847 PJ from the raw
PEFA JSON-stat, schema-leakage and merge/NaN checks — and confirmed it correct,
with one harmless latent issue (a merged audit column could go stale on
transient residual rows, never read by anything) fixed by a one-line
`uses.drop(columns="cp16_has_source_rows")`. Sweden was rebuilt and all 10
tests reran identically after each pass. **The Sweden public-core package has
been through two independent review passes with every finding addressed.**

**Three prerequisite questions, resolved without needing colleague input:**

1. *Which CPA subproducts count as energy* — unchanged. Still exactly the
   existing PEFA→CPA product map (`P23`→`CPA_C16`, `R28`/`R29`→`CPA_E37-E39`,
   `P10`/`P26`/`P27`→`CPA_D`, remaining `P14`–`P25`→`CPA_C19`). The
   residual-narrowing fix does not redefine scope; it only stops conflating
   "PEFA cannot detail this industry" with "this industry has no energy".
2. *Is a zero-quantity monetary residual still acceptable* — yes. The remaining
   118.844 bn SEK (use) and 102.567 bn SEK (supply) residuals stay as explicit,
   flagged rows, now with a clearer attribution.
3. *Is an additional EU-wide source admissible* — none was added in that pass.
   The fix reuses the already-approved `env_ac_pefasu` and
   `naio_10_cp15`/`naio_10_cp16` more carefully rather than pulling in a new
   dataset, keeping the increment tightly scoped and reviewable. PRODCOM was
   flagged as admissible for a *later* pass, which has since been executed (see
   the PRODCOM/waste pilot below).

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

## Pilot results — `env_ac_aibrid_r2` vs `emissions_bridge_items.xlsx` (2026-08-17)

Second pilot of the parameterization phase. Artifacts:
`data/preprocessing/scripts/download_emissions_bridge_dk_2020.py`,
`reconcile_emissions_bridge_dk_2020.py`; raw JSON-stat deliveries with
manifest and README under
`data/preprocessing/data/emissions_bridge_raw/DK/2020/` (DK + SE pulls,
EU-27 coverage probes, and an `env_air_gge` CRF4 cross-check); 7-sheet
workbook `data/preprocessing/data/emissions_bridge_dk2020_reconciliation.xlsx`
(16/16 internal checks pass).

### What the model actually consumes (inspected, not assumed)

`emissions_bridge_items.xlsx` is one sheet, 3 rows for 2020 only
(`bord_trade`, `internat_transp`, `lulucf`) × gas columns
(`ch4`, `co2_bio`, `co2_xbio`, `n2o`, `co2_eq`), thousand tonnes.
`read_data.py:379-403,694-696` uses:

- `lulucf` row → `qEmmLULUCF[t]`, **CO2-eq only**;
- `bord_trade` row → `qEmmBorderTrade[em,t]` per gas (`co2_bio` is NaN and
  dropped);
- **`internat_transp` is read but never exported to GAMS** — dead weight,
  like per-industry head counts in the employment pilot. The model computes
  its international-transport bridge terms (bunkering, international
  aviation) from the energy balance itself (`data_from_GR.gms:583-586`,
  `emissions.gms:105-111`), and at `data_from_GR.gms:586` also nets
  international road diesel (industry 49509) and international aviation jet
  fuel (51009) bunkering out of `qEmmBorderTrade`.

Unit/GWP identity verified on both sides: Danish `co2_eq` =
`co2_xbio + 28·ch4 + 265·n2o` **exactly** on all three rows (AR5 GWP100),
and Eurostat's `CH4_CO2E/CH4` and `N2O_CO2E/N2O` ratios equal the same
factors.

### Denmark 2020 reconciliation

One dataset covers all three Danish rows: `env_ac_aibrid_r2`'s `indic_env`
dimension carries both the residence adjustments (`AEMIS_RES_ABR_*`
residents abroad, `AEMIS_TER_NRES_*` non-residents on territory, by mode
fishing/land/water/air) and a LULUCF block (`LULUCF` = `FORL` + `CRL_GRL` +
`LULUCF_OTH`). No second dataset is needed.

- **Net residence adjustment: matches to ≤0.05% per gas.** Danish
  `bord_trade + internat_transp` vs Eurostat `AEMIS_RES_ABR −
  AEMIS_TER_NRES`: CO2 −0.006% (38,482.0 vs 38,484.2 kt), CO2-eq −0.006%,
  CH4 +0.027%, N2O −0.049%.
- **The two-row split is a Danish national definition, not reproducible
  from Eurostat's mode split — and quantified as a pure reclassification.**
  Denmark books international road hauliers under `internat_transp`;
  Eurostat books all road under land transport. The offsets cancel:
  `bord_trade` exceeds EU net-land by +361.0 kt CO2 while
  `internat_transp` falls short of EU net-(water+air+fishing) by −363.2 kt
  (difference = the 2.2 kt net discrepancy). Since `internat_transp` never
  reaches GAMS, the practical question is only how to build `bord_trade`:
  EU net land transport is the natural proxy, with the international-road
  component handled consistently with the model's own netting at
  `data_from_GR.gms:586` (method decision noted for the build, not a data
  gap).
- **LULUCF: exact concept match, numbers differ by inventory vintage.**
  aibrid `LULUCF` equals the UNFCCC inventory sector `env_air_gge` CRF4
  cell-for-cell (0.0 diff, all gases), and aibrid `AEMIS_TER_LULUCF` equals
  the inventory total `TOTXMEMO` exactly. The Danish file's LULUCF CO2-eq
  is +17.7% above the current inventory (1,292.1 vs 1,097.4 kt) with CO2
  +41%, CH4 −21%, N2O −12% — the Danish file was built from an earlier
  UNFCCC submission, and LULUCF recalculations between submissions are
  routinely this large. Same phenomenon expected for `government_finances`
  (concept-not-number).

### EU-27 coverage and Sweden

**Complete.** All 27 member states publish every key GHG cell
(`AEMIS_RES`, `AEMIS_RES_ABR`, `AEMIS_TER`, `AEMIS_TER_NRES`, `LULUCF`) in
`env_ac_aibrid_r2` for 2020, and all 27 publish the `env_air_gge` CRF4 GHG
total. Sweden's full 2020 slice is delivered with all three key indicators
present. This is the first pilot with zero coverage gaps.

### Verdict

**OK confirmed — the strongest pilot so far.** The load-bearing content
(`bord_trade` per gas, LULUCF CO2-eq) is available for all EU-27 from one
dataset, with the net adjustment reconciling to ≤0.05% and only two
build-time notes: (1) derive `bord_trade` from net land transport (the
row-split definition), (2) accept inventory-vintage differences on LULUCF
levels. A 2020-only build suffices: like `employed.xlsx`, the Danish file
carries a single year.

## Pilot results — `gov_10a_main` vs `government_finances.xlsx` (2026-08-17)

Third pilot of the parameterization phase. Artifacts:
`data/preprocessing/scripts/download_government_finances_dk_2020.py`,
`reconcile_government_finances_dk_2020.py`; raw JSON-stat deliveries with
manifest and README under
`data/preprocessing/data/government_finances_raw/DK/2020/` (DK + SE pulls of
`gov_10a_main` and `gov_10a_taxag`, EU-27 coverage probes for both, TE year
probe); 8-sheet workbook
`data/preprocessing/data/government_finances_dk2020_reconciliation.xlsx`
(15/15 internal checks pass). The `na_item` concordance was seeded from the
colleague's reference module `data/read_eurostat_data/government_data.py`.

### What the model actually consumes (inspected, not assumed)

`government_finances.xlsx` sheet `gov_fin`: 34 rows for 2020 only, bn DKK,
government transactions by ESA code (`trans_esa`) split into
`exp`/`rev`/`exp_eu`/`rev_eu`. `read_data.py:427-553` builds ~28 scalar time
series from it (`vG`, `vTrans`, `vtVAT`, `vtDirect`, `vtPAL`, `vtCorp`,
`vGovInv`, ...). No industry dimension anywhere. Two quirks: the "disagg"
read at line 545 actually re-reads sheet 0 (the two `tax_direct_other_labor`
rows are distinguished by `trans_txt`), and the `gov_fin_disagg` sheet
(cons_publ split into its 8 ESA components, with DST statbank provenance) is
never consumed.

### Denmark 2020 reconciliation — exact, contrary to expectation

The mapping doc predicted concept-not-number match because the Danish values
come from MAKRO. **In fact every mappable row reconciles to the third
decimal (bn DKK)** once four re-readings are applied, with a single
exception: interest revenue (`D41REC` 14.337 vs Danish 14.249, +0.088 bn,
+0.62%), which is also the entire net-lending gap (B9 8.434 vs Danish
rev−exp 8.348). MAKRO passes national-accounts levels through unchanged for
this input. Highlights (bn DKK, Danish = Eurostat exactly unless noted):
P3 576.099, D3PAY 75.463, D41PAY 12.058, P51G 82.871, NP −3.954, D9PAY
13.916, D211 231.650, D29REC 51.888, D61REC 20.123, D91REC 6.676, P51C
61.862, D7REC 24.009, D92_D99REC −5.53, and the total exp/rev sums 1220.039
/ 1228.387.

The four re-readings (all verified numerically, not assumed):

1. **PAL is a household tax in Eurostat.** Danish `tax_direct_corp` =
   `D51B_C2` exactly (67.720); the pension-yield tax (~48.3 bn) sits inside
   `D51A_C1` "taxes on individual/household income *including holding
   gains*". `source + other_labor + pension` = `D51A_C1 + D51D` to 0.001.
   PAL cannot be recovered as a separate series from `gov_10a_taxag` alone.
2. **The Danish "D214" row is really D212 + D214.** `tax_indirect_products`
   87.831 = taxag S13 `D212` (37.396, import excises recorded in S13) +
   `D214` (50.435). The separate `rev_eu` `tax_import` row (3.089) is the
   S212 slice of D212 (duties collected for the EU) — also exact.
3. **D42–D45 detail is not delivered for DK.** Danish dividends +
   quasi-corp + rent (6.288) = `D42_TO_D45REC` exactly, but the D421/D422/
   D45 detail `read_data.py` consumes separately (`vtDividends`,
   `vGovRevQuasi`, `vGovRent`) needs another source (candidate:
   `nasa_10_nf_tr` D42/D45 for S13) or a fixed split.
4. **The disagg sheet stores signed contributions** to the P3 formula; with
   signs applied all 8 components match `gov_10a_main` exactly.

Tax detail generally: for DK the main dataset does *not* deliver
`D211REC`/`D51A_C1REC`/`D59REC` despite the codes existing — the reliable
tax source is `gov_10a_taxag` (S13, plus S212 for EU-collected duties),
whose totals tie back to the main dataset's `D2REC`/`D5REC` identities
exactly.

### The genuine structural gaps (not number gaps)

- **Domestic/RoW counterpart splits.** Four Danish row pairs
  (`transfer_to_hh`/`transfer_to_row`, `transfers_from_dom`/`_row`,
  `cap_transfer_to_dom`/`_row`, `cap_transfers_from_dom`/`_row`) have no
  counterpart dimension in `gov_10a_main`. The partial published items do
  not close it: `D9PAY_S2`/`D9REC_S2` carry no value for DK 2020, and the
  EU-institutions proxy (`D74PAY + D76PAY` = 21.022) recovers only half of
  Danish `transfer_to_row` (42.660) — Danish RoW transfers include D62
  benefits paid abroad and non-EU D7. All four *sums* are exact. An EU
  rebuild needs `nasa_10_nf_tr` S2 counterpart data or fixed-share splits.
- **EU-paid CAP subsidies** (`subs_other_production_eu`, 7.035 →
  `vtCAP_prodsubsidy`): no delivered value anywhere in `gov_10a_*` — the
  flow sits in sector S212 and `D3REC_S212` carries no observation for DK
  or SE. Candidates: `nasa_10_nf_tr` D39 received by resident sectors net
  of gov `D39PAY`, or CAP budget data.
- Minor: Danish `trans_esa` label "D22+D99" on the capital-transfer rows is
  a typo for D92+D99 (values behave exactly as D9); Eurostat bundles P52
  with valuables as `P52_P53` (both 0.000 for DK 2020).

### EU-27 coverage and Sweden

14/27 countries publish every item the pilot mapping needs for 2020. The
gaps are narrow: `D8` missing for 8 countries and `D39REC` for 5 (both
plausibly zero-and-unpublished — Eurostat drops zero cells; neither is a
row of the Danish file, they only enter the TE identity), `D91`/`D91REC`
missing for EE and SE (Sweden abolished inheritance/capital taxes —
likely a true zero), `D212` missing in taxag S13 for FI/HU/NL. The
counterpart items are patchy EU-wide (`D3REC_S212` in 14/27,
`D9PAY_S2` in 18/27), consistent with the split gap above. TE series run
1995–2025 for all 27 (Finland from 1975). Sweden's full 2020 slice misses
only `D91REC` (true-zero candidate) and `D3REC_S212` (the CAP gap).

### Verdict

**OK confirmed, upgraded to number-exact.** `gov_10a_main` + `gov_10a_taxag`
reproduce the Danish file to the third decimal for every mappable row
(except D41REC +0.62%). What is left is structural, small and enumerable:
the four dom/RoW splits, the D421/D422/D45 detail, PAL as a separate series,
and the EU-paid CAP subsidy row. Each has a named candidate source
(`nasa_10_nf_tr`) or an explicit fallback (fixed shares from a base year).

## Pilot results — `nasa_10_f_bs` / `nasa_10_nf_tr` vs `institutional_financial_accounts.xlsx` (2026-08-18)

Fourth pilot of the parameterization phase. Artifacts:
`data/preprocessing/scripts/download_financial_accounts_dk_2020.py`,
`reconcile_financial_accounts_dk_2020.py`; raw JSON-stat deliveries with
manifest and README under
`data/preprocessing/data/financial_accounts_raw/DK/2020/` (DK + SE pulls of
`nasa_10_f_bs` stocks — both units, both consolidations, incl. the
S128/S129 insurance/pension subsectors — and `nasa_10_nf_tr` flows; EU-27
coverage probes for both; two year probes); 11-sheet workbook
`data/preprocessing/data/financial_accounts_dk2020_reconciliation.xlsx`
(21/23 internal checks pass; the 2 fails are one explained Eurostat
source-data quirk, see below). Instrument definitions were cross-checked
against the colleague's reference modules
`data/read_eurostat_data/financial_accounts_balance_data.py` / `_flow_data.py`.

### What the model actually consumes (inspected, not assumed)

The headline finding precedes any number: **the model never reads this
Excel.** `read_data.py:406-424` and `:556-570` build eight GDX symbols from
it (five `[sector, as_li_net, t]` parameters plus three government-interest
scalars), all exported to the country GDX — and none is ever `$load`-ed.
`data_from_GR.gms:138-140` loads `sector`, `vNetFinAssets` and
`vNetDebtInstruments` from
`Modules/financial_accounts/financial_accounts_data.gdx`, the live Eurostat
`nasa_10_f_bs` pull (PR #107), and the flow variables are model equations
(`model/modules/financial_accounts.gms:107-110`, generated from calibrated
rates `rInterests_s`/`rDividends`/`rRevaluations_s`). So the EU replacement
is already in production, previously unverified; this pilot verifies it.
Incidentally, `read_data.py:562-568` contains three no-op `.rename()` calls
(including an `as`-for-`li` typo) on exactly these orphaned symbols.

### Denmark 2020 reconciliation — exact where unadjusted, and the pension move quantified

The Danish file (20 rows: 5 vars × 4 sectors × as/li/net, bn DKK, 2020,
internally exact to 1e-13) differs from raw Eurostat **only** by the
documented Danish pension-asset reallocation (metadata `sectors`:
households' pension assets moved from financial corporations to
households), which touches `corp` and `hh` but not `gov`/`row`:

- **Equity = F5, exactly.** `vNetEquity` net matches `nasa_10_f_bs` F5 net
  to rounding for the unadjusted sectors (gov +0.007, row −0.020 bn DKK) —
  and row matches in gross as/li too (3,076.8 / 4,080.2). The implied
  corp→hh equity move is mirror-exact from both sides: 2,703.848 (hh) vs
  2,703.841 (corp).
- **The colleague reference definition does not reproduce the Danish
  file.** `data/read_eurostat_data` uses Equity = F51 with F52 counted as
  debt; that misses gov equity by −46.8 and row by +367.0 bn DKK. The live
  module's Equity = F5 / debt = F1+F2+F3+F4+F6+F7+F8−F11 is the
  Danish-consistent one. (Net positions are consolidation-invariant;
  Danish gross levels sit closest to non-consolidated.)
- **Flows are `nasa_10_nf_tr` D41/D42, exactly.** `vNetInterests` and
  `vNetDividends` match gov and row exactly in as (=RECV), li (=PAID) and
  net — gov interest 14.337/12.058/2.279 ties to the government pilot's
  D41REC/D41PAY to the third decimal. corp and hh match exactly in sum;
  the implied moves are interest 51.064 (mirror-exact) and dividends
  22.406/22.407 bn DKK.
- **The pension move is the insurance/pension subsector's portfolio.** The
  total implied moved portfolio (equity move + debt move + removal of the
  4,158.9 bn hh F6 claims) is 5,002.2 bn DKK vs the S128_S129 subsector's
  entire financial-asset portfolio of 4,952.1 bn — within 1%. It is **not
  net-neutral**: Danish hh net financial assets end +837.3 bn DKK above raw
  Eurostat (the moved portfolio exceeds the removed F6 claims). Exact
  composition replication would need the Danish computation, but S128_S129
  balance sheets are published EU-wide, so a close approximation is
  buildable. `nasa_10_nf_tr` publishes no D41/D42 for S128_S129 (DK), so
  the flow-side move cannot be replicated from that dataset.
- **Small unexplained debt-stock gaps** on the unadjusted sectors: gov
  +23.551 and row +46.788 bn DKK (0.3–1.3% of net positions; likeliest
  vintage — the Excel predates the current Eurostat vintage and financial
  accounts revise heavily; equity happens to be revision-stable).
- **`vNetRevaluations` has no source** in either pilot dataset (route if
  ever needed: Δ`nasa_10_f_bs` stocks − `nasa_10_f_tr` transactions −
  other volume changes). The model generates revaluations, so nothing is
  blocked.
- **One Eurostat source-data quirk:** the DK delivery contains a household
  F2 (currency/deposits) *liability* of exactly 5.950 bn that Eurostat's
  own published F total excludes — the two failing workbook checks are this
  additivity gap, present for S14+S15 and S14_S15 alike.

### Government-pilot leftovers probed in `nasa_10_nf_tr`

Of the four gaps the government pilot left open: **rent closed exactly**
(S13 D45 RECV = 0.533); **the D42 dividend bundle closed at D42 level**
(S13 D42 RECV = 5.755 = Danish dividends + quasi-corp; the D421/D422 split
is still undelivered for DK — and IE — though the codes exist); **EU-paid
CAP subsidies found a close candidate** (S2 D39 PAID = 6.809 vs Danish
7.035, −3.2%; the EU is not separable from other RoW in `nasa_10_nf_tr`);
**dom/RoW counterpart splits only bounded** (S2 D62+D7 RECV = 60.837
economy-wide vs Danish gov-specific 42.660 — no payer × receiver
dimension, so a gov split still needs fixed shares or national data).
**PAL is impossible here too**: `nasa_10_nf_tr` has no D51 subitems.

### EU-27 coverage and Sweden

**All 27 member states are complete** for the core 2020 requirement (F,
F2–F8 stocks for S11/S12/S13/S2 plus households, and D41/D42 flows) — the
second pilot with zero EU-27 coverage gaps, after the emissions bridge.
Every country publishes the S14/S15 split *and* the S128_S129 subsector
needed to replicate the pension reallocation. F1/F11 (monetary gold/SDRs)
are absent for most non-financial sectors as true zeros, deliberately not
counted as gaps. Stock series run 1995–2025 for nearly all (HU from 1990,
IE from 2001); flow series 1995–2024/25 (SE from 1993, BG ends 2022).

### Verdict

**OK confirmed — and the row is really "already in production, now
verified".** The two load-bearing symbols (`vNetFinAssets`,
`vNetDebtInstruments`) come from the live module today; this pilot proves
the module's instrument definitions are the Danish-consistent ones and
quantifies the one concept it omits: the Danish pension-asset reallocation
(equity 2,703.8 bn DKK, household net wealth +837.3 bn — now decision 18
in the mapping doc). Remaining defects are enumerable: no pension
reallocation, `geo`/years hardcoded to DK/2019–2020, no raw provenance,
and the D421/D422 and PAL details stay open on the government side.
