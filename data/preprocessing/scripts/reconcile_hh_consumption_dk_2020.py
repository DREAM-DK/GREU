"""Reconcile Eurostat nama_10_co3_p3 (household FCE by COICOP 1999)
against the 12 GREU consumption groups in io_long_format.xlsx,
Denmark 2020.

Twelfth pilot of the EU data replacement effort (see docs/eu_data_mapping.md).
FIGARO (Pilot 1) already matched the household *total*. This script tests the
untested purpose split: whether 3-digit COICOP uniquely identifies each GREU
group, and how the levels/shares compare.

There is no separate household-consumption Excel. The 12 groups are the `d`
columns of io_long_format.xlsx under col_l1 in {cons_hh, cons_hh_foreign}.
read_data.py:220-238 adds those two columns (the model has no tourist split);
data_from_GR.gms:414-517 builds vD[d,t] / qD[d,t]; input_output.gms:141 sets
vC[t] = sum(c, vD[c,t]); consumption_disaggregated.gms:87 calibrates the CES
nest qCHh / uCHh from qD[c,t1]. Dummy equal shares would mis-calibrate
food/housing/cars/tourism.

Inputs
------
- data/preprocessing/data/io_long_format.xlsx sheet io (year=2020).
- data/preprocessing/data/metadata.xlsx sheets cons_hh, cons_hh_coicop_map.
- data/preprocessing/data/hh_consumption_raw/DK/2020/*.json
  (from download_hh_consumption_dk_2020.py).
- data/preprocessing/data/figaro_raw/ (Pilot 1) to recompute the P3 identity.

Units: GREU bn DKK; Eurostat CP_MNAC (million national currency) / 1000.

Output
------
data/preprocessing/data/hh_consumption_dk2020_reconciliation.xlsx

Run:  python data/preprocessing/scripts/reconcile_hh_consumption_dk_2020.py
"""

from __future__ import annotations

import datetime
import json
import pathlib
from collections import defaultdict

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "hh_consumption_raw" / "DK" / "2020"
FIGARO_RAW = DATA / "figaro_raw"
OUT = DATA / "hh_consumption_dk2020_reconciliation.xlsx"
YEAR = 2020

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

GREU_C = [
    "cFoodVeg", "cFoodMeat", "cFoodFish", "cFoodDairy", "cFoodBev",
    "cCar", "cCarEne", "cHou", "cHouEne", "cNonFood", "cSer", "cTou",
]

def jsonstat_to_frame(payload: dict) -> pd.DataFrame:
    dims = payload["id"]
    sizes = payload["size"]
    cats = {d: list(payload["dimension"][d]["category"]["index"]) for d in dims}
    labels = {}
    for d in dims:
        lab = payload["dimension"][d]["category"].get("label", {})
        labels[d] = lab
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
        if "coicop" in row:
            row["coicop_label"] = labels.get("coicop", {}).get(row["coicop"], "")
        rows.append(row)
    return pd.DataFrame(rows)


def load_raw(name: str) -> pd.DataFrame:
    return jsonstat_to_frame(json.loads((RAW / name).read_text(encoding="utf-8")))


def ecoicop5(raw) -> str | None:
    """Pad Danish map floats (1111.0 = cereals) to 5-digit ECOICOP 1999."""
    if pd.isna(raw):
        return None
    s = str(int(raw))
    if len(s) <= 4:
        s = s.zfill(5)
    return s


def to_cp(eco: str, digits: int) -> str:
    return "CP" + eco[:digits]


def coicop_depth(code: str) -> int | None:
    if code == "TOTAL":
        return 0
    if not isinstance(code, str) or not code.startswith("CP"):
        return None
    rest = code[2:]
    if rest.isdigit():
        return len(rest)
    return None  # aggregates such as CP122_127


def build_clusters(map3: pd.DataFrame):
    """Connected components of the bipartite GREU <-> 3-digit COICOP graph."""
    parent: dict = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        parent[find(a)] = find(b)

    for _, r in map3.iterrows():
        union(("g", str(r.cons_hh_greu)), ("c", str(r.cp3)))
    # Groups with no mapped 3-digit code still need a component.
    for g in GREU_C:
        parent.setdefault(("g", g), ("g", g))

    comp: dict = defaultdict(list)
    for node in list(parent):
        comp[find(node)].append(node)
    clusters = []
    for members in comp.values():
        greu = sorted(x[1] for x in members if x[0] == "g")
        codes = sorted(x[1] for x in members if x[0] == "c")
        clusters.append({"label": "+".join(codes) if codes else "UNMAPPED",
                         "greu": greu, "codes": codes})
    clusters.sort(key=lambda c: (c["label"] == "UNMAPPED", c["label"]))
    greu2cl = {g: c["label"] for c in clusters for g in c["greu"]}
    return clusters, greu2cl


def check(rows: list, name: str, left, right, tol: float = 0.5,
          rel_tol: float | None = None, note: str = "") -> None:
    if left is None or right is None or pd.isna(left) or pd.isna(right):
        rows.append({"check": name, "left": left, "right": right,
                     "diff": None, "result": "SKIP", "note": note})
        return
    left_f = float(left)
    right_f = float(right)
    diff = right_f - left_f
    ok = abs(diff) <= tol
    if rel_tol is not None:
        scale = max(abs(left_f), abs(right_f), 1e-9)
        ok = ok or abs(diff) / scale <= rel_tol
    rows.append({
        "check": name,
        "left": round(left_f, 4),
        "right": round(right_f, 4),
        "diff": round(diff, 4),
        "result": "PASS" if ok else "FAIL",
        "note": note,
    })


