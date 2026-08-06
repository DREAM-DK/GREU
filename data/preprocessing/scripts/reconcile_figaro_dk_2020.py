"""Reconcile FIGARO DK 2020 against the Danish IO input io_long_format.xlsx.

Phase 1 pilot of the EU data replacement effort (see docs/eu_data_mapping.md).

Inputs
------
- data/preprocessing/data/io_long_format.xlsx          (Danish IO, bn DKK, 2020)
- data/preprocessing/data/figaro_raw/*.csv             (FIGARO 2026 ed., MIO_EUR,
  downloaded by download_figaro_dk_2020.py; see figaro_raw/README.md)
- data/preprocessing/data/metadata.xlsx, sheet industries_naceA64_map
  (57 GREU industries <-> NACE A64, many-to-many)

Method
------
FIGARO values (MIO_EUR) are converted to bn DKK with the 2020 annual-average
DKK/EUR rate from ert_bil_eur_a. Because the GREU<->A64 map is many-to-many,
industries are compared at the level of *clusters* = connected components of
the bipartite GREU-A64 graph (the finest partition on which both
classifications aggregate consistently).

Concept mapping (both tables are at basic prices with taxes-on-products rows):
  production rows            <-> ind-by-ind IO rows with c_orig = DK
  import rows                <-> rows with c_orig not in {DK, DOM}
  emp_comp                   <-> D1        (c_orig = DOM)
  gross_surplus              <-> B2A3G
  tax_other_production +
    subs_other_production    <-> D29X39 (net)
  tax_products + tax_vat     <-> D21X31
  cons_hh                    <-> P3_S14 + P3_S15 + OP_RES + OP_NRES  (verified
                                 exact: Danish cons_hh includes NPISH and
                                 residents' direct purchases abroad (OP_RES) and
                                 excludes non-residents' purchases in DK, which
                                 FIGARO removes via the negative OP_NRES row)
  cons_hh_foreign            <-> -OP_NRES (non-residents' purchases in DK;
                                 verified exact, 27.75 bn DKK both sides)
  cons_publ                  <-> P3_S13
  invest_* (3 columns)       <-> P51G
  invent_change              <-> P5M
  export column              <-> c_orig = DK, c_dest != DK  (note: FIGARO has no
                                 re-export concept; Danish re-exports = import
                                 rows x export column are reported as a memo)

Output
------
data/preprocessing/data/figaro_dk2020_reconciliation.xlsx  with sheets:
  metadata, totals, output_by_cluster, imports_by_cluster, exports_by_cluster,
  va_by_cluster, hh_cons_by_cluster, mapping

Run:  python data/preprocessing/scripts/reconcile_figaro_dk_2020.py
"""

import datetime
import pathlib
import re

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "figaro_raw"
OUT = DATA / "figaro_dk2020_reconciliation.xlsx"
YEAR = 2020

VA_CODES = ["D1", "D21X31", "D29X39", "B2A3G", "OP_RES", "OP_NRES"]
FD_CODES = ["P3_S13", "P3_S14", "P3_S15", "P51G", "P5M"]


def norm_a64(code: str) -> str:
    """metadata.xlsx A64 codes -> FIGARO SDMX codes (C10-C12 -> C10-12 etc.)."""
    special = {"D": "D35", "O": "O84", "P": "P85"}
    if code in special:
        return special[code]
    return re.sub(r"([-_])[A-Z]", r"\1", code)


def build_clusters(m: pd.DataFrame):
    """Connected components of the bipartite GREU <-> A64 graph."""
    parent = {}

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
    comp = {}
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


def cluster_compare(dk_by_greu, fig_by_nace, greu2cl, nace2cl, clusters):
    dk = dk_by_greu.rename(index=greu2cl).groupby(level=0).sum()
    fig = fig_by_nace.rename(index=nace2cl).groupby(level=0).sum()
    rows = []
    for c in clusters:
        d = dk.get(c["label"], 0.0)
        f = fig.get(c["label"], 0.0)
        rows.append(
            {
                "cluster": c["label"],
                "greu_industries": ", ".join(c["greu"]),
                "n_greu": len(c["greu"]),
                "n_a64": len(c["nace"]),
                "dk_bn_dkk": round(d, 2),
                "figaro_bn_dkk": round(f, 2),
                "diff_bn_dkk": round(f - d, 2),
                "pct_diff": round((f - d) / d * 100, 1) if abs(d) > 1e-9 else None,
            }
        )
    # anything FIGARO has outside the mapped clusters (e.g. industry U)
    unmapped = fig_by_nace[~fig_by_nace.index.isin(nace2cl)]
    for code, val in unmapped.items():
        rows.append(
            {
                "cluster": f"UNMAPPED:{code}",
                "greu_industries": "",
                "n_greu": 0,
                "n_a64": 1,
                "dk_bn_dkk": 0.0,
                "figaro_bn_dkk": round(val, 2),
                "diff_bn_dkk": round(val, 2),
                "pct_diff": None,
            }
        )
    return pd.DataFrame(rows)


