"""Probe: does nama_10_a64_p5 carry GFCF by asset type at A64 industry
detail? (structural gap 3, use margin - see docs/eu_data_mapping.md)

Background: the gap-3 task record assumed the use margin (investment by
asset type x investing industry) is only available at A21 via nama_10_nfa_st
and needs disaggregating to GREU's 57 industries. The colleague's reference
module data/read_eurostat_data/factor_demand_data.py queries nama_10_a64_p5
with an asset10 filter; this probe checks whether that dataset genuinely
publishes asset x industry investment at A64 detail, and for which
countries.

Method: pull P51G, CP_MNAC, 2020, the three GREU-relevant asset groups
(N11KG dwellings+buildings ~ iB; N1131G transport equipment ~ iT; N11MG
machinery ~ iM plus N115G cultivated resources, N117G IP products) for all
EU-27, all NACE codes, and count populated A64-level cells per country x
asset. In-memory probe; results are recorded in docs/eu_data_mapping.md
(gap-3 task record), no raw files kept.

Run:  python data/preprocessing/scripts/probe_nama_10_a64_p5_asset_detail.py
"""

from __future__ import annotations

import json

import requests

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
DATASET = "nama_10_a64_p5"
YEAR = "2020"

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

ASSETS = ["N11G", "N11KG", "N1131G", "N11MG", "N115G", "N117G"]

# The 64 industries of the A*64 breakdown (excluding aggregates).
A64 = [
    "A01", "A02", "A03", "B", "C10-C12", "C13-C15", "C16", "C17", "C18",
    "C19", "C20", "C21", "C22", "C23", "C24", "C25", "C26", "C27", "C28",
    "C29_C30", "C31_C32", "C33", "D", "E36", "E37-E39", "F", "G45", "G46",
    "G47", "H49", "H50", "H51", "H52", "H53", "I", "J58", "J59_J60", "J61",
    "J62_J63", "K64", "K65", "K66", "L", "M69_M70", "M71", "M72", "M73",
    "M74_M75", "N77", "N78", "N79", "N80-N82", "O", "P", "Q86", "Q87_Q88",
    "R90-R92", "R93", "S94", "S95", "S96", "T", "U",
]


def fetch(params: dict) -> dict:
    r = requests.get(f"{BASE}/{DATASET}", params=params, timeout=300)
    r.raise_for_status()
    payload = r.json()
    assert "value" in payload, f"unexpected response keys: {payload.keys()}"
    return payload


def flatten(payload: dict):
    dims = payload["id"]
    sizes = payload["size"]
    cats = {d: list(payload["dimension"][d]["category"]["index"]) for d in dims}
    for flat_str, val in payload["value"].items():
        flat = int(flat_str)
        idx = []
        for s in reversed(sizes):
            idx.append(flat % s)
            flat //= s
        idx.reverse()
        yield {d: cats[d][i] for d, i in zip(dims, idx)}, val


def main() -> None:
    payload = fetch({
        "geo": EU27, "time": YEAR, "unit": "CP_MNAC", "na_item": "P51G",
        "asset10": ASSETS, "lang": "en",
    })
    print("dimensions:", payload["id"])

    # populated A64-level cells per country x asset
    counts: dict[tuple[str, str], int] = {}
    nace_seen: dict[str, set] = {}
    for rec, _val in flatten(payload):
        nace_seen.setdefault(rec["geo"], set()).add(rec["nace_r2"])
        if rec["nace_r2"] in A64:
            key = (rec["geo"], rec["asset10"])
            counts[key] = counts.get(key, 0) + 1

    print(f"\nPopulated A64-level cells (of {len(A64)}) per country x asset, "
          f"P51G CP_MNAC {YEAR}:")
    header = "geo  " + "".join(f"{a:>8s}" for a in ASSETS)
    print(header)
    for geo in EU27:
        row = f"{geo:4s} " + "".join(
            f"{counts.get((geo, a), 0):8d}" for a in ASSETS)
        print(row)

    complete = [geo for geo in EU27
                if all(counts.get((geo, a), 0) >= 55
                       for a in ["N11KG", "N1131G", "N11MG"])]
    print(f"\nCountries with >=55/64 A64 industries populated for all three "
          f"key asset groups (N11KG/N1131G/N11MG): {len(complete)}/27")
    print(" ", complete)


if __name__ == "__main__":
    main()