def coicop_bn(df: pd.DataFrame, code: str, unit: str = "CP_MNAC") -> float:
    s = df[(df["unit"] == unit) & (df["coicop"] == code)]["value"]
    if len(s) == 0:
        return float("nan")
    return float(s.sum()) / 1000.0


def codes_bn(df: pd.DataFrame, codes: list[str], unit: str = "CP_MNAC") -> float:
    total = 0.0
    any_obs = False
    for c in codes:
        v = coicop_bn(df, c, unit)
        if pd.notna(v):
            total += v
            any_obs = True
    return total if any_obs else float("nan")


def main() -> None:
    created = datetime.date.today().isoformat()
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    retrieval_date = manifest["retrieval_date"]
    checks: list[dict] = []

    dk_payload = json.loads(
        (RAW / f"nama_10_co3_p3_DK_{YEAR}.json").read_text(encoding="utf-8")
    )
    dk_co = jsonstat_to_frame(dk_payload)
    se_co = load_raw(f"nama_10_co3_p3_SE_{YEAR}.json")
    cov = load_raw(f"nama_10_co3_p3_eu27_coverage_probe_{YEAR}.json")
    years = load_raw("nama_10_co3_p3_eu27_year_probe_TOTAL.json")
    dim_coicop = set(dk_payload["dimension"]["coicop"]["category"]["index"])

    io = pd.read_excel(DATA / "io_long_format.xlsx", sheet_name="io")
    io = io[io["year"] == YEAR].copy()
    io["col_l1"] = io["col_l1"].astype(str)
    io["col_l2"] = io["col_l2"].astype(str)
    io["row_l1"] = io["row_l1"].astype(str)
    io["row_l2"] = io["row_l2"].astype(str)

    labels = pd.read_excel(DATA / "metadata.xlsx", sheet_name="cons_hh")
    labels["cons_hh_greu"] = labels["cons_hh_greu"].astype(str)
    label_map = dict(zip(labels["cons_hh_greu"], labels["cons_hh_greu_txt"]))

    cmap = pd.read_excel(DATA / "metadata.xlsx", sheet_name="cons_hh_coicop_map")
    cmap["cons_hh_greu"] = cmap["cons_hh_greu"].astype(str)
    n_map_rows = len(cmap)
    n_map_na = int(cmap["coicop"].isna().sum())

    cmap_ok = cmap.dropna(subset=["coicop"]).copy()
    cmap_ok["eco"] = cmap_ok["coicop"].map(ecoicop5)
    cmap_ok["cp2"] = cmap_ok["eco"].map(lambda s: to_cp(s, 2))
    cmap_ok["cp3"] = cmap_ok["eco"].map(lambda s: to_cp(s, 3))

    published_3 = {
        c for c in dk_co["coicop"].unique() if coicop_depth(c) == 3
    }
    cmap_ok["cp3_published"] = cmap_ok["cp3"].isin(published_3)

    # ---------------- GREU household columns (same add as read_data.py) ------
    hh = io[io["col_l1"].str.contains("cons_hh")].copy()
    # prim_input on these columns is only tax_products + tax_vat, so the
    # all-rows total is the CES purchaser vD analogue
    # (vD_base = prod+imp, vtYM = TaxSub+Moms, vD = sum).
    by_group = (
        hh.groupby(["col_l1", "col_l2"], as_index=False)["value"].sum()
        .pivot(index="col_l2", columns="col_l1", values="value")
        .reindex(GREU_C)
        .fillna(0.0)
    )
    if "cons_hh" not in by_group.columns:
        by_group["cons_hh"] = 0.0
    if "cons_hh_foreign" not in by_group.columns:
        by_group["cons_hh_foreign"] = 0.0
    by_group["ces_vd"] = by_group["cons_hh"] + by_group["cons_hh_foreign"]
    dk_cons_hh = float(by_group["cons_hh"].sum())
    dk_foreign = float(by_group["cons_hh_foreign"].sum())
    dk_ces = float(by_group["ces_vd"].sum())

    # Confirm prim_input composition.
    prim_hh = hh[hh["row_l1"] == "prim_input"]
    prim_kinds = sorted(prim_hh["row_l2"].unique().tolist())
    tax_hh = float(
        prim_hh[prim_hh["row_l2"].isin(["tax_products", "tax_vat"])]["value"].sum()
    )

    # ---------------- FIGARO P3 identity (recompute, do not paste) ----------
    ert = pd.read_csv(FIGARO_RAW / "ert_bil_eur_a_DKK_2020.csv")
    rate = float(ert.loc[ert["TIME_PERIOD"].astype(str) == str(YEAR), "OBS_VALUE"].iloc[0])
    meur_to_bndkk = rate / 1000.0
    ii_dest = pd.read_csv(FIGARO_RAW / "naio_10_fcp_ii3_DKdest_2020.csv")
    ii_dest["bn_dkk"] = ii_dest["OBS_VALUE"] * meur_to_bndkk
    dom = ii_dest[ii_dest.c_orig == "DOM"]

    def fig_fd_total(code: str) -> float:
        return float(
            ii_dest[(ii_dest.ind_use == code) & (ii_dest.c_orig != "DOM")]["bn_dkk"].sum()
            + dom[(dom.ind_use == code) & (dom.ind_ava == "D21X31")]["bn_dkk"].sum()
        )

    fig_p3_s14 = fig_fd_total("P3_S14")
    fig_p3_s15 = fig_fd_total("P3_S15")
    fig_op_res = float(dom[dom.ind_ava == "OP_RES"]["bn_dkk"].sum())
    fig_op_nres = float(dom[dom.ind_ava == "OP_NRES"]["bn_dkk"].sum())
    fig_cons_hh = fig_p3_s14 + fig_p3_s15 + fig_op_res + fig_op_nres

    eu_total = coicop_bn(dk_co, "TOTAL")

    check(checks, "IO cons_hh column = FIGARO P3_S14+P3_S15+OP_RES+OP_NRES",
          dk_cons_hh, fig_cons_hh, tol=0.05,
          note="Pilot 1 identity, recomputed from figaro_raw")
    check(checks, "IO cons_hh_foreign = abs(FIGARO OP_NRES)",
          dk_foreign, abs(fig_op_nres), tol=0.05,
          note="File stores the foreign column positive; Pilot 1 wrote the identity as -OP_NRES")
    check(checks, "prim_input on household columns is only tax_products+tax_vat",
          float(len(prim_kinds)), 2.0, tol=0,
          note=f"row_l2={prim_kinds}; CES vD = all-rows total")
    check(checks, "nama_10_co3_p3 TOTAL vs FIGARO P3_S14 (same S14 household concept)",
          eu_total, fig_p3_s14, rel_tol=0.05,
          note="Purchaser COICOP vs FIGARO basic-plus-product-taxes; remaining gap is valuation")
    check(checks, "nama_10_co3_p3 TOTAL vs IO cons_hh (S14 vs S14+S15+tourism)",
          eu_total, dk_cons_hh, rel_tol=0.02,
          note="FAIL expected: COICOP is S14 only; Danish column includes NPISH and OP_RES/OP_NRES")
    check(checks, "nama_10_co3_p3 TOTAL vs CES vD (cons_hh+cons_hh_foreign)",
          eu_total, dk_ces, rel_tol=0.02,
          note="FAIL expected: read_data.py adds the two columns; CES calibrates on the sum")

    # ---------------- spanning lookup --------------------------------------
    span_rows = []
    for cp3, sub in cmap_ok.groupby("cp3"):
        groups = sorted(sub["cons_hh_greu"].unique().tolist())
        span_rows.append({
            "cp3": cp3,
            "published_in_nama": cp3 in published_3,
            "n_greu": len(groups),
            "spans": len(groups) > 1,
            "greu_groups": "+".join(groups),
            "n_map_rows": len(sub),
            "sample_txt": "; ".join(
                sorted(set(sub["coicop_txt"].dropna().astype(str)))[:4]
            ),
        })
    spanning = pd.DataFrame(span_rows).sort_values(["spans", "cp3"],
                                                   ascending=[False, True])

    span2_rows = []
    for cp2, sub in cmap_ok.groupby("cp2"):
        groups = sorted(sub["cons_hh_greu"].unique().tolist())
        span2_rows.append({
            "cp2": cp2,
            "n_greu": len(groups),
            "spans": len(groups) > 1,
            "greu_groups": "+".join(groups),
            "n_map_rows": len(sub),
        })
    spanning2 = pd.DataFrame(span2_rows).sort_values(["spans", "cp2"],
                                                     ascending=[False, True])

    map_pub = cmap_ok[cmap_ok["cp3_published"]].copy()
    clusters, greu2cl = build_clusters(map_pub)
    # Rebuild uniqueness from published 3-digit codes only.
    code_to_g = (
        map_pub.groupby("cp3")["cons_hh_greu"]
        .apply(lambda s: sorted(set(s.astype(str))))
        .to_dict()
    )
    g_to_codes = (
        map_pub.groupby("cons_hh_greu")["cp3"]
        .apply(lambda s: sorted(set(s.astype(str))))
        .to_dict()
    )

    unique_groups = []
    for g in GREU_C:
        codes = g_to_codes.get(g, [])
        if not codes:
            continue
        if all(code_to_g.get(c, []) == [g] for c in codes):
            unique_groups.append(g)

    n_span3 = int((spanning["spans"] & spanning["published_in_nama"]).sum())
    check(checks, "3-digit COICOP uniquely identifies all 12 GREU groups",
          float(len(unique_groups)), 12.0, tol=0,
          note=f"uniquely identified={unique_groups}; published 3-digit parents that span={n_span3}")

    unmapped_13 = cmap_ok[~cmap_ok["cp3_published"]]
    unpublished_codes = sorted(unmapped_13["cp3"].unique().tolist())
    empty_in_dim = sorted(c for c in unpublished_codes if c in dim_coicop)
    not_in_dim = sorted(c for c in unpublished_codes if c not in dim_coicop)
    check(checks, "map 3-digit codes absent from nama_10_co3_p3 1999 dimension",
          float(len(not_in_dim)), 0.0, tol=0,
          note=(
              f"COICOP 2018-style extras in the Danish map, not in the 1999 table: "
              f"{not_in_dim}. Empty-but-in-dimension (DK 2020 no observation): "
              f"{empty_in_dim} (CP023 label in 1999 is Narcotics; map uses 023 for tobacco)."
          ))

    # ---------------- group-by-group ---------------------------------------
    group_rows = []
    for g in GREU_C:
        codes = g_to_codes.get(g, [])
        cluster = greu2cl.get(g, "UNMAPPED")
        unique = g in unique_groups
        dk_g = float(by_group.loc[g, "ces_vd"]) if g in by_group.index else 0.0
        dk_hh = float(by_group.loc[g, "cons_hh"]) if g in by_group.index else 0.0
        dk_f = float(by_group.loc[g, "cons_hh_foreign"]) if g in by_group.index else 0.0
        extra_note = ""
        if unique:
            eu_g = codes_bn(dk_co, codes)
            result = "UNIQUE"
            used = "+".join(codes)
        elif not codes:
            eu_g = float("nan")
            result = "MISS"
            used = ""
            extra_note = "No COICOP in cons_hh_coicop_map (cTou)."
        else:
            # Do not copy the connected-component Eurostat total onto a
            # single GREU group (cSer links housing, non-food and car energy
            # into one giant cluster). Levels live on the clusters sheet.
            eu_g = float("nan")
            result = "CLUSTER"
            used = "+".join(codes)
            extra_note = (
                "3-digit parent(s) also used by another GREU group; "
                "do not compare this row's level to a COICOP total "
                "(see clusters / spanning_3digit)."
            )
        share_dk = dk_g / dk_ces if dk_ces else float("nan")
        share_eu = eu_g / eu_total if (pd.notna(eu_g) and eu_total) else float("nan")
        if result == "UNIQUE" and pd.notna(eu_g):
            scale = max(abs(dk_g), abs(eu_g), 1e-9)
            level_ok = abs(eu_g - dk_g) / scale <= 0.10 or abs(eu_g - dk_g) <= 1.0
            share_ok = pd.notna(share_eu) and abs(share_eu - share_dk) <= 0.02
            result = "PASS" if (level_ok and share_ok) else "FAIL"
            extra_note = "PASS requires level within 10% and share within 2pp"
            if g == "cFoodBev":
                extra_note += (
                    "; map is COICOP 2018-style (tobacco=023) vs nama 1999 "
                    "(tobacco=CP022). Unique published codes are beverages only."
                )
            check(checks, f"unique group {g} CES vs COICOP {used}",
                  dk_g, eu_g, rel_tol=0.10, note=extra_note)
        group_rows.append({
            "greu": g,
            "label": label_map.get(g, ""),
            "identification": (
                "unique" if g in unique_groups
                else ("unmapped" if not codes else "spans")
            ),
            "cluster": cluster,
            "coicop_codes": used,
            "dk_cons_hh_bn": round(dk_hh, 4),
            "dk_cons_hh_foreign_bn": round(dk_f, 4),
            "dk_ces_vd_bn": round(dk_g, 4),
            "eurostat_bn": None if pd.isna(eu_g) else round(float(eu_g), 4),
            "diff_bn": None if pd.isna(eu_g) else round(float(eu_g) - dk_g, 4),
            "share_dk": round(share_dk, 4),
            "share_eu": None if pd.isna(share_eu) else round(float(share_eu), 4),
            "share_pp_diff": (
                None if pd.isna(share_eu)
                else round(100.0 * (float(share_eu) - share_dk), 2)
            ),
            "result": result,
            "note": extra_note,
        })
    groups_df = pd.DataFrame(group_rows)

    # Cluster-level comparison (one row per connected component).
    cluster_rows = []
    for cl in clusters:
        dk_cl = float(by_group.reindex(cl["greu"])["ces_vd"].sum())
        eu_cl = codes_bn(dk_co, cl["codes"]) if cl["codes"] else float("nan")
        share_dk = dk_cl / dk_ces if dk_ces else float("nan")
        share_eu = eu_cl / eu_total if (pd.notna(eu_cl) and eu_total) else float("nan")
        n_g = len(cl["greu"])
        unique = n_g == 1 and cl["greu"][0] in unique_groups
        if pd.isna(eu_cl):
            result = "MISS"
        elif unique:
            scale = max(abs(dk_cl), abs(eu_cl), 1e-9)
            result = (
                "PASS" if abs(eu_cl - dk_cl) / scale <= 0.10 else "FAIL"
            )
        else:
            result = "CLUSTER"
        cluster_rows.append({
            "cluster": cl["label"],
            "kind": "connected_component",
            "n_greu": n_g,
            "greu_groups": "+".join(cl["greu"]),
            "coicop_codes": "+".join(cl["codes"]),
            "dk_ces_vd_bn": round(dk_cl, 4),
            "eurostat_bn": None if pd.isna(eu_cl) else round(float(eu_cl), 4),
            "diff_bn": None if pd.isna(eu_cl) else round(float(eu_cl) - dk_cl, 4),
            "share_dk": round(share_dk, 4),
            "share_eu": None if pd.isna(share_eu) else round(float(share_eu), 4),
            "result": result,
            "note": (
                "cSer shares 3-digit parents with cHou (CP044), cNonFood "
                "(CP031/032/056) and cCarEne (CP072), so those groups form "
                "one connected component at 3-digit."
                if n_g > 2 else ""
            ),
        })

    def add_useful_cluster(name, greu_list, codes, note, rel_tol=0.10):
        dk_cl = float(by_group.reindex(greu_list)["ces_vd"].sum())
        eu_cl = codes_bn(dk_co, codes)
        share_dk = dk_cl / dk_ces if dk_ces else float("nan")
        share_eu = eu_cl / eu_total if (pd.notna(eu_cl) and eu_total) else float("nan")
        if pd.isna(eu_cl):
            result = "SKIP"
        else:
            scale = max(abs(dk_cl), abs(eu_cl), 1e-9)
            result = "PASS" if abs(eu_cl - dk_cl) / scale <= rel_tol else "FAIL"
            check(checks, f"{name}", dk_cl, eu_cl, rel_tol=rel_tol, note=note)
        cluster_rows.append({
            "cluster": name,
            "kind": "useful_subcluster",
            "n_greu": len(greu_list),
            "greu_groups": "+".join(greu_list),
            "coicop_codes": "+".join(codes),
            "dk_ces_vd_bn": round(dk_cl, 4),
            "eurostat_bn": None if pd.isna(eu_cl) else round(float(eu_cl), 4),
            "diff_bn": None if pd.isna(eu_cl) else round(float(eu_cl) - dk_cl, 4),
            "share_dk": round(share_dk, 4),
            "share_eu": None if pd.isna(share_eu) else round(float(share_eu), 4),
            "result": result,
            "note": note,
        })

    add_useful_cluster(
        "FOOD_CP011",
        ["cFoodVeg", "cFoodMeat", "cFoodFish", "cFoodDairy"],
        ["CP011"],
        "Four GREU food groups collapse to one 1999 3-digit code (Food).",
    )
    add_useful_cluster(
        "BEV_TOB_COICOP1999",
        ["cFoodBev"],
        ["CP012", "CP021", "CP022"],
        "cFoodBev vs 1999 beverages+tobacco. Map is 2018-style (tobacco=023, "
        "empty under 1999 Narcotics label); 1999 tobacco is CP022.",
    )
    add_useful_cluster(
        "HOU_EXCL_WATER",
        ["cHou"],
        ["CP041", "CP042", "CP043"],
        "Housing rents/imputed rents/maintenance. CP044 (water/dwelling services) spans cSer.",
    )
    clusters_df = pd.DataFrame(cluster_rows)

    # ---------------- energy -----------------------------------------------
    energy_rows = []
    hou_ene_dk = float(by_group.loc["cHouEne", "ces_vd"])
    car_ene_dk = float(by_group.loc["cCarEne", "ces_vd"])
    car_dk = float(by_group.loc["cCar", "ces_vd"])
    cp045 = coicop_bn(dk_co, "CP045")
    cp071 = coicop_bn(dk_co, "CP071")
    cp072 = coicop_bn(dk_co, "CP072")
    # Map rows inside CP072 that are cCarEne vs cSer.
    cp072_map = cmap_ok[cmap_ok["cp3"] == "CP072"]
    cp072_groups = sorted(cp072_map["cons_hh_greu"].unique().tolist())
    energy_rows.append({
        "item": "cHouEne vs CP045 electricity/gas/other fuels",
        "dk_ces_vd_bn": round(hou_ene_dk, 4),
        "eurostat_bn": round(cp045, 4) if pd.notna(cp045) else None,
        "diff_bn": round(cp045 - hou_ene_dk, 4) if pd.notna(cp045) else None,
        "unique_3digit": "cHouEne" in unique_groups,
        "note": (
            "CP045 is exclusive to cHouEne in the Danish map. Sweden public "
            "core already fills cHouEne from PEFA HH_HEAT+HH_OTH, not COICOP."
        ),
    })
    energy_rows.append({
        "item": "cCar vs CP071 purchase of vehicles",
        "dk_ces_vd_bn": round(car_dk, 4),
        "eurostat_bn": round(cp071, 4) if pd.notna(cp071) else None,
        "diff_bn": round(cp071 - car_dk, 4) if pd.notna(cp071) else None,
        "unique_3digit": "cCar" in unique_groups,
        "note": "CP071 is exclusive to cCar in the Danish map.",
    })
    energy_rows.append({
        "item": "cCarEne vs CP072 operation of personal transport (MIXED)",
        "dk_ces_vd_bn": round(car_ene_dk, 4),
        "eurostat_bn": round(cp072, 4) if pd.notna(cp072) else None,
        "diff_bn": round(cp072 - car_ene_dk, 4) if pd.notna(cp072) else None,
        "unique_3digit": False,
        "note": (
            f"3-digit CP072 maps to {cp072_groups}. Map 5-digit fuels "
            f"(07221-07224 diesel/petrol/other/lubricants) are cCarEne; "
            f"spare parts and maintenance stay in cSer. Eurostat does not "
            f"publish 4-digit, so CP072 cannot isolate car energy. Use the "
            f"energy core (PEFA HH_TRA) for cCarEne."
        ),
    })
    energy_df = pd.DataFrame(energy_rows)
    check(checks, "cHouEne vs CP045", hou_ene_dk, cp045, rel_tol=0.10,
          note="unique 3-digit; remaining gap is S14 vs IO valuation")
    check(checks, "cCar vs CP071", car_dk, cp071, rel_tol=0.10,
          note="unique 3-digit")
    check(checks, "cCarEne vs CP072 (expected MIX - fuels vs maintenance)",
          car_ene_dk, cp072, rel_tol=0.10,
          note="FAIL expected: CP072 includes cSer maintenance")

    # ---------------- cTou --------------------------------------------------
    tou_dk = float(by_group.loc["cTou", "ces_vd"])
    tou_map_n = int((cmap["cons_hh_greu"] == "cTou").sum())
    tou_mapped = int(((cmap["cons_hh_greu"] == "cTou") & cmap["coicop"].notna()).sum())
    tou_rows = [{
        "item": "GREU cTou (expenses in other countries)",
        "value_bn": round(tou_dk, 4),
        "note": "IO cons_hh column; no cons_hh_foreign cells",
    }, {
        "item": "cons_hh_coicop_map rows for cTou with a COICOP code",
        "value_bn": tou_mapped,
        "note": f"{tou_map_n} map rows; the only NA coicop in the 299-line map is cTou",
    }, {
        "item": "FIGARO OP_RES (purchases by residents abroad), recomputed",
        "value_bn": round(fig_op_res, 4),
        "note": "Named analogue for cTou; not in nama_10_co3_p3 (domestic COICOP)",
    }, {
        "item": "nama_10_co3_p3 tourism-abroad cell",
        "value_bn": None,
        "note": "None. Dataset is domestic household FCE by COICOP 1999 purpose.",
    }]
    tou_df = pd.DataFrame(tou_rows)
    check(checks, "cTou vs FIGARO OP_RES (tourism-abroad analogue)",
          tou_dk, fig_op_res, rel_tol=0.10,
          note="Structural miss on nama_10_co3_p3; OP_RES is the FIGARO residual")

    # ---------------- shares of total --------------------------------------
    share_rows = []
    for r in group_rows:
        share_rows.append({
            "greu": r["greu"],
            "identification": r["identification"],
            "dk_share_of_ces": r["share_dk"],
            "eu_share_of_TOTAL": r["share_eu"],
            "pp_diff": r["share_pp_diff"],
            "note": (
                "CLUSTER rows reuse the cluster Eurostat total, so EU shares "
                "are not a 12-way partition (they overlap inside a cluster)."
                if r["identification"] == "spans"
                else "Purchaser COICOP vs IO CES valuation."
            ),
        })
    shares_df = pd.DataFrame(share_rows)

    # 2-digit COICOP vs GREU clusters that collapse to a division.
    two_digit = []
    for cp2 in [f"CP{i:02d}" for i in range(1, 13)]:
        eu2 = coicop_bn(dk_co, cp2)
        greu2 = sorted(cmap_ok.loc[cmap_ok["cp2"] == cp2, "cons_hh_greu"].unique().tolist())
        dk2 = float(by_group.reindex(greu2)["ces_vd"].sum()) if greu2 else float("nan")
        two_digit.append({
            "cp2": cp2,
            "eurostat_bn": None if pd.isna(eu2) else round(float(eu2), 4),
            "n_greu": len(greu2),
            "greu_groups": "+".join(greu2),
            "dk_ces_of_those_groups_bn": None if pd.isna(dk2) else round(dk2, 4),
            "note": "DK CES is the sum of groups that *touch* this division, not a partition",
        })
    two_digit_df = pd.DataFrame(two_digit)

    # ---------------- EU-27 coverage ---------------------------------------
    cov_mnac = cov[cov["unit"] == "CP_MNAC"].copy()
    cov_rows = []
    for geo in EU27:
        sub = cov_mnac[cov_mnac["geo"] == geo]
        codes = set(sub["coicop"].astype(str))
        n2 = sum(1 for c in codes if coicop_depth(c) == 2)
        n3 = sum(1 for c in codes if coicop_depth(c) == 3)
        has_total = "TOTAL" in codes
        total_bn = float("nan")
        tot = sub[sub["coicop"] == "TOTAL"]["value"]
        if len(tot):
            total_bn = float(tot.iloc[0]) / 1000.0
        depth = "3-digit" if n3 >= 20 else ("2-digit only" if n2 else "none")
        cov_rows.append({
            "geo": geo,
            "has_TOTAL": has_total,
            "n_2digit_codes": n2,
            "n_3digit_codes": n3,
            "digit_depth": depth,
            "total_cp_mnac_bn": None if pd.isna(total_bn) else round(total_bn, 4),
        })
    cov_df = pd.DataFrame(cov_rows)
    n3_countries = int((cov_df["digit_depth"] == "3-digit").sum())
    n2_only = int((cov_df["digit_depth"] == "2-digit only").sum())
    n_none = int((cov_df["digit_depth"] == "none").sum())
    check(checks, "EU-27 countries publishing 2020 3-digit COICOP",
          float(n3_countries), 27.0, tol=0,
          note=f"3-digit={n3_countries}; 2-digit only={n2_only}; none={n_none}")

    year_mnac = years[years["unit"] == "CP_MNAC"].copy()
    year_rows = []
    for geo in EU27:
        sub = year_mnac[year_mnac["geo"] == geo]
        if sub.empty:
            year_rows.append({
                "geo": geo, "n_years": 0, "min_year": None, "max_year": None,
                "has_2020": False, "total_2020_bn": None,
            })
            continue
        ys = sorted(sub["time"].astype(str).unique().tolist())
        y2020 = sub[sub["time"].astype(str) == str(YEAR)]["value"]
        year_rows.append({
            "geo": geo,
            "n_years": len(ys),
            "min_year": ys[0],
            "max_year": ys[-1],
            "has_2020": len(y2020) > 0,
            "total_2020_bn": (
                None if y2020.empty else round(float(y2020.iloc[0]) / 1000.0, 4)
            ),
        })
    year_df = pd.DataFrame(year_rows)
    n_y2020 = int(year_df["has_2020"].sum())
    check(checks, "EU-27 countries publishing 2020 TOTAL household FCE",
          float(n_y2020), 27.0, tol=0)

    # ---------------- Sweden snapshot --------------------------------------
    se_total = coicop_bn(se_co, "TOTAL")
    se_rows = [{
        "item": "SE 2020 TOTAL household FCE (bn SEK)",
        "value": None if pd.isna(se_total) else round(se_total, 4),
        "note": "CP_MNAC / 1000; not converted to DKK",
    }]
    for code in ["CP01", "CP04", "CP045", "CP07", "CP071", "CP072", "CP11", "CP12"]:
        v = coicop_bn(se_co, code)
        se_rows.append({
            "item": f"SE {code}",
            "value": None if pd.isna(v) else round(float(v), 4),
            "note": se_co.loc[se_co.coicop == code, "coicop_label"].iloc[0]
            if (se_co.coicop == code).any() else "",
        })
    se_codes = set(se_co.loc[se_co.unit == "CP_MNAC", "coicop"].astype(str))
    se_n3 = sum(1 for c in se_codes if coicop_depth(c) == 3)
    se_n2 = sum(1 for c in se_codes if coicop_depth(c) == 2)
    se_rows.append({
        "item": "SE 2020 n 2-digit / 3-digit codes",
        "value": f"{se_n2} / {se_n3}",
        "note": "Same 3-digit depth as DK" if se_n3 >= 20 else "Shallower than DK",
    })
    sweden_df = pd.DataFrame(se_rows)

    # ---------------- map diagnostics --------------------------------------
    map_diag = cmap_ok[["cons_hh_greu", "eco", "cp2", "cp3", "cp3_published",
                         "coicop_txt"]].copy()
    map_diag = map_diag.sort_values(["cons_hh_greu", "eco"])

    # ---------------- file usage -------------------------------------------
    usage = pd.DataFrame([
        {"item": "Danish object",
         "value": "io_long_format.xlsx columns cons_hh and cons_hh_foreign (12 d codes). No separate household-consumption Excel."},
        {"item": "read_data.py",
         "value": "Lines 220-238 add cons_hh + cons_hh_foreign (model has no tourist split) and export vIO_y / vIO_m on domain d."},
        {"item": "data_from_GR.gms",
         "value": "Line 125 $load; lines 414-517 build vD[d,t] / qD[d,t] (purchaser = prod+imp + distributed TaxSub+Moms)."},
        {"item": "input_output.gms",
         "value": "Line 141 vC[t] = sum(c, vD[c,t])."},
        {"item": "consumption_disaggregated.gms",
         "value": "Line 87 calibrates CES nest qCHh / uCHh from qD[c,t1]. Dummy equal shares would silently mis-calibrate food/housing/cars/tourism."},
        {"item": "Load-bearing?",
         "value": "YES. The 12-group split is the bottom of the household CES nest, not a dummy."},
        {"item": "Energy groups",
         "value": "cHouEne / cCarEne are also filled from the energy IO; Sweden public core constructs them from PEFA HH_HEAT/HH_OTH and HH_TRA. This pilot does not invent a PEFA x price household energy engine."},
        {"item": "Industry x group matrix",
         "value": "Not rebuilt. FIGARO already matched the total; cells stay FIGARO/SUT."},
        {"item": "COICOP concept",
         "value": "Purchaser prices, households only (S14). Danish cons_hh = P3_S14+P3_S15+OP_RES+OP_NRES. NPISH and cTou will not sit cleanly in nama_10_co3_p3."},
        {"item": "map",
         "value": f"metadata.xlsx sheet cons_hh_coicop_map: {n_map_rows} rows, {n_map_na} NA coicop (cTou). Codes stored as floats (1111.0 = cereals); padded to 5-digit ECOICOP, collapsed to CP0xx."},
        {"item": "Eurostat dimensions",
         "value": "nama_10_co3_p3 id = [freq, unit, coicop, geo, time]. No na_item. Finest published digit = 3 (CP011, CP045, ...). TOTAL not CP00."},
    ])

    n_pass = sum(1 for r in checks if r["result"] == "PASS")
    n_fail = sum(1 for r in checks if r["result"] == "FAIL")
    n_skip = sum(1 for r in checks if r["result"] == "SKIP")

    unique_str = ", ".join(unique_groups) if unique_groups else "none"
    headline = (
        f"COARSER / PILOT DONE. 3-digit COICOP uniquely identifies "
        f"{len(unique_groups)} of 12 GREU groups ({unique_str}). "
        f"nama_10_co3_p3 TOTAL {eu_total:.3f} bn DKK vs IO cons_hh "
        f"{dk_cons_hh:.3f} (FIGARO identity {fig_cons_hh:.3f}) and vs CES "
        f"vD {dk_ces:.3f} (cons_hh+foreign). Concept gap is S14 vs "
        f"S14+S15+tourism, not a missing source. Food four-pack collapses "
        f"to CP011; CP072 mixes cCarEne fuels with cSer maintenance; cTou "
        f"has no COICOP (FIGARO OP_RES {fig_op_res:.3f} vs cTou {tou_dk:.3f}). "
        f"EU-27 2020 3-digit publishers: {n3_countries}/27. Recipe: aggregate "
        f"the existing map to published digit depth, take cHouEne/cCarEne "
        f"from the energy core, treat cTou as a tourism/RoW residual."
    )

    totals = pd.DataFrame([
        {"item": "IO cons_hh all-rows 2020 bn DKK", "value": round(dk_cons_hh, 4)},
        {"item": "IO cons_hh_foreign all-rows 2020 bn DKK", "value": round(dk_foreign, 4)},
        {"item": "CES vD = cons_hh + cons_hh_foreign", "value": round(dk_ces, 4)},
        {"item": "tax_products+tax_vat on household columns", "value": round(tax_hh, 4)},
        {"item": "FIGARO P3_S14 (recomputed)", "value": round(fig_p3_s14, 4)},
        {"item": "FIGARO P3_S15 NPISH (recomputed)", "value": round(fig_p3_s15, 4)},
        {"item": "FIGARO OP_RES residents abroad (recomputed)", "value": round(fig_op_res, 4)},
        {"item": "FIGARO OP_NRES non-residents in DK (recomputed)", "value": round(fig_op_nres, 4)},
        {"item": "FIGARO cons_hh identity P3_S14+S15+OP_RES+OP_NRES",
         "value": round(fig_cons_hh, 4)},
        {"item": "nama_10_co3_p3 DK 2020 TOTAL CP_MNAC bn DKK", "value": round(eu_total, 4)},
        {"item": "DKK per EUR (ert_bil_eur_a 2020, for FIGARO only)", "value": round(rate, 4)},
        {"item": "uniquely identified GREU groups at 3-digit",
         "value": f"{len(unique_groups)}/12: {unique_str}"},
        {"item": "published 3-digit parents that span >1 GREU group", "value": n_span3},
        {"item": "EU-27 with 2020 3-digit COICOP", "value": n3_countries},
        {"item": "EU-27 with 2020 TOTAL", "value": n_y2020},
        {"item": "SE 2020 TOTAL bn SEK",
         "value": None if pd.isna(se_total) else round(se_total, 4)},
        {"item": "identity checks PASS/FAIL/SKIP",
         "value": f"{n_pass}/{n_fail}/{n_skip}"},
    ])
    totals = pd.concat(
        [totals, pd.DataFrame(checks).rename(columns={"check": "item"})],
        ignore_index=True,
    )

    readme = pd.DataFrame([
        {"key": "title",
         "value": "Reconciliation: Eurostat nama_10_co3_p3 vs GREU household consumption groups (io_long_format cons_hh), Denmark 2020"},
        {"key": "created", "value": created},
        {"key": "created_by",
         "value": "data/preprocessing/scripts/reconcile_hh_consumption_dk_2020.py"},
        {"key": "purpose",
         "value": "Pilot of the mapping-table COARSER verdict: test whether 3-digit COICOP uniquely identifies the 12 GREU c-groups and how levels/shares compare. FIGARO already closed the total."},
        {"key": "danish_source",
         "value": "data/preprocessing/data/io_long_format.xlsx sheet io, year=2020, col_l1 in {cons_hh, cons_hh_foreign}; metadata.xlsx sheets cons_hh and cons_hh_coicop_map"},
        {"key": "eurostat_source",
         "value": "nama_10_co3_p3 (household FCE by COICOP 1999 purpose). No na_item dimension. Unit CP_MNAC / 1000 = bn national currency."},
        {"key": "eurostat_retrieval_date", "value": retrieval_date},
        {"key": "raw_data",
         "value": "data/preprocessing/data/hh_consumption_raw/DK/2020/ (README.md + manifest.json with URLs, params, SHA-256). FIGARO identity recomputed from data/preprocessing/data/figaro_raw/."},
        {"key": "units", "value": "bn DKK (Eurostat million DKK / 1000). Sweden snapshot in bn SEK."},
        {"key": "headline", "value": headline},
        {"key": "sheets",
         "value": "file_usage | totals | spanning_3digit | spanning_2digit | groups | clusters | energy | cTou | shares | two_digit | eu27_coverage | eu27_years | sweden | map_codes"},
    ])

    with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
        readme.to_excel(xl, sheet_name="readme", index=False)
        usage.to_excel(xl, sheet_name="file_usage", index=False)
        totals.to_excel(xl, sheet_name="totals", index=False)
        spanning.to_excel(xl, sheet_name="spanning_3digit", index=False)
        spanning2.to_excel(xl, sheet_name="spanning_2digit", index=False)
        groups_df.to_excel(xl, sheet_name="groups", index=False)
        clusters_df.to_excel(xl, sheet_name="clusters", index=False)
        energy_df.to_excel(xl, sheet_name="energy", index=False)
        tou_df.to_excel(xl, sheet_name="cTou", index=False)
        shares_df.to_excel(xl, sheet_name="shares", index=False)
        two_digit_df.to_excel(xl, sheet_name="two_digit", index=False)
        cov_df.to_excel(xl, sheet_name="eu27_coverage", index=False)
        year_df.to_excel(xl, sheet_name="eu27_years", index=False)
        sweden_df.to_excel(xl, sheet_name="sweden", index=False)
        map_diag.to_excel(xl, sheet_name="map_codes", index=False)

    print(headline)
    print(f"wrote {OUT}")
    print(f"checks PASS/FAIL/SKIP = {n_pass}/{n_fail}/{n_skip}")
    print("unique groups:", unique_str)
    print(groups_df[["greu", "identification", "dk_ces_vd_bn", "eurostat_bn", "result"]].to_string(index=False))


if __name__ == "__main__":
    main()
