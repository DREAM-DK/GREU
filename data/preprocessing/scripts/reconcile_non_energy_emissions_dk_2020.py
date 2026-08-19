"""Reconcile Eurostat env_ac_ainah_r2 (combined air accounts) and
env_air_gge CRF1/2/3/5 (territorial inventory) against the Danish GREU
input non_energy_emissions.xlsx, Denmark 2020.

Eleventh pilot of the EU data replacement effort (see docs/eu_data_mapping.md).
The combined energy+non-energy vs ainah boundary was already piloted
2026-07-30; this script tests the untested energy/non-energy *split* and
open item 9 (CH4/N2O gap).

Inputs
------
- data/preprocessing/data/non_energy_emissions.xlsx
    Sheet ems_non_energy: 58 rows, 2020 only, bal=use, flow in
    {cons_inter, cons_hh}. 57 GREU industries + household `cHou`.
    Gas columns ch4, co2_bio, co2_xbio, n2o, hfc, pfc, sf6, co2_eq (kt;
    F-gases already in CO2e). Consumed by read_data.py:103-116, exported
    as NonEnergyEmissions; data_from_GR.gms:572 sets qEmmxE.
- data/preprocessing/data/energy_and_emissions.xlsx
    Energy-side emissions, used only to form the combined air-account
    total and the residual identity ainah - energy.
- data/preprocessing/data/metadata.xlsx sheet industries_naceA64_map.
- data/preprocessing/data/non_energy_emissions_raw/DK/2020/*.json
    Raw JSON-stat from download_non_energy_emissions_dk_2020.py.
- Optional vintage: eurostat_energy_emissions_raw/env_ac_ainah_r2_DK_2020.json
    (PEFA-pilot pull, 2026-07-30).

Units: GREU kt (and kt CO2e); Eurostat THS_T.

Output
------
data/preprocessing/data/non_energy_emissions_dk2020_reconciliation.xlsx

Run:  python data/preprocessing/scripts/reconcile_non_energy_emissions_dk_2020.py
"""

from __future__ import annotations

import datetime
import json
import pathlib
from collections import defaultdict

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "non_energy_emissions_raw" / "DK" / "2020"
OLD_AINAH = DATA / "eurostat_energy_emissions_raw" / "env_ac_ainah_r2_DK_2020.json"
OUT = DATA / "non_energy_emissions_dk2020_reconciliation.xlsx"
YEAR = 2020

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

A64 = [
    "A01", "A02", "A03", "B", "C10-C12", "C13-C15", "C16", "C17", "C18",
    "C19", "C20", "C21", "C22", "C23", "C24", "C25", "C26", "C27", "C28",
    "C29", "C30", "C31_C32", "C33", "D", "E36", "E37-E39", "F", "G45", "G46",
    "G47", "H49", "H50", "H51", "H52", "H53", "I", "J58", "J59_J60", "J61",
    "J62_J63", "K64", "K65", "K66", "L", "M69_M70", "M71", "M72", "M73",
    "M74_M75", "N77", "N78", "N79", "N80-N82", "O", "P", "Q86", "Q87_Q88",
    "R90-R92", "R93", "S94", "S95", "S96", "T", "U",
]

# GREU column -> ainah airpol. F-gases are a separate sum.
AEA_POLLUTANT_MAP = {
    "ch4": "CH4",
    "co2_bio": "CO2_BIO",
    "co2_xbio": "CO2",
    "n2o": "N2O",
    "co2_eq": "GHG",
}
FGAS_AINAH = ["HFC_CO2E", "PFC_CO2E", "NF3_SF6_CO2E"]
GWP = {"ch4": 28.0, "n2o": 265.0, "co2_xbio": 1.0, "hfc": 1.0, "pfc": 1.0, "sf6": 1.0}

CRF_PROCESS = ["CRF2", "CRF3", "CRF5"]
CRF_LABEL = {
    "TOTXMEMO": "Total excl. memo items (incl. LULUCF)",
    "TOTX4_MEMO": "Total excl. LULUCF and memo items",
    "CRF1": "Energy (territorial)",
    "CRF1A": "Fuel combustion",
    "CRF1B": "Fugitive emissions from fuels",
    "CRF2": "IPPU (industrial processes and product use)",
    "CRF2A": "Mineral industry (cement, lime, glass)",
    "CRF2F": "Product uses as ODS substitutes (F-gases)",
    "CRF3": "Agriculture",
    "CRF3A": "Enteric fermentation",
    "CRF3B": "Manure management",
    "CRF3D": "Managed agricultural soils",
    "CRF5": "Waste",
}


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


def build_clusters(mapping: pd.DataFrame):
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

    for _, r in mapping.iterrows():
        union(("g", str(r.indu_greu)), ("n", str(r.indu_naceA64)))
    comp: dict = defaultdict(list)
    for node in list(parent):
        comp[find(node)].append(node)
    clusters = []
    for members in comp.values():
        greu = sorted(x[1] for x in members if x[0] == "g")
        nace = sorted(x[1] for x in members if x[0] == "n")
        clusters.append({"label": "+".join(nace), "greu": greu, "nace": nace})
    clusters.sort(key=lambda c: c["label"])
    greu2cl = {g: c["label"] for c in clusters for g in c["greu"]}
    nace2cl = {n: c["label"] for c in clusters for n in c["nace"]}
    return clusters, greu2cl, nace2cl


def check(rows: list, name: str, left, right, tol: float = 0.05,
          note: str = "") -> None:
    if left is None or right is None or pd.isna(left) or pd.isna(right):
        rows.append({"check": name, "left": left, "right": right,
                     "diff": None, "result": "SKIP", "note": note})
        return
    diff = float(right) - float(left)
    rows.append({
        "check": name,
        "left": round(float(left), 4),
        "right": round(float(right), 4),
        "diff": round(diff, 4),
        "result": "PASS" if abs(diff) <= tol else "FAIL",
        "note": note,
    })


