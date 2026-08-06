# JRC-IDEES-2023 raw Denmark data

> **Not committed to Git.** The ZIP and extracted workbooks described below are
> excluded by the `data/preprocessing/data/*_raw/` rule in `.gitignore`; only
> this README is versioned. Re-create the directory with
> `python data/preprocessing/scripts/download_jrc_idees_dk_2023.py`.

- Retrieved: 2026-07-30
- Edition/version: JRC-IDEES-2023 v1
- Publisher: European Commission, Joint Research Centre
- Country selection: `DK` (Denmark country archive)
- Query parameters: none; static country ZIP distribution
- Direct source: https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/JRC-IDEES/JRC-IDEES-2023_v1/JRC-IDEES-2023_DK.zip
- Catalogue record: https://data.jrc.ec.europa.eu/dataset/1f0b480c-6d21-4d95-897d-20c7ca33df6f
- Dataset DOI: https://doi.org/10.2905/JRC.JPXYRT8
- Technical report: https://publications.jrc.ec.europa.eu/repository/handle/JRC144707
- Licence: Creative Commons Attribution 4.0 International (CC BY 4.0)
- Access: direct and anonymous; no registration or authentication

## Preserved delivery

- `JRC-IDEES-2023_DK.zip`: 12,117,793 bytes
- SHA-256: `04ff9884bf8887f3af4402e571d19cb6854673a773fe9a0df9f0e6be2857d3e8`
- ZIP members: 8; CRC validation passed

The ZIP is preserved byte-for-byte as delivered. The three workbooks needed
for this pilot are copied without modification to `extracted/`:

- `JRC-IDEES-2023_EnergyBalance_DK.xlsx` — SHA-256 `2c9c9e6c1434245dd91c9966e4ddc3d6e9baa2d161a45c186af42176c0b6c0c0`
- `JRC-IDEES-2023_Industry_DK.xlsx` — SHA-256 `28bec9b57285e8858ddba28eba2d3d7bfe99d7690f338081625bdd3b1b8e3cd8`
- `JRC-IDEES-2023_Residential_DK.xlsx` — SHA-256 `a45f3b3980de4d8b7af9d950f028dbb723df4df118688e7841a191ea89b461c2`

The Industry workbook supplies industrial process/end-use data. The
Residential workbook is inspected only to compare its household end-use
structure with PEFA. The EnergyBalance workbook is retained to audit the
IDEES energy-balance boundary.

Reproduce with:

```powershell
python data/preprocessing/scripts/download_jrc_idees_dk_2023.py
```
