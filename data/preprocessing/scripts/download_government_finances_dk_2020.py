"""Download Eurostat government-finance statistics (gov_10a_main, plus
gov_10a_taxag for tax detail) for the government_finances.xlsx pilot.

Eighth pilot in Phase 1 of the GREU EU-generic data work (see
docs/eu_data_mapping.md). Raw JSON-stat responses are saved exactly as
delivered by Eurostat's dissemination API.

Datasets
--------
gov_10a_main
    Government revenue, expenditure and main aggregates.
    Dimensions: freq, unit, sector, na_item, geo, time.
    na_item: ESA 2010 transactions with REC/PAY suffixes (D41PAY, D3PAY,
    D62_D632PAY, ...), production/consumption aggregates (P2, P3, P51G,
    P5, P51C, ...) and the TE/TR/B9 totals.
gov_10a_taxag
    Main national accounts tax aggregates. Same dimension set. Carries the
    tax detail the Danish file uses on the revenue side (D211 VAT, D214
    other product taxes, D51 income-tax subitems, D59, D91, D2122 import
    duties) including sector S212 (EU institutions) for the Danish
    `rev_eu` / `exp_eu` rows.

Downloads
---------
1. gov_10a_main DK 2020, sector S13, MIO_NAC, all na_items -> main pilot file.
2. gov_10a_taxag DK 2020, sectors S13 + S212, MIO_NAC, all na_items
   -> revenue-side tax detail.
3. gov_10a_main SE 2020, S13, MIO_NAC -> Sweden is the public-core pilot
   country.
4. gov_10a_main EU-27 coverage probe, 2020, MIO_NAC, S13, the na_items the
   pilot mapping needs -> EU-wide coverage.
5. gov_10a_main EU-27 year probe, TE only, MIO_NAC, S13, all years -> time
   coverage.

The Eurostat service can return an HTML error document with HTTP 200. This
downloader validates both the content and the JSON-stat structure before
accepting a response.

Output
------
data/preprocessing/data/government_finances_raw/DK/2020/
    gov_10a_main_DK_2020.json
    gov_10a_taxag_DK_2020.json
    gov_10a_main_SE_2020.json
    gov_10a_main_eu27_coverage_probe_2020.json
    gov_10a_main_eu27_year_probe_TE.json
    manifest.json, README.md

Run
---
python data/preprocessing/scripts/download_government_finances_dk_2020.py
"""

from __future__ import annotations

import datetime
import hashlib
import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET = "gov_10a_main"
DATASET_TAX = "gov_10a_taxag"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "government_finances_raw" / "DK" / "2020"
YEAR = "2020"
RETRIEVAL_DATE = datetime.date.today().isoformat()

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

# na_items the concordance to the Danish file needs (coverage probe slice).
KEY_ITEMS = [
    "TE", "TR", "B9",
    "P3", "P2", "P51G", "P5", "P51C", "P52_P53", "P11_P12_P131",
    "P11", "P131", "P12", "NP",
    "D1PAY", "D3PAY", "D39PAY", "D41PAY", "D4PAY", "D29PAY", "D29REC",
    "D62PAY", "D632PAY", "D62_D632PAY", "D7PAY", "D8", "D9PAY", "D92PAY", "D99PAY",
    "D2REC", "D21REC", "D4REC", "D41REC", "D42REC", "D42_TO_D45REC", "D45REC",
    "D39REC", "D5REC", "D51REC", "D51A_C1REC", "D51B_C2REC", "D59REC",
    "D61REC", "D7REC", "D91REC", "D92_D99REC", "D99REC",
    # counterpart (_S2/_S212) items used for the Danish dom/RoW splits
    "D9PAY_S2", "D9REC_S2", "D7REC_S212", "D74PAY", "D76PAY", "D3REC_S212",
]

# taxag na_items carrying the Danish revenue-side tax detail.
KEY_TAX_ITEMS = [
    "D2", "D21", "D211", "D212", "D214", "D29",
    "D5", "D51", "D51A_C1", "D51B_C2", "D51D", "D59", "D61", "D91",
]

EXPECTED_DIMS = ["freq", "unit", "sector", "na_item", "geo", "time"]

