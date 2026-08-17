"""Reconcile Eurostat env_ac_aibrid_r2 (plus env_air_gge for LULUCF) DK 2020
against the Danish GREU input emissions_bridge_items.xlsx.

Seventh pilot of the EU data replacement effort (see docs/eu_data_mapping.md).

Inputs
------
- data/preprocessing/data/emissions_bridge_items.xlsx
    Danish input: one sheet 'bridge_items', three 2020 rows
    (bord_trade, internat_transp, lulucf) x gas columns
    (ch4, co2_bio, co2_xbio, n2o, co2_eq), thousand tonnes.
    Consumed by read_data.py lines 379-403 / 694-696:
      lulucf co2_eq        -> qEmmLULUCF[t]
      bord_trade per gas   -> qEmmBorderTrade[em,t]
      internat_transp      -> read but never exported to GAMS.
- data/preprocessing/data/emissions_bridge_raw/DK/2020/*.json
    Raw JSON-stat from the Eurostat dissemination API, downloaded by
    download_emissions_bridge_dk_2020.py (see README.md / manifest.json).

Concept mapping (established numerically in this pilot)
-------------------------------------------------------
Danish rows are accounts-minus-inventory contributions, sign convention
residents-abroad minus non-residents-on-territory:
  bord_trade      ~ AEMIS_RES_ABR_LTR  - AEMIS_TER_NRES_LTR   (land transport)
  internat_transp ~ sum(WTR, ATR, FWTR) of the same difference
  lulucf          = indic_env LULUCF   (= env_air_gge src_crf CRF4, verified)
  row sum         = AEMIS_RES - AEMIS_TER - ADJ_SD
Gas columns: ch4->CH4, co2_bio->CO2_BIO, co2_xbio->CO2 (fossil), n2o->N2O,
co2_eq->GHG. Danish co2_eq = co2_xbio + 28*ch4 + 265*n2o (AR5 GWPs), which
also reproduces Eurostat's GHG for the bridge indicators exactly (no F-gases
in these rows).

Output
------
data/preprocessing/data/emissions_bridge_dk2020_reconciliation.xlsx with
sheets: readme, bridge_file_usage, totals, rows, lulucf_crosscheck,
eu27_coverage, anomalies

Run:  python data/preprocessing/scripts/reconcile_emissions_bridge_dk_2020.py
"""

from __future__ import annotations

import datetime
import json
import pathlib

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "emissions_bridge_raw" / "DK" / "2020"
OUT = DATA / "emissions_bridge_dk2020_reconciliation.xlsx"
YEAR = 2020

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

# Danish gas column -> Eurostat airpol code.
GAS_MAP = {
    "ch4": "CH4",
    "co2_bio": "CO2_BIO",
    "co2_xbio": "CO2",
    "n2o": "N2O",
    "co2_eq": "GHG",
}
GWP_AR5 = {"ch4": 28.0, "n2o": 265.0}

RES_ABR_MODES = ["AEMIS_RES_ABR_LTR", "AEMIS_RES_ABR_WTR",
                 "AEMIS_RES_ABR_ATR", "AEMIS_RES_ABR_FWTR"]
TER_NRES_MODES = ["AEMIS_TER_NRES_LTR", "AEMIS_TER_NRES_WTR",
                  "AEMIS_TER_NRES_ATR"]
KEY_INDICATORS = (
    ["AEMIS_RES", "AEMIS_TER", "AEMIS_RES_ABR", "AEMIS_TER_NRES", "ADJ_SD",
     "LULUCF"] + RES_ABR_MODES + TER_NRES_MODES
)


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


def load_raw(name: str) -> pd.DataFrame:
    return jsonstat_to_frame(
        json.loads((RAW / name).read_text(encoding="utf-8"))
    )


