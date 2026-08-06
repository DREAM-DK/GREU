"""Download official public inputs for a country monetary-energy public core.

Raw responses are preserved byte-for-byte. The default invocation downloads the
Sweden 2020 pilot approved for GREU:

    python data/preprocessing/scripts/download_energy_money_public_core.py

The output is data/preprocessing/data/eu_core_raw/<CC>/<YEAR>/.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import time

import requests


DATA = Path(__file__).resolve().parents[1] / "data"
EUROSTAT_JSON = (
    "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
)
EUROSTAT_SDMX = (
    "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data"
)
RETRIEVAL_DATE = "2026-07-30"
EU27 = [
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE",
    "EL", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT",
    "RO", "SK", "SI", "ES", "SE",
]

JSON_DATASETS = {
    "env_ac_pefasu": [
        "freq", "stk_flow", "nace_r2", "prod_nrg", "unit", "geo", "time"
    ],
    "env_ac_ainah_r2": [
        "freq", "airpol", "nace_r2", "unit", "geo", "time"
    ],
    "env_ac_taxind2": ["freq", "tax", "unit", "nace_r2", "geo", "time"],
    "nrg_pc_202_c": [
        "freq", "nrg_prc", "nrg_cons", "currency", "unit", "geo", "time"
    ],
    "nrg_pc_203_c": [
        "freq", "nrg_prc", "nrg_cons", "currency", "unit", "geo", "time"
    ],
    "nrg_pc_204_c": [
        "freq", "nrg_cons", "nrg_prc", "currency", "geo", "time"
    ],
    "nrg_pc_205_c": [
        "freq", "nrg_prc", "nrg_cons", "currency", "geo", "time"
    ],
    "naio_10_cp15": [
        "freq", "unit", "stk_flow", "ind_impv", "prd_amo", "geo", "time"
    ],
    "naio_10_cp16": [
        "freq", "unit", "stk_flow", "ind_use", "prd_ava", "geo", "time"
    ],
}

DOCUMENTS = {
    "Weekly_Oil_Bulletin_Prices_History_2026-07-30.xlsx": (
        "https://energy.ec.europa.eu/document/download/"
        "906e60ca-8b6a-44e7-8589-652854d2fd3f_en"
        "?filename=Weekly_Oil_Bulletin_Prices_History_maticni_4web.xlsx",
        "European Commission legal notice/reuse policy",
    ),
    "excise_duties_energy_products_rates_2021-07-01.pdf": (
        "https://taxation-customs.ec.europa.eu/system/files/2021-09/"
        "excise_duties-part_ii_energy_products_en.pdf",
        "European Commission legal notice/reuse policy",
    ),
    "vat_rates_2020-01-01.pdf": (
        "https://taxation-customs.ec.europa.eu/document/download/"
        "82a38bdb-d724-472d-8e02-325b271e0d88_en"
        "?filename=vat_rates_en.pdf",
        "European Commission legal notice/reuse policy",
    ),
}


def sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def request(
    session: requests.Session,
    url: str,
    *,
    params: dict[str, str] | None = None,
    timeout: int = 900,
) -> requests.Response:
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
    raise RuntimeError(f"GET failed after three attempts: {url}: {last_error}")


def validate_jsonstat(
    content: bytes, dataset: str, geo: str, year: str
) -> dict:
    if not content.lstrip().startswith(b"{"):
        raise ValueError(f"{dataset}: response is not JSON")
    payload = json.loads(content)
    if payload.get("id") != JSON_DATASETS[dataset]:
        raise ValueError(
            f"{dataset}: dimensions {payload.get('id')} != "
            f"{JSON_DATASETS[dataset]}"
        )
    if (
        payload["dimension"]["geo"]["category"]["index"] != {geo: 0}
        or payload["dimension"]["time"]["category"]["index"] != {year: 0}
    ):
        raise ValueError(f"{dataset}: response is not restricted to {geo}/{year}")
    if not payload.get("value"):
        raise ValueError(f"{dataset}: no observations")
    return payload


def validate_sdmx_csv(content: bytes) -> None:
    if content.lstrip()[:9].upper() != b"DATAFLOW,":
        raise ValueError("response is not SDMX-CSV")


def save_or_validate(
    path: Path,
    fetch,
    validate,
) -> bytes:
    if path.exists():
        content = path.read_bytes()
        try:
            validate(content)
            return content
        except (ValueError, json.JSONDecodeError):
            pass
    content = fetch()
    validate(content)
    path.write_bytes(content)
    return content


def prepared_url(url: str, params: dict[str, str] | None = None) -> str:
    return requests.Request("GET", url, params=params).prepare().url


def figaro_queries(country: str, currency: str) -> list[tuple[str, str, str]]:
    return [
        ("naio_10_fcp_s3", f"A....{country}", f"naio_10_fcp_s3_{country}_2020.csv"),
        (
            "naio_10_fcp_u3",
            f"A...{country}..",
            f"naio_10_fcp_u3_{country}dest_2020.csv",
        ),
        (
            "naio_10_fcp_u3",
            f"A.....{country}",
            f"naio_10_fcp_u3_{country}orig_2020.csv",
        ),
        (
            "naio_10_fcp_ii3",
            f"A...{country}..",
            f"naio_10_fcp_ii3_{country}dest_2020.csv",
        ),
        (
            "naio_10_fcp_ii3",
            f"A.....{country}",
            f"naio_10_fcp_ii3_{country}orig_2020.csv",
        ),
        (
            "ert_bil_eur_a",
            f"A.AVG.NAC.{currency}",
            f"ert_bil_eur_a_{currency}_2020.csv",
        ),
    ]


def coverage_probe(dataset: str, geo: str, year: str) -> dict:
    url = f"{EUROSTAT_JSON}/{dataset}"
    params = {"geo": geo, "time": year, "lang": "en"}
    try:
        with requests.Session() as session:
            response = request(session, url, params=params, timeout=300)
        payload = json.loads(response.content)
        observations = len(payload.get("value", {}))
        available = payload.get("id") == JSON_DATASETS[dataset] and observations > 0
        error = "" if available else "no observations or unexpected dimensions"
    except Exception as exc:
        observations = 0
        available = False
        error = str(exc)
    return {
        "dataset": dataset,
        "geo": geo,
        "year": year,
        "available": available,
        "observations": observations,
        "error": error,
        "url": prepared_url(url, params),
        "retrieval_date": RETRIEVAL_DATE,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--country", default="SE")
    parser.add_argument("--year", default="2020")
    parser.add_argument("--currency", default="SEK")
    parser.add_argument("--coverage-workers", type=int, default=8)
    args = parser.parse_args()
    country = args.country.upper()
    year = str(args.year)
    currency = args.currency.upper()
    if len(country) != 2 or not country.isalpha():
        raise ValueError("--country must be a two-letter code")
    out = DATA / "eu_core_raw" / country / year
    out.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    manifest: list[dict] = []

    for dataset in JSON_DATASETS:
        url = f"{EUROSTAT_JSON}/{dataset}"
        params = {"geo": country, "time": year, "lang": "en"}
        filename = f"{dataset}_{country}_{year}.json"
        path = out / filename
        content = save_or_validate(
            path,
            lambda url=url, params=params: request(
                session, url, params=params
            ).content,
            lambda content, dataset=dataset: validate_jsonstat(
                content, dataset, country, year
            ),
        )
        payload = validate_jsonstat(content, dataset, country, year)
        unit_codes = list(
            payload["dimension"].get("unit", {}).get("category", {}).get("index", {})
        )
        manifest.append(
            {
                "source": dataset,
                "url": prepared_url(url, params),
                "query_filters": {"geo": country, "time": year, "lang": "en"},
                "file": filename,
                "bytes": len(content),
                "sha256": sha256(content),
                "observations": len(payload["value"]),
                "dimensions": payload["id"],
                "units_present": unit_codes,
                "source_status": "official_direct_observation",
                "licence_reuse": "Eurostat reuse policy",
                "retrieval_date": RETRIEVAL_DATE,
            }
        )
        print(f"validated {filename}")

    sdmx_params = {
        "format": "SDMX-CSV",
        "startPeriod": year,
        "endPeriod": year,
    }
    for dataset, key, filename in figaro_queries(country, currency):
        filename = filename.replace("2020", year)
        url = f"{EUROSTAT_SDMX}/{dataset}/{key}"
        path = out / filename
        content = save_or_validate(
            path,
            lambda url=url: request(session, url, params=sdmx_params).content,
            validate_sdmx_csv,
        )
        manifest.append(
            {
                "source": dataset,
                "url": prepared_url(url, sdmx_params),
                "query_filters": {
                    "sdmx_key": key,
                    "startPeriod": year,
                    "endPeriod": year,
                },
                "file": filename,
                "bytes": len(content),
                "sha256": sha256(content),
                "source_status": "official_direct_observation",
                "units_present": (
                    ["national currency per EUR"]
                    if dataset == "ert_bil_eur_a"
                    else ["MIO_EUR"]
                ),
                "eu_country_coverage": "EU-27/27 in FIGARO 2026 edition",
                "licence_reuse": "Eurostat reuse policy",
                "retrieval_date": RETRIEVAL_DATE,
            }
        )
        print(f"validated {filename}")

    for filename, (url, licence) in DOCUMENTS.items():
        path = out / filename

        def validate_document(content: bytes, suffix=path.suffix.lower()) -> None:
            if suffix == ".pdf" and not content.startswith(b"%PDF"):
                raise ValueError("response is not PDF")
            if suffix == ".xlsx" and not content.startswith(b"PK"):
                raise ValueError("response is not XLSX")

        content = save_or_validate(
            path,
            lambda url=url: request(session, url).content,
            validate_document,
        )
        manifest.append(
            {
                "source": filename,
                "url": url,
                "query_filters": {},
                "file": filename,
                "bytes": len(content),
                "sha256": sha256(content),
                "source_status": (
                    "official_exact_2020_reference"
                    if "vat_rates_2020" in filename
                    else "official_nearest_reference"
                    if filename.startswith("excise")
                    else "official_weekly_observations"
                ),
                "licence_reuse": licence,
                "retrieval_date": RETRIEVAL_DATE,
            }
        )
        print(f"validated {filename}")

    jobs = [
        (dataset, geo, year)
        for dataset in JSON_DATASETS
        for geo in EU27
    ]
    probes: list[dict] = []
    with ThreadPoolExecutor(max_workers=args.coverage_workers) as executor:
        futures = {
            executor.submit(coverage_probe, *job): job for job in jobs
        }
        for future in as_completed(futures):
            probes.append(future.result())
    probes.sort(key=lambda row: (row["dataset"], EU27.index(row["geo"])))
    (out / "eu27_coverage_probe.json").write_text(
        json.dumps(probes, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    coverage = {
        dataset: {
            "countries_with_observations": sum(
                row["available"]
                for row in probes
                if row["dataset"] == dataset
            ),
            "countries_tested": 27,
            "missing": [
                row["geo"]
                for row in probes
                if row["dataset"] == dataset and not row["available"]
            ],
        }
        for dataset in JSON_DATASETS
    }
    (out / "manifest.json").write_text(
        json.dumps(
            {
                "country": country,
                "reference_year": int(year),
                "retrieval_date": RETRIEVAL_DATE,
                "raw_files": manifest,
                "eu27_coverage": coverage,
                "figaro_coverage": "EU-27/27 plus partners; 46 areas",
            },
            indent=2,
            ensure_ascii=False,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"wrote {out / 'manifest.json'}")


if __name__ == "__main__":
    main()
