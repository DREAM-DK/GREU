"""Endpoint-verification probe for Eurostat PRODCOM (run 2026-07-31).

Documents, re-runnably, how the working PRODCOM endpoint was identified for
the Sweden 2020 CPA_C16 pilot:

1. ``prc_stapro`` — the dataset code claimed in docs/eu_data_mapping.md —
   returns HTTP 404 ("not available for dissemination") on both the main
   dissemination API and its SDMX dataflow registry. The claim is WRONG.
2. The legacy Comext PRODCOM code ``ds-056120`` also returns HTTP 404 on the
   main and Comext APIs: it has been decommissioned.
3. The Comext dataflow catalogue lists the current PRODCOM dataflows:
   DS-059358 (sold production, exports and imports; PRODCOM list/CPA 2.1 —
   correct vintage for reference year 2020), DS-059367 (CPA 2.2 successor),
   DS-059359/DS-059368 (total production).
4. A live sample query for Sweden 2020 wood pellets (16291500) works on both
   the JSON-stat statistics API and the SDMX-CSV data API.

Run:  python data/preprocessing/scripts/probe_prodcom_endpoint_2026_07_31.py
"""

from __future__ import annotations

import re

import requests

MAIN = "https://ec.europa.eu/eurostat/api/dissemination"
COMEXT = "https://ec.europa.eu/eurostat/api/comext/dissemination"

session = requests.Session()
session.headers["User-Agent"] = "GREU-data-probe/1.0"


def show(label: str, url: str, params: dict | None = None) -> requests.Response:
    r = session.get(url, params=params or {}, timeout=300)
    print(f"--- {label}\n    HTTP {r.status_code}  len={len(r.content)}")
    print(f"    starts: {r.text[:160]!r}")
    return r


def main() -> None:
    print("== 1. doc claim prc_stapro (expected: 404)")
    show(
        "prc_stapro via main statistics API",
        f"{MAIN}/statistics/1.0/data/prc_stapro",
        {"format": "JSON", "lang": "EN", "geo": "SE", "time": "2020"},
    )
    show("prc_stapro dataflow via main SDMX", f"{MAIN}/sdmx/2.1/dataflow/ESTAT/PRC_STAPRO")

    print("\n== 2. legacy ds-056120 (expected: 404)")
    show(
        "ds-056120 via comext statistics API",
        f"{COMEXT}/statistics/1.0/data/ds-056120",
        {"format": "JSON", "lang": "EN", "time": "2020"},
    )

    print("\n== 3. comext dataflow catalogue (expected: DS-059358 et al.)")
    r = show("comext dataflows", f"{COMEXT}/sdmx/2.1/dataflow/all?detail=allstubs")
    for m in re.finditer(r'<s:Dataflow[^>]*\bid="([^"]+)"(.*?)</s:Dataflow>', r.text, re.S):
        name = re.search(r'<c:Name xml:lang="en">(.*?)</c:Name>', m.group(2))
        print(f"    {m.group(1)}: {name.group(1) if name else '?'}")

    print("\n== 4. live sample: DS-059358, Sweden 2020, wood pellets 16291500")
    show(
        "SDMX-CSV data query",
        f"{COMEXT}/sdmx/2.1/data/DS-059358/A.SE.16291500./",
        {"format": "SDMX-CSV", "startPeriod": "2020", "endPeriod": "2020"},
    )


if __name__ == "__main__":
    main()
