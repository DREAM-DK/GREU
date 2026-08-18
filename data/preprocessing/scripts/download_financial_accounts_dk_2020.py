"""Download Eurostat financial-accounts data (nasa_10_f_bs stocks, plus
nasa_10_nf_tr property-income flows) for the institutional_financial_accounts.xlsx
pilot.

Ninth pilot in Phase 1 of the GREU EU-generic data work (see
docs/eu_data_mapping.md). Raw JSON-stat responses are saved exactly as
delivered by Eurostat's dissemination API.

Datasets
--------
nasa_10_f_bs
    Financial balance sheets (stocks) by sector and instrument.
    Dimensions: freq, unit, co_nco, sector, finpos, na_item, geo, time.
    na_item: ESA 2010 financial instruments F..F8 including the F6
    insurance/pension subitems F61..F66 needed for the Danish pension-asset
    reallocation, and F51/F52 needed to arbitrate the two competing
    debt/equity definitions found in the repo.
nasa_10_nf_tr
    Non-financial transactions (flows) by sector.
    Dimensions: freq, unit, direct, na_item, sector, geo, time.
    Carries the property-income detail (D41 interest, D42/D421/D422
    dividends, D43-D45) behind the Danish flow variables, plus the items
    the government-finances pilot left open (D3/D31/D39 subsidies, D7x
    current transfers incl. D74_EUI, D9x capital transfers, D5/D61/D62).
    Note: no D51 subitems, so the Danish PAL tax cannot come from here.

Downloads
---------
1. nasa_10_f_bs DK 2020: units MIO_NAC + MIO_EUR and consolidations CO + NCO
   in one file, sectors S11/S12/S13/S14/S15/S14_S15/S2 plus the
   insurance/pension subsectors S128/S129/S128_S129 (to quantify the Danish
   pension-asset reallocation), instrument detail
   -> settles the unit and consolidation questions from raw data.
2. nasa_10_nf_tr DK 2020: CP_MNAC, same sectors, property-income and
   government-gap na_items, both directions (RECV/PAID).
3+4. The same two slices for SE 2020 (public-core pilot country).
5. nasa_10_f_bs EU-27 coverage probe, 2020, MIO_NAC, CO, key instruments.
6. nasa_10_nf_tr EU-27 coverage probe, 2020, CP_MNAC, key transactions.
7. nasa_10_f_bs EU-27 year probe: households F assets, all years.
8. nasa_10_nf_tr EU-27 year probe: government D41 paid, all years.

The Eurostat service can return an HTML error document with HTTP 200. This
downloader validates both the content and the JSON-stat structure before
accepting a response.

Output
------
data/preprocessing/data/financial_accounts_raw/DK/2020/
    nasa_10_f_bs_DK_2020.json
    nasa_10_nf_tr_DK_2020.json
    nasa_10_f_bs_SE_2020.json
    nasa_10_nf_tr_SE_2020.json
    nasa_10_f_bs_eu27_coverage_probe_2020.json
    nasa_10_nf_tr_eu27_coverage_probe_2020.json
    nasa_10_f_bs_eu27_year_probe_F.json
    nasa_10_nf_tr_eu27_year_probe_D41.json
    manifest.json, README.md

Run
---
python data/preprocessing/scripts/download_financial_accounts_dk_2020.py
"""

from __future__ import annotations

import datetime
import hashlib
import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET_BS = "nasa_10_f_bs"
DATASET_TR = "nasa_10_nf_tr"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "financial_accounts_raw" / "DK" / "2020"
YEAR = "2020"
RETRIEVAL_DATE = datetime.date.today().isoformat()

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

# The Danish file's sectors are corp = S11+S12, gov = S13, hh = S14+S15,
# row = S2 (metadata.xlsx sheet `sectors`). S14_S15 is requested as well
# because several member states publish only the combined household sector.
# S128/S129 (insurance corporations / pension funds) quantify the Danish
# pension-asset reallocation from financial corporations to households.
SECTORS = ["S11", "S12", "S128", "S129", "S128_S129",
           "S13", "S14", "S15", "S14_S15", "S2"]
