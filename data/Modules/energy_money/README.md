# Monetary-energy compatibility layer

This package selects and validates a coarser public-EU monetary-energy core
with optional country detail. Sweden 2020 is the first generated non-Danish
public-core package. It uses only public European controls and keeps the three
energy-money inputs consumed by `read_data.py` and their GDX symbols compatible.

## Runtime modes

- `country_detail` (default): use a complete country-detail layer. With the
  default country `DK`, this resolves to the existing files in
  `data/preprocessing/data/` and writes the legacy `data_DK.gdx`.
- `public_core`: use only a complete generated layer under
  `data/preprocessing/data/eu_core/<CC>/`. Missing artifacts are an error;
  there is no fallback to Danish files or Danish allocation shares.

Each selected layer must contain:

1. `energy_and_emissions.xlsx`, first sheet `ems_energy`;
2. `io_energy_long_format.xlsx`, first sheet `io`;
3. `EU_GR_data.gdx`, a complete compatible marginal-rate file containing
   `tEAFG_REmarg` and `tCO2_REmarg`.

The workbooks retain one header row and the established keys:

- energy: `year/bal/flow/indu/purp/product`;
- energy IO: `year/row_l1/row_l2/col_l1/col_l2`.

Validation also opens the marginal-rate GDX and checks the required symbols and
record-domain columns before data construction begins.

`read_data.py` still handles all unrelated Danish inputs exactly as before.
Therefore `public_core` is an infrastructure and contract increment, not yet a
complete non-Danish model run.

## Environment variables

- `GREU_COUNTRY_CODE` — two-letter code; default `DK`.
- `GREU_ENERGY_MONEY_MODE` — `country_detail` or `public_core`; default
  `country_detail`.
- `GREU_ENERGY_MONEY_PUBLIC_CORE_ROOT` — optional root containing `<CC>/`.
- `GREU_ENERGY_MONEY_COUNTRY_DETAIL_ROOT` — optional country-detail root
  containing `<CC>/`.
- `GREU_ENERGY_MONEY_GENERATED_ROOT` — optional root for non-legacy generated
  country GDX files.
- `GREU_ENERGY_MONEY_OUTPUT_GDX` — optional explicit generated GDX path.

Example:

```powershell
$env:GREU_COUNTRY_CODE = "SE"
$env:GREU_ENERGY_MONEY_MODE = "public_core"
python run.py
```

The Sweden package is at
`data/preprocessing/data/eu_core/SE/`. Validate it without running the Danish
non-energy preprocessing:

```powershell
$env:GREU_COUNTRY_CODE = "SE"
$env:GREU_ENERGY_MONEY_MODE = "public_core"
python -c "from data.Modules.energy_money import get_energy_money_config; get_energy_money_config().validate(); print('PASS')"
python -m unittest test_energy_money.py
```

The package passes the workbook and GDX contract with no Danish fallback.
It is **not** a full Sweden GREU run: `read_data.py` still reads unrelated
Danish IO, employment, assets, government, emissions and other inputs.

## Sweden 2020 public-core method and result

Reproduce the source and build:

```powershell
python data/preprocessing/scripts/download_energy_money_public_core.py --country SE --year 2020 --currency SEK
python data/preprocessing/scripts/build_energy_money_public_core.py --country SE --year 2020 --force --check-determinism
```

Policy `public_core_v1.0` is stored at
`data/preprocessing/data/eu_core/public_core_v1.0_policy.json`. Its rules are:

- aggregate the existing NACE A64↔GREU map by connected components and label
  each whole cluster with one representative runtime code; never split A64
  with Danish shares;
- use `unspecified` for industrial purpose, while retaining PEFA's direct
  household heating/transport/other purposes;
- control physical supply/use to PEFA and retain reporting-detail and rounding
  residuals explicitly;
- use public price families as initial weights, then calibrate to Sweden's
  national SUT CPA×user purchaser controls;
- encode SUT's combined trade/transport margin entirely as `ws_marg`/EAV;
  `ret_marg` and `mvs_marg` are zero compatibility fields;
- encode the aggregate non-VAT product-tax wedge as `ener_tax`; the four
  unavailable named tax fields are zero;
- apply Sweden's 25% statutory VAT rule to non-recovering households, cap it
  at the SUT tax wedge, and retain the legal-rate/calibration difference;