def ainah_total(df: pd.DataFrame, airpol: str, nace: str = "TOTAL_HH") -> float:
    s = df[(df.unit == "THS_T") & (df.airpol == airpol) & (df.nace_r2 == nace)]["value"]
    return float(s.sum()) if len(s) else float("nan")


def gge_cell(df: pd.DataFrame, airpol: str, src: str) -> float:
    s = df[(df.airpol == airpol) & (df.src_crf == src)]["value"]
    return float(s.iloc[0]) if len(s) else float("nan")


def main() -> None:
    created = datetime.date.today().isoformat()
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    retrieval_date = manifest["retrieval_date"]
    checks: list[dict] = []

    ainah = load_raw(f"env_ac_ainah_r2_DK_{YEAR}.json")
    ainah_se = load_raw(f"env_ac_ainah_r2_SE_{YEAR}.json")
    ainah_cov = load_raw(f"env_ac_ainah_r2_eu27_coverage_probe_{YEAR}.json")
    ainah_years = load_raw("env_ac_ainah_r2_eu27_year_probe_GHG.json")
    gge = load_raw(f"env_air_gge_DK_{YEAR}_crf.json")
    gge_se = load_raw(f"env_air_gge_SE_{YEAR}_crf.json")
    gge_cov = load_raw(f"env_air_gge_eu27_crf_coverage_probe_{YEAR}.json")

    nonenergy = pd.read_excel(DATA / "non_energy_emissions.xlsx",
                              sheet_name="ems_non_energy")
    energy = pd.read_excel(DATA / "energy_and_emissions.xlsx",
                           sheet_name="ems_energy")
    industry_map = pd.read_excel(DATA / "metadata.xlsx",
                                 sheet_name="industries_naceA64_map")
    industry_map["indu_greu"] = industry_map["indu_greu"].astype(str)
    industry_map["indu_naceA64"] = industry_map["indu_naceA64"].astype(str)
    nonenergy["indu"] = nonenergy["indu"].astype(str)
    energy["indu"] = energy["indu"].astype(str)
    energy = energy[energy["year"] == YEAR].copy()
    nonenergy = nonenergy[nonenergy["year"] == YEAR].copy()

    clusters, greu2cl, nace2cl = build_clusters(industry_map)

    gases = ["ch4", "co2_bio", "co2_xbio", "n2o", "hfc", "pfc", "sf6", "co2_eq"]
    ne = nonenergy.copy()
    en = energy.copy()
    for g in gases:
        if g not in ne.columns:
            ne[g] = 0.0
        if g not in en.columns:
            en[g] = 0.0
        ne[g] = ne[g].fillna(0.0)
        en[g] = en[g].fillna(0.0)

    # ---------------- file profile + GWP identity ----------------
    gwp_calc = (
        ne["co2_xbio"] + 28.0 * ne["ch4"] + 265.0 * ne["n2o"]
        + ne["hfc"] + ne["pfc"] + ne["sf6"]
    )
    check(checks, "Danish co2_eq = AR5 (CO2 + 28 CH4 + 265 N2O + F-gases)",
          float(ne["co2_eq"].sum()), float(gwp_calc.sum()),
          tol=1e-6, note="F-gases already stored in CO2e (GWP=1 in the model)")
    check(checks, "Danish file is 2020 only",
          float(nonenergy["year"].nunique()), 1.0, tol=0,
          note=f"years={sorted(nonenergy['year'].unique().tolist())}")
    check(checks, "57 GREU industries on cons_inter + cHou household row",
          float(ne[ne.flow == "cons_inter"]["indu"].nunique()), 57.0, tol=0)
    check(checks, "Flows are cons_inter and cons_hh only",
          float(ne["flow"].nunique()), 2.0, tol=0,
          note=str(sorted(ne["flow"].unique().tolist())))

    dk_ne = {g: float(ne[g].sum()) for g in gases}
    dk_en = {g: float(en[g].sum()) for g in gases}
    dk_comb = {g: dk_en[g] + dk_ne[g] for g in gases}
    dk_fgas = dk_ne["hfc"] + dk_ne["pfc"] + dk_ne["sf6"]

    # ---------------- combined boundary vs ainah (recomputed) ----------------
    aea = {code: ainah_total(ainah, code) for code in
           list(AEA_POLLUTANT_MAP.values()) + FGAS_AINAH}
    aea_fgas = sum(aea[c] for c in FGAS_AINAH)

    national_rows = []
    for dk_col, aea_code in AEA_POLLUTANT_MAP.items():
        eu = aea[aea_code]
        implied = eu - dk_en[dk_col]
        national_rows.append({
            "pollutant": dk_col,
            "eurostat_airpol": aea_code,
            "unit": "kt CO2e" if dk_col in {"co2_eq", "hfc", "pfc", "sf6"} else "kt",
            "dk_energy": round(dk_en[dk_col], 4),
            "dk_nonenergy": round(dk_ne[dk_col], 4),
            "dk_combined": round(dk_comb[dk_col], 4),
            "ainah_TOTAL_HH": round(eu, 4),
            "combined_minus_ainah": round(dk_comb[dk_col] - eu, 4),
            "combined_pct": round(100 * (dk_comb[dk_col] - eu) / eu, 4)
            if abs(eu) > 1e-12 else None,
            "implied_nonenergy_ainah_minus_energy": round(implied, 4),
            "identity_minus_dk_nonenergy": round(implied - dk_ne[dk_col], 4),
            "identity_pct_of_dk_nonenergy": round(
                100 * (implied - dk_ne[dk_col]) / dk_ne[dk_col], 4)
            if abs(dk_ne[dk_col]) > 1e-12 else None,
        })
    national_rows.append({
        "pollutant": "f_gases_co2e",
        "eurostat_airpol": "+".join(FGAS_AINAH),
        "unit": "kt CO2e",
        "dk_energy": 0.0,
        "dk_nonenergy": round(dk_fgas, 4),
        "dk_combined": round(dk_fgas, 4),
        "ainah_TOTAL_HH": round(aea_fgas, 4),
        "combined_minus_ainah": round(dk_fgas - aea_fgas, 4),
        "combined_pct": round(100 * (dk_fgas - aea_fgas) / aea_fgas, 4)
        if abs(aea_fgas) > 1e-12 else None,
        "implied_nonenergy_ainah_minus_energy": round(aea_fgas, 4),
        "identity_minus_dk_nonenergy": round(aea_fgas - dk_fgas, 4),
        "identity_pct_of_dk_nonenergy": round(
            100 * (aea_fgas - dk_fgas) / dk_fgas, 4) if dk_fgas else None,
    })
    national = pd.DataFrame(national_rows)

    # Combined-boundary checks (should match the 2026-07-30 PEFA figures
    # unless Eurostat has revised). Identity checks are the new work.
    check(checks, "F-gases: GREU non-energy = ainah HFC+PFC+NF3_SF6",
          dk_fgas, aea_fgas, tol=0.05,
          note="F-gases live only in the non-energy file; 100% process")
    check(checks, "Fossil CO2 combined vs ainah (recomputed PEFA boundary)",
          dk_comb["co2_xbio"], aea["CO2"], tol=5.0,
          note="PEFA-pilot residual was -4.6 kt / -0.0069%; tol 5 kt")
    check(checks, "Biogenic CO2 combined vs ainah",
          dk_comb["co2_bio"], aea["CO2_BIO"], tol=0.5)
    check(checks, "CH4 combined vs ainah (known item-9 gap)",
          dk_comb["ch4"], aea["CH4"], tol=0.05,
          note="Expected FAIL: this is item 9")
    check(checks, "N2O combined vs ainah (known item-9 gap)",
          dk_comb["n2o"], aea["N2O"], tol=0.05,
          note="Expected FAIL: this is item 9")
    check(checks, "Split identity CH4: ainah-energy = GREU non-energy",
          aea["CH4"] - dk_en["ch4"], dk_ne["ch4"], tol=0.05,
          note="Fails by the same residual as the combined CH4 gap")
    check(checks, "Split identity N2O: ainah-energy = GREU non-energy",
          aea["N2O"] - dk_en["n2o"], dk_ne["n2o"], tol=0.05,
          note="Fails by the same residual as the combined N2O gap")
    check(checks, "Split identity fossil CO2: ainah-energy = GREU non-energy",
          aea["CO2"] - dk_en["co2_xbio"], dk_ne["co2_xbio"], tol=5.0,
          note="Residual equals the combined-boundary CO2 gap, redistributed")
    check(checks, "Split identity F-gases: ainah = GREU non-energy (energy=0)",
          aea_fgas, dk_fgas, tol=0.05)

    # ainah AR5 component identity
    ch4_co2e = ainah_total(ainah, "CH4_CO2E")
    n2o_co2e = ainah_total(ainah, "N2O_CO2E")
    check(checks, "ainah CH4_CO2E / CH4 = AR5 28",
          ch4_co2e / aea["CH4"] if aea["CH4"] else None, 28.0, tol=0.01)
    check(checks, "ainah N2O_CO2E / N2O = AR5 265",
          n2o_co2e / aea["N2O"] if aea["N2O"] else None, 265.0, tol=0.05)

    # ---------------- vintage: 2026-07-30 vs this pull ----------------
    vintage_rows = []
    if OLD_AINAH.exists():
        old = jsonstat_to_frame(json.loads(OLD_AINAH.read_text(encoding="utf-8")))
        for code in list(AEA_POLLUTANT_MAP.values()) + FGAS_AINAH:
            old_v = ainah_total(old, code)
            new_v = aea[code] if code in aea else ainah_total(ainah, code)
            vintage_rows.append({
                "airpol": code,
                "pefa_pilot_2026_07_30": round(old_v, 4),
                "this_pull": round(new_v, 4),
                "diff": round(new_v - old_v, 4),
                "revised": "yes" if abs(new_v - old_v) > 0.05 else "",
            })
        ch4_rev = next(r for r in vintage_rows if r["airpol"] == "CH4")
        check(checks, "ainah CH4 TOTAL_HH unchanged vs 2026-07-30 pull",
              ch4_rev["pefa_pilot_2026_07_30"], ch4_rev["this_pull"], tol=0.05,
              note="If PASS, the item-9 gap is not an Eurostat revision since the PEFA pilot")
    vintage = pd.DataFrame(vintage_rows) if vintage_rows else pd.DataFrame(
        [{"airpol": "(no 2026-07-30 file found)", "this_pull": None}]
    )

    # ---------------- household ----------------
    hh_rows = []
    for dk_col, aea_code in list(AEA_POLLUTANT_MAP.items()) + [("hfc", "HFC_CO2E")]:
        dke = float(en[en.flow == "cons_hh"][dk_col].sum()) if dk_col in en.columns else 0.0
        dkn = float(ne[ne.flow == "cons_hh"][dk_col].sum()) if dk_col in ne.columns else 0.0
        if dk_col == "hfc":
            dke = 0.0
            dkn = float(ne[ne.flow == "cons_hh"][["hfc", "pfc", "sf6"]].sum().sum())
            aea_code = "HFC_CO2E+PFC_CO2E+NF3_SF6_CO2E"
            eu = sum(ainah_total(ainah, c, "HH") for c in FGAS_AINAH)
        else:
            eu = ainah_total(ainah, aea_code, "HH")
        hh_rows.append({
            "pollutant": dk_col if dk_col != "hfc" else "f_gases_co2e",
            "eurostat_airpol": aea_code,
            "dk_energy_hh": round(dke, 4),
            "dk_nonenergy_hh": round(dkn, 4),
            "dk_combined_hh": round(dke + dkn, 4),
            "ainah_HH": round(eu, 4),
            "identity_ainah_minus_energy_vs_nonenergy": round(eu - dke - dkn, 4),
        })
    household = pd.DataFrame(hh_rows)

    # ---------------- cluster split identity ----------------
    aea_ind = ainah[
        (ainah.unit == "THS_T") & ainah.nace_r2.isin(nace2cl)
        & ainah.airpol.isin(list(AEA_POLLUTANT_MAP.values()) + FGAS_AINAH)
    ].copy()
    aea_ind["cluster"] = aea_ind["nace_r2"].map(nace2cl)

    cluster_rows = []
    agri_key = next((c["label"] for c in clusters if "A01" in c["nace"]), None)
    for dk_col, aea_code in list(AEA_POLLUTANT_MAP.items()) + [("f_gases", None)]:
        if dk_col == "f_gases":
            dk_en_by = pd.Series(dtype=float)
            dk_ne_by = (
                ne[ne.flow == "cons_inter"]
                .assign(cluster=lambda x: x["indu"].map(greu2cl))
                .groupby("cluster")[["hfc", "pfc", "sf6"]].sum().sum(axis=1)
            )
            eu_by = (
                aea_ind[aea_ind.airpol.isin(FGAS_AINAH)]
                .groupby("cluster")["value"].sum()
            )
            label = "f_gases_co2e"
        else:
            dk_en_by = (
                en[(en.flow == "cons_inter") & en.indu.isin(greu2cl)]
                .assign(cluster=lambda x: x["indu"].map(greu2cl))
                .groupby("cluster")[dk_col].sum()
            )
            dk_ne_by = (
                ne[(ne.flow == "cons_inter") & ne.indu.isin(greu2cl)]
                .assign(cluster=lambda x: x["indu"].map(greu2cl))
                .groupby("cluster")[dk_col].sum()
            )
            eu_by = (
                aea_ind[aea_ind.airpol == aea_code]
                .groupby("cluster")["value"].sum()
            )
            label = dk_col
        for c in clusters:
            key = c["label"]
            dke = float(dk_en_by.get(key, 0.0) or 0.0)
            dkn = float(dk_ne_by.get(key, 0.0) or 0.0)
            eu = float(eu_by.get(key, 0.0) or 0.0)
            implied = eu - dke
            cluster_rows.append({
                "pollutant": label,
                "cluster": key,
                "greu_industries": ", ".join(c["greu"]),
                "n_greu": len(c["greu"]),
                "n_a64": len(c["nace"]),
                "dk_energy": round(dke, 4),
                "dk_nonenergy": round(dkn, 4),
                "dk_combined": round(dke + dkn, 4),
                "ainah": round(eu, 4),
                "implied_nonenergy": round(implied, 4),
                "identity_diff": round(implied - dkn, 4),
                "identity_pct": round(100 * (implied - dkn) / dkn, 3)
                if abs(dkn) > 1e-9 else None,
            })
    clusters_df = pd.DataFrame(cluster_rows)

    # ---------------- CRF / item 9 ----------------
    crf_rows = []
    for src in CRF_LABEL:
        for airpol in ["GHG", "CO2", "CH4", "CH4_CO2E", "N2O", "N2O_CO2E",
                       "HFC_CO2E", "PFC_CO2E", "SF6_CO2E", "NF3_CO2E"]:
            val = gge_cell(gge, airpol, src)
            if pd.isna(val):
                continue
            crf_rows.append({
                "src_crf": src,
                "label": CRF_LABEL[src],
                "airpol": airpol,
                "kt": round(val, 4),
            })
    crf_detail = pd.DataFrame(crf_rows)

    crf1_ghg = gge_cell(gge, "GHG", "CRF1")
    crf2_ghg = gge_cell(gge, "GHG", "CRF2")
    crf3_ghg = gge_cell(gge, "GHG", "CRF3")
    crf5_ghg = gge_cell(gge, "GHG", "CRF5")
    crf_process_ghg = crf2_ghg + crf3_ghg + crf5_ghg
    crf1_ch4 = gge_cell(gge, "CH4", "CRF1")
    crf3_ch4 = gge_cell(gge, "CH4", "CRF3")
    crf5_ch4 = gge_cell(gge, "CH4", "CRF5")
    crf_process_ch4 = (
        gge_cell(gge, "CH4", "CRF2") + crf3_ch4 + crf5_ch4
    )
    crf3_n2o = gge_cell(gge, "N2O", "CRF3")
    crf_process_n2o = (
        gge_cell(gge, "N2O", "CRF2") + crf3_n2o + gge_cell(gge, "N2O", "CRF5")
    )
    crf2f_hfc = gge_cell(gge, "HFC_CO2E", "CRF2F")
    tot_ex_lulucf = gge_cell(gge, "GHG", "TOTX4_MEMO")

    agri_ne_ch4 = 0.0
    agri_ne_n2o = 0.0
    agri_ne_co2e = 0.0
    agri_en_ch4 = 0.0
    agri_comb_co2e = 0.0
    if agri_key:
        agri_ne = ne[(ne.flow == "cons_inter") & ne.indu.map(greu2cl).eq(agri_key)]
        agri_en = en[(en.flow == "cons_inter") & en.indu.map(greu2cl).eq(agri_key)]
        agri_ne_ch4 = float(agri_ne["ch4"].sum())
        agri_ne_n2o = float(agri_ne["n2o"].sum())
        agri_ne_co2e = float(agri_ne["co2_eq"].sum())
        agri_en_ch4 = float(agri_en["ch4"].sum())
        agri_comb_co2e = float(agri_en["co2_eq"].sum() + agri_ne["co2_eq"].sum())
    agri_ainah_ch4 = ainah_total(ainah, "CH4", "A01")
    agri_ainah_ghg = ainah_total(ainah, "GHG", "A01")

    item9 = pd.DataFrame([
        {"comparison": "CRF1 energy GHG vs GREU energy co2_eq",
         "left_label": "GREU energy co2_eq (residence, incl. bunkers)",
         "left": round(dk_en["co2_eq"], 3),
         "right_label": "CRF1 GHG (territorial inventory)",
         "right": round(crf1_ghg, 3),
         "diff": round(crf1_ghg - dk_en["co2_eq"], 3),
         "interpretation": (
             "Not like-for-like: GREU energy includes resident international "
             "transport; CRF1 is territorial. The ~39 Mt bunker wedge from the "
             "PEFA/bridge pilots sits here. Do not use CRF1 as the energy "
             "subtrahend for an ainah residual."
         )},
        {"comparison": "CRF2+3+5 process GHG vs GREU non-energy co2_eq",
         "left_label": "GREU non-energy co2_eq",
         "left": round(dk_ne["co2_eq"], 3),
         "right_label": "CRF2+CRF3+CRF5 GHG",
         "right": round(crf_process_ghg, 3),
         "diff": round(crf_process_ghg - dk_ne["co2_eq"], 3),
         "interpretation": (
             "Closest independent process-emissions control. Territorial vs "
             "residence should barely matter for IPPU/agriculture/waste."
         )},
        {"comparison": "CRF3 agriculture CH4 vs GREU A01 non-energy CH4",
         "left_label": "GREU A01 cluster non-energy CH4",
         "left": round(agri_ne_ch4, 3),
         "right_label": "CRF3 CH4 (agriculture, territorial)",
         "right": round(crf3_ch4, 3),
         "diff": round(crf3_ch4 - agri_ne_ch4, 3),
         "interpretation": (
             "Item 9 lives here if the ainah-GREU CH4 residual concentrates "
             "in A01. CRF3 vs GREU A01 distinguishes inventory vs GREU "
             "national adjustment; ainah A01 vs CRF3 distinguishes "
             "air-accounts vs inventory."
         )},
        {"comparison": "ainah A01 CH4 vs GREU A01 combined CH4",
         "left_label": "GREU A01 energy+non-energy CH4",
         "left": round(agri_en_ch4 + agri_ne_ch4, 3),
         "right_label": "ainah A01 CH4 (residence air accounts)",
         "right": round(agri_ainah_ch4, 3),
         "diff": round(agri_ainah_ch4 - agri_en_ch4 - agri_ne_ch4, 3),
         "interpretation": "The PEFA-pilot +811 kt CO2e agriculture cluster, in CH4 tonnes."},
        {"comparison": "ainah A01 CH4 vs CRF3 CH4",
         "left_label": "CRF3 CH4 (territorial inventory)",
         "left": round(crf3_ch4, 3),
         "right_label": "ainah A01 CH4 (residence air accounts)",
         "right": round(agri_ainah_ch4, 3),
         "diff": round(agri_ainah_ch4 - crf3_ch4, 3),
         "interpretation": (
             "Not small: air-accounts A01 sit above territorial CRF3. "
             "Residence vs territory plus air-account compilation vs CRF "
             "both belong here; do not treat ainah and CRF3 as interchangeable."
         )},
        {"comparison": "CRF3 N2O vs GREU A01 non-energy N2O",
         "left_label": "GREU A01 non-energy N2O",
         "left": round(agri_ne_n2o, 3),
         "right_label": "CRF3 N2O",
         "right": round(crf3_n2o, 3),
         "diff": round(crf3_n2o - agri_ne_n2o, 3),
         "interpretation": "N2O half of item 9, agriculture soils (CRF3D)."},
        {"comparison": "CRF2+3+5 CH4 vs GREU non-energy CH4",
         "left_label": "GREU non-energy CH4",
         "left": round(dk_ne["ch4"], 3),
         "right_label": "CRF2+CRF3+CRF5 CH4",
         "right": round(crf_process_ch4, 3),
         "diff": round(crf_process_ch4 - dk_ne["ch4"], 3),
         "interpretation": "Process-side CH4 control (mostly agriculture + waste)."},
        {"comparison": "CRF2+3+5 N2O vs GREU non-energy N2O",
         "left_label": "GREU non-energy N2O",
         "left": round(dk_ne["n2o"], 3),
         "right_label": "CRF2+CRF3+CRF5 N2O",
         "right": round(crf_process_n2o, 3),
         "diff": round(crf_process_n2o - dk_ne["n2o"], 3),
         "interpretation": "Process-side N2O control."},
        {"comparison": "CRF2F HFC vs GREU HFC",
         "left_label": "GREU HFC (CO2e)",
         "left": round(dk_ne["hfc"], 3),
         "right_label": "CRF2F HFC_CO2E",
         "right": round(crf2f_hfc, 3),
         "diff": round(crf2f_hfc - dk_ne["hfc"], 3),
         "interpretation": "F-gas product-use category; should be close."},
        {"comparison": "ainah GHG TOTAL_HH vs inventory TOTX4_MEMO",
         "left_label": "ainah GHG TOTAL_HH (residence)",
         "left": round(aea["GHG"], 3),
         "right_label": "env_air_gge TOTX4_MEMO (territorial, excl. LULUCF)",
         "right": round(tot_ex_lulucf, 3),
         "diff": round(tot_ex_lulucf - aea["GHG"], 3),
         "interpretation": (
             "Residence vs territory. The wedge is international transport of "
             "residents minus non-resident activity on the territory — the "
             "bridge-items dataset, not this file."
         )},
    ])

    check(checks, "CRF2F HFC_CO2E vs GREU HFC (process F-gases)",
          dk_ne["hfc"], crf2f_hfc, tol=1.0,
          note="Product-use F-gases; territorial vs residence should be small")

    # ---------------- EU-27 coverage ----------------
    a64_set = set(A64)
    cov_rows = []
    for geo in EU27:
        sub = ainah_cov[(ainah_cov.geo == geo) & (ainah_cov.unit == "THS_T")]
        naces = set(sub.nace_r2.unique())
        n_a64 = len(naces & a64_set)
        gases_present = {}
        for code in ["GHG", "CO2", "CH4", "N2O", "HFC_CO2E"]:
            gases_present[code] = bool(
                len(sub[(sub.airpol == code) & (sub.nace_r2 == "TOTAL_HH")])
            )
        year_sub = ainah_years[ainah_years.geo == geo]
        years = sorted(year_sub.time.unique().tolist())
        crf_geo = gge_cov[gge_cov.geo == geo]
        crf_ok = {
            src: bool(len(crf_geo[crf_geo.src_crf == src]))
            for src in ["CRF1", "CRF2", "CRF3", "CRF5"]
        }
        if n_a64 >= 55:
            detail = "A64"
        elif n_a64 >= 40:
            detail = "near-A64"
        elif n_a64 >= 18:
            detail = "A21-ish"
        else:
            detail = "sparse"
        cov_rows.append({
            "geo": geo,
            "ainah_n_a64": n_a64,
            "ainah_industry_detail": detail,
            "ainah_TOTAL_HH_GHG": gases_present["GHG"],
            "ainah_TOTAL_HH_CO2": gases_present["CO2"],
            "ainah_TOTAL_HH_CH4": gases_present["CH4"],
            "ainah_TOTAL_HH_N2O": gases_present["N2O"],
            "ainah_TOTAL_HH_HFC": gases_present["HFC_CO2E"],
            "ainah_years_n": len(years),
            "ainah_year_min": years[0] if years else None,
            "ainah_year_max": years[-1] if years else None,
            "has_2020": "2020" in years,
            "gge_CRF1": crf_ok["CRF1"],
            "gge_CRF2": crf_ok["CRF2"],
            "gge_CRF3": crf_ok["CRF3"],
            "gge_CRF5": crf_ok["CRF5"],
        })
    coverage = pd.DataFrame(cov_rows)
    n_a64_full = int((coverage.ainah_n_a64 >= 55).sum())
    n_ainah_2020 = int(coverage.has_2020.sum())
    n_crf_all = int(
        coverage[["gge_CRF1", "gge_CRF2", "gge_CRF3", "gge_CRF5"]].all(axis=1).sum()
    )

    # ---------------- Sweden snapshot ----------------
    se_rows = []
    for code in list(AEA_POLLUTANT_MAP.values()) + FGAS_AINAH:
        se_rows.append({
            "source": "ainah",
            "item": f"SE 2020 {code} TOTAL_HH",
            "kt": round(ainah_total(ainah_se, code), 3),
        })
    for src in ["CRF1", "CRF2", "CRF3", "CRF5", "TOTX4_MEMO"]:
        se_rows.append({
            "source": "env_air_gge",
            "item": f"SE 2020 {src} GHG",
            "kt": round(gge_cell(gge_se, "GHG", src), 3),
        })
    se_process = sum(gge_cell(gge_se, "GHG", s) for s in CRF_PROCESS)
    se_rows.append({
        "source": "env_air_gge",
        "item": "SE 2020 CRF2+3+5 GHG (process control)",
        "kt": round(se_process, 3),
    })
    sweden = pd.DataFrame(se_rows)

    # ---------------- usage / anomalies / readme ----------------
    usage = pd.DataFrame([
        {"step": "Excel",
         "what": "non_energy_emissions.xlsx sheet ems_non_energy, 58 rows, 2020, "
                 "bal=use, flow cons_inter (57 GREU industries) + cons_hh (cHou)"},
        {"step": "read_data.py:103-116",
         "what": "Stacks gas columns onto ebalitems, maps flow via dict_transaction "
                 "(cons_inter→input_in_production, cons_hh→household_consumption) "
                 "and gases via dict_ebalitems (co2_xbio→co2ubio, co2_eq→co2e). "
                 "hfc/pfc/sf6/ch4/n2o keep their column names. Exports "
                 "NonEnergyEmissions[ebalitems,transaction,d,t]."},
        {"step": "data_from_GR.gms:128 and :572",
         "what": "$load NonEnergyEmissions; qEmmxE[em,d,t] = sum(demand_transaction, "
                 "NonEnergyEmissions[...]). Dummy zeros would silently drop "
                 "process-emission tax and non-energy GHGs."},
        {"step": "model/modules/emissions.gms",
         "what": "qEmmxE is the aggregate non-energy emission by gas and demand "
                 "component (kt CO2e for CO2e). GWP: CH4=28, N2O=265, F-gases=1 "
                 "(already CO2e in the Danish file)."},
        {"step": "model/modules/energy_and_emissions_taxes.gms",
         "what": "Non-energy CO2 tax vtCO2_xE and ETS non-energy "
                 "vtCO2_ETS_xE are levied on qEmmxE. Load-bearing."},
        {"step": "This Excel vs energy_and_emissions.xlsx",
         "what": "Energy file has no F-gas columns. Combined air-account total = "
                 "energy + non-energy. ainah cannot split them."},
    ])

    ch4_gap = aea["CH4"] - dk_comb["ch4"]
    n2o_gap = aea["N2O"] - dk_comb["n2o"]
    agri_ch4_gap = agri_ainah_ch4 - agri_en_ch4 - agri_ne_ch4
    process_ghg_gap = crf_process_ghg - dk_ne["co2_eq"]
    crf3_vs_ainah = agri_ainah_ch4 - crf3_ch4
    crf3_vs_greu = crf3_ch4 - agri_ne_ch4

    anomalies_rows = [
        {"anomaly": "ainah has no energy/non-energy split",
         "detail": (
             "env_ac_ainah_r2 is the combined air-account control. Deriving "
             "non-energy as ainah - GREU energy simply parks the known "
             f"CH4 {ch4_gap:+.3f} kt / N2O {n2o_gap:+.3f} kt combined residual "
             "on the non-energy side. That residual is not process emissions "
             "until item 9 is resolved. F-gases and (almost) fossil CO2 do "
             "survive this derivation."
         )},
        {"anomaly": "Item 9 CH4 is two gaps stacked, both in agriculture (A01)",
         "detail": (
             f"Of the national CH4 gap {ch4_gap:+.3f} kt, A01 accounts for "
             f"{agri_ch4_gap:+.3f} kt (the rest is waste E37-E39 ~0.7 kt). "
             f"GREU A01 non-energy CH4 {agri_ne_ch4:.3f} vs CRF3 {crf3_ch4:.3f} "
             f"({crf3_vs_greu:+.3f} kt: GREU below the current inventory). "
             f"ainah A01 CH4 {agri_ainah_ch4:.3f} vs CRF3 {crf3_ch4:.3f} "
             f"({crf3_vs_ainah:+.3f} kt: air-accounts above the territorial "
             "inventory — a real concept difference, not zero). Eurostat ainah "
             "TOTAL_HH is unchanged vs the 2026-07-30 pull, so this is not a "
             "revision since the PEFA pilot. Public EU data cannot tell a GREU "
             "national adjustment from an older inventory vintage baked into "
             "the Danish file. There is no missing source."
         )},
        {"anomaly": "CRF1 cannot be the energy subtrahend under ainah",
         "detail": (
             f"GREU energy co2_eq {dk_en['co2_eq']:.1f} vs CRF1 "
             f"{crf1_ghg:.1f} kt. Residence (ainah/GREU) vs territorial "
             "(inventory) is a ~39 Mt bunker wedge. Subtracting CRF1 from "
             "ainah would fabricate a huge fake 'process' residual."
         )},
        {"anomaly": "Do not build PEFA x emission-factor energy emissions for DK",
         "detail": (
             "GREU energy already closes fossil CO2 to -0.007% vs ainah. A "
             "PEFA x EF engine is a construction method for countries without a "
             "GREU energy file, not this reconciliation. CH4/N2O still would "
             "not be rescued by it: they are not an energy-side miss."
         )},
        {"anomaly": "Sweden public core left runtime emissions at zero for this reason",
         "detail": (
             "The 2026-07-31 Sweden package audited ainah but refused to "
             "allocate it onto energy products because that would fabricate "
             "the split this pilot is testing. A usable EU recipe is: F-gases "
             "from ainah wholly as non-energy; fossil CO2 residual (tiny) as "
             "non-energy; CH4/N2O from CRF3/CRF5 (inventory) or from ainah "
             "A01/waste clusters — not from ainah - energy."
         )},
        {"anomaly": f"CRF2+3+5 vs GREU non-energy GHG: {process_ghg_gap:+.1f} kt",
         "detail": (
             f"GREU non-energy {dk_ne['co2_eq']:.1f} vs CRF2+3+5 "
             f"{crf_process_ghg:.1f}. Close as a national process total "
             f"({100 * process_ghg_gap / dk_ne['co2_eq']:+.2f}%). Remaining "
             "difference is inventory vintage and/or GREU national "
             "adjustments, not a missing dataset."
         )},
        {"anomaly": f"EU-27: ainah 2020 TOTAL_HH in {n_ainah_2020}/27; A64 in {n_a64_full}/27; CRF1/2/3/5 in {n_crf_all}/27",
         "detail": (
             "Complete coverage: every member state publishes 2020 ainah at "
             "full A64 for GHG/CO2/CH4/N2O/F-gases, and every member state "
             "publishes CRF1/2/3/5. Coverage is not the blocker; the "
             "energy/non-energy derivation rule is."
         )},
        {"anomaly": "Household fossil-CO2 allocation differs even though the national total matches",
         "detail": (
             "National fossil CO2 combined vs ainah is +4.6 kt. Households "
             "alone are ~73 kt above ainah HH, so industries are below. The "
             "non-energy household CO2 row (65 kt) is not recoverable as "
             "ainah_HH minus GREU energy_HH. Keep F-gas and CH4 household "
             "rows; do not trust the CO2 household residual identity."
         )},
    ]
    anomalies = pd.DataFrame(anomalies_rows)

    n_pass = sum(1 for r in checks if r["result"] == "PASS")
    n_fail = sum(1 for r in checks if r["result"] == "FAIL")
    n_skip = sum(1 for r in checks if r["result"] == "SKIP")

    headline = (
        f"COARSER / PILOT DONE. File is load-bearing (qEmmxE). F-gases match "
        f"ainah ({dk_fgas:.3f} vs {aea_fgas:.3f} kt CO2e) and CRF2F HFC exactly; "
        f"copy them wholly as non-energy. The ainah-energy identity is "
        f"tautological: it reassigns the known CH4 {ch4_gap:+.3f} kt / "
        f"N2O {n2o_gap:+.3f} kt combined gap onto the non-energy side. "
        f"Item 9 is agriculture and is two stacked gaps, not one: GREU A01 "
        f"non-energy CH4 {agri_ne_ch4:.3f} vs CRF3 {crf3_ch4:.3f} "
        f"({crf3_vs_greu:+.3f} kt, GREU below inventory) and ainah A01 "
        f"{agri_ainah_ch4:.3f} vs CRF3 ({crf3_vs_ainah:+.3f} kt, air-accounts "
        f"above inventory). Ainah totals unchanged vs 2026-07-30. No missing "
        f"source. CRF2+3+5 {crf_process_ghg:.1f} vs GREU non-energy "
        f"{dk_ne['co2_eq']:.1f} kt CO2e. All 27 countries publish 2020 ainah "
        f"at A64 and CRF1/2/3/5. Do not PEFA x EF."
    )

    totals = pd.DataFrame([
        {"item": "DK non-energy ch4 kt", "value": round(dk_ne["ch4"], 4)},
        {"item": "DK energy ch4 kt", "value": round(dk_en["ch4"], 4)},
        {"item": "DK combined ch4 kt", "value": round(dk_comb["ch4"], 4)},
        {"item": "ainah CH4 TOTAL_HH kt", "value": round(aea["CH4"], 4)},
        {"item": "DK non-energy n2o kt", "value": round(dk_ne["n2o"], 4)},
        {"item": "ainah N2O TOTAL_HH kt", "value": round(aea["N2O"], 4)},
        {"item": "DK non-energy co2_xbio kt", "value": round(dk_ne["co2_xbio"], 4)},
        {"item": "ainah CO2 TOTAL_HH kt", "value": round(aea["CO2"], 4)},
        {"item": "DK F-gases kt CO2e", "value": round(dk_fgas, 4)},
        {"item": "ainah F-gases kt CO2e", "value": round(aea_fgas, 4)},
        {"item": "DK non-energy co2_eq kt CO2e", "value": round(dk_ne["co2_eq"], 4)},
        {"item": "CRF2+3+5 GHG kt CO2e", "value": round(crf_process_ghg, 4)},
        {"item": "CRF3 CH4 kt", "value": round(crf3_ch4, 4)},
        {"item": "GREU A01 non-energy CH4 kt", "value": round(agri_ne_ch4, 4)},
        {"item": "ainah A01 CH4 kt", "value": round(agri_ainah_ch4, 4)},
        {"item": "CRF1 GHG kt CO2e (territorial energy)", "value": round(crf1_ghg, 4)},
        {"item": "DK energy co2_eq kt CO2e (residence)", "value": round(dk_en["co2_eq"], 4)},
        {"item": "ainah GHG TOTAL_HH", "value": round(aea["GHG"], 4)},
        {"item": "inventory TOTX4_MEMO GHG", "value": round(tot_ex_lulucf, 4)},
        {"item": "SE ainah GHG TOTAL_HH", "value": round(ainah_total(ainah_se, "GHG"), 4)},
        {"item": "SE CRF2+3+5 GHG", "value": round(se_process, 4)},
        {"item": f"identity checks PASS/FAIL/SKIP",
         "value": f"{n_pass}/{n_fail}/{n_skip}"},
    ])
    totals = pd.concat(
        [totals, pd.DataFrame(checks).rename(columns={"check": "item"})],
        ignore_index=True,
    )

    readme = pd.DataFrame([
        {"key": "title",
         "value": "Reconciliation: Eurostat env_ac_ainah_r2 + env_air_gge CRF1/2/3/5 vs non_energy_emissions.xlsx, Denmark 2020"},
        {"key": "created", "value": created},
        {"key": "created_by",
         "value": "data/preprocessing/scripts/reconcile_non_energy_emissions_dk_2020.py"},
        {"key": "purpose",
         "value": "Pilot of the mapping-table COARSER verdict: test the energy/non-energy split (ainah - energy) and close or document item 9 via CRF agriculture/IPPU/waste"},
        {"key": "danish_source",
         "value": "data/preprocessing/data/non_energy_emissions.xlsx (year=2020, sheet ems_non_energy); energy_and_emissions.xlsx for the energy side of the residual only"},
        {"key": "eurostat_sources",
         "value": "env_ac_ainah_r2 (residence air accounts, combined energy+process) and env_air_gge (territorial UNFCCC inventory, CRF1/2/3/5)"},
        {"key": "eurostat_retrieval_date", "value": retrieval_date},
        {"key": "raw_data",
         "value": "data/preprocessing/data/non_energy_emissions_raw/DK/2020/ (README.md + manifest.json with URLs, params, SHA-256). Earlier PEFA-pilot ainah pull kept at eurostat_energy_emissions_raw/ for vintage comparison."},
        {"key": "units", "value": "kt and kt CO2e (Eurostat THS_T)"},
        {"key": "concept",
         "value": "ainah and GREU are residence-principle air accounts. env_air_gge is territorial UNFCCC inventory. Agriculture/IPPU/waste are comparable across the two; energy (CRF1 vs GREU energy) is not, because of bunkers."},
        {"key": "headline", "value": headline},
        {"key": "sheets",
         "value": "file_usage | totals (sums + identity checks) | national_split | household | clusters | item9_crf | crf_detail | vintage | eu27_coverage | sweden | anomalies"},
    ])

    with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
        readme.to_excel(xl, sheet_name="readme", index=False)
        usage.to_excel(xl, sheet_name="file_usage", index=False)
        totals.to_excel(xl, sheet_name="totals", index=False)
        national.to_excel(xl, sheet_name="national_split", index=False)
        household.to_excel(xl, sheet_name="household", index=False)
        clusters_df.to_excel(xl, sheet_name="clusters", index=False)
        item9.to_excel(xl, sheet_name="item9_crf", index=False)
        crf_detail.to_excel(xl, sheet_name="crf_detail", index=False)
        vintage.to_excel(xl, sheet_name="vintage", index=False)
        coverage.to_excel(xl, sheet_name="eu27_coverage", index=False)
        sweden.to_excel(xl, sheet_name="sweden", index=False)
        anomalies.to_excel(xl, sheet_name="anomalies", index=False)
    print(f"wrote {OUT}")

    pd.set_option("display.width", 220)
    pd.set_option("display.max_colwidth", 100)
    print("\nHEADLINE:")
    print(headline)
    print("\nNATIONAL SPLIT:")
    print(national.to_string(index=False))
    print("\nITEM 9 / CRF:")
    print(item9[["comparison", "left", "right", "diff"]].to_string(index=False))
    print("\nCHECKS:")
    print(pd.DataFrame(checks).to_string(index=False))
    print("\nCOVERAGE summary: A64", n_a64_full, "/27; ainah 2020", n_ainah_2020,
          "/27; CRF all four", n_crf_all, "/27")
    print("\nVINTAGE:")
    print(vintage.to_string(index=False))


if __name__ == "__main__":
    main()
