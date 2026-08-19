"""Download Eurostat air-emissions accounts and UNFCCC inventory sectors
for the non_energy_emissions.xlsx pilot.

Eleventh pilot in Phase 1 of the GREU EU-generic data work (see
docs/eu_data_mapping.md). Raw JSON-stat responses are saved exactly as
delivered by Eurostat's dissemination API.

The combined energy+non-energy vs env_ac_ainah_r2 boundary was already
piloted 2026-07-30. This pull is for the untested energy/non-energy
*split*: ainah as the combined control, env_air_gge CRF1/2/3/5 as an
independent process-emissions (IPPU / agriculture / waste) control.

Datasets
--------
env_ac_ainah_r2
    Air-emissions accounts by NACE Rev. 2 activity and pollutant.
    Dimensions: freq, airpol, nace_r2, unit, geo, time.
    Residence principle (same as GREU). Combined energy + process.
env_air_gge
    Greenhouse gas emissions by source sector (EEA/UNFCCC inventory).
    Dimensions: freq, unit, airpol, src_crf, geo, time.
    Territorial principle. CRF1 energy, CRF2 IPPU, CRF3 agriculture,
    CRF5 waste. Used here as the independent energy vs process split,
    not as a LULUCF cross-check (that was the 2026-08-03 bridge pilot).

Downloads
---------
1. env_ac_ainah_r2 DK 2020, all airpol / nace / units as delivered.
2. env_ac_ainah_r2 SE 2020, same slice (public-core pilot country).
3. env_ac_ainah_r2 EU-27 coverage probe, 2020, THS_T, GHG-relevant airpol.
4. env_ac_ainah_r2 EU-27 year probe: GHG, THS_T, TOTAL_HH, all years.
5. env_air_gge DK 2020: CRF1/2/3/5 (plus a few children and inventory
   totals), GHG gases in THS_T.
6. env_air_gge SE 2020, same slice.
7. env_air_gge EU-27 coverage probe, 2020, GHG, CRF1/2/3/5.

The Eurostat service can return an HTML error document with HTTP 200.
This downloader validates both the content and the JSON-stat structure
before accepting a response.

A 2026-07-30 DK ainah pull already lives under
data/preprocessing/data/eurostat_energy_emissions_raw/. This script
re-downloads DK into a dedicated directory so a vintage comparison is
possible; it does not overwrite that earlier file.

Output
------
data/preprocessing/data/non_energy_emissions_raw/DK/2020/

Run
---
python data/preprocessing/scripts/download_non_energy_emissions_dk_2020.py
"""

from __future__ import annotations