def main() -> None:
    created = datetime.date.today().isoformat()
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    retrieval_date = manifest["retrieval_date"]

    # ---------------- Danish side ----------------
    dk = pd.read_excel(DATA / "emissions_bridge_items.xlsx")
    dk = dk[dk["year"] == YEAR].set_index("item")
    dk_val = {
        (item, gas): (float(dk.at[item, gas]) if pd.notna(dk.at[item, gas]) else None)
        for item in dk.index
        for gas in GAS_MAP
    }

    # ---------------- Eurostat side ----------------
    es_raw = load_raw("env_ac_aibrid_r2_DK_2020.json")
    es_ths = es_raw[es_raw.unit == "THS_T"]

    def es(indic: str, airpol: str) -> float | None:
        s = es_ths[(es_ths.indic_env == indic) & (es_ths.airpol == airpol)]["value"]
        return float(s.iloc[0]) if len(s) else None

    def net_modes(res_modes: list[str], nres_modes: list[str], airpol: str) -> float:
        tot = 0.0
        for ind in res_modes:
            tot += es(ind, airpol) or 0.0
        for ind in nres_modes:
            tot -= es(ind, airpol) or 0.0
        return tot

    # Eurostat construction of the three Danish rows, per gas.
    es_row = {}
    for gas, pol in GAS_MAP.items():
        es_row[("bord_trade", gas)] = net_modes(
            ["AEMIS_RES_ABR_LTR"], ["AEMIS_TER_NRES_LTR"], pol)
        es_row[("internat_transp", gas)] = net_modes(
            ["AEMIS_RES_ABR_WTR", "AEMIS_RES_ABR_ATR", "AEMIS_RES_ABR_FWTR"],
            ["AEMIS_TER_NRES_WTR", "AEMIS_TER_NRES_ATR"], pol)
        es_row[("lulucf", gas)] = es("LULUCF", pol)
        # Total bridge from the accounts/inventory totals (excludes ADJ_SD,
        # which is zero for DK 2020 - checked below).
        res, ter = es("AEMIS_RES", pol), es("AEMIS_TER", pol)
        adj = es("ADJ_SD", pol) or 0.0
        es_row[("SUM_residence_bridge", gas)] = (
            res - ter - adj if res is not None and ter is not None else None)

    # ---------------- identity checks ----------------
    checks = []

    def check(name: str, delta: float | None, tol: float) -> None:
        ok = delta is not None and abs(delta) <= tol
        checks.append({"check": name,
                       "delta": None if delta is None else round(delta, 6),
                       "tolerance": tol, "result": "PASS" if ok else "FAIL"})

    for item in ["bord_trade", "internat_transp", "lulucf"]:
        d = dk_val[(item, "co2_eq")]
        implied = (dk_val[(item, "co2_xbio")]
                   + GWP_AR5["ch4"] * dk_val[(item, "ch4")]
                   + GWP_AR5["n2o"] * dk_val[(item, "n2o")])
        check(f"DK AR5 identity co2_eq = co2_xbio+28*ch4+265*n2o [{item}]",
              d - implied, 1e-3)
    for ind in ["AEMIS_RES_ABR", "AEMIS_TER_NRES", "LULUCF"]:
        implied = (es(ind, "CO2") + GWP_AR5["ch4"] * es(ind, "CH4")
                   + GWP_AR5["n2o"] * es(ind, "N2O"))
        # LULUCF GHG may include tiny F-gas amounts; bridge rows have none.
        check(f"ES AR5 identity GHG = CO2+28*CH4+265*N2O [{ind}]",
              es(ind, "GHG") - implied, 1.0)
    for pol in ["GHG", "CO2", "CH4", "N2O"]:
        lhs = (es("AEMIS_RES", pol) - es("AEMIS_RES_ABR", pol)
               + es("AEMIS_TER_NRES", pol) + (es("ADJ_SD", pol) or 0.0))
        check(f"ES bridge identity RES-RES_ABR+TER_NRES+ADJ = TER [{pol}]",
              lhs - es("AEMIS_TER", pol), 0.01)
    check("ES ADJ_SD is zero for DK 2020 [GHG]", es("ADJ_SD", "GHG"), 0.0)

    # LULUCF cross-check against the inventory dataset env_air_gge.
    gge = load_raw("env_air_gge_DK_2020_lulucf.json")

    def gge_val(src: str, airpol: str) -> float | None:
        s = gge[(gge.src_crf == src) & (gge.airpol == airpol)]["value"]
        return float(s.iloc[0]) if len(s) else None

    lulucf_rows = []
    for pol in ["GHG", "CO2", "CH4", "N2O"]:
        a, g = es("LULUCF", pol), gge_val("CRF4", pol)
        check(f"aibrid LULUCF == env_air_gge CRF4 [{pol}]",
              None if a is None or g is None else a - g, 0.01)
        lulucf_rows.append({
            "airpol": pol,
            "dk_lulucf_row": dk_val[("lulucf",
                                     {v: k for k, v in GAS_MAP.items()}[pol])],
            "aibrid_LULUCF": a,
            "env_air_gge_CRF4": g,
            "aibrid_AEMIS_TER": es("AEMIS_TER", pol),
            "gge_TOTX4_MEMO_excl_lulucf": gge_val("TOTX4_MEMO", pol),
            "aibrid_AEMIS_TER_LULUCF": es("AEMIS_TER_LULUCF", pol),
            "gge_TOTXMEMO_incl_lulucf": gge_val("TOTXMEMO", pol),
        })
    check("aibrid AEMIS_TER_LULUCF == gge TOTXMEMO [GHG]",
          es("AEMIS_TER_LULUCF", "GHG") - gge_val("TOTXMEMO", "GHG"), 0.01)
    lulucf_crosscheck = pd.DataFrame(lulucf_rows)

    # ---------------- row comparison ----------------
    row_records = []
    for item in ["bord_trade", "internat_transp", "SUM_residence_bridge",
                 "lulucf"]:
        for gas in GAS_MAP:
            if item == "SUM_residence_bridge":
                parts = [dk_val[("bord_trade", gas)],
                         dk_val[("internat_transp", gas)]]
                d = sum(p for p in parts if p is not None) if any(
                    p is not None for p in parts) else None
            else:
                d = dk_val[(item, gas)]
            e = es_row[(item, gas)]
            rec = {"item": item, "gas": gas, "eurostat_airpol": GAS_MAP[gas],
                   "dk_ths_t": d, "eurostat_ths_t": e,
                   "diff": None if d is None or e is None else round(e - d, 3),
                   "pct_diff": (None if d in (None, 0) or e is None
                                else round(100 * (e - d) / d, 3))}
            row_records.append(rec)
    rows_cmp = pd.DataFrame(row_records)

    # ---------------- totals sheet (bridge sum + checks) ----------------
    totals = rows_cmp[rows_cmp["item"] == "SUM_residence_bridge"].copy()
    totals = pd.concat(
        [totals, pd.DataFrame(checks).rename(columns={"check": "item"})],
        ignore_index=True)

    # ---------------- EU-27 coverage ----------------
    probe = load_raw("env_ac_aibrid_r2_eu27_coverage_probe_2020.json")
    yprobe = load_raw("env_ac_aibrid_r2_eu27_year_probe_GHG.json")
    gge_probe = load_raw("env_air_gge_eu27_lulucf_coverage_probe_2020.json")
    gases5 = ["GHG", "CO2", "CO2_BIO", "CH4", "N2O"]

    cov_rows = []
    for geo in EU27:
        g = probe[probe.geo == geo]
        have = {(r.indic_env, r.airpol) for r in g.itertuples()}
        row = {"geo": geo}
        for ind in ["AEMIS_RES", "AEMIS_TER", "AEMIS_RES_ABR",
                    "AEMIS_TER_NRES", "LULUCF"]:
            missing = [p for p in gases5 if (ind, p) not in have]
            # CO2_BIO is never published for LULUCF (inventory concept).
            if ind == "LULUCF":
                missing = [p for p in missing if p != "CO2_BIO"]
            row[f"{ind}_gases_missing"] = ", ".join(missing)
        row["res_abr_modes_present"] = sum(
            1 for ind in RES_ABR_MODES if (ind, "GHG") in have)
        row["ter_nres_modes_present"] = sum(
            1 for ind in TER_NRES_MODES if (ind, "GHG") in have)
        adj = g[(g.indic_env == "ADJ_SD") & (g.airpol == "GHG")]["value"]
        row["adj_sd_GHG_ths_t"] = float(adj.iloc[0]) if len(adj) else None
        yg = yprobe[(yprobe.geo == geo) & (yprobe.indic_env == "AEMIS_RES")]
        years = sorted(yg["time"].astype(int))
        row["years_GHG_AEMIS_RES"] = (
            f"{years[0]}-{years[-1]} (n={len(years)})" if years else "none")
        yl = yprobe[(yprobe.geo == geo) & (yprobe.indic_env == "LULUCF")]
        yearsl = sorted(yl["time"].astype(int))
        row["years_GHG_LULUCF"] = (
            f"{yearsl[0]}-{yearsl[-1]} (n={len(yearsl)})" if yearsl else "none")
        row["gge_CRF4_GHG_2020"] = bool(
            len(gge_probe[(gge_probe.geo == geo)
                          & (gge_probe.src_crf == "CRF4")]))
        core_ok = all(
            (ind, p) in have
            for ind in ["AEMIS_RES", "AEMIS_TER", "AEMIS_RES_ABR",
                        "AEMIS_TER_NRES"]
            for p in gases5)
        lulucf_ok = all((("LULUCF", p) in have) for p in
                        ["GHG", "CO2", "CH4", "N2O"])
        row["complete_core_2020"] = core_ok
        row["complete_lulucf_2020"] = lulucf_ok
        cov_rows.append(row)
    coverage = pd.DataFrame(cov_rows)

    # ---------------- usage sheet ----------------
    usage = pd.DataFrame([
        {"item": "file", "detail": "data/preprocessing/data/emissions_bridge_items.xlsx, single sheet 'bridge_items'"},
        {"item": "columns", "detail": "year, item (bord_trade / internat_transp / lulucf), ch4, co2_bio, co2_xbio, n2o, co2_eq"},
        {"item": "years", "detail": "2020 only (3 rows); co2_bio is empty (NaN) in all rows"},
        {"item": "units", "detail": "thousand tonnes (kt); co2_eq in kt CO2-equivalent using AR5 GWPs (co2_eq = co2_xbio + 28*ch4 + 265*n2o, exact in all three rows)"},
        {"item": "read_data.py line 380", "detail": "emissions_bridge_items = pd.read_excel('../data/preprocessing/data/emissions_bridge_items.xlsx')"},
        {"item": "read_data.py lines 382-392", "detail": "lulucf row, co2_eq column only -> qEmmLULUCF"},
        {"item": "read_data.py lines 394-403", "detail": "bord_trade row, all gas columns (renamed via dict_ebalitems: co2_xbio->co2ubio, co2_eq->co2e; ch4/n2o unchanged; NaN co2_bio dropped) -> qEmmBorderTrade[em,t]"},
        {"item": "read_data.py lines 695-696", "detail": "GAMS parameters qEmmLULUCF(t) and qEmmBorderTrade(em,t)"},
        {"item": "model needs", "detail": "(1) LULUCF total in CO2-eq; (2) border-trade residence adjustment by gas. The internat_transp row is read but NEVER exported to GAMS - dead weight in the current model."},
    ])

    # ---------------- anomalies ----------------
    b_dk = dk_val[("bord_trade", "co2_xbio")]
    b_es = es_row[("bord_trade", "co2_xbio")]
    i_dk = dk_val[("internat_transp", "co2_xbio")]
    i_es = es_row[("internat_transp", "co2_xbio")]
    l_dk = dk_val[("lulucf", "co2_eq")]
    l_es = es_row[("lulucf", "co2_eq")]
    anomalies = pd.DataFrame([
        {"anomaly": "bord_trade / internat_transp split is definitional, not numerical", "detail":
            f"DK 2020 CO2: bord_trade {b_dk:,.0f} vs Eurostat net land transport "
            f"{b_es:,.1f} kt; internat_transp {i_dk:,.0f} vs Eurostat net "
            f"water+air+fishing {i_es:,.1f} kt. Both rows are off by the same "
            f"~{abs(b_es - b_dk):,.0f} kt with opposite signs while the SUM "
            "matches to 0.006%. Consistent with DST counting international "
            "road freight as international transport, while the aibrid mode "
            "split groups ALL land transport (incl. lorries abroad) in _LTR. "
            "An EU build from aibrid reproduces the total exactly but draws "
            "the boundary between the two rows differently. This affects "
            "qEmmBorderTrade levels (bord_trade is the only row exported per "
            "gas)."},
        {"anomaly": "LULUCF vintage gap (-15%)", "detail":
            f"DK file lulucf co2_eq {l_dk:,.1f} vs current Eurostat LULUCF GHG "
            f"{l_es:,.1f} kt CO2-eq. aibrid LULUCF == env_air_gge CRF4 exactly "
            "(same inventory), so the Danish file was built from an OLDER "
            "inventory submission; LULUCF is heavily recalculated between "
            "annual submissions. Concept match is exact; the number moved "
            "with the 2020->2026 resubmissions."},
        {"anomaly": "aibrid AEMIS_TER is not the plain UNFCCC total-excl-LULUCF", "detail":
            "DK 2020 GHG: AEMIS_TER 43,475.7 vs env_air_gge TOTX4_MEMO "
            "43,237.2 kt (+238.5; CO2 +39.6, CH4 +16.2 kt). AEMIS_TER_LULUCF "
            "== TOTXMEMO exactly, and the aibrid internal bridge identity "
            "holds to <0.01 kt, so this is a scope nuance of the AEMIS_TER "
            "line (UNFCCC+CLRTAP scope), not an error in our construction."},
        {"anomaly": "internat_transp is dead weight in read_data.py", "detail":
            "The row is loaded but no GAMS parameter is built from it; only "
            "bord_trade (per gas) and lulucf (co2_eq) reach the model. An EU "
            "pipeline still needs the row only if the model later adds "
            "international transport emissions."},
        {"anomaly": "co2_bio empty on both sides for bridge rows", "detail":
            "Danish co2_bio column is all-NaN; Eurostat publishes CO2_BIO = 0 "
            "for AEMIS_RES_ABR / AEMIS_TER_NRES and does not publish CO2_BIO "
            "for LULUCF. No information is lost."},
        {"anomaly": "ADJ_SD has no place in the Danish two-row structure", "detail":
            "ADJ_SD (other adjustments and statistical differences) is 0 for "
            "DK 2020 but LARGE for several member states (2020 GHG, kt "
            "CO2-eq: DE -32,171, CZ +9,186, NL -5,828, BE -4,304; see "
            "eu27_coverage column adj_sd_GHG_ths_t). An EU-generic build must "
            "decide where to put it (own bridge item or a third residual "
            "row); it cannot be silently dropped for those countries even "
            "though it is not exported to the model today."},
        {"anomaly": "Coverage: modes complete EU-27; accounts series mostly start 2008", "detail":
            "All 27 member states publish all 4 AEMIS_RES_ABR modes and all "
            "3 AEMIS_TER_NRES modes for 2020, and LULUCF 1995-2024 (n=30). "
            "The accounts-side series (AEMIS_RES etc.) start 2008 for most "
            "countries (1995 for DK, HU, MT, NL, PT, SK; 2006 for DE, HR), "
            "extending to 2025. See eu27_coverage."},
    ])

    # ---------------- readme ----------------
    readme = pd.DataFrame([
        {"key": "title", "value": "Reconciliation: Eurostat env_ac_aibrid_r2 (+ env_air_gge LULUCF) vs emissions_bridge_items.xlsx, Denmark 2020"},
        {"key": "created", "value": created},
        {"key": "created_by", "value": "data/preprocessing/scripts/reconcile_emissions_bridge_dk_2020.py"},
        {"key": "purpose", "value": "Pilot test of the eu_data_mapping.md 'OK' verdict: can env_ac_aibrid_r2 replace the Danish emissions_bridge_items.xlsx input for any EU country?"},
        {"key": "danish_source", "value": "data/preprocessing/data/emissions_bridge_items.xlsx (year=2020)"},
        {"key": "eurostat_sources", "value": "env_ac_aibrid_r2 (bridging items) and env_air_gge (inventory, LULUCF cross-check) via the Eurostat dissemination API (JSON-stat 2.0)"},
        {"key": "eurostat_retrieval_date", "value": retrieval_date},
        {"key": "raw_data", "value": "data/preprocessing/data/emissions_bridge_raw/DK/2020/ (README.md + manifest.json with URLs, params, SHA-256)"},
        {"key": "concept_mapping", "value": "bord_trade ~ net land transport (AEMIS_RES_ABR_LTR - AEMIS_TER_NRES_LTR); internat_transp ~ net water+air+fishing; lulucf = LULUCF (= env_air_gge CRF4); row sum = AEMIS_RES - AEMIS_TER - ADJ_SD"},
        {"key": "gas_mapping", "value": "ch4->CH4, co2_bio->CO2_BIO, co2_xbio->CO2 (fossil), n2o->N2O, co2_eq->GHG; both sides use AR5 GWPs (28/265), verified exactly"},
        {"key": "units", "value": "thousand tonnes (THS_T) on both sides"},
        {"key": "headline", "value": "Residence-bridge SUM matches to 0.006% in every gas; the split between the two Danish rows differs by ~361 kt CO2 (definitional: road freight abroad); LULUCF concept exact but -15% vintage gap."},
        {"key": "sheets", "value": "bridge_file_usage | totals (sum + identity checks) | rows | lulucf_crosscheck | eu27_coverage | anomalies"},
    ])

    with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
        readme.to_excel(xl, sheet_name="readme", index=False)
        usage.to_excel(xl, sheet_name="bridge_file_usage", index=False)
        totals.to_excel(xl, sheet_name="totals", index=False)
        rows_cmp.to_excel(xl, sheet_name="rows", index=False)
        lulucf_crosscheck.to_excel(xl, sheet_name="lulucf_crosscheck", index=False)
        coverage.to_excel(xl, sheet_name="eu27_coverage", index=False)
        anomalies.to_excel(xl, sheet_name="anomalies", index=False)
    print(f"wrote {OUT}")

    # ---------------- console report ----------------
    pd.set_option("display.width", 250)
    print("\nROW COMPARISON (thousand tonnes):")
    print(rows_cmp.to_string(index=False))
    print("\nIDENTITY CHECKS:")
    print(pd.DataFrame(checks).to_string(index=False))
    print("\nLULUCF CROSS-CHECK:")
    print(lulucf_crosscheck.to_string(index=False))
    print("\nEU-27 coverage (countries NOT complete for core 2020):")
    inc = coverage[~coverage["complete_core_2020"]]
    print(inc.to_string(index=False) if len(inc) else "  none - all 27 complete")
    print("\nEU-27 coverage (countries NOT complete for LULUCF 2020):")
    inc = coverage[~coverage["complete_lulucf_2020"]]
    print(inc[["geo", "LULUCF_gases_missing", "years_GHG_LULUCF",
               "gge_CRF4_GHG_2020"]].to_string(index=False)
          if len(inc) else "  none - all 27 complete")
    print("\nSweden row:")
    print(coverage[coverage.geo == "SE"].to_string(index=False))
    n_fail = sum(1 for c in checks if c["result"] == "FAIL")
    print(f"\nchecks: {len(checks) - n_fail}/{len(checks)} PASS")


if __name__ == "__main__":
    main()
