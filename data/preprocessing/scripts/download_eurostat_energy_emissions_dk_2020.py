"""Download Eurostat PEFA and air-emissions accounts for Denmark, 2020.

Second pilot in Phase 1 of the GREU EU-generic data work. Raw JSON-stat
responses are saved exactly as delivered by Eurostat's dissemination API.

Datasets
--------
env_ac_pefasu
    Physical energy supply and use, TJ, by PEFA flow table, NACE Rev. 2
    activity, and energy product.
env_ac_ainah_r2
    Air-emissions accounts by NACE Rev. 2 activity and pollutant.

Retrieval date recorded for this pilot: 2026-07-30.

The Eurostat service can return an HTML error document with HTTP 200. This
downloader validates both the content type and required JSON-stat structure
before accepting a response.

Output
------
data/preprocessing/data/eurostat_energy_emissions_raw/

Run
---
python data/preprocessing/scripts/download_eurostat_energy_emissions_dk_2020.py
"""

from __future__ import annotations

import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "eurostat_energy_emissions_raw"
YEAR = "2020"
GEO = "DK"
RETRIEVAL_DATE = "2026-07-30"

QUERIES = [
    ("env_ac_pefasu", "env_ac_pefasu_DK_2020.json"),
    ("env_ac_ainah_r2", "env_ac_ainah_r2_DK_2020.json"),
]

EXPECTED_DIMS = {
    "env_ac_pefasu": ["freq", "stk_flow", "nace_r2", "prod_nrg", "unit", "geo", "time"],
    "env_ac_ainah_r2": ["freq", "airpol", "nace_r2", "unit", "geo", "time"],
}


def validate_jsonstat(content: bytes, dataset: str) -> dict:
    """Return parsed JSON-stat or raise a descriptive validation error."""
    stripped = content.lstrip()
    if not stripped.startswith(b"{"):
        preview = stripped[:120].decode("utf-8", errors="replace")
        raise ValueError(f"{dataset}: response is not JSON (starts {preview!r})")
    payload = json.loads(content)
    required = {"id", "size", "dimension", "value"}
    missing = required - payload.keys()
    if missing:
        raise ValueError(f"{dataset}: JSON-stat keys missing: {sorted(missing)}")
    if payload["id"] != EXPECTED_DIMS[dataset]:
        raise ValueError(
            f"{dataset}: unexpected dimensions {payload['id']!r}; "
            f"expected {EXPECTED_DIMS[dataset]!r}"
        )
    if payload.get("dimension", {}).get("geo", {}).get("category", {}).get("index") != {GEO: 0}:
        raise ValueError(f"{dataset}: response is not restricted to geo={GEO}")
    if payload.get("dimension", {}).get("time", {}).get("category", {}).get("index") != {YEAR: 0}:
        raise ValueError(f"{dataset}: response is not restricted to time={YEAR}")
    if not payload["value"]:
        raise ValueError(f"{dataset}: response has no observations")
    return payload


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    params = {"geo": GEO, "time": YEAR, "lang": "en"}

    for dataset, filename in QUERIES:
        path = OUT / filename
        if path.exists():
            try:
                validate_jsonstat(path.read_bytes(), dataset)
                print(f"skip (already downloaded and valid): {path}")
                continue
            except (ValueError, json.JSONDecodeError):
                print(f"existing file is invalid; replacing: {path}")

        url = f"{BASE}/{dataset}"
        for attempt in range(1, 4):
            print(f"GET {url} {params} (attempt {attempt})")
            response = session.get(url, params=params, timeout=300)
            try:
                if response.status_code != 200:
                    raise ValueError(f"HTTP {response.status_code}")
                validate_jsonstat(response.content, dataset)
            except (ValueError, json.JSONDecodeError) as exc:
                print(f"  invalid response ({len(response.content):,} bytes): {exc}")
                if attempt < 3:
                    time.sleep(20 * attempt)
                    continue
                raise RuntimeError(f"failed to download valid {dataset} after 3 attempts") from exc

            path.write_bytes(response.content)
            print(f"  -> {path} ({len(response.content):,} bytes)")
            break


if __name__ == "__main__":
    main()
