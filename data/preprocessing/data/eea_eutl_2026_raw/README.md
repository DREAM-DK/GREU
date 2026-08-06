# EEA EU ETS / Union Registry raw data — July 2026

> **Not committed to Git.** The archives and extracted members described below
> are excluded by the `data/preprocessing/data/*_raw/` rule in `.gitignore`;
> only the README files are versioned. Re-create the directory with
> `python data/preprocessing/scripts/download_eea_eutl_2026.py` and verify the
> SHA-256 hashes recorded here.

- Retrieved: 2026-07-30
- Publisher: European Environment Agency (EEA)
- Source system: European Commission Union Registry (formerly EUTL)
- Edition: July 2026; published 2026-07-08
- Temporal coverage stated by EEA: 2005-2025
- Geographic coverage: EU ETS participating countries; the pilot validates
  all EU-27 country codes and filters Denmark (`DK`) for calendar year 2020
- Query/filter parameters: none for the bulk download; Denmark/year filters
  are applied locally and recorded in the reconciliation workbook
- Catalogue: https://www.eea.europa.eu/en/datahub/datahubitem-view/98f04097-26de-4fca-86c4-63834818c0c0/file
- Stable record alias: https://sdi.eea.europa.eu/data/a94a5d68-9973-4e2c-9a7a-fd7690ec3473
- Resolved anonymous bulk URL on retrieval date: https://sdi.eea.europa.eu/datashare/s/BrZkLYoYCGAy73H/download
- Official activity-code mapping: https://sdi.eea.europa.eu/catalogue/api/records/a94a5d68-9973-4e2c-9a7a-fd7690ec3473/attachments/Translation%20of%20activity%20codes%20May%202019.xlsx
- Union Registry public website: https://union-registry-data.ec.europa.eu/
- Installation/operator master: https://dlsclimabi.blob.core.windows.net/public-data/eutlpublic/extracts/_all_extracts/operator/operators_daily.csv.gz
- Installation-year compliance data: https://dlsclimabi.blob.core.windows.net/public-data/eutlpublic/extracts/_all_extracts/operators_yearly_activity/operators_yearly_activity_daily.csv.gz
- Access: anonymous public HTTPS; no login, cookie, API key, or manual
  scraping required. The EEA record alias resolves to a read-only bulk ZIP;
  the Commission site exposes stable daily GZIP-CSV bulk endpoints.
- Licence/re-use: the EEA release metadata states CC BY 4.0, copyright
  European Commission and EEA, with no limitations on public access.
  Commission materials are subject to the Commission legal notice/re-use
  policy. Attribute the European Commission Union Registry and EEA.
- Legal notice: https://www.eea.europa.eu/en/legal-notice
- EEA data policy: https://www.eea.europa.eu/en/datahub/eea-data-policy
- Commission legal notice: https://commission.europa.eu/legal-notice_en

## Preserved delivery

- `eea_eutl_union_registry_july_2026.zip`: 7,862,765 bytes
- SHA-256: `3909a1e8f72e199db73af3565b384c7d51f3af04836b2b77f4a131ed35067cba`
- ZIP members: 9; CRC validation passed
- Delivered activity map `Translation of activity codes May 2019.xlsx`:
  158,878 bytes; SHA-256 `f98658c9056d80b5bc167f352f56f209dea3f6a5b23decf9fed1dfc6028632b4`
- `operators_daily.csv.gz`: 1,735,762 bytes;
  SHA-256 `07b62df0328dcd5751f34a8c58b68b258b834285346e6a91d71ab0cc26e5baf2`; HTTP Last-Modified
  `Thu, 30 Jul 2026 03:24:39 GMT`;
  ETag `0x8DEEDEA169C7FD0`
- `operators_yearly_activity_daily.csv.gz`: 5,086,870 bytes;
  SHA-256 `3368b0122dbbe4d676fb62c6db7e4504d6a858b753175a9ef0abd7f75660fd23`; HTTP Last-Modified
  `Thu, 30 Jul 2026 03:27:49 GMT`;
  ETag `0x8DEEDEA8832AE40`

The EEA ZIP and Commission GZIP-CSV files are preserved byte-for-byte as
delivered. Archive members are copied without transformation to
`extracted/` for inspection and reconciliation:

- `EEA_EUETS_data_viewer_user manual_June12.pdf` — 475,528 bytes — SHA-256 `c43834b0cc40ad2e91022ca99c1aad0d74998aff980fcc03362b51f2059673b3`
- `ETC-CM_EEA EU ETS data viewer background note_July_2026.pdf` — 1,021,179 bytes — SHA-256 `3bb05871dcdfea9bbd5e7ec8b5af891387b452ea0112e28a48d3bbb4cbd8d729`
- `ETC-CM EU-ETS data quality July_2026.pdf` — 716,194 bytes — SHA-256 `e1da28933d18b324e8a85c02265a019bbca61aab52034a478fcfe5d14e54fb42`
- `ETS_Database_July_2026.xlsx` — 3,356,861 bytes — SHA-256 `16de0c57d33faaf91dff9569362cc2683bc34e3f62de522654f4208b437e413c`
- `ETS.png` — 133,823 bytes — SHA-256 `5b9a923c2f717935e22646f0121ad9d061d24c770f82bd089b00d1289391406b`
- `European_Union_Emissions_Trading_System_EU_ETS_data_from_the_Union_Reg_metadata_a94a5d68-9973-4e2c-9a7a-fd7690ec3473.xml` — 52,710 bytes — SHA-256 `44c8d82f10393b6fc02112eabb90db2db37d9b6c7c8056fad722173b8473f073`
- `README.md` — 1,651 bytes — SHA-256 `4d4415bf24d4e52800014d2d6140b0764f33e72e0ee79a9c9d8e506e14f8957a`
- `Technical report - ETS Scope estimate (2023 update).pdf` — 1,943,147 bytes — SHA-256 `4c10708eb488330842c494cb30713d251fe7ccd09dd46ad33ff470693c948a40`
- `Translation of activity codes May 2019.xlsx` — 158,878 bytes — SHA-256 `f98658c9056d80b5bc167f352f56f209dea3f6a5b23decf9fed1dfc6028632b4`

Reproduce with:

```powershell
python data/preprocessing/scripts/download_eea_eutl_2026.py
```
