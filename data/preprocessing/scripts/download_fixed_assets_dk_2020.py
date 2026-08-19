"""Download Eurostat capital-stock and GFCF data (nama_10_nfa_st stocks,
plus nama_10_a64_p5 investment by asset) for the fixed_assets.xlsx pilot.

Tenth pilot in Phase 1 of the GREU EU-generic data work (see
docs/eu_data_mapping.md). Raw JSON-stat responses are saved exactly as
delivered by Eurostat's dissemination API.

The same pull doubles as structural-gap-3 groundwork: nama_10_a64_p5 is
the use-margin source for qI_k_i (investment by type x investing industry),
and nama_10_nfa_st is the A21 fallback for countries that do not publish
A64 GFCF by asset.

Datasets
--------
nama_10_nfa_st
    Capital stocks by industry (NACE Rev. 2) and detailed asset type.
    Dimensions: freq, unit, nace_r2, asset10, geo, time.
    asset10: ESA AN.11 codes, both net (N..N) and gross (N..G).
    unit: CRC_* current replacement cost, PYR_* previous-year replacement
    cost, CLV15/CLV20_* chain-linked volumes, each in MEUR and MNAC.
nama_10_a64_p5
    Capital formation by industry (NACE Rev. 2) and detailed asset type.
    Dimensions: freq, unit, nace_r2, asset10, na_item, geo, time.
    na_item P51G = GFCF. Gross assets only (no net). Carries N12G
    inventories as well, which GREU reads from the IO table, not here.

Downloads
---------
1. nama_10_nfa_st DK 2020, all units / nace / assets as delivered.
2. nama_10_a64_p5 DK 2020, CP_MNAC + PYP_MNAC, P51G, all nace / assets.
3+4. The same two slices for SE 2020 (public-core pilot country).
5. nama_10_nfa_st EU-27 coverage probe, 2020, CRC_MNAC, all nace / assets.
6. nama_10_a64_p5 EU-27 coverage probe, 2020, CP_MNAC, P51G, all nace / assets.
7. nama_10_nfa_st EU-27 year probe: TOTAL, CRC_MNAC, N11N + N11G, all years.
8. nama_10_a64_p5 EU-27 year probe: TOTAL, CP_MNAC, P51G, N11G, all years.

The Eurostat service can return an HTML error document with HTTP 200. This
downloader validates both the content and the JSON-stat structure before
accepting a response.

Output
------
data/preprocessing/data/fixed_assets_raw/DK/2020/
    nama_10_nfa_st_DK_2020.json
    nama_10_a64_p5_DK_2020.json
    nama_10_nfa_st_SE_2020.json
    nama_10_a64_p5_SE_2020.json
    nama_10_nfa_st_eu27_coverage_probe_2020.json
    nama_10_a64_p5_eu27_coverage_probe_2020.json
    nama_10_nfa_st_eu27_year_probe_N11.json
    nama_10_a64_p5_eu27_year_probe_N11G.json
    manifest.json, README.md

Run
---
python data/preprocessing/scripts/download_fixed_assets_dk_2020.py
"""

from __future__ import annotations

import datetime
import hashlib
import json
import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET_ST = "nama_10_nfa_st"
DATASET_P5 = "nama_10_a64_p5"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "fixed_assets_raw" / "DK" / "2020"
YEAR = "2020"
RETRIEVAL_DATE = datetime.date.today().isoformat()

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

EXPECTED_DIMS = {
    DATASET_ST: ["freq", "unit", "nace_r2", "asset10", "geo", "time"],
    DATASET_P5: ["freq", "unit", "nace_r2", "asset10", "na_item", "geo", "time"],
}

