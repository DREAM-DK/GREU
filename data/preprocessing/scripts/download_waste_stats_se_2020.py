"""Download EU-wide public statistics characterizing NACE E37-E39 output.

Feasibility probe for the Sweden 2020 public-core CPA_E37-E39 monetary
residual (60.156 bn SEK supply-side control, 54.357 bn SEK use-side
residual): can public EU-wide data characterize how much of the
waste/sewerage industry's output is energy-relevant?

    python data/preprocessing/scripts/download_waste_stats_se_2020.py

Raw JSON-stat responses are preserved byte-for-byte under
data/preprocessing/data/waste_stats_raw/<CC>/<YEAR>/ together with
manifest.json (URLs, filters, hashes, retrieval date), the recorded
negative probes (datasets that exist but have no 2020 data, or that do
not exist), and an EU-27 coverage probe for the key sources.

The Eurostat API can return an HTML "Server temporarily unavailable"
page with HTTP 200; every response is validated as JSON-stat restricted
to the requested geo/time before being written.
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
RETRIEVAL_DATE = "2026-07-31"
EU27 = [
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE",
    "EL", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT",
    "RO", "SK", "SI", "ES", "SE",
]

SBS_NACE_E = [
    "E", "E36", "E360", "E3600",
    "E37", "E370", "E3700",
    "E38", "E381", "E3811", "E3812", "E382", "E3821", "E3822",
    "E383", "E3831", "E3832",
    "E39", "E390", "E3900",
]
SBS_INDICATORS = [
    "V11110",  # enterprises
    "V12110",  # turnover, M EUR
    "V12120",  # production value, M EUR
    "V12130",  # gross margin on goods for resale, M EUR
    "V12150",  # value added at factor cost, M EUR
    "V16110",  # persons employed
    "V18110",  # turnover from principal activity, M EUR
    "V20110",  # purchases of energy products, M EUR
]

# dataset -> (expected JSON-stat dimension ids, extra query filters)
DATASETS: dict[str, tuple[list[str], list[tuple[str, str]]]] = {
    # SBS annual detailed enterprise statistics for industry (B-E),
    # NACE Rev. 2, series covering 2008-2020: turnover/production value
    # down to 4-digit NACE for E37/E38/E39.
    "sbs_na_ind_r2": (
        ["freq", "nace_r2", "indic_sb", "geo", "time"],
        [("nace_r2", c) for c in SBS_NACE_E]
        + [("indic_sb", i) for i in SBS_INDICATORS],
    ),
    # Waste generation by NACE activity, tonnes (biennial, 2020 covered).
    "env_wasgen": (
        ["freq", "unit", "hazard", "nace_r2", "waste", "geo", "time"],
        [("unit", "T"), ("hazard", "HAZ_NHAZ"),
         ("waste", "TOTAL"), ("waste", "TOT_X_MIN")],
    ),
    # Waste treatment by operation (incl. RCV_E energy recovery R1), tonnes.
    "env_wastrt": (
        ["freq", "unit", "hazard", "wst_oper", "waste", "geo", "time"],
        [("unit", "T"), ("hazard", "HAZ_NHAZ"),
         ("waste", "TOTAL"), ("waste", "TOT_X_MIN")],
    ),
    # EPEA: production of environmental protection services by general
    # government and NPISH, by CEPA domain (CEPA2 wastewater, CEPA3 waste).
    "env_ac_pepsgg1": (
        ["freq", "ceparema", "env_econ", "unit", "geo", "time"],
        [],
    ),
    # EPEA: market output of environmental protection services by
    # specialist producers (corporations), by CEPA domain.
    "env_ac_pepssp1": (
        ["freq", "ceparema", "env_econ", "unit", "geo", "time"],
        [],
    ),
    # EGSS: output/value added/exports by NACE section x CEPA/CReMA
    # (CReMA 13A = production of energy from renewable sources).
    "env_ac_egss2": (
        ["freq", "nace_r2", "ceparema", "na_item", "ty", "unit", "geo",
         "time"],
        [],
    ),
    # Complete energy balance, waste fuels only: how much waste goes to
    # energy transformation and in which plant types.
    "nrg_bal_c": (
        ["freq", "nrg_bal", "siec", "unit", "geo", "time"],
        [("unit", "TJ"), ("siec", "W6100"), ("siec", "W6210"),
         ("siec", "W6220"), ("siec", "W6100_6220")],
    ),
}

# Candidate datasets probed and found NOT usable for the reference year;
# they are queried anyway so the negative result is recorded reproducibly.
NEGATIVE_PROBES = {
    "sbs_ovw_act": "new SBS series; exists but has no 2020 observations",
    "sbs_sc_ovw": "new SBS series; exists but has no 2020 observations",
    "env_ac_epneec": "guessed EPEA code; HTTP 404 (does not exist)",
    "env_ac_pepsnsp1": (
        "EPEA ancillary output of non-specialist producers; HTTP 404 "
        "(not published as a dissemination dataset)"
    ),
}

# Minimal one-cell queries used for the EU-27 coverage probe of the key
# sources (dataset -> filters identifying one indicative series).
COVERAGE_QUERIES: dict[str, list[tuple[str, str]]] = {
    "sbs_na_ind_r2": [("nace_r2", "E38"), ("indic_sb", "V12120")],
    "env_wastrt": [("waste", "TOT_X_MIN"), ("hazard", "HAZ_NHAZ"),
                   ("unit", "T"), ("wst_oper", "RCV_E")],
    "env_ac_pepsgg1": [("ceparema", "CEPA3"), ("env_econ", "EPS_P1"),
                       ("unit", "MIO_EUR")],
    "env_ac_pepssp1": [("ceparema", "CEPA3"), ("env_econ", "EPS_P11"),
                       ("unit", "MIO_EUR")],
    "env_ac_egss2": [("nace_r2", "E"), ("ceparema", "CEPA3"),
                     ("na_item", "P1"), ("ty", "MKT"),
                     ("unit", "MIO_EUR")],
    "nrg_bal_c": [("siec", "W6210"), ("nrg_bal", "TI_EHG_E"),
                  ("unit", "TJ")],
}


def sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def request(
    session: requests.Session,
    url: str,
    *,
    params: list[tuple[str, str]] | None = None,
    timeout: int = 900,
    allow_404: bool = False,
) -> requests.Response:
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            response = session.get(url, params=params, timeout=timeout)
            if response.status_code == 404 and allow_404:
                return response
            if response.status_code != 200:
                raise ValueError(f"HTTP {response.status_code}")
            if not response.content:
                raise ValueError("empty response")
            if not response.content.lstrip().startswith(b"{"):
                # HTML "Server temporarily unavailable" page with HTTP 200
                raise ValueError("response is not JSON")
            return response
        except (requests.RequestException, ValueError) as exc:
            last_error = exc
            if attempt < 3:
                time.sleep(10 * attempt)
    raise RuntimeError(f"GET failed after three attempts: {url}: {last_error}")


def validate_jsonstat(
    content: bytes, dataset: str, dims: list[str], geo: str, year: str
) -> dict:
    if not content.lstrip().startswith(b"{"):
        raise ValueError(f"{dataset}: response is not JSON")
    payload = json.loads(content)
    if payload.get("id") != dims:
        raise ValueError(
            f"{dataset}: dimensions {payload.get('id')} != {dims}"
        )
    if (
        payload["dimension"]["geo"]["category"]["index"] != {geo: 0}
        or payload["dimension"]["time"]["category"]["index"] != {year: 0}
    ):
        raise ValueError(f"{dataset}: response not restricted to {geo}/{year}")
    if not payload.get("value"):
        raise ValueError(f"{dataset}: no observations")
    return payload


def save_or_validate(path: Path, fetch, validate) -> bytes:
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


def prepared_url(url: str, params: list[tuple[str, str]] | None) -> str:
    return requests.Request("GET", url, params=params).prepare().url


def coverage_probe(dataset: str, geo: str, year: str) -> dict:
    url = f"{EUROSTAT_JSON}/{dataset}"
    params = [("geo", geo), ("time", year), ("lang", "en")]
    params += COVERAGE_QUERIES[dataset]
    try:
        with requests.Session() as session:
            response = request(session, url, params=params, timeout=300)
        payload = json.loads(response.content)
        observations = len(payload.get("value", {}))
        available = observations > 0
        error = "" if available else "no observations"
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
    parser.add_argument("--coverage-workers", type=int, default=8)
    parser.add_argument(
        "--skip-coverage", action="store_true",
        help="skip the 162-request EU-27 coverage probe",
    )
    args = parser.parse_args()
    country = args.country.upper()
    year = str(args.year)
    if len(country) != 2 or not country.isalpha():
        raise ValueError("--country must be a two-letter code")
    out = DATA / "waste_stats_raw" / country / year
    out.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    manifest: list[dict] = []

    for dataset, (dims, extra) in DATASETS.items():
        url = f"{EUROSTAT_JSON}/{dataset}"
        params = [("geo", country), ("time", year), ("lang", "en")] + extra
        filename = f"{dataset}_{country}_{year}.json"
        path = out / filename
        content = save_or_validate(
            path,
            lambda url=url, params=params: request(
                session, url, params=params
            ).content,
            lambda content, dataset=dataset, dims=dims: validate_jsonstat(
                content, dataset, dims, country, year
            ),
        )
        payload = validate_jsonstat(content, dataset, dims, country, year)
        manifest.append(
            {
                "source": dataset,
                "url": prepared_url(url, params),
                "query_filters": {
                    "geo": country, "time": year, "lang": "en",
                    "extra": extra,
                },
                "file": filename,
                "bytes": len(content),
                "sha256": sha256(content),
                "observations": len(payload["value"]),
                "dimensions": payload["id"],
                "source_status": "official_direct_observation",
                "licence_reuse": "Eurostat reuse policy",
                "retrieval_date": RETRIEVAL_DATE,
            }
        )
        print(f"validated {filename}")

    negative: list[dict] = []
    for dataset, reason in NEGATIVE_PROBES.items():
        url = f"{EUROSTAT_JSON}/{dataset}"
        params = [("geo", country), ("time", year), ("lang", "en")]
        try:
            response = request(
                session, url, params=params, timeout=300, allow_404=True
            )
            status = response.status_code
            observations = 0
            if status == 200:
                observations = len(
                    json.loads(response.content).get("value", {})
                )
        except RuntimeError as exc:
            status = -1
            observations = 0
            reason = f"{reason}; probe error: {exc}"
        negative.append(
            {
                "dataset": dataset,
                "url": prepared_url(url, params),
                "http_status": status,
                "observations": observations,
                "verdict": reason,
                "retrieval_date": RETRIEVAL_DATE,
            }
        )
        print(f"negative probe {dataset}: HTTP {status}, "
              f"{observations} observations")

    coverage: dict = {}
    if not args.skip_coverage:
        jobs = [
            (dataset, geo, year)
            for dataset in COVERAGE_QUERIES
            for geo in EU27
        ]
        probes: list[dict] = []
        with ThreadPoolExecutor(max_workers=args.coverage_workers) as pool:
            futures = {pool.submit(coverage_probe, *job): job for job in jobs}
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
                "probe_series": dict(COVERAGE_QUERIES[dataset]),
            }
            for dataset in COVERAGE_QUERIES
        }
        print("wrote eu27_coverage_probe.json")

    (out / "manifest.json").write_text(
        json.dumps(
            {
                "purpose": (
                    "characterize NACE E37-E39 output composition for the "
                    "CPA_E37-E39 monetary residual feasibility probe"
                ),
                "country": country,
                "reference_year": int(year),
                "retrieval_date": RETRIEVAL_DATE,
                "raw_files": manifest,
                "negative_probes": negative,
                "eu27_coverage": coverage,
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
