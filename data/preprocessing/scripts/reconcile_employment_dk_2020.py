"""Reconcile Eurostat nama_10_a64_e DK 2020 against the Danish GREU input
employed.xlsx.

Sixth pilot of the EU data replacement effort (see docs/eu_data_mapping.md).

Inputs
------
- data/preprocessing/data/employed.xlsx
    Danish input: year, indu (57 GREU industries), type
    (employees / self-employed), employed (persons, units), hours
    (thousand hours). Years 2019-2020. Consumed by read_data.py lines
    331-359: `hours` by type feeds the independents' wage upscaling
    (wagesum * hours_self-employed / hours_employees, line 351) and
    `employed` summed over industries and types feeds the scalar
    nEmployed parameter (lines 358-359, 686).
- data/preprocessing/data/employment_raw/DK/2020/*.json
    Raw JSON-stat from the Eurostat dissemination API, downloaded by
    download_employment_dk_2020.py (see README.md / manifest.json there).
- data/preprocessing/data/metadata.xlsx, sheet industries_naceA64_map
    57 GREU industries <-> NACE A64, many-to-many.

Method
------
Same as the earlier FIGARO/PEFA pilots: because the GREU<->A64 map is
many-to-many, industries are compared on *clusters* = connected components
of the bipartite GREU-A64 graph (the finest partition on which both
classifications aggregate consistently). NACE codes are normalized
defensively before joining (C10-C12 vs C10-12 style variants).

Units: Danish `employed` is persons (units); Eurostat THS_PER is thousand
persons and is multiplied by 1000. Danish `hours` and Eurostat THS_HW are
both thousand hours (verified: national totals coincide to <0.001%).

Eurostat na_item: EMP_DC total employment, SAL_DC employees, SELF_DC
self-employed (all domestic concept). SELF is published directly; the
EMP - SAL = SELF identity is checked explicitly.

Output
------
data/preprocessing/data/employment_dk2020_reconciliation.xlsx  with sheets:
  readme, employed_file_usage, totals, persons_by_cluster, hours_by_cluster,
  eu27_se_coverage, mapping, anomalies

Run:  python data/preprocessing/scripts/reconcile_employment_dk_2020.py
"""

from __future__ import annotations

import datetime
import json
import pathlib
import re

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "employment_raw" / "DK" / "2020"
OUT = DATA / "employment_dk2020_reconciliation.xlsx"
YEAR = 2020

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

# NACE aggregates present in nama_10_a64_e beyond the A64 leaves.
A64_AGGREGATES = {
    "TOTAL", "A", "B-E", "C", "G-I", "J", "K", "L", "M_N", "O-Q", "R-U",
    "B", "D", "E", "F", "G", "H", "I", "M", "N", "O", "P", "Q", "R", "S",
    "T", "U",
}
# Of these, the one-letter sections that ARE themselves A64 leaves in the
# Danish concordance (no finer split exists in A64): B, D, E36+E37-E39 make
# up E, etc. The concordance uses B, D, F, I, L, O, P, T directly.
SECTION_LEAVES = {"B", "D", "F", "I", "L", "O", "P", "T"}


def norm_a64(code: str) -> str:
    """Normalize NACE A64 spelling variants: C10-C12 -> C10-12, J59_J60 -> J59_60."""
    return re.sub(r"([-_])[A-Z]", r"\1", str(code).strip())


def jsonstat_to_frame(payload: dict) -> pd.DataFrame:
    """Flatten a JSON-stat 2.0 payload to a tidy DataFrame."""
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


