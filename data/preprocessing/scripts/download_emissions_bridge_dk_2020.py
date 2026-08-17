"""Download Eurostat air-emissions bridging items (env_ac_aibrid_r2) for the
emissions_bridge_items.xlsx pilot.

Seventh pilot in Phase 1 of the GREU EU-generic data work (see
docs/eu_data_mapping.md). Raw JSON-stat responses are saved exactly as
delivered by Eurostat's dissemination API.

Datasets
--------
env_ac_aibrid_r2
    Air emissions accounts totals bridging to emission inventory totals.
    Dimensions: freq, airpol, indic_env, unit, geo, time.
    indic_env: AEMIS_RES (accounts total), AEMIS_RES_ABR[_FWTR/_LTR/_WTR/_ATR]
               (residents' emissions abroad), AEMIS_TER_NRES[_LTR/_WTR/_ATR]
               (non-residents' emissions on the territory), ADJ_SD,
               AEMIS_TER (inventory total), AEMIS_TER_LULUCF,
               LULUCF / FORL / CRL_GRL / LULUCF_OTH.
    airpol:    GHG (CO2-eq), CO2 (fossil), CO2_BIO, CH4, N2O, F-gases in
               CO2-eq, plus air pollutants (SOx, NOx, NH3, PM, NMVOC, CO).
    unit:      T (tonnes), THS_T (thousand tonnes), G_HAB, KG_HAB.

    Note: the dataset covers *both* Danish bridge concepts in one place —
    the residence adjustments (border trade, international transport) *and*
    LULUCF — so no second dataset is strictly needed for the lulucf row.

env_air_gge
    Greenhouse gas emissions by source sector (EEA/UNFCCC inventory).
    Dimensions: freq, unit, airpol, src_crf, geo, time.
    Used only as an independent cross-check of the aibrid LULUCF figure:
    src_crf CRF4 (LULUCF sector), TOTXMEMO / TOTX4_MEMO (totals with /
    without LULUCF).

Downloads
---------
1. env_ac_aibrid_r2 DK 2020, all airpol / indic_env / units as delivered
   -> main pilot file.
2. env_ac_aibrid_r2 SE 2020, same slice -> Sweden is the public-core pilot
   country.
3. env_ac_aibrid_r2 EU-27 coverage probe, 2020, unit THS_T, GHG-relevant
   airpol, all indic_env, all 27 member states -> EU-wide coverage.
4. env_ac_aibrid_r2 EU-27 year-coverage probe, airpol GHG only, unit THS_T,
   all years -> time coverage.
5. env_air_gge DK 2020, GHG gases, src_crf CRF4 + TOTXMEMO + TOTX4_MEMO
   -> inventory cross-check of the LULUCF row.
6. env_air_gge EU-27 coverage probe, 2020, GHG, CRF4 -> LULUCF coverage.

The Eurostat service can return an HTML error document with HTTP 200. This
downloader validates both the content and the JSON-stat structure before
accepting a response.

Output
------
data/preprocessing/data/emissions_bridge_raw/DK/2020/
    env_ac_aibrid_r2_DK_2020.json
    env_ac_aibrid_r2_SE_2020.json
    env_ac_aibrid_r2_eu27_coverage_probe_2020.json
    env_ac_aibrid_r2_eu27_year_probe_GHG.json
    env_air_gge_DK_2020_lulucf.json
    env_air_gge_eu27_lulucf_coverage_probe_2020.json
    manifest.json, README.md

Run
---
python data/preprocessing/scripts/download_emissions_bridge_dk_2020.py
"""

from __future__ import annotations

import datetime
import hashlib
import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET = "env_ac_aibrid_r2"
DATASET_GGE = "env_air_gge"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "emissions_bridge_raw" / "DK" / "2020"
YEAR = "2020"
RETRIEVAL_DATE = datetime.date.today().isoformat()

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

GHG_AIRPOL = ["GHG", "CO2", "CO2_BIO", "CH4", "N2O"]

EXPECTED_DIMS = ["freq", "airpol", "indic_env", "unit", "geo", "time"]
EXPECTED_DIMS_GGE = ["freq", "unit", "airpol", "src_crf", "geo", "time"]

