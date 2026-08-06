"""Download official public sources for the GREU monetary-energy feasibility audit.

The script preserves Denmark-2020 Eurostat source responses exactly as delivered,
downloads official Commission petroleum-price and tax documents, and probes
EU-27 availability without retaining unneeded country values.

Run
---
python data/preprocessing/scripts/download_energy_money_sources_dk_2020.py
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests


DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
OUT = DATA / "eurostat_energy_money_raw"
BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
RETRIEVAL_DATE = "2026-07-30"
GEO = "DK"
YEAR = "2020"

EU27 = [
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE",
    "EL", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT",
    "RO", "SK", "SI", "ES", "SE",
]

EUROSTAT_DATASETS = {
    "env_ac_taxind2": ["freq", "tax", "unit", "nace_r2", "geo", "time"],
    "nrg_pc_202_c": ["freq", "nrg_prc", "nrg_cons", "currency", "unit", "geo", "time"],
    "nrg_pc_203_c": ["freq", "nrg_prc", "nrg_cons", "currency", "unit", "geo", "time"],
    "nrg_pc_204_c": ["freq", "nrg_cons", "nrg_prc", "currency", "geo", "time"],
    "nrg_pc_205_c": ["freq", "nrg_prc", "nrg_cons", "currency", "geo", "time"],
    "naio_10_cp15": ["freq", "unit", "stk_flow", "ind_impv", "prd_amo", "geo", "time"],
    "naio_10_cp16": ["freq", "unit", "stk_flow", "ind_use", "prd_ava", "geo", "time"],
}

DOCUMENTS = {
    "Weekly_Oil_Bulletin_Prices_History_2026-07-30.xlsx": (
        "https://energy.ec.europa.eu/document/download/"
        "906e60ca-8b6a-44e7-8589-652854d2fd3f_en"
        "?filename=Weekly_Oil_Bulletin_Prices_History_maticni_4web.xlsx"
    ),
    "excise_duties_energy_products_rates_2021-07-01.pdf": (
        "https://taxation-customs.ec.europa.eu/system/files/2021-09/"
        "excise_duties-part_ii_energy_products_en.pdf"
    ),
    "vat_rates_2020-01-01.pdf": (
        "https://taxation-customs.ec.europa.eu/document/download/"
        "82a38bdb-d724-472d-8e02-325b271e0d88_en"
        "?filename=vat_rates_en.pdf"
    ),
}


def request_with_retries(
    session: requests.Session, url: str, params: dict | None = None, timeout: int = 600
) -> requests.Response:
    """GET a URL, retrying transient Eurostat/Commission errors."""
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            response = session.get(url, params=params, timeout=timeout)
            if response.status_code != 200:
                raise ValueError(f"HTTP {response.status_code}")
            if not response.content:
                raise ValueError("empty response")
            return response
        except (requests.RequestException, ValueError) as exc:
            last_error = exc
            if attempt < 3:
                time.sleep(10 * attempt)
    raise RuntimeError(f"failed GET {url}: {last_error}")


def validate_jsonstat(content: bytes, dataset: str, geo: str = GEO) -> dict:
    """Validate a filtered Eurostat JSON-stat response."""
    if not content.lstrip().startswith(b"{"):
        raise ValueError(f"{dataset}: response is not JSON")
    payload = json.loads(content)
    required = {"id", "size", "dimension", "value"}
    if required - payload.keys():
        raise ValueError(f"{dataset}: missing JSON-stat keys {sorted(required - payload.keys())}")
    if payload["id"] != EUROSTAT_DATASETS[dataset]:
        raise ValueError(f"{dataset}: unexpected dimensions {payload['id']}")
    geo_index = payload["dimension"]["geo"]["category"]["index"]
    if geo_index != {geo: 0}:
        raise ValueError(f"{dataset}: unexpected geo index {geo_index}")
    time_index = payload["dimension"]["time"]["category"]["index"]
    if time_index != {YEAR: 0}:
        raise ValueError(f"{dataset}: unexpected time index {time_index}")
    return payload


def sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    manifest: list[dict] = []

    for dataset in EUROSTAT_DATASETS:
        filename = f"{dataset}_{GEO}_{YEAR}.json"
        path = OUT / filename
        url = f"{BASE}/{dataset}"
        params = {"geo": GEO, "time": YEAR, "lang": "en"}
        if path.exists():
            try:
                payload = validate_jsonstat(path.read_bytes(), dataset)
                content = path.read_bytes()
                print(f"skip valid {path}")
            except (ValueError, json.JSONDecodeError):
                path.unlink()
                payload = None
                content = b""
        else:
            payload = None
            content = b""
        if payload is None:
            response = request_with_retries(session, url, params=params)
            content = response.content
            payload = validate_jsonstat(content, dataset)
            path.write_bytes(content)
            print(f"saved {path} ({len(content):,} bytes)")
        manifest.append(
            {
                "source": dataset,
                "url": requests.Request("GET", url, params=params).prepare().url,
                "file": filename,
                "bytes": len(content),
                "sha256": sha256(content),
                "observations": len(payload["value"]),
                "dimensions": payload["id"],
                "retrieval_date": RETRIEVAL_DATE,
            }
        )

    for filename, url in DOCUMENTS.items():
        path = OUT / filename
        if path.exists() and path.stat().st_size > 1000:
            content = path.read_bytes()
            print(f"skip existing {path}")
        else:
            response = request_with_retries(session, url)
            content = response.content
            if filename.endswith(".pdf") and not content.startswith(b"%PDF"):
                raise ValueError(f"{filename}: response is not PDF")
            if filename.endswith(".xlsx") and not content.startswith(b"PK"):
                raise ValueError(f"{filename}: response is not XLSX")
            path.write_bytes(content)
            print(f"saved {path} ({len(content):,} bytes)")
        manifest.append(
            {
                "source": filename,
                "url": url,
                "file": filename,
                "bytes": len(content),
                "sha256": sha256(content),
                "observations": None,
                "dimensions": None,
                "retrieval_date": RETRIEVAL_DATE,
            }
        )

    # Probe anonymous access and actual 2020 observations for all EU-27. These
    # small diagnostics are not used as values in the construction.
    def probe(dataset: str, geo: str, year: str = YEAR) -> dict:
        url = f"{BASE}/{dataset}"
        params = {"geo": geo, "time": year, "lang": "en"}
        anonymous_http_access = False
        try:
            with requests.Session() as probe_session:
                response = request_with_retries(
                    probe_session, url, params=params, timeout=300
                )
            anonymous_http_access = True
            payload = json.loads(response.content)
            if payload.get("id") != EUROSTAT_DATASETS[dataset]:
                raise ValueError(f"unexpected dimensions {payload.get('id')}")
            observations = len(payload.get("value", {}))
            available = observations > 0
            error = "" if available else "HTTP 200 JSON-stat response; no 2020 observations"
        except Exception as exc:  # preserve a per-country audit trail
            observations = 0
            available = False
            error = str(exc)
        return {
            "dataset": dataset,
            "geo": geo,
            "year": year,
            "anonymous_http_access": anonymous_http_access,
            "observations": observations,
            "available": available,
            "error": error,
            "url": requests.Request("GET", url, params=params).prepare().url,
            "retrieval_date": RETRIEVAL_DATE,
        }

    probes: list[dict] = []
    jobs = [(dataset, geo) for dataset in EUROSTAT_DATASETS for geo in EU27]
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(probe, *job): job for job in jobs}
        for future in as_completed(futures):
            result = future.result()
            probes.append(result)
            print(
                result["dataset"],
                result["geo"],
                result["observations"],
                "OK" if result["available"] else "MISSING",
            )
    probes.sort(key=lambda row: (row["dataset"], EU27.index(row["geo"])))

    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    (OUT / "eu27_coverage_probe_2020.json").write_text(
        json.dumps(probes, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    # Test whether a nearby year closes each 2020 gap. This distinguishes a
    # one-year vintage gap from a structural absence in the live dissemination
    # series. Values remain unused.
    missing_pairs = [(row["dataset"], row["geo"]) for row in probes if not row["available"]]
    nearest_jobs = [
        (dataset, geo, str(year))
        for dataset, geo in missing_pairs
        for year in range(2015, 2025)
    ]
    nearest: list[dict] = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(probe, *job): job for job in nearest_jobs}
        for future in as_completed(futures):
            result = future.result()
            nearest.append(result)
            print(
                "nearest",
                result["dataset"],
                result["geo"],
                result["year"],
                result["observations"],
            )
    nearest.sort(key=lambda row: (row["dataset"], row["geo"], row["year"]))
    (OUT / "nearest_year_probe_2015_2024.json").write_text(
        json.dumps(nearest, indent=2, ensure_ascii=False), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