def cluster_table(dk_by_greu: dict, es_by_nace: dict, greu2cl, nace2cl, clusters,
                  dk_names, es_names, unit_label):
    """dk_by_greu / es_by_nace: {measure: Series indexed by greu/nace}."""
    rows = []
    for c in clusters:
        row = {
            "cluster": c["label"],
            "greu_industries": ", ".join(c["greu"]),
            "n_greu": len(c["greu"]),
            "n_a64": len(c["nace"]),
        }
        for meas, dk_name, es_name in zip(dk_by_greu, dk_names, es_names):
            dk = dk_by_greu[meas].rename(index=greu2cl).groupby(level=0).sum()
            es = es_by_nace[meas].rename(index=nace2cl).groupby(level=0).sum()
            d = float(dk.get(c["label"], 0.0))
            e = float(es.get(c["label"], 0.0))
            row[f"dk_{meas}_{unit_label}"] = round(d, 3)
            row[f"eurostat_{meas}_{unit_label}"] = round(e, 3)
            row[f"diff_{meas}"] = round(e - d, 3)
            row[f"pct_diff_{meas}"] = round(100 * (e - d) / d, 3) if d else None
        rows.append(row)
    df = pd.DataFrame(rows)
    total = {"cluster": "TOTAL (sum of clusters)", "greu_industries": "",
             "n_greu": int(df["n_greu"].sum()), "n_a64": int(df["n_a64"].sum())}
    for meas in dk_by_greu:
        d = df[f"dk_{meas}_{unit_label}"].sum()
        e = df[f"eurostat_{meas}_{unit_label}"].sum()
        total[f"dk_{meas}_{unit_label}"] = round(d, 3)
        total[f"eurostat_{meas}_{unit_label}"] = round(e, 3)
        total[f"diff_{meas}"] = round(e - d, 3)
        total[f"pct_diff_{meas}"] = round(100 * (e - d) / d, 3) if d else None
    return pd.concat([df, pd.DataFrame([total])], ignore_index=True)