QUERIES = [
    {
        "filename": f"{DATASET}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": "Denmark 2020, all airpol/indic_env/units as delivered.",
    },
    {
        "filename": f"{DATASET}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Sweden 2020 availability probe (public-core pilot country).",
    },
    {
        "filename": f"{DATASET}_eu27_coverage_probe_{YEAR}.json",
        "params": {
            "geo": EU27,
            "time": YEAR,
            "unit": "THS_T",
            "airpol": GHG_AIRPOL,
            "lang": "en",
        },
        "geos": EU27,
        "times": [YEAR],
        "note": "EU-27 coverage probe 2020: THS_T, GHG-relevant airpol, all indic_env.",
    },
    {
        "filename": f"{DATASET}_eu27_year_probe_GHG.json",
        "params": {
            "geo": EU27,
            "unit": "THS_T",
            "airpol": "GHG",
            "lang": "en",
        },
        "geos": EU27,
        "times": None,  # all years as delivered
        "note": "EU-27 year-coverage probe: GHG in THS_T, all indic_env, all years.",
    },
    {
        "dataset": DATASET_GGE,
        "dims": EXPECTED_DIMS_GGE,
        "filename": f"{DATASET_GGE}_DK_{YEAR}_lulucf.json",
        "params": {
            "geo": "DK",
            "time": YEAR,
            "unit": "THS_T",
            "src_crf": ["CRF4", "TOTXMEMO", "TOTX4_MEMO"],
            "airpol": [
                "GHG", "CO2", "CH4", "CH4_CO2E", "N2O", "N2O_CO2E",
                "HFC_CO2E", "PFC_CO2E", "HFC_PFC_NSP_CO2E", "SF6_CO2E",
                "NF3_CO2E",
            ],
            "lang": "en",
        },
        "geos": ["DK"],
        "times": [YEAR],
        "note": (
            "Inventory (env_air_gge) DK 2020: LULUCF sector CRF4 and totals "
            "with/without LULUCF — independent cross-check of aibrid LULUCF."
        ),
    },
    {
        "dataset": DATASET_GGE,
        "dims": EXPECTED_DIMS_GGE,
        "filename": f"{DATASET_GGE}_eu27_lulucf_coverage_probe_{YEAR}.json",
        "params": {
            "geo": EU27,
            "time": YEAR,
            "unit": "THS_T",
            "src_crf": "CRF4",
            "airpol": "GHG",
            "lang": "en",
        },
        "geos": EU27,
        "times": [YEAR],
        "note": "EU-27 coverage probe for the inventory LULUCF sector (CRF4, GHG).",
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
        dims = query.get("dims", EXPECTED_DIMS)
        path = OUT / query["filename"]
        url = f"{BASE}/{dataset}"
        fetched = False
        if path.exists():
            try:
                validate_jsonstat(path.read_bytes(), query["geos"], query["times"], dims)
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
                        response.content, query["geos"], query["times"], dims
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
        "datasets": [DATASET, DATASET_GGE],
        "source": "Eurostat dissemination API (statistics/1.0, JSON-stat 2.0)",
        "base_url": BASE,
        "retrieval_date": RETRIEVAL_DATE,
        "purpose": (
            "Pilot reconciliation of env_ac_aibrid_r2 (plus env_air_gge as "
            "LULUCF cross-check) against the Danish GREU input "
            "emissions_bridge_items.xlsx (DK 2020), with SE-2020 and EU-27 "
            "coverage/year probes. See docs/eu_data_mapping.md."
        ),
        "files": manifest_entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"manifest -> {OUT / 'manifest.json'}")

    readme = f"""# Eurostat `env_ac_aibrid_r2` raw downloads — emissions bridge pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: {RETRIEVAL_DATE}. Downloaded by
`data/preprocessing/scripts/download_emissions_bridge_dk_2020.py` (re-runnable;
it skips files that already exist and validate).

Dataset: **env_ac_aibrid_r2** — Air emissions accounts totals bridging to
emission inventory totals. Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_ac_aibrid_r2/default/table

Dimensions: freq (A), airpol, indic_env, unit, geo, time.

- `indic_env`: `AEMIS_RES` accounts total; `AEMIS_RES_ABR` (+ `_FWTR`, `_LTR`,
  `_WTR`, `_ATR`) residents' emissions from fuel purchased abroad;
  `AEMIS_TER_NRES` (+ `_LTR`, `_WTR`, `_ATR`) non-residents' emissions from
  fuel purchased on the territory; `ADJ_SD` other adjustments; `AEMIS_TER`
  inventory total; `AEMIS_TER_LULUCF`; `LULUCF`, `FORL`, `CRL_GRL`,
  `LULUCF_OTH`.
- `airpol`: `GHG` (CO2-eq incl. F-gases), `CO2` (fossil), `CO2_BIO`, `CH4`,
  `N2O`, F-gas groups in CO2-eq, plus non-GHG air pollutants.
- `unit`: `T` tonnes, `THS_T` thousand tonnes, `G_HAB`/`KG_HAB` per capita.

Second dataset: **env_air_gge** — Greenhouse gas emissions by source sector
(EEA/UNFCCC inventory), used only as an independent cross-check of the aibrid
LULUCF figure (`src_crf` `CRF4` = LULUCF sector; `TOTXMEMO`/`TOTX4_MEMO` =
totals with/without LULUCF). Source page:
https://ec.europa.eu/eurostat/databrowser/view/env_air_gge/default/table

## Files

| file | content |
|---|---|
| `env_ac_aibrid_r2_DK_2020.json` | Denmark 2020, all airpol/indic_env/units |
| `env_ac_aibrid_r2_SE_2020.json` | Sweden 2020, same slice (public-core pilot country) |
| `env_ac_aibrid_r2_eu27_coverage_probe_2020.json` | all 27 member states, 2020, THS_T, GHG/CO2/CO2_BIO/CH4/N2O, all indic_env |
| `env_ac_aibrid_r2_eu27_year_probe_GHG.json` | all 27 member states, all years, GHG in THS_T, all indic_env |
| `env_air_gge_DK_2020_lulucf.json` | inventory DK 2020: CRF4 + totals with/without LULUCF, GHG gases |
| `env_air_gge_eu27_lulucf_coverage_probe_2020.json` | all 27 member states, 2020, CRF4 GHG |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_emissions_bridge_dk_2020.py`,
which writes `data/preprocessing/data/emissions_bridge_dk2020_reconciliation.xlsx`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(f"README -> {OUT / 'README.md'}")


if __name__ == "__main__":
    main()