def main() -> None:
    # ---------------- exchange rate ----------------
    ert = pd.read_csv(RAW / "ert_bil_eur_a_DKK_2020.csv")
    rate = float(ert.loc[ert["TIME_PERIOD"] == YEAR, "OBS_VALUE"].iloc[0])  # DKK per EUR
    meur_to_bndkk = rate / 1000.0

    # ---------------- Danish IO ----------------
    dk = pd.read_excel(DATA / "io_long_format.xlsx")
    dk = dk[dk["year"] == YEAR].copy()

    prod = dk[dk.row_l1 == "production"]
    imp = dk[dk.row_l1 == "import"]
    prim = dk[dk.row_l1 == "prim_input"]

    dk_output_by_greu = prod.groupby("row_l2")["value"].sum()
    dk_imports_by_greu = imp.groupby("row_l2")["value"].sum()
    dk_exports_by_greu = prod[prod.col_l1 == "export"].groupby("row_l2")["value"].sum()
    dk_reexports = imp[imp.col_l1 == "export"]["value"].sum()
    dk_hh_by_greu = (
        dk[dk.row_l1.isin(["production", "import"]) & dk.col_l1.isin(["cons_hh", "cons_hh_foreign"])]
        .groupby("row_l2")["value"]
        .sum()
    )
    prim_ind = prim[prim.col_l1 == "cons_inter"]
    dk_va = prim_ind.pivot_table(index="col_l2", columns="row_l2", values="value", aggfunc="sum").fillna(0.0)
    dk_tax_prod_total = prim[prim.row_l2.isin(["tax_products", "tax_vat"])]["value"].sum()

    def dk_col_total(col_l1):
        return dk[dk.col_l1 == col_l1]["value"].sum()

    # ---------------- FIGARO ind-by-ind ----------------
    ii_dest = pd.read_csv(RAW / "naio_10_fcp_ii3_DKdest_2020.csv")
    ii_orig = pd.read_csv(RAW / "naio_10_fcp_ii3_DKorig_2020.csv")
    for df in (ii_dest, ii_orig):
        df["bn_dkk"] = df["OBS_VALUE"] * meur_to_bndkk

    industries = sorted(ii_orig["ind_ava"].unique())  # 64 industry codes

    fig_output_by_nace = ii_orig.groupby("ind_ava")["bn_dkk"].sum()  # all dests, all uses
    imp_rows = ii_dest[~ii_dest.c_orig.isin(["DK", "DOM"])]
    fig_imports_by_nace = imp_rows.groupby("ind_ava")["bn_dkk"].sum()
    fig_exports_by_nace = ii_orig[ii_orig.c_dest != "DK"].groupby("ind_ava")["bn_dkk"].sum()
    # by-industry household consumption: include NPISH (P3_S15) because the
    # Danish cons_hh column contains it; OP_RES/OP_NRES are total-only DOM rows
    # and will show up as small industry-level differences (tourism industries).
    fig_hh_by_nace = (
        ii_dest[ii_dest.ind_use.isin(["P3_S14", "P3_S15"]) & (ii_dest.c_orig != "DOM")]
        .groupby("ind_ava")["bn_dkk"]
        .sum()
    )
    dom = ii_dest[ii_dest.c_orig == "DOM"]
    fig_d21x31_total = dom[dom.ind_ava == "D21X31"]["bn_dkk"].sum()

    def fig_fd_total(code):
        return ii_dest[(ii_dest.ind_use == code) & (ii_dest.c_orig != "DOM")]["bn_dkk"].sum() + dom[
            (dom.ind_use == code) & (dom.ind_ava == "D21X31")
        ]["bn_dkk"].sum()

    # supply-table cross-check of output. NB: naio_10_fcp_s3 spells NACE codes
    # differently from ii3/u3 ("C10-C12" vs "C10-12") - normalise before use.
    s3 = pd.read_csv(RAW / "naio_10_fcp_s3_DK_2020.csv")
    s3["nace"] = s3["nace_r2"].astype(str).map(norm_a64)
    assert set(s3["nace"]) == set(industries), "supply table industry codes do not match IO table"
    fig_output_s3 = s3["OBS_VALUE"].sum() * meur_to_bndkk

    # ---------------- clusters ----------------
    m = pd.read_excel(DATA / "metadata.xlsx", sheet_name="industries_naceA64_map")
    m["nace"] = m["indu_naceA64"].astype(str).map(norm_a64)
    clusters, greu2cl, nace2cl = build_clusters(m)

    # ---------------- totals sheet ----------------
    dk_interm_basic = (
        dk[dk.row_l1.isin(["production", "import"]) & (dk.col_l1 == "cons_inter")]["value"].sum()
    )
    fig_interm_basic = (
        ii_dest[(ii_dest.c_orig != "DOM") & ii_dest.ind_use.isin(industries)]["bn_dkk"].sum()
    )
    dk_gdp = prim["value"].sum()
    fig_va_by_code = dom[dom.ind_use.isin(industries)].groupby("ind_ava")["bn_dkk"].sum()
    fig_gdp = fig_va_by_code.reindex(["D1", "B2A3G", "D29X39"]).sum() + fig_d21x31_total

    totals = [
        ("Total domestic output, basic prices", dk_output_by_greu.sum(), fig_output_by_nace.sum()),
        ("  memo: FIGARO output from supply table (cross-check)", None, fig_output_s3),
        ("Total imports (all rows from abroad)", dk_imports_by_greu.sum(), fig_imports_by_nace.sum()),
        ("Intermediate consumption (dom+imp, basic prices)", dk_interm_basic, fig_interm_basic),
        ("Compensation of employees (emp_comp / D1)", dk_va["emp_comp"].sum(), fig_va_by_code.get("D1")),
        ("Gross operating surplus (gross_surplus / B2A3G)", dk_va["gross_surplus"].sum(), fig_va_by_code.get("B2A3G")),
        (
            "Other taxes less subsidies on production (net / D29X39)",
            dk_va["tax_other_production"].sum() + dk_va["subs_other_production"].sum(),
            fig_va_by_code.get("D29X39"),
        ),
        (
            "Taxes less subsidies on products incl VAT, all uses (tax_products+tax_vat / D21X31)",
            dk_tax_prod_total,
            fig_d21x31_total,
        ),
        ("GDP (sum of the four rows above)", dk_gdp, fig_gdp),
        (
            "  memo: Total imports excl Danish re-exports",
            dk_imports_by_greu.sum() - dk_reexports,
            fig_imports_by_nace.sum(),
        ),
        (
            "Household consumption incl NPISH (cons_hh / P3_S14+P3_S15+OP_RES+OP_NRES)",
            dk_col_total("cons_hh"),
            fig_fd_total("P3_S14")
            + fig_fd_total("P3_S15")
            + dom[dom.ind_ava.isin(["OP_RES", "OP_NRES"])]["bn_dkk"].sum(),
        ),
        (
            "Non-residents' consumption in DK (cons_hh_foreign / -OP_NRES)",
            dk_col_total("cons_hh_foreign"),
            -dom[dom.ind_ava == "OP_NRES"]["bn_dkk"].sum(),
        ),
        ("  memo: FIGARO NPISH consumption P3_S15 (inside Danish cons_hh)", None, fig_fd_total("P3_S15")),
        ("Government consumption (cons_publ / P3_S13)", dk_col_total("cons_publ"), fig_fd_total("P3_S13")),
        (
            "Gross fixed capital formation (invest_build+trans+other / P51G)",
            dk_col_total("invest_build") + dk_col_total("invest_trans") + dk_col_total("invest_other"),
            fig_fd_total("P51G"),
        ),
        ("Changes in inventories (invent_change / P5M)", dk_col_total("invent_change"), fig_fd_total("P5M")),
        ("Exports, total Danish concept (export column, incl re-exports)", dk_col_total("export"), None),
        (
            "Exports of domestic output (production rows x export / c_orig=DK, c_dest!=DK)",
            dk_exports_by_greu.sum(),
            fig_exports_by_nace.sum(),
        ),
        ("  memo: Danish re-exports (import rows x export column)", dk_reexports, None),
        ("  memo: FIGARO OP_RES (purchases by residents abroad row)", None, dom[dom.ind_ava == "OP_RES"]["bn_dkk"].sum()),
        ("  memo: FIGARO OP_NRES (purchases by non-residents row)", None, dom[dom.ind_ava == "OP_NRES"]["bn_dkk"].sum()),
    ]
    totals_df = pd.DataFrame(
        [
            {
                "aggregate": name,
                "dk_bn_dkk": round(d, 2) if d is not None else None,
                "figaro_bn_dkk": round(f, 2) if f is not None else None,
                "diff_bn_dkk": round(f - d, 2) if d is not None and f is not None else None,
                "pct_diff": round((f - d) / d * 100, 1) if d not in (None, 0) and f is not None else None,
            }
            for name, d, f in totals
        ]
    )

    # ---------------- by-cluster sheets ----------------
    out_cmp = cluster_compare(dk_output_by_greu, fig_output_by_nace, greu2cl, nace2cl, clusters)
    imp_cmp = cluster_compare(dk_imports_by_greu, fig_imports_by_nace, greu2cl, nace2cl, clusters)
    exp_cmp = cluster_compare(dk_exports_by_greu, fig_exports_by_nace, greu2cl, nace2cl, clusters)
    hh_cmp = cluster_compare(dk_hh_by_greu, fig_hh_by_nace, greu2cl, nace2cl, clusters)

    # VA by cluster, three components side by side (long)
    va_pairs = [
        ("emp_comp", "D1"),
        ("gross_surplus", "B2A3G"),
        ("tax_other_net", "D29X39"),
        ("tax_products_vat", "D21X31"),
    ]
    dk_va_ext = dk_va.copy()
    dk_va_ext["tax_other_net"] = dk_va_ext["tax_other_production"] + dk_va_ext["subs_other_production"]
    dk_va_ext["tax_products_vat"] = dk_va_ext["tax_products"] + dk_va_ext["tax_vat"]
    va_frames = []
    for dk_name, fig_code in va_pairs:
        d_by = dk_va_ext[dk_name]
        f_by = dom[(dom.ind_ava == fig_code) & dom.ind_use.isin(industries)].groupby("ind_use")["bn_dkk"].sum()
        cmp_ = cluster_compare(d_by, f_by, greu2cl, nace2cl, clusters)
        cmp_.insert(0, "component", f"{dk_name} / {fig_code}")
        va_frames.append(cmp_)
    va_cmp = pd.concat(va_frames, ignore_index=True)

    # ---------------- mapping sheet ----------------
    mapping_rows = []
    for c in clusters:
        mapping_rows.append(
            {
                "cluster": c["label"],
                "n_greu": len(c["greu"]),
                "n_a64": len(c["nace"]),
                "greu_industries": ", ".join(c["greu"]),
                "a64_codes": ", ".join(c["nace"]),
                "figaro_coarser": "yes" if len(c["greu"]) > len(c["nace"]) else "",
                "greu_coarser": "yes" if len(c["nace"]) > len(c["greu"]) else "",
            }
        )
    fig_unmapped = [i for i in industries if i not in nace2cl]
    for code in fig_unmapped:
        mapping_rows.append(
            {
                "cluster": f"UNMAPPED:{code}",
                "n_greu": 0,
                "n_a64": 1,
                "greu_industries": "",
                "a64_codes": code,
                "figaro_coarser": "",
                "greu_coarser": "",
            }
        )
    mapping_df = pd.DataFrame(mapping_rows)

    # ---------------- metadata sheet ----------------
    meta = pd.DataFrame(
        {
            "key": [
                "created",
                "script",
                "danish_input",
                "figaro_source",
                "figaro_edition",
                "figaro_files",
                "retrieval_date",
                "unit",
                "exchange_rate_DKK_per_EUR_2020",
                "exchange_rate_source",
                "comparison_year",
                "method",
            ],
            "value": [
                datetime.date.today().isoformat(),
                "data/preprocessing/scripts/reconcile_figaro_dk_2020.py",
                "data/preprocessing/data/io_long_format.xlsx (year 2020, bn DKK)",
                "Eurostat dissemination API, naio_10_fcp_s3/u3/ii3 (FIGARO)",
                "FIGARO 2026 edition (datasets last updated 18-20 Jul 2026, 2010-2024)",
                "data/preprocessing/data/figaro_raw/ (see README.md there)",
                "2026-07-29",
                "bn DKK (FIGARO MIO_EUR converted)",
                rate,
                "Eurostat ert_bil_eur_a, A.AVG.NAC.DKK, 2020",
                YEAR,
                "clusters = connected components of GREU<->NACE A64 bipartite map "
                "(metadata.xlsx, industries_naceA64_map); pct_diff = (FIGARO-DK)/DK*100",
            ],
        }
    )

    with pd.ExcelWriter(OUT, engine="openpyxl") as xw:
        meta.to_excel(xw, sheet_name="metadata", index=False)
        totals_df.to_excel(xw, sheet_name="totals", index=False)
        out_cmp.to_excel(xw, sheet_name="output_by_cluster", index=False)
        imp_cmp.to_excel(xw, sheet_name="imports_by_cluster", index=False)
        exp_cmp.to_excel(xw, sheet_name="exports_by_cluster", index=False)
        va_cmp.to_excel(xw, sheet_name="va_by_cluster", index=False)
        hh_cmp.to_excel(xw, sheet_name="hh_cons_by_cluster", index=False)
        mapping_df.to_excel(xw, sheet_name="mapping", index=False)
    print("wrote", OUT)
    print("\nDKK per EUR 2020:", rate)
    print("\n=== totals ===")
    print(totals_df.to_string(index=False))


if __name__ == "__main__":
    main()
