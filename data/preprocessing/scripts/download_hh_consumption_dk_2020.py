"""Download Eurostat household consumption by COICOP purpose for the
io_long_format cons_hh / cons_hh_foreign (12 GREU c-groups) pilot.

Twelfth pilot in Phase 1 of the GREU EU-generic data work (see
docs/eu_data_mapping.md). Raw JSON-stat responses are saved exactly as
delivered by Eurostat's dissemination API.

Dataset
-------
nama_10_co3_p3
    Final consumption expenditure of households by consumption purpose
    (COICOP 1999). Dimensions: freq, unit, coicop, geo, time.
    There is no na_item dimension — the table is already household FCE
    (conceptually P31_S14). National TOTAL is the code TOTAL, not CP00.

Downloads
---------
1. DK 2020, all coicop / unit as delivered (digit depth and units from
   the payload).
2. SE 2020, same slice (public-core pilot country).
3. EU-27 coverage probe 2020, unit=CP_MNAC, all coicop.
4. EU-27 year probe: coicop=TOTAL, unit=CP_MNAC, all years.

The Eurostat service can return an HTML error document with HTTP 200.
This downloader validates both the content and the JSON-stat structure
before accepting a response.

Output
------
data/preprocessing/data/hh_consumption_raw/DK/2020/

Run
---
python data/preprocessing/scripts/download_hh_consumption_dk_2020.py
"""

from __future__ import annotations

import datetime
import hashlib
import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET = "nama_10_co3_p3"
OUT = (
    pathlib.Path(__file__).resolve().parents[1]
    / "data"
    / "hh_consumption_raw"
    / "DK"
    / "2020"
)
YEAR = "2020"
RETRIEVAL_DATE = datetime.date.today().isoformat()

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

EXPECTED_DIMS = ["freq", "unit", "coicop", "geo", "time"]

QUERIES = [
    {
        "filename": f"{DATASET}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": (
            "Denmark 2020 household FCE by COICOP purpose: all coicop / "
            "units as delivered. Digit depth (2- vs 3-digit) is read from "
            "the payload. No na_item filter — the dataset has none."
        ),
    },
    {
        "filename": f"{DATASET}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": (
            "Sweden 2020 household FCE by COICOP purpose, same slice as DK."
        ),
    },
    {
        "filename": f"{DATASET}_eu27_coverage_probe_{YEAR}.json",
        "params": {
            "geo": EU27,
            "time": YEAR,
            "unit": "CP_MNAC",
            "lang": "en",
        },
        "geos": EU27,
        "times": [YEAR],
        "note": (
            "EU-27 coverage probe 2020: current prices, millions of national "
            "currency, all published COICOP codes. Used to see who publishes "
            "3-digit vs 2-digit only."
        ),
    },
    {
        "filename": f"{DATASET}_eu27_year_probe_TOTAL.json",
        "params": {
            "geo": EU27,
            "unit": "CP_MNAC",
            "coicop": "TOTAL",
            "lang": "en",
        },
        "geos": EU27,
        "times": None,
        "note": (
            "EU-27 year probe: TOTAL household FCE, current prices, millions "
            "of national currency, all years as delivered."
        ),
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
        path = OUT / query["filename"]
        url = f"{BASE}/{DATASET}"
        fetched = False
        if path.exists():
            try:
                validate_jsonstat(
                    path.read_bytes(),
                    query["geos"],
                    query["times"],
                    EXPECTED_DIMS,
                )
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
                    validate_jsonstat(
                        response.content,
                        query["geos"],
                        query["times"],
                        EXPECTED_DIMS,
                    )
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
        "datasets": [DATASET],
        "source": "Eurostat dissemination API (statistics/1.0, JSON-stat 2.0)",
        "base_url": BASE,
        "retrieval_date": RETRIEVAL_DATE,
        "purpose": (
            "Pilot reconciliation of nama_10_co3_p3 (household FCE by COICOP "
            "1999 purpose) against the 12 GREU consumption groups in "
            "io_long_format.xlsx (DK 2020 cons_hh / cons_hh_foreign columns), "
            "with SE-2020 and EU-27 coverage/year probes. See "
            "docs/eu_data_mapping.md."
        ),
        "dimension_note": (
            "Live JSON-stat id is [freq, unit, coicop, geo, time]. There is "
            "no na_item dimension (the table is already household FCE). "
            "National total code is TOTAL, not CP00."
        ),
        "files": manifest_entries,
    }
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, default=str), encoding="utf-8"
    )
    print(f"manifest -> {OUT / 'manifest.json'}")

    readme = f"""# Eurostat `nama_10_co3_p3` raw downloads — household consumption pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: {RETRIEVAL_DATE}. Downloaded by
`data/preprocessing/scripts/download_hh_consumption_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **nama_10_co3_p3** — Final consumption expenditure of households by
consumption purpose (COICOP 1999). Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_co3_p3/default/table

Dimensions: freq (A), unit, coicop, geo, time. There is **no na_item**
dimension — the table is already household FCE (P31_S14 conceptually).
The national total code is `TOTAL`, not `CP00`.

The reconciliation uses `CP_MNAC` (current prices, millions of national
currency), divided by 1,000 to match GREU bn DKK.

## Files

| file | content |
|---|---|
| `nama_10_co3_p3_DK_2020.json` | Denmark 2020, all coicop / units |
| `nama_10_co3_p3_SE_2020.json` | Sweden 2020, same slice |
| `nama_10_co3_p3_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CP_MNAC, all coicop |
| `nama_10_co3_p3_eu27_year_probe_TOTAL.json` | all 27 member states, all years, TOTAL, CP_MNAC |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_hh_consumption_dk_2020.py`,
which writes `data/preprocessing/data/hh_consumption_dk2020_reconciliation.xlsx`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(f"README -> {OUT / 'README.md'}")


if __name__ == "__main__":
    main()
