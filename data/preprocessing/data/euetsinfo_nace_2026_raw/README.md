# EUETS.INFO installation-to-NACE data — public feasibility input

> **Not committed to Git.** The 499 MB ZIP and its extracted members are
> excluded by the `data/preprocessing/data/*_raw/` rule in `.gitignore`; only
> this README is versioned. Re-create the directory with
> `python data/preprocessing/scripts/download_euetsinfo_nace_2026.py` and verify
> the MD5/SHA-256 hashes recorded here.

- Retrieved: 2026-07-30
- Publisher/author: Jan Abrell, University of Basel
- Release: version 2, published 2026-07-17; archive dated 2026-07-21
- Concept DOI: https://doi.org/10.5281/zenodo.20509230
- Version DOI: https://doi.org/10.5281/zenodo.21414185
- Zenodo record: https://zenodo.org/records/21414185
- Record API: https://zenodo.org/api/records/21414185
- Direct archive: https://zenodo.org/api/records/21414185/files/eutl_data_package_2026-07-21.zip/content
- Query/filter parameters: none; complete static package downloaded
- Access: anonymous, public, no login or API key
- Licence: CC BY 4.0 for the author's compilation and transformations;
  underlying records retain their providers' terms
- Status: secondary/non-official concordance. NACE codes are derived from
  European Commission 2015/2020 carbon-leakage lists. They are not a
  current Union Registry field and must not be treated as authoritative
  company classifications.

## Preserved delivery

- `eutl_data_package_2026-07-21.zip`: 498,861,808 bytes
- MD5: `629595320851d20bd1b610878a2ecd1e` (matches Zenodo)
- SHA-256: `cd9fc016f012231b9eff8eea47e6fd5ee1e25dce029ca3559140da4712309c8b`
- ZIP members: 17; CRC validation passed

The ZIP is preserved byte-for-byte as delivered. The following members
are copied without modification to `extracted/` for the bridge test:

- `datapackage.json` — 54,823 bytes — SHA-256 `3fb327d3b411d7ef42c72aadf14abad97b8845613e9b9f65d73ac2e7dca2dbf6`
- `installations.csv` — 4,498,803 bytes — SHA-256 `2c81b16fffd6c70f77886fb44b1e55bb3a59d08eacca9dde01ae5a3e2f232947`
- `nace_mappings.csv` — 599,463 bytes — SHA-256 `7012bae7a8c6a4f70c358aadd8d13abacca313fe30c3c5d961b90cf57e1370cc`

Reproduce with:

```powershell
python data/preprocessing/scripts/download_euetsinfo_nace_2026.py
```