QUERIES = [
    {
        "filename": f"{DATASET}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "sector": "S13",
                   "unit": "MIO_NAC", "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": "Denmark 2020, general government (S13), MIO_NAC, all na_items as delivered.",
    },
    {
        "dataset": DATASET_TAX,
        "filename": f"{DATASET_TAX}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "sector": ["S13", "S212"],
                   "unit": "MIO_NAC", "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": ("Denmark 2020 tax aggregates, S13 + S212 (EU institutions), "
                 "MIO_NAC, all na_items — detail for the Danish revenue rows."),
    },
    {
        "filename": f"{DATASET}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "sector": "S13",
                   "unit": "MIO_NAC", "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Sweden 2020 availability probe (public-core pilot country).",
    },
    {
        "filename": f"{DATASET}_eu27_coverage_probe_{YEAR}.json",
        "params": {"geo": EU27, "time": YEAR, "sector": "S13",
                   "unit": "MIO_NAC", "na_item": KEY_ITEMS, "lang": "en"},
        "geos": EU27,
        "times": [YEAR],
        "note": "EU-27 coverage probe 2020: S13, MIO_NAC, the na_items used by the pilot mapping.",
    },
    {
        "dataset": DATASET_TAX,
        "filename": f"{DATASET_TAX}_eu27_coverage_probe_{YEAR}.json",
        "params": {"geo": EU27, "time": YEAR, "sector": ["S13", "S212"],
                   "unit": "MIO_NAC", "na_item": KEY_TAX_ITEMS, "lang": "en"},
        "geos": EU27,
        "times": [YEAR],
        "note": ("EU-27 coverage probe 2020 for the tax detail: gov_10a_taxag, "
                 "S13 + S212, MIO_NAC, the na_items used by the pilot mapping."),
    },
    {
        "filename": f"{DATASET}_eu27_year_probe_TE.json",
        "params": {"geo": EU27, "sector": "S13", "unit": "MIO_NAC",
                   "na_item": "TE", "lang": "en"},
        "geos": EU27,
        "times": None,  # all years as delivered
        "note": "EU-27 year-coverage probe: total expenditure TE, all years.",
    },
]


def validate_jsonstat(
    content: bytes,
    expected_geos: list[str],
    expected_times: list[str] | None,
    expected_dims: list[str] = EXPECTED_DIMS,
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
        dataset = query.get("dataset", DATASET)
        path = OUT / query["filename"]
        url = f"{BASE}/{dataset}"
        fetched = False
        if path.exists():
            try:
                validate_jsonstat(path.read_bytes(), query["geos"], query["times"])
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
                    validate_jsonstat(response.content, query["geos"], query["times"])
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
        "datasets": [DATASET, DATASET_TAX],
        "source": "Eurostat dissemination API (statistics/1.0, JSON-stat 2.0)",
        "base_url": BASE,
        "retrieval_date": RETRIEVAL_DATE,
        "purpose": (
            "Pilot reconciliation of gov_10a_main (plus gov_10a_taxag tax "
            "detail) against the Danish GREU input government_finances.xlsx "
            "(DK 2020), with SE-2020 and EU-27 coverage/year probes. See "
            "docs/eu_data_mapping.md."
        ),
        "files": manifest_entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"manifest -> {OUT / 'manifest.json'}")

    readme = f"""# Eurostat `gov_10a_main` raw downloads — government finances pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: {RETRIEVAL_DATE}. Downloaded by
`data/preprocessing/scripts/download_government_finances_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **gov_10a_main** — Government revenue, expenditure and main
aggregates. Source page:
https://ec.europa.eu/eurostat/databrowser/view/gov_10a_main/default/table

Dimensions: freq (A), unit, sector, na_item, geo, time. All files use
`unit=MIO_NAC` (million national currency; the Danish input is bn DKK, so
values divide by 1000) and `sector=S13` (general government).

Second dataset: **gov_10a_taxag** — Main national accounts tax aggregates,
same dimensions. Carries the tax detail on the Danish revenue side (D211 VAT,
D214, D51 income-tax subitems, D59, D91, D2122 import duties) including
sector S212 (institutions of the EU) for the Danish `rev_eu`/`exp_eu` rows.
Source page:
https://ec.europa.eu/eurostat/databrowser/view/gov_10a_taxag/default/table

## Files

| file | content |
|---|---|
| `gov_10a_main_DK_2020.json` | Denmark 2020, S13, MIO_NAC, all na_items |
| `gov_10a_taxag_DK_2020.json` | Denmark 2020 tax aggregates, S13 + S212, MIO_NAC, all na_items |
| `gov_10a_main_SE_2020.json` | Sweden 2020, same slice (public-core pilot country) |
| `gov_10a_main_eu27_coverage_probe_2020.json` | all 27 member states, 2020, S13, MIO_NAC, pilot na_items |
| `gov_10a_taxag_eu27_coverage_probe_2020.json` | all 27 member states, 2020, S13 + S212, MIO_NAC, tax-detail na_items |
| `gov_10a_main_eu27_year_probe_TE.json` | all 27 member states, all years, TE |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_government_finances_dk_2020.py`,
which writes `data/preprocessing/data/government_finances_dk2020_reconciliation.xlsx`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(f"README -> {OUT / 'README.md'}")


if __name__ == "__main__":
    main()
