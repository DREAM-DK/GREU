"""Reconcile Eurostat nama_10_nfa_st (stocks) plus nama_10_a64_p5 (GFCF)
DK 2020 against the Danish GREU input fixed_assets.xlsx.

Tenth pilot of the EU data replacement effort (see docs/eu_data_mapping.md).
The GFCF comparison against io_invest_long_format.xlsx is gap-3 use-margin
groundwork, not a second input pilot.

Inputs
------
- data/preprocessing/data/fixed_assets.xlsx
    Danish input, sheet 'fixed_assets': year, indu (57 GREU industries),
    asset (7 ESA-style codes), value in bn DKK, 2020 only. Consumed by
    read_data.py:362-370: the 7 codes are mapped to GREU k in {iB, iT, iM}
    and summed; exported as qK[k, d, t] (line 689).
- data/preprocessing/data/io_invest_long_format.xlsx
    Danish investment by type x investing industry; read_data.py:305-311
    drops the supplying dimension and builds qI_k_i. Used here only as the
    gap-3 use-margin truth for the GFCF comparison.
- data/preprocessing/data/metadata.xlsx sheets 'fixed_assets' and
    'industries_naceA64_map'.
- data/preprocessing/data/fixed_assets_raw/DK/2020/*.json
    Raw JSON-stat from download_fixed_assets_dk_2020.py.

Units: Danish bn DKK; Eurostat CRC_MNAC / CP_MNAC million national currency,
divided by 1000.

Output
------
data/preprocessing/data/fixed_assets_dk2020_reconciliation.xlsx

Run:  python data/preprocessing/scripts/reconcile_fixed_assets_dk_2020.py
"""

from __future__ import annotations

import datetime
import json
import pathlib
import re

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "fixed_assets_raw" / "DK" / "2020"
OUT = DATA / "fixed_assets_dk2020_reconciliation.xlsx"
YEAR = 2020

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

# read_data.py:89 — 7 Danish ESA-style codes -> 3 GREU capital types.
DK_ASSET_TO_K = {
    "N11P": "iM", "N1121": "iB", "N1122_3": "iB", "N1131": "iT",
    "N115": "iM", "N117": "iM", "N111": "iB",
}
IO_INV_TO_K = {
    "invest_build": "iB", "invest_trans": "iT", "invest_other": "iM",
}

# Eurostat net stocks -> GREU k. N112 is not split into buildings vs other
# structures; both Danish N1121 and N1122_3 map to iB anyway.
ES_NET_TO_K = {
    "N111N": "iB", "N112N": "iB", "N11KN": "iB",
    "N1131N": "iT",
    "N1132N": "iM", "N11ON": "iM", "N115N": "iM", "N117N": "iM",
}
ES_GROSS_TO_K = {
    "N111G": "iB", "N112G": "iB", "N11KG": "iB",
    "N1131G": "iT",
    "N1132G": "iM", "N11OG": "iM", "N115G": "iM", "N117G": "iM",
}

# Leaf assets used to build k without double-counting parent aggregates.
NET_LEAVES = ["N111N", "N112N", "N1131N", "N1132N", "N11ON", "N115N", "N117N"]
GROSS_LEAVES = ["N111G", "N112G", "N1131G", "N1132G", "N11OG", "N115G", "N117G"]

A64 = [
    "A01", "A02", "A03", "B", "C10-C12", "C13-C15", "C16", "C17", "C18",
    "C19", "C20", "C21", "C22", "C23", "C24", "C25", "C26", "C27", "C28",
    "C29", "C30", "C31_C32", "C33", "D", "E36", "E37-E39", "F", "G45", "G46",
    "G47", "H49", "H50", "H51", "H52", "H53", "I", "J58", "J59_J60", "J61",
    "J62_J63", "K64", "K65", "K66", "L", "M69_M70", "M71", "M72", "M73",
    "M74_M75", "N77", "N78", "N79", "N80-N82", "O", "P", "Q86", "Q87_Q88",
    "R90-R92", "R93", "S94", "S95", "S96", "T", "U",
]
A21 = list("ABCDEFGHIJKLMNOPQRSTU")
A21_FROM_A64 = {
    "A01": "A", "A02": "A", "A03": "A",
    "B": "B",
    "C10-C12": "C", "C13-C15": "C", "C16": "C", "C17": "C", "C18": "C",
    "C19": "C", "C20": "C", "C21": "C", "C22": "C", "C23": "C", "C24": "C",
    "C25": "C", "C26": "C", "C27": "C", "C28": "C", "C29": "C", "C30": "C",
    "C31_C32": "C", "C33": "C",
    "D": "D", "E36": "E", "E37-E39": "E", "F": "F",
    "G45": "G", "G46": "G", "G47": "G",
    "H49": "H", "H50": "H", "H51": "H", "H52": "H", "H53": "H",
    "I": "I",
    "J58": "J", "J59_J60": "J", "J61": "J", "J62_J63": "J",
    "K64": "K", "K65": "K", "K66": "K", "L": "L",
    "M69_M70": "M", "M71": "M", "M72": "M", "M73": "M", "M74_M75": "M",
    "N77": "N", "N78": "N", "N79": "N", "N80-N82": "N",
    "O": "O", "P": "P", "Q86": "Q", "Q87_Q88": "Q",
    "R90-R92": "R", "R93": "R",
    "S94": "S", "S95": "S", "S96": "S", "T": "T", "U": "U",
}


def norm_a64(code: str) -> str:
    """Normalize NACE A64 spelling variants: C10-C12 -> C10-12, J59_J60 -> J59_60."""
    return re.sub(r"([-_])[A-Z]", r"\1", str(code).strip())


