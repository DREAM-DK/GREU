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

## EU-source findings for these files (pointers, not copies)

Everything this repository has verified about replacing these Danish energy
files with EU sources lives in two other documents. It is deliberately **not**
repeated here: the same figures were previously maintained in three files at
once, which is a drift hazard and costs three times as much to read.

- `docs/eu_data_pilots.md` — the PEFA/air-emissions, JRC-IDEES, EUTL and
  monetary-energy feasibility pilots, plus the Sweden 2020 public-core package.
  Single source of truth for every reconciliation number.
- `docs/eu_data_mapping.md` — current verdicts per input, the four structural
  gaps, open questions and the next task.

The four headline results, so you know whether you need to look:

- **Physical energy is well covered.** PEFA reproduces GREU's 2,251.550 PJ to
  within −0.611% on a like-for-like boundary. Do not compare against PEFA's
  published 3,702.820 PJ all-flow total, which also counts upstream natural
  inputs and 1,155.402 PJ of losses/dissipative heat (`R30`).
- **Money is not covered at all.** 0 of 862 nonzero use rows have every
  required monetary component observed at product × user × purpose grain.
  Public sources work as calibration controls, never as cells.
- **The purpose dimension stays constructed.** JRC-IDEES supports a combined
  process envelope (+3.05%) but not GREU's exact categories, and EUTL proves
  ETS membership without publishing any PJ.
- **Four concordance errors in `energy_products_pefa_map` were found and are
  still unfixed** pending owner review: `sem_refin_oil` misspelling, P18
  (146.140 PJ) missing from the diesel mapping, `heat_pump` belongs with
  renewable natural inputs rather than P27 output heat, P10 derived gas
  unmapped. The pilots applied these as explicit adjustments and did **not**
  modify `metadata.xlsx`.
- Product-label caveat: `energy_and_emissions.xlsx` uses the operational labels
  `natgas_incl_biongas` and `natgas_extraction` while the `metadata.xlsx`
  product list shows `natgas`.