# nasa_10_nf_tr publishes the insurance/pension subsector only combined.
TR_SECTORS = ["S11", "S12", "S128_S129", "S13", "S14", "S15", "S14_S15", "S2"]

# Instrument detail: totals and the subitems the pilot needs. F51/F52
# arbitrate the two competing debt/equity definitions in the repo
# (Modules/financial_accounts uses Equity=F5; the reference implementation
# in data/read_eurostat_data uses Equity=F51 with F52 counted as debt).
# F61..F66 carry the pension detail behind the Danish pension-asset
# reallocation (F63_F64_F65 = pension entitlements and related claims).
BS_ITEMS = [
    "F", "F1", "F11", "F2", "F3", "F4", "F5", "F51", "F52",
    "F6", "F61", "F62", "F63", "F64", "F65", "F66", "F63_F64_F65",
    "F7", "F8",
]

# Property-income detail behind the Danish flow variables plus the items the
# government-finances pilot left open (counterpart splits via the S2 column,
# D421/D422/D45 detail, D74_EUI for EU flows; PAL is NOT here - nasa_10_nf_tr
# has no D51 subitems).
TR_ITEMS = [
    "B9",
    "D4", "D41", "D42", "D421", "D422", "D43", "D44", "D45",
    "D3", "D31", "D39",
    "D5", "D51", "D59", "D61", "D62", "D63", "D631", "D632",
    "D7", "D74", "D74_EUI", "D75", "D76",
    "D8", "D9", "D91", "D92", "D99",
]

EXPECTED_DIMS = {
    DATASET_BS: ["freq", "unit", "co_nco", "sector", "finpos", "na_item", "geo", "time"],
    DATASET_TR: ["freq", "unit", "direct", "na_item", "sector", "geo", "time"],
}

QUERIES = [
    {
        "dataset": DATASET_BS,
        "filename": f"{DATASET_BS}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "unit": ["MIO_NAC", "MIO_EUR"],
                   "co_nco": ["CO", "NCO"], "sector": SECTORS,
                   "na_item": BS_ITEMS, "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": ("Denmark 2020 financial balance sheets: both units and both "
                 "consolidations so the Danish file's unit/consolidation basis "
                 "is settled from raw data; instrument detail incl. F6 pension "
                 "subitems and F51/F52."),
    },
    {
        "dataset": DATASET_TR,
        "filename": f"{DATASET_TR}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "unit": "CP_MNAC",
                   "sector": TR_SECTORS, "na_item": TR_ITEMS, "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": ("Denmark 2020 non-financial transactions: property income "
                 "(D41-D45 with D421/D422 detail) for the Danish flow "
                 "variables, plus the government-pilot leftover items."),
    },
    {
        "dataset": DATASET_BS,
        "filename": f"{DATASET_BS}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "unit": ["MIO_NAC", "MIO_EUR"],
                   "co_nco": ["CO", "NCO"], "sector": SECTORS,
                   "na_item": BS_ITEMS, "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Sweden 2020 balance sheets, same slice (public-core pilot country).",
    },
    {
        "dataset": DATASET_TR,
        "filename": f"{DATASET_TR}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "unit": "CP_MNAC",
                   "sector": TR_SECTORS, "na_item": TR_ITEMS, "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Sweden 2020 transactions, same slice (public-core pilot country).",
    },
    {
        "dataset": DATASET_BS,
        "filename": f"{DATASET_BS}_eu27_coverage_probe_{YEAR}.json",
        "params": {"geo": EU27, "time": YEAR, "unit": "MIO_NAC", "co_nco": "CO",
                   "sector": SECTORS, "na_item": BS_ITEMS, "lang": "en"},
        "geos": EU27,
        "times": [YEAR],
        "note": ("EU-27 coverage probe 2020: balance sheets, MIO_NAC, "
                 "consolidated, pilot sectors and instruments."),
    },
    {
        "dataset": DATASET_TR,
        "filename": f"{DATASET_TR}_eu27_coverage_probe_{YEAR}.json",
        "params": {"geo": EU27, "time": YEAR, "unit": "CP_MNAC",
                   "sector": TR_SECTORS, "na_item": TR_ITEMS, "lang": "en"},
        "geos": EU27,
        "times": [YEAR],
        "note": ("EU-27 coverage probe 2020: transactions, CP_MNAC, pilot "
                 "sectors and na_items."),
    },
    {
        "dataset": DATASET_BS,
        "filename": f"{DATASET_BS}_eu27_year_probe_F.json",
        "params": {"geo": EU27, "unit": "MIO_NAC", "co_nco": "CO",
                   "sector": "S14_S15", "finpos": "ASS", "na_item": "F",
                   "lang": "en"},
        "geos": EU27,
        "times": None,  # all years as delivered
        "note": ("EU-27 year-coverage probe: household-sector total financial "
                 "assets, all years."),
    },
    {
        "dataset": DATASET_TR,
        "filename": f"{DATASET_TR}_eu27_year_probe_D41.json",
        "params": {"geo": EU27, "unit": "CP_MNAC", "sector": "S13",
                   "na_item": "D41", "direct": "PAID", "lang": "en"},
        "geos": EU27,
        "times": None,  # all years as delivered
        "note": "EU-27 year-coverage probe: government interest paid, all years.",
    },
]