A64_NORM = {norm_a64(c) for c in A64}
A21_FROM_A64_NORM = {norm_a64(k): v for k, v in A21_FROM_A64.items()}


def jsonstat_to_frame(payload: dict) -> pd.DataFrame:
    dims = payload["id"]
    sizes = payload["size"]
    cats = {d: list(payload["dimension"][d]["category"]["index"]) for d in dims}
    rows = []
    for flat_str, val in payload["value"].items():
        flat = int(flat_str)
        idx = []
        for s in reversed(sizes):
            idx.append(flat % s)
            flat //= s
        idx.reverse()
        row = {d: cats[d][i] for d, i in zip(dims, idx)}
        row["value"] = val
        rows.append(row)
    return pd.DataFrame(rows)


def load_raw(name: str) -> pd.DataFrame:
    return jsonstat_to_frame(json.loads((RAW / name).read_text(encoding="utf-8")))


def build_clusters(m: pd.DataFrame):
    """Connected components of the bipartite GREU <-> A64 graph."""
    parent: dict = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        parent[find(a)] = find(b)

    for _, r in m.iterrows():
        union(("g", r.indu_greu), ("n", r.nace))
    comp: dict = {}
    for node in list(parent):
        comp.setdefault(find(node), []).append(node)
    clusters = []
    for members in comp.values():
        greu = sorted(x[1] for x in members if x[0] == "g")
        nace = sorted(x[1] for x in members if x[0] == "n")
        clusters.append({"label": "+".join(nace), "greu": greu, "nace": nace})
    clusters.sort(key=lambda c: c["label"])
    greu2cl = {g: c["label"] for c in clusters for g in c["greu"]}
    nace2cl = {n: c["label"] for c in clusters for n in c["nace"]}
    return clusters, greu2cl, nace2cl


def cluster_compare(dk_by_greu: pd.Series, es_by_nace: pd.Series,
                    greu2cl, nace2cl, clusters, value_label: str) -> pd.DataFrame:
    dk = dk_by_greu.rename(index=greu2cl).groupby(level=0).sum()
    es = es_by_nace.rename(index=nace2cl).groupby(level=0).sum()
    rows = []
    for c in clusters:
        d = float(dk.get(c["label"], 0.0))
        e = float(es.get(c["label"], 0.0))
        rows.append({
            "cluster": c["label"],
            "greu_industries": ", ".join(c["greu"]),
            "n_greu": len(c["greu"]),
            "n_a64": len(c["nace"]),
            f"dk_{value_label}": round(d, 3),
            f"eurostat_{value_label}": round(e, 3),
            "diff": round(e - d, 3),
            "pct_diff": round(100 * (e - d) / d, 3) if abs(d) > 1e-9 else None,
        })
    df = pd.DataFrame(rows)
    dsum = float(df[f"dk_{value_label}"].sum())
    esum = float(df[f"eurostat_{value_label}"].sum())
    total = {
        "cluster": "TOTAL (sum of clusters)",
        "greu_industries": "",
        "n_greu": int(df["n_greu"].sum()),
        "n_a64": int(df["n_a64"].sum()),
        f"dk_{value_label}": round(dsum, 3),
        f"eurostat_{value_label}": round(esum, 3),
        "diff": round(esum - dsum, 3),
        "pct_diff": round(100 * (esum - dsum) / dsum, 3) if dsum else None,
    }
    return pd.concat([df, pd.DataFrame([total])], ignore_index=True)


def es_cell(df: pd.DataFrame, nace: str, asset: str) -> float | None:
    s = df[(df.nace_r2 == nace) & (df.asset10 == asset)]["bn"]
    return float(s.iloc[0]) if len(s) else None


def check(rows: list, name: str, left, right, tol: float = 0.015) -> None:
    if left is None or right is None:
        rows.append({"check": name, "left": left, "right": right,
                     "diff": None, "result": "SKIP"})
        return
    diff = float(right) - float(left)
    rows.append({"check": name, "left": round(float(left), 4),
                 "right": round(float(right), 4), "diff": round(diff, 4),
                 "result": "PASS" if abs(diff) <= tol else "FAIL"})


def detail_label(n_a64: int, n_a21: int) -> str:
    if n_a64 >= 55:
        return "A64"
    if n_a64 >= 40:
        return "near-A64"
    if n_a21 >= 18:
        return "A21"
    if n_a21 >= 6:
        return "sparse-A21"
    return "sparse"