QUERIES = [
    {
        "dataset": DATASET_ST,
        "filename": f"{DATASET_ST}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": ("Denmark 2020 capital stocks: all units, NACE codes and asset "
                 "types as delivered, so net vs gross and CRC vs CLV can be "
                 "settled from raw data."),
    },
    {
        "dataset": DATASET_P5,
        "filename": f"{DATASET_P5}_DK_{YEAR}.json",
        "params": {"geo": "DK", "time": YEAR, "unit": ["CP_MNAC", "PYP_MNAC"],
                   "na_item": "P51G", "lang": "en"},
        "geos": ["DK"],
        "times": [YEAR],
        "note": ("Denmark 2020 GFCF (P51G) by industry x asset: current and "
                 "previous-year prices in national currency."),
    },
    {
        "dataset": DATASET_ST,
        "filename": f"{DATASET_ST}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Sweden 2020 capital stocks, same slice (public-core pilot country).",
    },
    {
        "dataset": DATASET_P5,
        "filename": f"{DATASET_P5}_SE_{YEAR}.json",
        "params": {"geo": "SE", "time": YEAR, "unit": ["CP_MNAC", "PYP_MNAC"],
                   "na_item": "P51G", "lang": "en"},
        "geos": ["SE"],
        "times": [YEAR],
        "note": "Sweden 2020 GFCF, same slice.",
    },
    {
        "dataset": DATASET_ST,
        "filename": f"{DATASET_ST}_eu27_coverage_probe_{YEAR}.json",
        "params": {"geo": EU27, "time": YEAR, "unit": "CRC_MNAC", "lang": "en"},
        "geos": EU27,
        "times": [YEAR],
        "note": ("EU-27 coverage probe 2020: stocks at current replacement cost "
                 "in national currency, all NACE codes and asset types."),
    },
    {
        "dataset": DATASET_P5,
        "filename": f"{DATASET_P5}_eu27_coverage_probe_{YEAR}.json",
        "params": {"geo": EU27, "time": YEAR, "unit": "CP_MNAC",
                   "na_item": "P51G", "lang": "en"},
        "geos": EU27,
        "times": [YEAR],
        "note": ("EU-27 coverage probe 2020: GFCF P51G at current prices in "
                 "national currency, all NACE codes and asset types."),
    },
    {
        "dataset": DATASET_ST,
        "filename": f"{DATASET_ST}_eu27_year_probe_N11.json",
        "params": {"geo": EU27, "unit": "CRC_MNAC", "nace_r2": "TOTAL",
                   "asset10": ["N11N", "N11G"], "lang": "en"},
        "geos": EU27,
        "times": None,
        "note": ("EU-27 year-coverage probe: economy-wide total fixed assets, "
                 "net and gross, current replacement cost."),
    },
    {
        "dataset": DATASET_P5,
        "filename": f"{DATASET_P5}_eu27_year_probe_N11G.json",
        "params": {"geo": EU27, "unit": "CP_MNAC", "na_item": "P51G",
                   "nace_r2": "TOTAL", "asset10": "N11G", "lang": "en"},
        "geos": EU27,
        "times": None,
        "note": "EU-27 year-coverage probe: economy-wide GFCF, total fixed assets.",
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
        "datasets": [DATASET_ST, DATASET_P5],
        "source": "Eurostat dissemination API (statistics/1.0, JSON-stat 2.0)",
        "base_url": BASE,
        "retrieval_date": RETRIEVAL_DATE,
        "purpose": (
            "Pilot reconciliation of nama_10_nfa_st (plus nama_10_a64_p5 GFCF "
            "detail) against the Danish GREU input fixed_assets.xlsx (DK 2020), "
            "with SE-2020 and EU-27 coverage/year probes. The GFCF pull is also "
            "gap-3 use-margin groundwork. See docs/eu_data_mapping.md."
        ),
        "files": manifest_entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"manifest -> {OUT / 'manifest.json'}")

    readme = f"""# Eurostat `nama_10_nfa_st` / `nama_10_a64_p5` raw downloads — fixed-assets pilot (DK 2020)

Raw JSON-stat 2.0 responses from the Eurostat dissemination API, saved exactly
as delivered. Retrieval date: {RETRIEVAL_DATE}. Downloaded by
`data/preprocessing/scripts/download_fixed_assets_dk_2020.py`
(re-runnable; it skips files that already exist and validate).

Dataset: **nama_10_nfa_st** — Capital stocks by industry and detailed asset
type. Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_nfa_st/default/table

Dimensions: freq (A), unit, nace_r2, asset10, geo, time. The DK/SE files
carry all eight valuation units so the Danish input's basis (net vs gross,
current replacement cost vs chain-linked volumes) can be established from
data; the probes use `CRC_MNAC` (current replacement costs, million units of
national currency). The Danish input is bn DKK, so values divide by 1000.

Second dataset: **nama_10_a64_p5** — Capital formation by industry and
detailed asset type, `P51G` GFCF, `CP_MNAC` + `PYP_MNAC`. This is the
structural-gap-3 *use margin* source (investment by asset type x investing
industry). Source page:
https://ec.europa.eu/eurostat/databrowser/view/nama_10_a64_p5/default/table

## Files

| file | content |
|---|---|
| `nama_10_nfa_st_DK_2020.json` | Denmark 2020 stocks, all units / NACE / assets |
| `nama_10_a64_p5_DK_2020.json` | Denmark 2020 GFCF P51G, CP_MNAC+PYP_MNAC |
| `nama_10_nfa_st_SE_2020.json` | Sweden 2020 stocks, same slice (public-core pilot country) |
| `nama_10_a64_p5_SE_2020.json` | Sweden 2020 GFCF, same slice |
| `nama_10_nfa_st_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CRC_MNAC, all NACE / assets |
| `nama_10_a64_p5_eu27_coverage_probe_2020.json` | all 27 member states, 2020, CP_MNAC, P51G, all NACE / assets |
| `nama_10_nfa_st_eu27_year_probe_N11.json` | all 27 member states, all years, TOTAL N11N+N11G |
| `nama_10_a64_p5_eu27_year_probe_N11G.json` | all 27 member states, all years, TOTAL GFCF N11G |
| `manifest.json` | URLs, query parameters, SHA-256 hashes, sizes, observation counts |

Used by `data/preprocessing/scripts/reconcile_fixed_assets_dk_2020.py`,
which writes `data/preprocessing/data/fixed_assets_dk2020_reconciliation.xlsx`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(f"README -> {OUT / 'README.md'}")


if __name__ == "__main__":
    main()
