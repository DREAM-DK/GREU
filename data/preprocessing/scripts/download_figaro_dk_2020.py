"""Download FIGARO tables for Denmark, reference year 2020 (Phase 1 pilot).

Source: Eurostat dissemination API (SDMX 2.1), datasets
  naio_10_fcp_s3  - EU inter-country supply table, basic prices (2018-2021)
  naio_10_fcp_u3  - EU inter-country use table, basic prices (2018-2021)
  naio_10_fcp_ii3 - EU inter-country input-output table, industry by industry,
                    basic prices (2018-2021)
These are the FIGARO 2026-edition tables (datasets last updated 18/20 July 2026,
covering 2010-2024; 64 NACE Rev.2 industries / 64 CPA 2.1 products, 46 areas).
Official FIGARO page:
https://joint-research-centre.ec.europa.eu/projects-and-activities/trade-and-industrial-policy-analysis/input-output-accounts/figaro-tables_en

Retrieval date: 2026-07-29.

Downloads DK-relevant slices for 2020 as SDMX-CSV (raw, as delivered):
  - supply table, geo=DK (all industries x products)
  - use table and ind-by-ind IO table: c_dest=DK slice (all inputs into DK,
    incl. imports by origin country and value-added rows c_orig=DOM) and
    c_orig=DK slice (all DK-origin flows to all destinations = exports + domestic)
  - annual average DKK/EUR exchange rate 2020 (ert_bil_eur_a) for currency
    conversion in the reconciliation step.

Output: data/preprocessing/data/figaro_raw/  (never overwrites silently; will
re-download and replace files in that folder if re-run).

Run:  python data/preprocessing/scripts/download_figaro_dk_2020.py
"""

import pathlib
import time

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data"
OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "figaro_raw"
YEAR = "2020"

# (dataset, key, filename)
# Key positions:
#   naio_10_fcp_s3 : freq.nace_r2.cpa2_1.unit.geo
#   naio_10_fcp_u3 : freq.ind_use.prd_ava.c_dest.unit.c_orig
#   naio_10_fcp_ii3: freq.ind_use.ind_ava.c_dest.unit.c_orig
#   ert_bil_eur_a  : freq.statinfo.unit.currency (AVG = annual average,
#                    NAC = national currency per euro)
QUERIES = [
    ("naio_10_fcp_s3", "A....DK", "naio_10_fcp_s3_DK_2020.csv"),
    ("naio_10_fcp_u3", "A...DK..", "naio_10_fcp_u3_DKdest_2020.csv"),
    ("naio_10_fcp_u3", "A.....DK", "naio_10_fcp_u3_DKorig_2020.csv"),
    ("naio_10_fcp_ii3", "A...DK..", "naio_10_fcp_ii3_DKdest_2020.csv"),
    ("naio_10_fcp_ii3", "A.....DK", "naio_10_fcp_ii3_DKorig_2020.csv"),
    ("ert_bil_eur_a", "A.AVG.NAC.DKK", "ert_bil_eur_a_DKK_2020.csv"),
]


def is_valid_sdmx_csv(content: bytes) -> bool:
    """The API sometimes returns an HTML error page with HTTP 200."""
    return content.lstrip()[:9].upper() == b"DATAFLOW,"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for dataset, key, fname in QUERIES:
        path = OUT / fname
        if path.exists() and is_valid_sdmx_csv(path.read_bytes()):
            print(f"skip (already downloaded and valid): {path}")
            continue
        url = f"{BASE}/{dataset}/{key}"
        params = {"format": "SDMX-CSV", "startPeriod": YEAR, "endPeriod": YEAR}
        for attempt in range(1, 4):
            print(f"GET {url} {params} (attempt {attempt})")
            t0 = time.time()
            r = requests.get(url, params=params, timeout=900)
            if r.status_code == 200 and is_valid_sdmx_csv(r.content):
                path.write_bytes(r.content)
                print(f"  -> {path}  ({len(r.content):,} bytes, {time.time() - t0:.1f}s)")
                break
            print(f"  invalid response (HTTP {r.status_code}, {len(r.content):,} bytes), retrying...")
            time.sleep(30)
        else:
            raise RuntimeError(f"failed to download {dataset} {key} after 3 attempts")


if __name__ == "__main__":
    main()