def main() -> None:
    created = datetime.date.today().isoformat()
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    retrieval_date = manifest["retrieval_date"]

    # ---------------- Danish side ----------------
    emp = pd.read_excel(DATA / "employed.xlsx")
    emp = emp[emp["year"] == YEAR].copy()
    emp["indu"] = emp["indu"].astype(str)
    dk_piv_per = emp.pivot_table(index="indu", columns="type", values="employed",
                                 aggfunc="sum").fillna(0.0)
    dk_piv_hw = emp.pivot_table(index="indu", columns="type", values="hours",
                                aggfunc="sum").fillna(0.0)
    dk_per = {
        "total": dk_piv_per.sum(axis=1),
        "employees": dk_piv_per.get("employees", 0.0),
        "self_employed": dk_piv_per.get("self-employed", 0.0),
    }
    dk_hw = {
        "total": dk_piv_hw.sum(axis=1),
        "employees": dk_piv_hw.get("employees", 0.0),
        "self_employed": dk_piv_hw.get("self-employed", 0.0),
    }

    # ---------------- Eurostat side ----------------
    es_raw = jsonstat_to_frame(
        json.loads((RAW / "nama_10_a64_e_DK_2020.json").read_text(encoding="utf-8"))
    )
    es_raw["nace_norm"] = es_raw["nace_r2"].map(norm_a64)

    # ---------------- concordance / clusters ----------------
    m = pd.read_excel(DATA / "metadata.xlsx", sheet_name="industries_naceA64_map")
    m = m.rename(columns={"indu_naceA64": "nace"})
    m["indu_greu"] = m["indu_greu"].astype(str)
    m["nace"] = m["nace"].map(norm_a64)
    clusters, greu2cl, nace2cl = build_clusters(m)
    mapped_nace = sorted(m["nace"].unique())

    unmapped_greu = sorted(set(emp["indu"]) - set(m["indu_greu"]))
    if unmapped_greu:
        raise RuntimeError(f"GREU industries missing from concordance: {unmapped_greu}")

    def es_series(unit: str, na_item: str, scale: float) -> pd.Series:
        sub = es_raw[(es_raw.unit == unit) & (es_raw.na_item == na_item)
                     & (es_raw.nace_norm.isin(mapped_nace))]
        return sub.set_index("nace_norm")["value"].astype(float) * scale

    # THS_PER -> persons (x1000); THS_HW already thousand hours like the DK file.
    es_per = {
        "total": es_series("THS_PER", "EMP_DC", 1000.0),
        "employees": es_series("THS_PER", "SAL_DC", 1000.0),
        "self_employed": es_series("THS_PER", "SELF_DC", 1000.0),
    }
    es_hw = {
        "total": es_series("THS_HW", "EMP_DC", 1.0),
        "employees": es_series("THS_HW", "SAL_DC", 1.0),
        "self_employed": es_series("THS_HW", "SELF_DC", 1.0),
    }

    # Eurostat nace codes not reachable by the concordance (A64 leaves only)
    es_leaves = set(es_raw["nace_norm"].unique()) - {norm_a64(c) for c in A64_AGGREGATES - SECTION_LEAVES}
    # E is an aggregate of E36 + E37-39, C of C10..C33 etc.; leaves = codes with
    # no children among the other codes. Simplest audit: codes in the Eurostat
    # A64 breakdown that the map does not use.
    unmapped_nace = sorted(
        c for c in es_leaves
        if c not in mapped_nace and c not in {norm_a64(x) for x in A64_AGGREGATES}
    )

    # ---------------- cluster comparisons ----------------
    meas = ["total", "employees", "self_employed"]
    per_cl = cluster_table(dk_per, es_per, greu2cl, nace2cl, clusters,
                           meas, meas, "persons")
    hw_cl = cluster_table(dk_hw, es_hw, greu2cl, nace2cl, clusters,
                          meas, meas, "ths_hours")

    # ---------------- totals & identity checks ----------------
    def es_total(unit, na_item):
        s = es_raw[(es_raw.unit == unit) & (es_raw.na_item == na_item)
                   & (es_raw.nace_r2 == "TOTAL")]["value"]
        return float(s.iloc[0])

    totals_rows = []
    for label, dk_side, unit, scale in [
        ("persons", dk_per, "THS_PER", 1000.0),
        ("thousand hours", dk_hw, "THS_HW", 1.0),
    ]:
        for meas_name, na_item in [("total", "EMP_DC"), ("employees", "SAL_DC"),
                                   ("self_employed", "SELF_DC")]:
            d = float(dk_side[meas_name].sum())
            e_tot = es_total(unit, na_item) * scale
            e_mapped = float(es_series(unit, na_item, scale).sum())
            totals_rows.append({
                "measure": f"{meas_name} ({label})",
                "dk_employed_xlsx": round(d, 3),
                "eurostat_nace_TOTAL": round(e_tot, 3),
                "eurostat_sum_mapped_A64": round(e_mapped, 3),
                "diff_dk_vs_TOTAL": round(e_tot - d, 3),
                "pct_diff_dk_vs_TOTAL": round(100 * (e_tot - d) / d, 3),
                "eurostat_A64_coverage_of_TOTAL_pct": round(100 * e_mapped / e_tot, 3),
            })
    # EMP - SAL = SELF identity on Eurostat side
    for unit in ["THS_PER", "THS_HW"]:
        gap = es_total(unit, "EMP_DC") - es_total(unit, "SAL_DC") - es_total(unit, "SELF_DC")
        totals_rows.append({
            "measure": f"Eurostat identity EMP-SAL-SELF, TOTAL, {unit}",
            "dk_employed_xlsx": None, "eurostat_nace_TOTAL": round(gap, 3),
            "eurostat_sum_mapped_A64": None, "diff_dk_vs_TOTAL": None,
            "pct_diff_dk_vs_TOTAL": None, "eurostat_A64_coverage_of_TOTAL_pct": None,
        })
    totals = pd.DataFrame(totals_rows)

    # ---------------- EU-27 / SE coverage ----------------
    probe = jsonstat_to_frame(json.loads(
        (RAW / "nama_10_a64_e_eu27_coverage_probe_2020.json").read_text(encoding="utf-8")
    ))
    probe["nace_norm"] = probe["nace_r2"].map(norm_a64)
    probe_mapped = probe[probe.nace_norm.isin(mapped_nace)]
    n_needed = len(mapped_nace)
    cov_rows = []
    for geo in EU27:
        g = probe_mapped[probe_mapped.geo == geo]
        gt = probe[(probe.geo == geo) & (probe.nace_r2 == "TOTAL")]
        row = {"geo": geo}
        have = {}
        for unit in ["THS_PER", "THS_HW"]:
            for na_item in ["EMP_DC", "SAL_DC", "SELF_DC"]:
                codes = set(g[(g.unit == unit) & (g.na_item == na_item)]["nace_norm"])
                have[(unit, na_item)] = codes
                row[f"n_A64_{na_item}_{unit}"] = len(codes)
            t = gt[(gt.unit == unit) & (gt.na_item == "EMP_DC")]["value"]
            row[f"TOTAL_EMP_DC_{unit}"] = float(t.iloc[0]) if len(t) else None
        row["complete_all_6_combos"] = all(
            len(have[(u, ni)]) == n_needed
            for u in ["THS_PER", "THS_HW"] for ni in ["EMP_DC", "SAL_DC", "SELF_DC"]
        )
        row["missing_A64_EMP_persons"] = ", ".join(
            c for c in mapped_nace if c not in have[("THS_PER", "EMP_DC")])
        row["missing_A64_EMP_hours"] = ", ".join(
            c for c in mapped_nace if c not in have[("THS_HW", "EMP_DC")])
        # SELF suppressed where EMP exists -> derivable as EMP - SAL if SAL exists
        self_gap = sorted(
            (have[("THS_PER", "EMP_DC")] - have[("THS_PER", "SELF_DC")])
            | (have[("THS_HW", "EMP_DC")] - have[("THS_HW", "SELF_DC")])
        )
        row["SELF_missing_where_EMP_present"] = ", ".join(self_gap)
        row["SELF_gap_closable_by_EMP_minus_SAL"] = all(
            c in have[("THS_PER", "SAL_DC")] for c in self_gap) if self_gap else ""
        cov_rows.append(row)
    coverage = pd.DataFrame(cov_rows)
    coverage.insert(1, "n_A64_codes_needed", n_needed)

    # ---------------- mapping sheet ----------------
    mapping = pd.DataFrame(
        [{"cluster": c["label"], "n_greu": len(c["greu"]), "n_a64": len(c["nace"]),
          "greu_industries": ", ".join(c["greu"]), "a64_codes": ", ".join(c["nace"])}
         for c in clusters]
    )

    # ---------------- description of employed.xlsx & usage ----------------
    usage = pd.DataFrame([
        {"item": "file", "detail": "data/preprocessing/data/employed.xlsx, single sheet 'Sheet1'"},
        {"item": "columns", "detail": "year, indu (57 GREU industry codes), type ('employees'/'self-employed'), employed, hours"},
        {"item": "years", "detail": "2019 and 2020 (207 rows; some industries lack a self-employed row)"},
        {"item": "unit: employed", "detail": "persons (units). DK 2020 total = 2,869,924"},
        {"item": "unit: hours", "detail": "thousand hours per year. DK 2020 total = 3,982,709 (= 3.98 bn hours; matches Eurostat THS_HW exactly)"},
        {"item": "read_data.py line 331", "detail": "employed_fullset = pd.read_excel('../data/preprocessing/data/employed.xlsx')"},
        {"item": "read_data.py lines 333-334", "detail": "splits hours by type: employees vs self-employed, per industry and year"},
        {"item": "read_data.py line 351", "detail": "wagesum_ = wagesum + wagesum * hours_self-employed / hours_employees  (imputes independents' labour income; only the hours RATIO per industry matters)"},
        {"item": "read_data.py lines 358-359", "detail": "nemployed_frame = employed column summed over industries AND types, per year (a single national scalar)"},
        {"item": "read_data.py line 686", "detail": "GAMS parameter nEmployed(t) 'Total number of employees including independents' from that scalar"},
        {"item": "model needs", "detail": "(1) hours by industry x employees/self-employed (only the ratio is used); (2) national total persons employed. Head counts by industry and the 'employed' column per industry are NOT otherwise consumed. No FTE concept is used."},
    ])

    # ---------------- anomalies ----------------
    worst_per = per_cl.iloc[:-1].reindex(
        per_cl.iloc[:-1]["pct_diff_total"].abs().sort_values(ascending=False).index
    ).head(3)
    anomalies = pd.DataFrame([
        {"anomaly": "Persons level gap", "detail":
            "Danish 'employed' 2020 total is 2,869,924 persons vs Eurostat EMP_DC "
            "2,970,850 (Eurostat +3.52%). Hours match to <0.001%, so both trace to "
            "DST national accounts; the Danish file's head count is on a different "
            "person concept/vintage than the published NA annual-average "
            "employment. Affects only the scalar nEmployed, not the hours-ratio "
            "wage imputation."},
        {"anomaly": "Employees vs self-employed persons split", "detail":
            "DK 2020 employees 2,695,648 vs SAL_DC 2,792,480 (+3.59%); "
            "self-employed 174,276 vs SELF_DC 178,370 (+2.35%)."},
        {"anomaly": "Worst persons clusters", "detail": "; ".join(
            f"{r.cluster}: dk {r.dk_total_persons:,.0f} vs es "
            f"{r.eurostat_total_persons:,.0f} ({r.pct_diff_total:+.2f}%)"
            for r in worst_per.itertuples())},
        {"anomaly": "Real-estate boundary (cluster L)", "detail":
            "Known from the FIGARO pilot: GREU 68203 'Housing sector' is dwellings "
            "only, the rest of NACE L sits in GREU 71000, so the concordance line "
            "L<->68203 is not value-consistent. Here: L hours dk 23,483 vs es "
            "65,769 thousand (+180.1%), mirrored by the business-services cluster "
            "(-8.9%) and I+J58+... (-3.4%)."},
        {"anomaly": "Public-sector cluster persons gap", "detail":
            "O+P+Q86+Q87_88+R90-92 persons dk 879,883 vs es 944,620 (+7.36%) while "
            "its hours differ only +1.87% - consistent with the national persons-"
            "concept gap concentrating in public services (part-time/leave "
            "handling)."},
        {"anomaly": "Missing self-employed rows in employed.xlsx", "detail":
            f"{57 * 2 * 2 - 207} of 228 expected year x industry x type rows are "
            "absent (industries with no self-employed, e.g. public sector 'off'); "
            "read_data.py reindexes with fill_value=0, Eurostat publishes explicit "
            "small non-zero SELF_DC values for some of these (checked in "
            "persons_by_cluster / hours_by_cluster)."},
        {"anomaly": "Eurostat A64 codes unused by the concordance", "detail":
            ", ".join(unmapped_nace) if unmapped_nace else
            "none - every A64 leaf in nama_10_a64_e except U (extraterritorial "
            "organisations) is reachable from the GREU map; U is unmapped as in "
            "the FIGARO pilot."},
        {"anomaly": "NACE spelling", "detail":
            "nama_10_a64_e uses the same spelling as metadata.xlsx (C10-C12, "
            "J59_J60): zero codes dropped on join. Defensive normalization to "
            "C10-12-style applied on both sides anyway."},
        {"anomaly": "THS_JOB absent for DK", "detail":
            "The jobs unit (THS_JOB) has no DK 2020 observations; persons and "
            "hours are complete (96/96 NACE codes for all three na_items)."},
        {"anomaly": "Cluster count vs docs", "detail":
            "docs/eu_data_mapping.md says '24 clusters'; the FIGARO pilot artifact "
            "figaro_dk2020_reconciliation.xlsx mapping sheet actually holds 28 "
            "mapped clusters (+1 unmapped U). This pilot's 28 clusters match that "
            "artifact exactly."},
        {"anomaly": "SE 2020: six A64 codes suppressed", "detail":
            "Sweden lacks C20, C21, H52, H53, M71, M72 in ALL na_item x unit "
            "combinations. Parent aggregates are published, so pair residuals are "
            "derivable (EMP_DC persons: C20+C21 = 29k, H52+H53 = 105k, "
            "M71+M72 = 167k) but splitting each pair needs an external key (e.g. "
            "SBS employment). C20, C21, H52, H53 are single-industry GREU "
            "clusters, so an SE build is COARSER there."},
        {"anomaly": "Hours not at A64 for several countries", "detail":
            "THS_HW is published at roughly A38 level only for DE, FR, BE, BG, LT "
            "(~19-21 of the 63 mapped codes) and at section level only for EE (8). "
            "LU publishes ~34 codes and MT 55 for BOTH units. Filling A64 hours "
            "for these countries requires distributing coarser hours over A64 "
            "persons shares (assume equal hours per person within the aggregate)."},
        {"anomaly": "SELF_DC suppressed for some cells", "detail":
            "HU (19 codes), FI (K65, O, T), LT (O), EE (K65, K66) miss SELF_DC "
            "where EMP_DC exists; SAL_DC is present there, so self-employed is "
            "recoverable as EMP_DC - SAL_DC (see eu27_se_coverage sheet, column "
            "SELF_gap_closable_by_EMP_minus_SAL)."},
    ])

    readme = pd.DataFrame([
        {"key": "title", "value": "Reconciliation: Eurostat nama_10_a64_e vs employed.xlsx, Denmark 2020"},
        {"key": "created", "value": created},
        {"key": "created_by", "value": "data/preprocessing/scripts/reconcile_employment_dk_2020.py"},
        {"key": "purpose", "value": "Pilot test of the eu_data_mapping.md 'OK' verdict: can nama_10_a64_e (persons + hours by NACE A64, EMP/SAL/SELF split) replace the Danish employed.xlsx input for any EU country?"},
        {"key": "danish_source", "value": "data/preprocessing/data/employed.xlsx (year=2020 slice)"},
        {"key": "eurostat_source", "value": "nama_10_a64_e via https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nama_10_a64_e (JSON-stat 2.0)"},
        {"key": "eurostat_retrieval_date", "value": retrieval_date},
        {"key": "raw_data", "value": "data/preprocessing/data/employment_raw/DK/2020/ (README.md + manifest.json with URLs, params, SHA-256)"},
        {"key": "concordance", "value": "data/preprocessing/data/metadata.xlsx sheet industries_naceA64_map (57 GREU <-> 63 A64 codes, many-to-many)"},
        {"key": "method", "value": f"Comparison on {len(clusters)} connected-component clusters of the bipartite GREU-A64 graph, as in the FIGARO/PEFA pilots. No observation is split among finer industries."},
        {"key": "units", "value": "persons: employed.xlsx 'employed' is persons; Eurostat THS_PER x 1000. hours: both sides thousand hours (THS_HW)."},
        {"key": "sheets", "value": "employed_file_usage | totals | persons_by_cluster | hours_by_cluster | eu27_se_coverage | mapping | anomalies"},
    ])

    with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
        readme.to_excel(xl, sheet_name="readme", index=False)
        usage.to_excel(xl, sheet_name="employed_file_usage", index=False)
        totals.to_excel(xl, sheet_name="totals", index=False)
        per_cl.to_excel(xl, sheet_name="persons_by_cluster", index=False)
        hw_cl.to_excel(xl, sheet_name="hours_by_cluster", index=False)
        coverage.to_excel(xl, sheet_name="eu27_se_coverage", index=False)
        mapping.to_excel(xl, sheet_name="mapping", index=False)
        anomalies.to_excel(xl, sheet_name="anomalies", index=False)
    print(f"wrote {OUT}")

    # ---------------- console report ----------------
    pd.set_option("display.width", 250)
    print(f"\nclusters: {len(clusters)}")
    print("\nTOTALS:")
    print(totals.to_string(index=False))
    print("\nPERSONS by cluster (worst 8 by |pct_diff_total|):")
    body = per_cl.iloc[:-1]
    cols = ["cluster", "dk_total_persons", "eurostat_total_persons", "diff_total",
            "pct_diff_total", "pct_diff_employees", "pct_diff_self_employed"]
    print(body.reindex(body["pct_diff_total"].abs().sort_values(ascending=False).index)
          [cols].head(8).to_string(index=False))
    print("\nHOURS by cluster (worst 8 by |pct_diff_total|):")
    body = hw_cl.iloc[:-1]
    cols = ["cluster", "dk_total_ths_hours", "eurostat_total_ths_hours", "diff_total",
            "pct_diff_total", "pct_diff_employees", "pct_diff_self_employed"]
    print(body.reindex(body["pct_diff_total"].abs().sort_values(ascending=False).index)
          [cols].head(8).to_string(index=False))
    print("\nEU-27 coverage (countries NOT complete for all 6 na_item x unit combos):")
    inc = coverage[~coverage["complete_all_6_combos"]]
    print(inc.to_string(index=False) if len(inc) else "  none - all 27 complete")
    print("\nSweden row:")
    print(coverage[coverage.geo == "SE"].to_string(index=False))


if __name__ == "__main__":
    main()