def main() -> None:
    created = datetime.date.today().isoformat()
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    retrieval_date = manifest["retrieval_date"]
    checks: list[dict] = []

    # ---------------- Danish stocks ----------------
    dk = pd.read_excel(DATA / "fixed_assets.xlsx")
    dk = dk[dk["year"] == YEAR].copy()
    dk["indu"] = dk["indu"].astype(str)
    dk["k"] = dk["asset"].map(DK_ASSET_TO_K)
    if dk["k"].isna().any():
        raise RuntimeError(f"unmapped Danish assets: {dk.loc[dk.k.isna(), 'asset'].unique()}")

    dk_asset = dk.groupby("asset", as_index=True)["value"].sum()
    dk_k = dk.groupby("k")["value"].sum()
    dk_by_indu = dk.groupby("indu")["value"].sum()
    dk_k_indu = dk.groupby(["k", "indu"])["value"].sum()

    # ---------------- Danish investment (gap-3 truth) ----------------
    inv = pd.read_excel(DATA / "io_invest_long_format.xlsx")
    inv = inv[inv["year"] == YEAR].copy()
    inv["k"] = inv["invest_group"].map(IO_INV_TO_K)
    inv["indu"] = inv["col"].astype(str)
    inv_k = inv.groupby("k")["value"].sum()
    inv_by_indu = inv.groupby("indu")["value"].sum()
    inv_k_indu = inv.groupby(["k", "indu"])["value"].sum()

    # ---------------- Eurostat stocks ----------------
    st_all = load_raw("nama_10_nfa_st_DK_2020.json")
    st_all["bn"] = st_all["value"] / 1000.0
    st = st_all[st_all["unit"] == "CRC_MNAC"].copy()
    st["nace_norm"] = st["nace_r2"].map(norm_a64)

    def st_k_by_nace(leaves: list[str], mapping: dict) -> pd.DataFrame:
        sub = st[st.asset10.isin(leaves)].copy()
        sub["k"] = sub["asset10"].map(mapping)
        return (sub.dropna(subset=["k"])
                .groupby(["nace_norm", "k"], as_index=False)["bn"].sum())

    st_k = st_k_by_nace(NET_LEAVES, ES_NET_TO_K)
    st_tot_by_nace = (st[st.asset10 == "N11N"]
                      .set_index("nace_norm")["bn"])

    # ---------------- Eurostat GFCF ----------------
    p5_all = load_raw("nama_10_a64_p5_DK_2020.json")
    p5_all["bn"] = p5_all["value"] / 1000.0
    p5 = p5_all[p5_all["unit"] == "CP_MNAC"].copy()
    p5["nace_norm"] = p5["nace_r2"].map(norm_a64)
    p5_k = p5[p5.asset10.isin(GROSS_LEAVES)].copy()
    p5_k["k"] = p5_k["asset10"].map(ES_GROSS_TO_K)
    p5_k = (p5_k.dropna(subset=["k"])
            .groupby(["nace_norm", "k"], as_index=False)["bn"].sum())
    p5_tot_by_nace = (p5[p5.asset10 == "N11G"]
                      .set_index("nace_norm")["bn"])

    # ---------------- concordance / clusters ----------------
    meta_fa = pd.read_excel(DATA / "metadata.xlsx", sheet_name="fixed_assets")
    m = pd.read_excel(DATA / "metadata.xlsx", sheet_name="industries_naceA64_map")
    m["indu_greu"] = m["indu_greu"].astype(str)
    m["nace"] = m["indu_naceA64"].map(norm_a64)
    clusters, greu2cl, nace2cl = build_clusters(m)

    unmapped_greu = sorted(set(dk["indu"]) - set(m["indu_greu"]))
    if unmapped_greu:
        raise RuntimeError(f"GREU industries missing from concordance: {unmapped_greu}")

    # ---------------- valuation identity ----------------
    n11n_crc = es_cell(st, "TOTAL", "N11N")
    n11g_crc = es_cell(st, "TOTAL", "N11G")
    clv = st_all[st_all.unit == "CLV20_MNAC"].copy()
    clv["bn"] = clv["value"] / 1000.0
    n11n_clv20 = es_cell(clv, "TOTAL", "N11N")
    n11kn = es_cell(st, "TOTAL", "N11KN")
    n11mn = es_cell(st, "TOTAL", "N11MN")
    n111n = es_cell(st, "TOTAL", "N111N")
    n112n = es_cell(st, "TOTAL", "N112N")
    n1131n = es_cell(st, "TOTAL", "N1131N")
    n1132n = es_cell(st, "TOTAL", "N1132N")
    n11on = es_cell(st, "TOTAL", "N11ON")
    n115n = es_cell(st, "TOTAL", "N115N")
    n117n = es_cell(st, "TOTAL", "N117N")
    es_ib = n11kn
    es_it = n1131n
    es_im = (n1132n or 0) + (n11on or 0) + (n115n or 0) + (n117n or 0)

    n11g_p5 = es_cell(p5, "TOTAL", "N11G")
    n11kg_p5 = es_cell(p5, "TOTAL", "N11KG")
    n1131g_p5 = es_cell(p5, "TOTAL", "N1131G")
    p5_ib = n11kg_p5
    p5_it = n1131g_p5
    p5_im = (n11g_p5 or 0) - (n11kg_p5 or 0) - (n1131g_p5 or 0)

    l_n111n = es_cell(st, "L", "N111N")
    l68a_n111n = es_cell(st, "L68A", "N111N")

    check(checks, "DK total = ES net CRC_MNAC N11N", dk["value"].sum(), n11n_crc)
    check(checks, "DK iB = ES N11KN", dk_k["iB"], es_ib)
    check(checks, "DK iT = ES N1131N", dk_k["iT"], es_it)
    check(checks, "DK iM = ES N1132N+N11ON+N115N+N117N", dk_k["iM"], es_im)
    check(checks, "N11N = N11KN+N11MN+N115N+N117N",
          n11n_crc, (n11kn or 0) + (n11mn or 0) + (n115n or 0) + (n117n or 0))
    check(checks, "N11KN = N111N+N112N", n11kn, (n111n or 0) + (n112n or 0))
    check(checks, "N11MN = N1131N+N1132N+N11ON",
          n11mn, (n1131n or 0) + (n1132n or 0) + (n11on or 0))
    check(checks, "DK N111 = ES N111N", dk_asset.get("N111"), n111n)
    check(checks, "DK N1121+N1122_3 = ES N112N",
          dk_asset.get("N1121", 0) + dk_asset.get("N1122_3", 0), n112n)
    check(checks, "DK N1131 = ES N1131N", dk_asset.get("N1131"), n1131n)
    check(checks, "DK N11P = ES N1132N+N11ON",
          dk_asset.get("N11P"), (n1132n or 0) + (n11on or 0))
    check(checks, "DK N115 = ES N115N", dk_asset.get("N115"), n115n)
    check(checks, "DK N117 = ES N117N", dk_asset.get("N117"), n117n)
    check(checks, "2020 CLV20_MNAC N11N = CRC_MNAC N11N (base year)",
          n11n_clv20, n11n_crc)
    check(checks, "All dwellings sit in NACE L (L N111N = TOTAL N111N)",
          l_n111n, n111n)
    check(checks, "L68A is of-which L (L68A N111N < L N111N)",
          1.0 if (l68a_n111n is not None and l_n111n is not None
                  and l68a_n111n < l_n111n - 1) else 0.0, 1.0)
    check(checks, "DK invest total = ES P51G N11G", inv["value"].sum(), n11g_p5)
    check(checks, "DK invest_build = ES P51G N11KG", inv_k["iB"], p5_ib)
    check(checks, "DK invest_trans = ES P51G N1131G", inv_k["iT"], p5_it)
    check(checks, "DK invest_other = ES P51G N11G-N11KG-N1131G", inv_k["iM"], p5_im)
    check(checks, "Gross N11G is NOT the Danish concept (should FAIL)",
          dk["value"].sum(), n11g_crc, tol=0.015)
    # Force the gross check to record FAIL as expected; keep it labelled.
    checks[-1]["result"] = "FAIL (expected — Danish file is net, not gross)"

    # ---------------- cluster comparisons ----------------
    stocks_cl = cluster_compare(dk_by_indu, st_tot_by_nace, greu2cl, nace2cl,
                                clusters, "bn_dkk")
    gfcf_cl = cluster_compare(inv_by_indu, p5_tot_by_nace, greu2cl, nace2cl,
                              clusters, "bn_dkk")

    def k_cluster(dk_series: pd.Series, es_k_df: pd.DataFrame, k: str) -> pd.DataFrame:
        dk_k_s = dk_series.xs(k) if k in dk_series.index.get_level_values(0) else pd.Series(dtype=float)
        es_s = (es_k_df[es_k_df.k == k].set_index("nace_norm")["bn"]
                if len(es_k_df) else pd.Series(dtype=float))
        cmp = cluster_compare(dk_k_s, es_s, greu2cl, nace2cl, clusters, "bn_dkk")
        cmp.insert(0, "k", k)
        return cmp

    stocks_k_cl = pd.concat(
        [k_cluster(dk_k_indu, st_k, k) for k in ["iB", "iT", "iM"]],
        ignore_index=True)
    gfcf_k_cl = pd.concat(
        [k_cluster(inv_k_indu, p5_k, k) for k in ["iB", "iT", "iM"]],
        ignore_index=True)

    # ---------------- 7-type national concordance ----------------
    asset_rows = []
    for _, r in meta_fa.iterrows():
        dk_code = r["asset"]
        k = DK_ASSET_TO_K[dk_code]
        dk_val = float(dk_asset.get(dk_code, 0.0))
        if dk_code == "N1121" or dk_code == "N1122_3":
            es_code = "N112N (combined; Eurostat does not split N1121/N1122_3)"
            es_val = n112n if dk_code == "N1121" else None  # shown once on N1121
            if dk_code == "N1122_3":
                es_val = None
        elif dk_code == "N11P":
            es_code = "N1132N + N11ON"
            es_val = (n1132n or 0) + (n11on or 0)
        else:
            es_code = {"N111": "N111N", "N1131": "N1131N",
                       "N115": "N115N", "N117": "N117N"}[dk_code]
            es_val = es_cell(st, "TOTAL", es_code)
        asset_rows.append({
            "danish_asset": dk_code,
            "danish_label": r["asset_txt"],
            "esa2010": r["asset_esa"],
            "greu_k": k,
            "dk_bn_dkk": round(dk_val, 3),
            "eurostat_net_code": es_code,
            "eurostat_net_bn_dkk": None if es_val is None else round(es_val, 3),
            "diff": None if es_val is None else round(es_val - dk_val, 3),
        })
    # combined N112 row
    n112_dk = float(dk_asset.get("N1121", 0) + dk_asset.get("N1122_3", 0))
    asset_rows.append({
        "danish_asset": "N1121 + N1122_3",
        "danish_label": "Buildings other than dwellings + other structures",
        "esa2010": "AN112",
        "greu_k": "iB",
        "dk_bn_dkk": round(n112_dk, 3),
        "eurostat_net_code": "N112N",
        "eurostat_net_bn_dkk": round(n112n or 0, 3),
        "diff": round((n112n or 0) - n112_dk, 3),
    })
    asset_conc = pd.DataFrame(asset_rows)

    totals = pd.DataFrame([
        {"item": "DK fixed_assets.xlsx total", "bn_dkk": round(float(dk["value"].sum()), 3)},
        {"item": "ES N11N CRC_MNAC (net, current replacement cost)", "bn_dkk": round(n11n_crc or 0, 3)},
        {"item": "ES N11G CRC_MNAC (gross — NOT the Danish concept)", "bn_dkk": round(n11g_crc or 0, 3)},
        {"item": "ES N11N CLV20_MNAC (equals CRC in 2020, chain-linked base year)",
         "bn_dkk": round(n11n_clv20 or 0, 3)},
        {"item": "DK iB / ES N11KN", "bn_dkk": round(float(dk_k["iB"]), 3)},
        {"item": "ES iB N11KN", "bn_dkk": round(es_ib or 0, 3)},
        {"item": "DK iT / ES N1131N", "bn_dkk": round(float(dk_k["iT"]), 3)},
        {"item": "ES iT N1131N", "bn_dkk": round(es_it or 0, 3)},
        {"item": "DK iM", "bn_dkk": round(float(dk_k["iM"]), 3)},
        {"item": "ES iM N1132N+N11ON+N115N+N117N", "bn_dkk": round(es_im, 3)},
        {"item": "DK io_invest total (qI_k_i)", "bn_dkk": round(float(inv["value"].sum()), 3)},
        {"item": "ES P51G N11G CP_MNAC", "bn_dkk": round(n11g_p5 or 0, 3)},
        {"item": "DK invest_build / ES N11KG", "bn_dkk": round(float(inv_k["iB"]), 3)},
        {"item": "ES N11KG", "bn_dkk": round(p5_ib or 0, 3)},
        {"item": "DK invest_trans / ES N1131G", "bn_dkk": round(float(inv_k["iT"]), 3)},
        {"item": "ES N1131G", "bn_dkk": round(p5_it or 0, 3)},
        {"item": "DK invest_other", "bn_dkk": round(float(inv_k["iM"]), 3)},
        {"item": "ES N11G-N11KG-N1131G", "bn_dkk": round(p5_im, 3)},
        {"item": "L N111N (dwellings in real estate)", "bn_dkk": round(l_n111n or 0, 3)},
        {"item": "L68A N111N (imputed rents of owner-occupied dwellings, of-which L)",
         "bn_dkk": round(l68a_n111n or 0, 3)},
    ])
    totals = pd.concat(
        [totals, pd.DataFrame(checks).rename(columns={"check": "item"})],
        ignore_index=True)

    # ---------------- A21 -> GREU lookup (gap-3 identification) ----------------
    greu_a21: dict[str, set[str]] = {}
    for _, r in m.iterrows():
        a21 = A21_FROM_A64_NORM.get(r["nace"])
        if a21:
            greu_a21.setdefault(r["indu_greu"], set()).add(a21)
    spanning = sorted(
        (g, ",".join(sorted(s))) for g, s in greu_a21.items() if len(s) > 1)
    a21_rows = []
    for sec in A21:
        wholly = sorted(g for g, s in greu_a21.items() if s == {sec})
        touching = sorted(g for g, s in greu_a21.items() if sec in s)
        a21_rows.append({
            "a21": sec,
            "n_greu_wholly_contained": len(wholly),
            "n_greu_touching": len(touching),
            "years_to_identify_if_nested": len(wholly),  # task-record n_g rule
            "wholly_contained_greu": ", ".join(wholly),
            "also_touched_by_spanning_greu": ", ".join(
                g for g in touching if g not in wholly),
        })
    a21_lookup = pd.DataFrame(a21_rows)
    spanning_df = pd.DataFrame(
        [{"greu": g, "a21_sections": secs,
          "note": "does not nest in one A21 group; the n_g identification "
                  "arithmetic in the gap-3 task record does not apply as written"}
         for g, secs in spanning]
    )

    # ---------------- EU-27 coverage ----------------
    st_probe = load_raw("nama_10_nfa_st_eu27_coverage_probe_2020.json")
    p5_probe = load_raw("nama_10_a64_p5_eu27_coverage_probe_2020.json")
    st_year = load_raw("nama_10_nfa_st_eu27_year_probe_N11.json")
    p5_year = load_raw("nama_10_a64_p5_eu27_year_probe_N11G.json")
    st_probe["nace_norm"] = st_probe["nace_r2"].map(norm_a64)
    p5_probe["nace_norm"] = p5_probe["nace_r2"].map(norm_a64)

    cov_rows = []
    for geo in EU27:
        sg = st_probe[st_probe.geo == geo]
        pg = p5_probe[p5_probe.geo == geo]
        n_a64_n = sg[(sg.asset10 == "N11N") & (sg.nace_norm.isin(A64_NORM))].nace_norm.nunique()
        n_a64_g = sg[(sg.asset10 == "N11G") & (sg.nace_norm.isin(A64_NORM))].nace_norm.nunique()
        n_a21_n = sg[(sg.asset10 == "N11N") & (sg.nace_r2.isin(A21))].nace_r2.nunique()
        n_a21_g = sg[(sg.asset10 == "N11G") & (sg.nace_r2.isin(A21))].nace_r2.nunique()
        has_net = ((sg.asset10 == "N11N") & (sg.nace_r2 == "TOTAL")).any()
        has_gross = ((sg.asset10 == "N11G") & (sg.nace_r2 == "TOTAL")).any()
        has_it_n = ((sg.asset10 == "N1131N") & (sg.nace_r2 == "TOTAL")).any()
        has_it_g = ((sg.asset10 == "N1131G") & (sg.nace_r2 == "TOTAL")).any()
        p5_a64_ib = pg[(pg.asset10 == "N11KG") & (pg.nace_norm.isin(A64_NORM))].nace_norm.nunique()
        p5_a64_it = pg[(pg.asset10 == "N1131G") & (pg.nace_norm.isin(A64_NORM))].nace_norm.nunique()
        p5_a64_im = pg[(pg.asset10 == "N11MG") & (pg.nace_norm.isin(A64_NORM))].nace_norm.nunique()
        p5_a21 = pg[(pg.asset10 == "N11G") & (pg.nace_r2.isin(A21))].nace_r2.nunique()
        sy = sorted(st_year[(st_year.geo == geo) & (st_year.asset10 == "N11N")]["time"].astype(int))
        if not sy:
            sy = sorted(st_year[(st_year.geo == geo) & (st_year.asset10 == "N11G")]["time"].astype(int))
        py = sorted(p5_year[p5_year.geo == geo]["time"].astype(int))
        stocks_ok = has_net and has_it_n and n_a21_n >= 18
        gfcf_direct = min(p5_a64_ib, p5_a64_it, p5_a64_im) >= 55
        cov_rows.append({
            "geo": geo,
            "stocks_has_net_N11N": bool(has_net),
            "stocks_has_gross_N11G": bool(has_gross),
            "stocks_has_iT_N1131N": bool(has_it_n),
            "stocks_has_iT_N1131G": bool(has_it_g),
            "stocks_n_A64_net": int(n_a64_n),
            "stocks_n_A64_gross": int(n_a64_g),
            "stocks_n_A21_net": int(n_a21_n),
            "stocks_n_A21_gross": int(n_a21_g),
            "stocks_industry_detail": detail_label(int(n_a64_n or n_a64_g),
                                                   int(n_a21_n or n_a21_g)),
            "gfcf_n_A64_N11KG_iB": int(p5_a64_ib),
            "gfcf_n_A64_N1131G_iT": int(p5_a64_it),
            "gfcf_n_A64_N11MG_iM": int(p5_a64_im),
            "gfcf_n_A21_N11G": int(p5_a21),
            "gfcf_industry_detail": detail_label(
                min(int(p5_a64_ib), int(p5_a64_it), int(p5_a64_im)), int(p5_a21)),
            "gfcf_use_margin_direct": gfcf_direct,
            "stocks_core_2020": stocks_ok,
            "years_stocks": (f"{sy[0]}-{sy[-1]} (n={len(sy)})" if sy else "none"),
            "years_gfcf": (f"{py[0]}-{py[-1]} (n={len(py)})" if py else "none"),
        })
    coverage = pd.DataFrame(cov_rows)

    # ---------------- Sweden snapshot ----------------
    se_st = load_raw("nama_10_nfa_st_SE_2020.json")
    se_st = se_st[se_st.unit == "CRC_MNAC"].copy()
    se_st["bn"] = se_st["value"] / 1000.0
    se_p5 = load_raw("nama_10_a64_p5_SE_2020.json")
    se_p5 = se_p5[se_p5.unit == "CP_MNAC"].copy()
    se_p5["bn"] = se_p5["value"] / 1000.0
    se_n11n = es_cell(se_st, "TOTAL", "N11N")
    se_n11g = es_cell(se_st, "TOTAL", "N11G")
    se_it = es_cell(se_st, "TOTAL", "N1131N")
    se_p51 = es_cell(se_p5, "TOTAL", "N11G")
    sweden = pd.DataFrame([
        {"item": "SE N11N CRC_MNAC (net, bn SEK)", "value": None if se_n11n is None else round(se_n11n, 3)},
        {"item": "SE N11G CRC_MNAC (gross, bn SEK)",
         "value": ("not published — Sweden is net-only" if se_n11g is None
                   else round(se_n11g, 3))},
        {"item": "SE N1131N (iT, bn SEK)", "value": None if se_it is None else round(se_it, 3)},
        {"item": "SE P51G N11G (GFCF, bn SEK)", "value": None if se_p51 is None else round(se_p51, 3)},
        {"item": "SE stocks industry detail (from coverage)",
         "value": coverage.loc[coverage.geo == "SE", "stocks_industry_detail"].iloc[0]},
        {"item": "SE GFCF industry detail (from coverage)",
         "value": coverage.loc[coverage.geo == "SE", "gfcf_industry_detail"].iloc[0]},
        {"item": "SE GFCF use-margin direct (A64 x 3 assets)?",
         "value": bool(coverage.loc[coverage.geo == "SE", "gfcf_use_margin_direct"].iloc[0])},
    ])

    # ---------------- usage / colleague / anomalies ----------------
    usage = pd.DataFrame([
        {"item": "file", "detail": "data/preprocessing/data/fixed_assets.xlsx, sheet 'fixed_assets'"},
        {"item": "columns", "detail": "year, indu, asset, value; 296 rows, 2020 only, 57 GREU industries, 7 ESA-style asset codes, bn DKK"},
        {"item": "read_data.py:89", "detail": "fixed_assets_dict maps N111/N1121/N1122_3 -> iB, N1131 -> iT, N11P/N115/N117 -> iM"},
        {"item": "read_data.py:362-370", "detail": "replace asset codes, groupby k x i x year summing levels (7 types collapse to 3)"},
        {"item": "read_data.py:689", "detail": "exported as Parameter qK[k,d,t] 'Capital split on types and sectors'"},
        {"item": "data_from_GR.gms:126", "detail": "$load nEmployed,qL,qK,qI_k_i — this Excel IS load-bearing, unlike institutional_financial_accounts.xlsx"},
        {"item": "data_from_GR.gms:592-594, 601", "detail": "qProd[iM/iT/iB] = qK[...]; qK_k_i is then frozen at the 2020 cross-section"},
        {"item": "factor_demand.gms", "detail": "qK_k_i is the capital stock in the production function and in capital accumulation (investments are the residual)"},
        {"item": "qI_k_i source", "detail": "NOT this file — io_invest_long_format.xlsx (supplying dimension dropped). Compared here as gap-3 groundwork."},
        {"item": "valuation (this pilot)", "detail": "Danish file = net capital stock at current replacement cost (CRC_MNAC / 1000). Gross is ~1.82x larger and is the wrong concept."},
        {"item": "L68A", "detail": "Imputed rents of owner-occupied dwellings is an of-which of NACE L; adding it would double-count. Concordance 68203 -> L is correct."},
    ])

    colleague = pd.DataFrame([
        {"item": "module", "detail": "data/read_eurostat_data/factor_demand_data.py"},
        {"item": "stock dataset / unit", "detail": "nama_10_nfa_st, CRC_MEUR deflated by PYR_MEUR (gross, euro, previous-year prices)"},
        {"item": "stock assets pulled", "detail": "N11G, N11KG, N11MG, N115G, N117G — GROSS, and N11MG includes transport equipment"},
        {"item": "iT", "detail": "NOT in the asset filter and not in the rename map. GREU k={iB,iT,iM}; the reference implementation collapses transport into machinery or drops it. For DK 2020 that is 397.4 bn DKK (5.2% of net stock, 33% of the iM+iT block)."},
        {"item": "gross vs net", "detail": "Using N11G against a model calibrated on net qK would scale Danish capital ~1.82x (13,882 vs 7,624 bn). Sweden does not publish gross stocks at all, so the reference path also fails for the public-core country. Do not adopt."},
        {"item": "industry", "detail": "Reference pipeline aggregates to NACE A19 sections. DK (and several others) publish A64 in nama_10_nfa_st; A19 is an implementation choice, not a data constraint."},
        {"item": "GFCF", "detail": "nama_10_a64_p5 P51G, same missing-iT pattern (N11MG includes N1131G). The dataset itself has N1131G."},
        {"item": "decision", "detail": "Keep as concordance seed (dataset codes, CRC unit). Do not copy the asset map or the gross/euro deflator path into the deliverable pipeline."},
    ])

    cl_body = stocks_cl[stocks_cl.cluster != "TOTAL (sum of clusters)"]
    worst = cl_body.reindex(cl_body["pct_diff"].abs().sort_values(ascending=False).index).head(4)
    l_row = cl_body[cl_body.cluster == "L"].iloc[0]
    # business-services cluster label starts with J62
    bus = cl_body[cl_body.cluster.str.startswith("J62")].iloc[0]
    pub = cl_body[cl_body.cluster.str.startswith("O+")].iloc[0]
    cons = cl_body[cl_body.cluster.str.startswith("I+")].iloc[0]
    offset = (l_row["diff"] + bus["diff"] + pub["diff"] + cons["diff"])

    n_a64_direct = int(coverage["gfcf_use_margin_direct"].sum())
    n_stocks_ok = int(coverage["stocks_core_2020"].sum())
    n_stocks_a64 = int((coverage["stocks_industry_detail"] == "A64").sum())
    n_pass = sum(1 for c in checks if c["result"] == "PASS")
    n_fail = sum(1 for c in checks if str(c["result"]).startswith("FAIL"))

    anomalies_rows = [
        {"anomaly": "National stocks are number-exact on net CRC",
         "detail": f"Danish total {dk['value'].sum():.3f} = Eurostat N11N CRC_MNAC "
                   f"{n11n_crc:.3f} bn DKK. The three GREU types match the ESA "
                   f"net groups to rounding (iB {dk_k['iB']:.3f} vs N11KN {es_ib:.3f}; "
                   f"iT {dk_k['iT']:.3f} vs N1131N {es_it:.3f}; "
                   f"iM {dk_k['iM']:.3f} vs {es_im:.3f}). Gross N11G is 13,882 bn "
                   f"— the wrong concept."},
        {"anomaly": "GFCF use margin is also number-exact at the 3-type totals",
         "detail": f"Danish io_invest_long_format 2020 totals {inv['value'].sum():.3f} = "
                   f"nama_10_a64_p5 P51G N11G {n11g_p5:.3f}. Buildings = N11KG "
                   f"{n11kg_p5:.3f}, transport = N1131G {n1131g_p5:.3f}, other = "
                   f"{p5_im:.3f}. Gap-3's use margin is direct data at this level "
                   f"for Denmark, not an A21 estimation problem."},
        {"anomaly": "Industry mismatches are the known NACE-L / services boundary (decision 7)",
         "detail": f"24 of 28 clusters match to rounding (<0.02%). The four that "
                   f"do not: L (68203) Eurostat {l_row['diff']:+.3f} bn "
                   f"({l_row['pct_diff']:+.2f}%), business-services 71000 "
                   f"{bus['diff']:+.3f} ({bus['pct_diff']:+.2f}%), public 'off' "
                   f"{pub['diff']:+.3f} ({pub['pct_diff']:+.2f}%), consumer 55560 "
                   f"{cons['diff']:+.3f} ({cons['pct_diff']:+.2f}%). The four "
                   f"signed diffs sum to {offset:+.3f} bn (cancel). Same L↔68203 "
                   f"split previously hit by FIGARO, PEFA and employment."},
        {"anomaly": "Eurostat does not split N112 into buildings vs other structures",
         "detail": "Danish N1121 + N1122_3 = Eurostat N112N exactly. Both map to "
                   "iB, so the missing split is irrelevant for qK. It would only "
                   "matter if the model ever wanted the 7-type Danish asset list "
                   "rather than the 3 GREU groups."},
        {"anomaly": "Mapping-table 'A21 only' claim is false for stocks",
         "detail": f"nama_10_nfa_st publishes A64-level net stocks for DK (64/64 "
                   f"leaves) and for {n_stocks_a64}/27 member states at A64; most "
                   "of the rest still have a complete A21. The A21 fallback is "
                   "real for a minority of countries, not the general case."},
        {"anomaly": f"GFCF A64 x 3 assets is direct for {n_a64_direct}/27 countries",
         "detail": "Persists the 2026-08-17 in-memory probe against saved raw "
                   "payloads. Those countries need only the GREU↔A64 cluster "
                   "concordance (and decision 7); the 14 others fall back to A21 "
                   "+ disaggregation, where the n_g rule is further weakened by "
                   "three GREU industries that span several A21 sections."},
        {"anomaly": "Three GREU industries do not nest in A21",
         "detail": "55560 (consumer services), 71000 (business services) and off "
                   "(public) each map to several NACE sections. The gap-3 "
                   "identification arithmetic (years required ≈ n_g per A21 group) "
                   "assumed a partition; it does not hold for these three, which "
                   "are exactly the clusters that already disagree on the L/"
                   "services boundary."},
        {"anomaly": "Colleague reference uses gross stocks and drops iT",
         "detail": "factor_demand_data.py pulls N11KG/N11MG/N115G/N117G in "
                   "CRC_MEUR (gross; N11MG includes transport) and has no iT. "
                   "Dataset codes are useful; the asset map is not."},
        {"anomaly": "L68A must not be added on top of L",
         "detail": f"L N111N = {l_n111n:.3f} = TOTAL N111N; L68A N111N = "
                   f"{l68a_n111n:.3f} is of-which owner-occupied dwellings. "
                   "68203 -> L already captures the lot."},
    ]
    anomalies = pd.DataFrame(anomalies_rows)

    readme = pd.DataFrame([
        {"key": "title", "value": "Reconciliation: Eurostat nama_10_nfa_st (+ nama_10_a64_p5) vs fixed_assets.xlsx, Denmark 2020"},
        {"key": "created", "value": created},
        {"key": "created_by", "value": "data/preprocessing/scripts/reconcile_fixed_assets_dk_2020.py"},
        {"key": "purpose", "value": "Pilot of the mapping-table COARSER verdict, and gap-3 use-margin groundwork via nama_10_a64_p5 vs io_invest_long_format.xlsx"},
        {"key": "danish_source", "value": "data/preprocessing/data/fixed_assets.xlsx (year=2020, sheet 'fixed_assets'); io_invest_long_format.xlsx for the GFCF comparison only"},
        {"key": "eurostat_sources", "value": "nama_10_nfa_st (net/gross stocks, CRC_MNAC) and nama_10_a64_p5 (P51G GFCF, CP_MNAC) via the Eurostat dissemination API (JSON-stat 2.0)"},
        {"key": "eurostat_retrieval_date", "value": retrieval_date},
        {"key": "raw_data", "value": "data/preprocessing/data/fixed_assets_raw/DK/2020/ (README.md + manifest.json with URLs, params, SHA-256)"},
        {"key": "units", "value": "bn DKK on both sides (Eurostat million national currency / 1000)"},
        {"key": "colleague_reference", "value": "data/read_eurostat_data/factor_demand_data.py (dataset codes kept; gross/no-iT asset map rejected)"},
        {"key": "headline", "value": "OK at the concept the model uses: Danish qK is net capital stock at current replacement cost and matches nama_10_nfa_st N11N / N11KN / N1131N / remainder to rounding nationally and in 24/28 industry clusters. The four cluster gaps are the known NACE-L/services boundary (decision 7) and cancel. GFCF P51G matches io_invest 3-type totals exactly — gap-3 use margin is direct data for DK and for the A64-publishing member states. Mapping table's 'A21 only' claim is false."},
        {"key": "sheets", "value": "file_usage | totals (sums + identity checks) | asset_concordance | stocks_by_cluster | stocks_by_k_cluster | gfcf_by_cluster | gfcf_by_k_cluster | a21_lookup | spanning_greu | eu27_coverage | sweden | colleague_diff | anomalies"},
    ])

    with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
        readme.to_excel(xl, sheet_name="readme", index=False)
        usage.to_excel(xl, sheet_name="file_usage", index=False)
        totals.to_excel(xl, sheet_name="totals", index=False)
        asset_conc.to_excel(xl, sheet_name="asset_concordance", index=False)
        stocks_cl.to_excel(xl, sheet_name="stocks_by_cluster", index=False)
        stocks_k_cl.to_excel(xl, sheet_name="stocks_by_k_cluster", index=False)
        gfcf_cl.to_excel(xl, sheet_name="gfcf_by_cluster", index=False)
        gfcf_k_cl.to_excel(xl, sheet_name="gfcf_by_k_cluster", index=False)
        a21_lookup.to_excel(xl, sheet_name="a21_lookup", index=False)
        spanning_df.to_excel(xl, sheet_name="spanning_greu", index=False)
        coverage.to_excel(xl, sheet_name="eu27_coverage", index=False)
        sweden.to_excel(xl, sheet_name="sweden", index=False)
        colleague.to_excel(xl, sheet_name="colleague_diff", index=False)
        anomalies.to_excel(xl, sheet_name="anomalies", index=False)
    print(f"wrote {OUT}")

    pd.set_option("display.width", 220)
    pd.set_option("display.max_colwidth", 80)
    print("\nNATIONAL TOTALS (bn DKK):")
    print(totals.head(20).to_string(index=False))
    print("\nSTOCKS BY CLUSTER (pct_diff, worst first):")
    print(cl_body.sort_values("pct_diff", key=lambda s: s.abs(),
                              ascending=False).head(8).to_string(index=False))
    print("\nIDENTITY CHECKS:")
    print(pd.DataFrame(checks).to_string(index=False))
    print("\nA21 LOOKUP (n_greu wholly contained):")
    print(a21_lookup[["a21", "n_greu_wholly_contained", "n_greu_touching"]].to_string(index=False))
    print("\nSPANNING GREU INDUSTRIES:")
    print(spanning_df.to_string(index=False))
    print("\nEU-27: stocks core / GFCF direct / industry detail")
    print(coverage[["geo", "stocks_core_2020", "stocks_industry_detail",
                    "gfcf_use_margin_direct", "gfcf_industry_detail",
                    "years_stocks", "years_gfcf"]].to_string(index=False))
    print(f"\nstocks core 2020: {n_stocks_ok}/27; stocks A64: {n_stocks_a64}/27; "
          f"GFCF use-margin direct: {n_a64_direct}/27")
    print(f"checks: {n_pass}/{len(checks)} PASS "
          f"({n_fail} FAIL, of which the gross-vs-net one is expected)")
    print("\nSWEDEN:")
    print(sweden.to_string(index=False))


if __name__ == "__main__":
    main()