import datetime
import hashlib
import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET_AINAH = "env_ac_ainah_r2"
DATASET_GGE = "env_air_gge"
OUT = (
    pathlib.Path(__file__).resolve().parents[1]
    / "data"
    / "non_energy_emissions_raw"
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

AINAH_AIRPOL = [
    "GHG", "CO2", "CO2_BIO", "CH4", "N2O",
    "HFC_CO2E", "PFC_CO2E", "NF3_SF6_CO2E",
]
GGE_AIRPOL = [
    "GHG", "CO2", "CO2_BIO", "CH4", "CH4_CO2E", "N2O", "N2O_CO2E",
    "HFC_CO2E", "PFC_CO2E", "SF6_CO2E", "NF3_CO2E",
]
GGE_SRC = [
    "TOTXMEMO", "TOTX4_MEMO",
    "CRF1", "CRF1A", "CRF1B",
    "CRF2", "CRF2A", "CRF2F",
    "CRF3", "CRF3A", "CRF3B", "CRF3D",
    "CRF5",
]

EXPECTED_DIMS = {
    DATASET_AINAH: ["freq", "airpol", "nace_r2", "unit", "geo", "time"],
    DATASET_GGE: ["freq", "unit", "airpol", "src_crf", "geo", "time"],
}

QUERIES = [
    {
        "dataset": DATASET_AINAH,
        "filename": f"{DATASET_AINAH}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": (
            "Denmark 2020 air-emissions accounts: all airpol / NACE / units "
            "as delivered. Re-downloaded so a vintage comparison against the "
            "2026-07-30 PEFA-pilot pull is possible."
        ),
    },
    {
        "dataset": DATASET_AINAH,
        "filename": f"{DATASET_AINAH}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Sweden 2020 air-emissions accounts, same slice (public-core pilot country).",
    },
    {
        "dataset": DATASET_AINAH,
        "filename": f"{DATASET_AINAH}_eu27_coverage_probe_{YEAR}.json",
        "params": {
            "geo": EU27,
            "time": YEAR,
            "unit": "THS_T",
            "airpol": AINAH_AIRPOL,
            "lang": "en",
        },
        "geos": EU27,
        "times": [YEAR],
        "note": (
            "EU-27 coverage probe 2020: THS_T, GHG-relevant airpol including "
            "F-gases, all NACE codes as delivered."
        ),
    },
    {
        "dataset": DATASET_AINAH,
        "filename": f"{DATASET_AINAH}_eu27_year_probe_GHG.json",
        "params": {
            "geo": EU27,
            "unit": "THS_T",
            "airpol": "GHG",
            "nace_r2": "TOTAL_HH",
            "lang": "en",
        },
        "geos": EU27,
        "times": None,
        "note": "EU-27 year-coverage probe: GHG in THS_T, TOTAL_HH (accounts total incl. households), all years.",
    },
    {
        "dataset": DATASET_GGE,
        "filename": f"{DATASET_GGE}_DK_{YEAR}_crf.json",
        "params": {
            "geo": "DK",
            "time": YEAR,
            "unit": "THS_T",
            "src_crf": GGE_SRC,
            "airpol": GGE_AIRPOL,
            "lang": "en",
        },
        "geos": ["DK"],
        "times": [YEAR],
        "note": (
            "Inventory (env_air_gge) DK 2020: CRF1 energy, CRF2 IPPU, CRF3 "
            "agriculture, CRF5 waste, plus selected children and inventory "
            "totals — independent energy vs process split for item 9."
        ),
    },
    {
        "dataset": DATASET_GGE,
        "filename": f"{DATASET_GGE}_SE_{YEAR}_crf.json",
        "params": {
            "geo": "SE",
            "time": YEAR,
            "unit": "THS_T",
            "src_crf": GGE_SRC,
            "airpol": GGE_AIRPOL,
            "lang": "en",
        },
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Inventory SE 2020, same CRF slice (public-core pilot country).",
    },
    {
        "dataset": DATASET_GGE,
        "filename": f"{DATASET_GGE}_eu27_crf_coverage_probe_{YEAR}.json",
        "params": {
            "geo": EU27,
            "time": YEAR,
            "unit": "THS_T",
            "src_crf": ["CRF1", "CRF2", "CRF3", "CRF5"],
            "airpol": "GHG",
            "lang": "en",
        },
        "geos": EU27,
        "times": [YEAR],
        "note": "EU-27 coverage probe 2020: inventory GHG for CRF1/2/3/5.",
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
                validate_jsonstat(
                    path.read_bytes(),
                    query["geos"],
                    query["times"],
                    EXPECTED_DIMS[dataset],
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
                        EXPECTED_DIMS[dataset],
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
        "datasets": [DATASET_AINAH, DATASET_GGE],
        "source": "Eurostat dissemination API (statistics/1.0, JSON-stat 2.0)",
        "base_url": BASE,
        "retrieval_date": RETRIEVAL_DATE,
        "purpose": (
            "Pilot reconciliation of env_ac_ainah_r2 (combined air accounts) "
            "and env_air_gge CRF1/2/3/5 (territorial inventory split) against "
            "the Danish GREU input non_energy_emissions.xlsx (DK 2020), with "
            "SE-2020 and EU-27 coverage/year probes. See docs/eu_data_mapping.md."
        ),
        "related_earlier_pull": (
            "data/preprocessing/data/eurostat_energy_emissions_raw/"
            "env_ac_ainah_r2_DK_2020.json (retrieved 2026-07-30; kept for vintage comparison)"
        ),
        "files": manifest_entries,
    }
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, default=str), encoding="utf-8"
    )
    print(f"manifest -> {OUT / 'manifest.json'}")

    readme = f"""# Eurostat `env_ac_ainah_r2` / `env_air_gge` raw downloads — non-energy emissions pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: {RETRIEVAL_DATE}. Downloaded by
`data/preprocessing/scripts/download_non_energy_emissions_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **env_ac_ainah_r2** — Air-emissions accounts by NACE Rev. 2 activity
and pollutant (residence principle; energy and process combined). Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_ac_ainah_r2/default/table

Dimensions: freq (A), airpol, nace_r2, unit, geo, time. The reconciliation
uses `THS_T` (thousand tonnes = kt). `GHG` and F-gas CO2-equivalent series
are therefore kt CO2e. National total for the GREU comparison is `TOTAL_HH`
(industries + households).

Second dataset: **env_air_gge** — Greenhouse gas emissions by UNFCCC CRF
source sector (territorial inventory). Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_air_gge/default/table

Used here for CRF1 (energy), CRF2 (IPPU), CRF3 (agriculture) and CRF5
(waste) as an independent process-emissions control. This is a different
slice from the 2026-08-03 emissions-bridge pull, which only used CRF4
(LULUCF).

An earlier DK ainah pull (2026-07-30) is preserved at
`data/preprocessing/data/eurostat_energy_emissions_raw/env_ac_ainah_r2_DK_2020.json`
and is **not** overwritten. The reconcile script compares the two vintages.

## Files

| file | content |
|---|---|
| `env_ac_ainah_r2_DK_2020.json` | Denmark 2020 air accounts, all airpol / NACE / units |
| `env_ac_ainah_r2_SE_2020.json` | Sweden 2020 air accounts, same slice |
| `env_ac_ainah_r2_eu27_coverage_probe_2020.json` | all 27 member states, 2020, THS_T, GHG-relevant airpol |
| `env_ac_ainah_r2_eu27_year_probe_GHG.json` | all 27 member states, all years, GHG THS_T TOTAL_HH |
| `env_air_gge_DK_2020_crf.json` | Denmark 2020 inventory CRF1/2/3/5 (+ children, totals) |
| `env_air_gge_SE_2020_crf.json` | Sweden 2020 inventory, same CRF slice |
| `env_air_gge_eu27_crf_coverage_probe_2020.json` | all 27 member states, 2020, GHG, CRF1/2/3/5 |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_non_energy_emissions_dk_2020.py`,
which writes `data/preprocessing/data/non_energy_emissions_dk2020_reconciliation.xlsx`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(f"README -> {OUT / 'README.md'}")


if __name__ == "__main__":
    main()
