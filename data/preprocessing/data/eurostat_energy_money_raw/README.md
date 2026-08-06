# Monetary-energy source audit — Denmark 2020

> **Not committed to Git.** The raw deliveries described below are excluded by
> the `data/preprocessing/data/*_raw/` rule in `.gitignore`; only this README,
> `manifest.json` and the coverage/nearest-year probe results are versioned.
> Re-create the directory with
> `python data/preprocessing/scripts/download_energy_money_sources_dk_2020.py`.

Raw official source files used by the GREU monetary-energy feasibility audit.
Retrieved **2026-07-30** by
`data/preprocessing/scripts/download_energy_money_sources_dk_2020.py`.
The downloader validates file formats, records SHA-256 hashes in `manifest.json`,
and probes anonymous 2020 availability for all EU-27 countries in
`eu27_coverage_probe_2020.json`. For every missing country/dataset pair it also
tests 2015–2024 in `nearest_year_probe_2015_2024.json`.

## Eurostat JSON-stat responses

Each query uses `geo=DK&time=2020&lang=en` and is preserved exactly as delivered
by the dissemination API:

- `env_ac_taxind2_DK_2020.json` — environmental taxes by tax category and
  NACE payer. URL:
  https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/env_ac_taxind2?geo=DK&time=2020&lang=en
- `nrg_pc_202_c_DK_2020.json` — household natural-gas annual price components.
  URL:
  https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nrg_pc_202_c?geo=DK&time=2020&lang=en
- `nrg_pc_203_c_DK_2020.json` — non-household natural-gas annual price
  components. URL:
  https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nrg_pc_203_c?geo=DK&time=2020&lang=en
- `nrg_pc_204_c_DK_2020.json` — household electricity annual price components.
  URL:
  https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nrg_pc_204_c?geo=DK&time=2020&lang=en
- `nrg_pc_205_c_DK_2020.json` — non-household electricity annual price
  components. URL:
  https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nrg_pc_205_c?geo=DK&time=2020&lang=en
- `naio_10_cp15_DK_2020.json` — national supply table, including total supply
  at basic and purchasers' prices, combined trade/transport margins, and net
  product taxes by broad CPA product. URL:
  https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/naio_10_cp15?geo=DK&time=2020&lang=en
- `naio_10_cp16_DK_2020.json` — national use table at purchasers' prices by
  broad CPA product and user. URL:
  https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/naio_10_cp16?geo=DK&time=2020&lang=en

Eurostat access is anonymous and machine-readable. Eurostat data are covered by
the European Commission reuse policy; source attribution and any dataset notes
must be retained. The live EU-27 probe found 2020 observations for 27/27
countries in `env_ac_taxind2` and both electricity-component datasets, 26/27 in
the two national SUT datasets (Bulgaria absent), 24/27 in household gas
components, and 25/27 in non-household gas components.
The nearest-year probe found no observations in 2015–2024 for Bulgaria's two
national SUT tables, household gas components for Cyprus/Finland/Malta, or
non-household gas components for Cyprus/Malta. These are therefore not merely
one-year vintage gaps in the live series.

## Other official Commission deliveries

- `Weekly_Oil_Bulletin_Prices_History_2026-07-30.xlsx` — weekly petroleum
  consumer prices with/without taxes, VAT, excise and other indirect taxes from
  2005 onward. The country price series are EUR per 1,000 litres (or EUR per
  tonne for fuel oil); the duty sheets are in national currency per unit:
  https://energy.ec.europa.eu/document/download/906e60ca-8b6a-44e7-8589-652854d2fd3f_en?filename=Weekly_Oil_Bulletin_Prices_History_maticni_4web.xlsx
- `excise_duties_energy_products_rates_2021-07-01.pdf` — DG TAXUD energy
  products and electricity rate table, situation at 2021-07-01 (the nearest
  stable archival rate table found, not an exact 2020 rate source):
  https://taxation-customs.ec.europa.eu/system/files/2021-09/excise_duties-part_ii_energy_products_en.pdf
- `vat_rates_2020-01-01.pdf` — DG TAXUD VAT rates, situation at 2020-01-01:
  https://taxation-customs.ec.europa.eu/document/download/82a38bdb-d724-472d-8e02-325b271e0d88_en?filename=vat_rates_en.pdf

These files are anonymously downloadable. No dataset-specific licence statement
was found on the delivery pages; the audit therefore records the Commission
legal notice/reuse policy rather than claiming CC BY.

## Scope warning

These sources supply valuable controls, but no source jointly identifies GREU
energy product × user × purpose with basic value, three separate trade margins,
five Danish-style energy taxes, VAT, and purchaser value. The raw data must not
be interpreted as a model-ready replacement or combined using Danish target
shares without an explicit owner-approved modelling method.

## Successor implementation

The approved calibrated method was subsequently implemented for Sweden 2020.
Its country-specific raw sources are under `eu_core_raw/SE/2020/`, its runtime
package is under `eu_core/SE/`, and its detailed audit is
`energy_money_se2020_public_core_reconciliation.xlsx`. That package preserves
this warning: 0 monetary cells are direct; all allocations and residuals are
labelled.
