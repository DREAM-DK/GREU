# Eurostat PRODCOM raw data — Sweden 2020 (NACE division 16 pilot)

> **Not committed to Git.** The raw deliveries are excluded by the
> `data/preprocessing/data/*_raw/` rule in `.gitignore`; only this README,
> `manifest.json` and `ds-059358_eu_coverage_probe_2020.csv` are versioned.
> Re-create the directory with
> `python data/preprocessing/scripts/download_prodcom_se_2020.py`.

Retrieved 2026-07-31 from the Eurostat **Comext** dissemination API by
`data/preprocessing/scripts/download_prodcom_se_2020.py`. Files are the raw
deliveries, byte-for-byte; SHA-256 hashes, exact URLs and query parameters are
in `manifest.json`.

## Dataset identification (verified against the live API 2026-07-31)

- Correct dataflow: **DS-059358** "Sold production, exports and imports"
  (PRODCOM list, CPA 2.1 vintage — correct for reference year 2020).
- The code `prc_stapro` claimed in `docs/eu_data_mapping.md` does **not**
  exist on the dissemination API (HTTP 404 "not available for dissemination"),
  nor does the legacy Comext code `ds-056120`. PRODCOM is served only through
  the Comext dissemination API
  (`https://ec.europa.eu/eurostat/api/comext/dissemination/...`), not the main
  statistics API. Related dataflows: DS-059367 (PRODCOM list CPA 2.2),
  DS-059359/DS-059368 (total production).

## Files

- `ds-059358_SE_2020_all_products.csv` — SDMX-CSV, reporter SE, year 2020,
  all PRODCOM codes and all indicators (values in euro, quantities, flags).
- `ds-059358_eu_coverage_probe_2020.csv` — SDMX-CSV, all reporters, year 2020,
  products 16291500 (wood pellets/briquettes) and 16101033 (coniferous
  sawnwood): EU-27 availability probe.
- `cxt_prodcom2_sold_codelist.xml` — product codelist (code -> label).
- `cxt_indicators_codelist.xml` — indicator codelist.

## Confidentiality flags (PVALFLAG/PQNTFLAG..., per Eurostat PRODCOM guide)

blank = available; `:` = not available; `:C` = confidential; `:E` = reliable
estimate (published); `:U` = low-reliability estimate suppressed from national
publication (included in EU totals); `:R` = rounded (see rounding base);
`-` = not applicable. Suppressed cells must never be treated as zero.

## Licence / reuse

Eurostat data are subject to the Eurostat re-use policy (CC BY 4.0 for most
Eurostat online data since 2020; see https://ec.europa.eu/eurostat/about-us/policies/copyright).