def validate_jsonstat(
    content: bytes,
    expected_geos: list[str],
    expected_times: list[str] | None,
    expected_dims: list[str],
) -> dict:
    """Return parsed JSON-stat or raise a descriptive validation error."""
    stripped = content.lstrip()
    if not stripped.startswith(b"{"):
        preview = stripped[:120].decode("utf-8", errors="replace")
        raise ValueError(f"response is not JSON (starts {preview!r})")
    payload = json.loads(content)
    required = {"id", "size", "dimension", "value"}
    missing = required - payload.keys()
    if missing:
        raise ValueError(f"JSON-stat keys missing: {sorted(missing)}")
    if payload["id"] != expected_dims:
        raise ValueError(
            f"unexpected dimensions {payload['id']!r}; expected {expected_dims!r}"
        )
    geos = set(payload["dimension"]["geo"]["category"]["index"])
    if geos != set(expected_geos):
        raise ValueError(
            f"geo mismatch: got {sorted(geos)}, expected {sorted(expected_geos)}"
        )
    if expected_times is not None:
        times = payload["dimension"]["time"]["category"]["index"]
        if list(times) != expected_times:
            raise ValueError(
                f"response is not restricted to time={expected_times}: {list(times)}"
            )
    if not payload["value"]:
        raise ValueError("response has no observations")
    return payload


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    manifest_entries = []

    for query in QUERIES:
        dataset = query["dataset"]
        path = OUT / query["filename"]
        url = f"{BASE}/{dataset}"
        fetched = False
        if path.exists():
            try:
                validate_jsonstat(path.read_bytes(), query["geos"], query["times"],
                                  EXPECTED_DIMS[dataset])
                print(f"skip (already downloaded and valid): {path}")
            except (ValueError, json.JSONDecodeError):
                print(f"existing file is invalid; replacing: {path}")
                fetched = True
        else:
            fetched = True

        if fetched:
            for attempt in range(1, 4):
                print(f"GET {url} {query['params']} (attempt {attempt})")
                response = session.get(url, params=query["params"], timeout=300)
                try:
                    if response.status_code != 200:
                        raise ValueError(f"HTTP {response.status_code}")
                    validate_jsonstat(response.content, query["geos"], query["times"],
                                      EXPECTED_DIMS[dataset])
                except (ValueError, json.JSONDecodeError) as exc:
                    print(f"  invalid response ({len(response.content):,} bytes): {exc}")
                    if attempt < 3:
                        time.sleep(20 * attempt)
                        continue
                    raise RuntimeError(
                        f"failed to download valid {query['filename']} after 3 attempts"
                    ) from exc
                path.write_bytes(response.content)
                print(f"  -> {path} ({len(response.content):,} bytes)")
                break

        content = path.read_bytes()
        manifest_entries.append(
            {
                "file": query["filename"],
                "dataset": dataset,
                "url": url,
                "params": query["params"],
                "note": query["note"],
                "bytes": len(content),
                "sha256": hashlib.sha256(content).hexdigest(),
                "retrieval_date": RETRIEVAL_DATE,
                "n_observations": len(json.loads(content)["value"]),
            }
        )

    manifest = {
        "datasets": [DATASET_BS, DATASET_TR],
        "source": "Eurostat dissemination API (statistics/1.0, JSON-stat 2.0)",
        "base_url": BASE,
        "retrieval_date": RETRIEVAL_DATE,
        "purpose": (
            "Pilot reconciliation of nasa_10_f_bs (plus nasa_10_nf_tr flow "
            "detail) against the Danish GREU input "
            "institutional_financial_accounts.xlsx (DK 2020), with SE-2020 "
            "and EU-27 coverage/year probes. Also probes the "
            "government-finances pilot's leftover gaps. See "
            "docs/eu_data_mapping.md."
        ),
        "files": manifest_entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"manifest -> {OUT / 'manifest.json'}")

    readme = f"""# Eurostat `nasa_10_f_bs` / `nasa_10_nf_tr` raw downloads — financial accounts pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: {RETRIEVAL_DATE}. Downloaded by
`data/preprocessing/scripts/download_financial_accounts_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **nasa_10_f_bs** — Financial balance sheets by sector (stocks).
Source page:
https://ec.europa.eu/eurostat/databrowser/view/nasa_10_f_bs/default/table

Dimensions: freq (A), unit, co_nco, sector, finpos, na_item, geo, time. The
DK/SE files carry both `MIO_NAC` and `MIO_EUR` and both consolidations
(`CO`/`NCO`) so the Danish input's basis can be established from data; the
probes use `MIO_NAC` + `CO` (the live module's convention; the Danish input
is bn DKK, so values divide by 1000).

Second dataset: **nasa_10_nf_tr** — Non-financial transactions by sector
(flows), `CP_MNAC`, directions RECV/PAID. Carries the property-income detail
(D41, D42 incl. D421/D422, D43, D44, D45) behind the Danish flow variables
and the items the government-finances pilot left open (D3/D31/D39, D7x incl.
D74_EUI, D9x, D5/D61/D62/D63). It has **no D51 subitems**, so the Danish PAL
(pension-yield tax) series cannot come from this dataset.
Source page:
https://ec.europa.eu/eurostat/databrowser/view/nasa_10_nf_tr/default/table

## Files

| file | content |
|---|---|
| `nasa_10_f_bs_DK_2020.json` | Denmark 2020, MIO_NAC+MIO_EUR, CO+NCO, pilot sectors, instrument detail incl. F6 subitems |
| `nasa_10_nf_tr_DK_2020.json` | Denmark 2020, CP_MNAC, RECV+PAID, property income + government-gap items |
| `nasa_10_f_bs_SE_2020.json` | Sweden 2020, same balance-sheet slice (public-core pilot country) |
| `nasa_10_nf_tr_SE_2020.json` | Sweden 2020, same transactions slice |
| `nasa_10_f_bs_eu27_coverage_probe_2020.json` | all 27 member states, 2020, MIO_NAC, CO, pilot sectors/instruments |
| `nasa_10_nf_tr_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CP_MNAC, pilot sectors/na_items |
| `nasa_10_f_bs_eu27_year_probe_F.json` | all 27 member states, all years, household total financial assets |
| `nasa_10_nf_tr_eu27_year_probe_D41.json` | all 27 member states, all years, government interest paid |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_financial_accounts_dk_2020.py`,
which writes `data/preprocessing/data/financial_accounts_dk2020_reconciliation.xlsx`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(f"README -> {OUT / 'README.md'}")


if __name__ == "__main__":
    main()
