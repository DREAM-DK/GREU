# Public-core raw sources — SE, 2020

> **Not committed to Git.** The raw deliveries are excluded by the
> `data/preprocessing/data/*_raw/` rule in `.gitignore`; only this README,
> `manifest.json` and `eu27_coverage_probe.json` are versioned. Re-create the
> directory with
> `python data/preprocessing/scripts/download_energy_money_public_core.py`.
> The runtime package built from these sources, `data/preprocessing/data/eu_core/SE/`,
> **is** committed.

Official source deliveries preserved byte-for-byte by
`data/preprocessing/scripts/download_energy_money_public_core.py`.
Retrieval date: **2026-07-30**. SHA-256 hashes, exact URLs,
filters, units, source status and reuse terms are in `manifest.json`.

Eurostat inputs: `env_ac_pefasu`, `env_ac_ainah_r2`,
`env_ac_taxind2`, `naio_10_cp15`, `naio_10_cp16`,
`nrg_pc_202_c`–`205_c`, FIGARO `naio_10_fcp_s3/u3/ii3`, and
`ert_bil_eur_a`. Other Commission sources are the Weekly Oil Bulletin
and TAXUD VAT/excise references.

EU-27 observation coverage measured by the downloader:
- `env_ac_ainah_r2`: 27/27; missing none.
- `env_ac_pefasu`: 27/27; missing none.
- `env_ac_taxind2`: 27/27; missing none.
- `naio_10_cp15`: 26/27; missing ['BG'].
- `naio_10_cp16`: 26/27; missing ['BG'].
- `nrg_pc_202_c`: 24/27; missing ['CY', 'FI', 'MT'].
- `nrg_pc_203_c`: 25/27; missing ['CY', 'MT'].
- `nrg_pc_204_c`: 27/27; missing none.
- `nrg_pc_205_c`: 27/27; missing none.

The 2020 VAT reference is exact. The 2021-07-01 excise table is
the nearest stable TAXUD reference and is not treated as exact 2020
evidence. Raw files are controls, not direct product×user×purpose
monetary observations.