- derive `purch` from the components;
- use allocated average `ener_tax/PJ` as the transparent average=marginal
  assumption in `tEAFG_REmarg`; `tCO2_REmarg` is complete but zero because no
  separate defensible CO2 rate exists at product×user grain.

The generated account balances at **4,611.0794 PJ** on both sides. Purchaser
value is **610.583 bn SEK**. Maximum product balance, component-identity and
SUT purchaser residuals are respectively `5.68e-14 PJ`, `7.11e-15 bn SEK`
and `2.84e-14 bn SEK`. These numerical closures do not make the underlying
cells observed: **0 monetary cells are direct and 117 nonzero use cells are
modelled/calibrated**. The audit exposes **1,765.088 PJ** of PEFA
reporting-detail residual and **118.844 bn SEK** of SUT controls lacking a
matched physical allocation on the use side (plus a separately-tracked
**102.567 bn SEK** on the supply/producer side — see below). Negative
inventory values are retained and flagged, not hidden.

**Found and fixed 2026-07-31:** the builder could not originally tell "source
reports a genuine zero" apart from "source has no row at all for this CPA" —
both produced an unflagged `0.0`. This hid **916.7847 PJ** (`CPA_B05`/`CPA_B06`
— coal and crude oil, ≈19.9% of Sweden's total energy), for which
`naio_10_cp15`/`naio_10_cp16` publish no Sweden observations whatsoever. The
builder now checks per-CPA source-row existence explicitly and raises 4
`ERROR` anomalies instead of a silent pass; see `cp15_has_source_rows`/
`cp16_has_source_rows` in the audit workbook's `valuation_controls` sheet.

**Unmatched-SUT-residual narrowed 2026-07-31 (same day, follow-up task):**
Sweden's PEFA reports USE-side energy consumption for whole NACE sections
(manufacturing `C`, agriculture `A`, water/waste `E`, trade/transport `G`/`H`)
without ever breaking them into the finer divisions (`C16`, `C19`, `E37-E39`,
...) the GREU concordance expects. That physical energy already sits in the
explicit `indu=res` reporting-detail residual — but `naio_10_cp16`'s
division-level money for the very same industries had no matching physical
row and was being booked as pure unmatched residual instead of being
recognised as the monetary counterpart of a bucket the audit already
disclosed. The builder now pools that money with the same `res` bucket
(`policy.reporting_detail_redirect_rule`; see the `reporting_detail_redirects`
audit sheet), which **cut the use-side unmatched SUT residual from
299.131 to 118.844 bn SEK** (180.287 bn SEK reclassified) with all identities
still closing to floating-point precision. Industries PEFA *does* detail
(e.g. financial/business services) are never redirected, so what remains is
genuinely non-energy spending inside a too-broad CPA (e.g. office furniture
within `CPA_C16` wood products) or national-accounts catch-all categories
(`export`, `other_final_use`) — not a reporting gap. The same investigation
also found that the headline residual metric only ever looked at `purch`,
which is always `0` on the supply side by construction, silently hiding a
comparable **102.567 bn SEK** producer-side (`basic`-value) unmatched
control — now exposed as `explicit_supply_side_monetary_residual_bn_SEK` and
an `INFO` anomaly rather than being invisible. See the mapping doc's Sweden
section for the full breakdown and remaining-gap interpretation.

Full provenance, hashes and findings are in
`data/preprocessing/data/eu_core/SE/energy_money_manifest.json` and
`data/preprocessing/data/energy_money_se2020_public_core_reconciliation.xlsx`.

## Optional country-detail overlay

`materialize_overlay(...)` is an explicit pre-build utility, not a runtime mode.
For each workbook, a complete detail row replaces a public-core row with the
same full key; detail-only keys are added; output is sorted deterministically.
Inputs are never modified, existing outputs are not overwritten, and generated
workbooks include a `metadata` sheet plus a JSON manifest with hashes and
provenance.

GDX symbols are **not merged**. The caller must select one complete compatible
marginal-rate GDX; the materializer copies it byte-for-byte and records its
hash. Place the resulting directory under the configured public-core root and
run in `public_core` mode.

This overlay mechanism only makes approved country detail optional and
auditable. Sweden proves the coarse calibrated contract; it does not turn
modelled allocations into observations or solve the remaining full-model
country-conversion gaps.
