"""Download Eurostat national-accounts employment (nama_10_a64_e) for the
employed.xlsx pilot.

Sixth pilot in Phase 1 of the GREU EU-generic data work (see
docs/eu_data_mapping.md). Raw JSON-stat responses are saved exactly as
delivered by Eurostat's dissemination API.

Dataset
-------
nama_10_a64_e
    National accounts employment data by industry (up to NACE A*64).
    Dimensions: freq, unit, nace_r2, na_item, geo, time.
    na_item: EMP_DC (total employment, domestic concept),
             SAL_DC (employees), SELF_DC (self-employed).
    unit:    THS_PER (thousand persons), THS_HW (thousand hours worked),
             THS_JOB (thousand jobs), plus percentage-change units.

Downloads
---------
1. DK 2020, all units / na_item / nace_r2 as delivered  -> main pilot file.
2. SE 2020, same slice -> Sweden is the public-core pilot country.
3. EU-27 coverage probe, 2020, units THS_PER + THS_HW, all na_item,
   all nace_r2, all 27 member states -> used to judge EU-wide coverage.

The Eurostat service can return an HTML error document with HTTP 200. This
downloader validates both the content and the JSON-stat structure before
accepting a response.

Output
------
data/preprocessing/data/employment_raw/DK/2020/
    nama_10_a64_e_DK_2020.json
    nama_10_a64_e_SE_2020.json
    nama_10_a64_e_eu27_coverage_probe_2020.json
    manifest.json, README.md

Run
---
python data/preprocessing/scripts/download_employment_dk_2020.py
"""

from __future__ import annotations

import datetime
import hashlib
import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET = "nama_10_a64_e"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "employment_raw" / "DK" / "2020"
YEAR = "2020"
RETRIEVAL_DATE = datetime.date.today().isoformat()

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

EXPECTED_DIMS = ["freq", "unit", "nace_r2", "na_item", "geo", "time"]

QUERIES = [
    {
        "filename": f"{DATASET}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "lang": "en"},
        "geos": ["DK"],
        "note": "Denmark 2020, all units/na_item/nace_r2 as delivered.",
    },
    {
        "filename": f"{DATASET}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "lang": "en"},
        "geos": ["SE"],
        "note": "Sweden 2020 availability probe (public-core pilot country).",
    },
    {
        "filename": f"{DATASET}_eu27_coverage_probe_{YEAR}.json",
        "params": {
            "geo": EU27,
            "time": YEAR,
            "unit": ["THS_PER", "THS_HW"],
            "lang": "en",
        },
        "geos": EU27,
        "note": "EU-27 coverage probe 2020: THS_PER + THS_HW, all na_item, all nace_r2.",
    },
]


def validate_jsonstat(content: bytes, expected_geos: list[str]) -> dict:
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
    if payload["id"] != EXPECTED_DIMS:
        raise ValueError(
            f"unexpected dimensions {payload['id']!r}; expected {EXPECTED_DIMS!r}"
        )
    geos = set(payload["dimension"]["geo"]["category"]["index"])
    if geos != set(expected_geos):
        raise ValueError(
            f"geo mismatch: got {sorted(geos)}, expected {sorted(expected_geos)}"
        )
    times = payload["dimension"]["time"]["category"]["index"]
    if list(times) != [YEAR]:
        raise ValueError(f"response is not restricted to time={YEAR}: {list(times)}")
    if not payload["value"]:
        raise ValueError("response has no observations")
    return payload


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    manifest_entries = []

    for query in QUERIES:
        path = OUT / query["filename"]
        url = f"{BASE}/{DATASET}"
        fetched = False
        if path.exists():
            try:
                validate_jsonstat(path.read_bytes(), query["geos"])
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
                    validate_jsonstat(response.content, query["geos"])
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
                "dataset": DATASET,
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
        "dataset": DATASET,
        "source": "Eurostat dissemination API (statistics/1.0, JSON-stat 2.0)",
        "base_url": BASE,
        "retrieval_date": RETRIEVAL_DATE,
        "purpose": (
            "Pilot reconciliation of nama_10_a64_e against the Danish GREU input "
            "employed.xlsx (DK 2020), plus SE-2020 and EU-27 coverage probes. "
            "See docs/eu_data_mapping.md."
        ),
        "files": manifest_entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"manifest -> {OUT / 'manifest.json'}")

    readme = f"""# Eurostat `nama_10_a64_e` raw downloads — employment pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: {RETRIEVAL_DATE}. Downloaded by
`data/preprocessing/scripts/download_employment_dk_2020.py` (re-runnable; it
skips files that already exist and validate).

Dataset: **nama_10_a64_e** — National accounts employment data by industry
(up to NACE A*64). Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_a64_e/default/table

Dimensions: freq (A), unit, nace_r2 (A64 + aggregates), na_item, geo, time.

- `na_item`: `EMP_DC` total employment, `SAL_DC` employees, `SELF_DC`
  self-employed — all domestic concept (matches national-accounts IO wage data).
- `unit`: `THS_PER` thousand persons, `THS_HW` thousand hours worked,
  `THS_JOB` thousand jobs, plus percentage-change units.

## Files

| file | content |
|---|---|
| `nama_10_a64_e_DK_2020.json` | Denmark 2020, all units/na_item/nace_r2 |
| `nama_10_a64_e_SE_2020.json` | Sweden 2020, same slice (public-core pilot country) |
| `nama_10_a64_e_eu27_coverage_probe_2020.json` | all 27 member states, 2020, THS_PER + THS_HW, all na_item/nace_r2 |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_employment_dk_2020.py`, which
writes `data/preprocessing/data/employment_dk2020_reconciliation.xlsx`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(f"README -> {OUT / 'README.md'}")


if __name__ == "__main__":
    main()
