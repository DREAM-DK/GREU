"""Reconcile Eurostat gov_10a_main (plus gov_10a_taxag for tax detail)
DK 2020 against the Danish GREU input government_finances.xlsx.

Eighth pilot of the EU data replacement effort (see docs/eu_data_mapping.md).

Inputs
------
- data/preprocessing/data/government_finances.xlsx
    Danish input, values in bn DKK, year 2020 only.
    Sheet 'gov_fin' (34 rows): balance (exp/rev/exp_eu/rev_eu) x trans,
    with ESA codes in trans_esa. This is the sheet read_data.py consumes
    (lines 427-553; note it reads sheet 0 twice - the "disagg" read at line
    545 also hits 'gov_fin', whose two tax_direct_other_labor rows are
    distinguished by trans_txt).
    Sheet 'gov_fin_disagg': same rows plus cons_publ split into its 8 ESA
    components (P3 = D1+P51c+P2+D29-D39+D632-P11-P131-P12), with DST
    statbank provenance columns. Not consumed by read_data.py.
- data/preprocessing/data/government_finances_raw/DK/2020/*.json
    Raw JSON-stat from the Eurostat dissemination API, downloaded by
    download_government_finances_dk_2020.py (see README.md / manifest.json).

Units: Danish bn DKK; Eurostat MIO_NAC / 1000.

Output
------
data/preprocessing/data/government_finances_dk2020_reconciliation.xlsx with
sheets: readme, gov_fin_file_usage, totals, rows, cons_publ_components,
tax_detail, eu27_coverage, anomalies

Run:  python data/preprocessing/scripts/reconcile_government_finances_dk_2020.py
"""

from __future__ import annotations

import datetime
import json
import pathlib

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "government_finances_raw" / "DK" / "2020"
OUT = DATA / "government_finances_dk2020_reconciliation.xlsx"
YEAR = 2020

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

# na_items a full EU-generic rebuild of the Danish file needs from
# gov_10a_main. Tax detail deliberately excluded: for DK the main dataset
# does not deliver D211REC/D51A_C1REC/D59REC etc. even though the codes
# exist - the reliable tax source is gov_10a_taxag (checked separately).
NEEDED_MAIN_ITEMS = [
    "B9", "TE", "TR",
    "P3", "P2", "P51G", "P51C", "P52_P53", "NP",
    "D1PAY", "D3PAY", "D41PAY", "D29PAY",
    "D62PAY", "D632PAY", "D7PAY", "D8", "D9PAY",
    "D41REC", "D42_TO_D45REC", "D39REC", "D29REC",
    "D61REC", "D7REC", "D91REC", "D92_D99REC",
]
# gov_10a_taxag S13 items carrying the Danish revenue-side tax detail.
NEEDED_TAX_ITEMS = ["D211", "D212", "D214", "D29", "D51", "D51A_C1",
                    "D51B_C2", "D59", "D91"]
# Counterpart (_S2 / _S212) items used for the Danish dom/RoW splits.
SPLIT_ITEMS = ["D9PAY_S2", "D9REC_S2", "D7REC_S212", "D74PAY", "D76PAY",
               "D3REC_S212"]


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
    return jsonstat_to_frame(json.loads((RAW / name).read_text(encoding="utf-8")))


def main() -> None:
    created = datetime.date.today().isoformat()
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    retrieval_date = manifest["retrieval_date"]

    # ---------------- Danish side ----------------
    dk = pd.read_excel(DATA / "government_finances.xlsx", sheet_name="gov_fin")
    dk = dk[dk["year"] == YEAR]

    def dk_rows(trans: str, txt_contains: str | None = None) -> pd.DataFrame:
        sel = dk[dk["trans"] == trans]
        if txt_contains is not None:
            sel = sel[sel["trans_txt"].str.contains(txt_contains, case=False)]
        return sel

    def dk_val(trans: str, txt_contains: str | None = None) -> float:
        sel = dk_rows(trans, txt_contains)
        if len(sel) == 0:
            raise KeyError(f"no Danish row for trans={trans!r} txt~{txt_contains!r}")
        return float(sel["value"].sum())

    disagg = pd.read_excel(DATA / "government_finances.xlsx",
                           sheet_name="gov_fin_disagg")
    disagg = disagg[disagg["year"] == YEAR][
        ["balance", "trans", "trans_esa", "trans_txt", "value"]]

    # ---------------- Eurostat side ----------------
    es_main = load_raw("gov_10a_main_DK_2020.json").set_index("na_item")["value"]
    tax_raw = load_raw("gov_10a_taxag_DK_2020.json")
    es_tax13 = tax_raw[tax_raw.sector == "S13"].set_index("na_item")["value"]
    es_tax212 = tax_raw[tax_raw.sector == "S212"].set_index("na_item")["value"]

    def es(item: str, series: pd.Series = es_main) -> float | None:
        """Value in bn DKK, or None if the na_item is not delivered."""
        if item in series.index:
            return float(series[item]) / 1000.0
        return None

    def es_sum(items: list[str], series: pd.Series = es_main) -> float:
        return sum(es(i, series) or 0.0 for i in items)

    def combine(*terms: tuple[float | None, int]) -> float | None:
        """Signed sum that propagates None if any term is missing."""
        total = 0.0
        for val, sign in terms:
            if val is None:
                return None
            total += sign * val
        return total

    # ---------------- identity checks ----------------
    checks = []

    def check(name: str, delta: float | None, tol: float) -> None:
        ok = delta is not None and abs(delta) <= tol
        checks.append({"check": name,
                       "delta_bn_dkk": None if delta is None else round(delta, 4),
                       "tolerance": tol, "result": "PASS" if ok else "FAIL"})

    # Eurostat-internal identities (verify our reading of the codes).
    check("ES D62_D632PAY = D62PAY + D632PAY",
          es("D62_D632PAY") - es("D62PAY") - es("D632PAY"), 0.01)
    check("ES D2REC = D21REC + D29REC",
          es("D2REC") - es("D21REC") - es("D29REC"), 0.01)
    check("ES D4REC = D41REC + D42_TO_D45REC",
          es("D4REC") - es("D41REC") - es("D42_TO_D45REC"), 0.01)
    check("ES D9REC = D91REC + D92_D99REC",
          es("D9REC") - es("D91REC") - es("D92_D99REC"), 0.01)
    check("ES main D21REC = taxag S13 D211+D212+D214",
          es("D21REC") - es_sum(["D211", "D212", "D214"], es_tax13), 0.01)
    check("ES main D211REC = taxag S13 D211",
          es("D211REC") - es("D211", es_tax13), 0.01)
    check("ES main D29REC = taxag S13 D29",
          es("D29REC") - es("D29", es_tax13), 0.01)
    check("ES main D91REC = taxag S13 D91",
          es("D91REC") - es("D91", es_tax13), 0.01)
    check("ES main D5REC = taxag S13 D51 + D59",
          es("D5REC") - es_sum(["D51", "D59"], es_tax13), 0.01)
    check("ES taxag D51 = D51A_C1 + D51B_C2 + D51D",
          es("D51", es_tax13) - es_sum(["D51A_C1", "D51B_C2", "D51D"],
                                       es_tax13), 0.01)
    check("ES B9 = TR - TE", es("B9") - (es("TR") - es("TE")), 0.01)
    # Published TR/TE against their ESA compositions as read by this script.
    tr_composed = es_sum(["P11_P12_P131", "D2REC", "D39REC", "D4REC", "D5REC",
                          "D61REC", "D7REC", "D91REC", "D92_D99REC"])
    check("ES TR = P11_P12_P131+D2REC+D39REC+D4REC+D5REC+D61REC+D7REC+D91REC+D92_D99REC",
          es("TR") - tr_composed, 0.5)
    te_composed = es_sum(["P2", "D1PAY", "D29PAY", "D3PAY", "D4PAY", "D5PAY",
                          "D62_D632PAY", "D7PAY", "D8", "D9PAY", "P5", "NP"])
    check("ES TE = P2+D1PAY+D29PAY+D3PAY+D4PAY+D5PAY+D62_D632PAY+D7PAY+D8+D9PAY+P5+NP",
          es("TE") - te_composed, 0.5)

    # Danish-internal identities. The disagg sheet stores each component with
    # its sign in the P3 formula (D39, P11/P131 and P12 are negative), so the
    # composition is a plain sum.
    dis_c = disagg[disagg["trans"] == "cons_publ"].set_index("trans_esa")["value"]
    check("DK disagg cons_publ components (signed) sum to gov_fin cons_publ",
          float(dis_c.sum()) - dk_val("cons_publ"), 0.01)

    dk_exp = float(dk[dk["balance"] == "exp"]["value"].sum())
    dk_rev = float(dk[dk["balance"] == "rev"]["value"].sum())
    dk_exp_eu = float(dk[dk["balance"] == "exp_eu"]["value"].sum())
    dk_rev_eu = float(dk[dk["balance"] == "rev_eu"]["value"].sum())
    # The Danish sheet books P51c and D41 interest on the revenue side as
    # offsets; its rev-exp balance uses only the national rows.
    check("DK (rev - exp, national rows) = ES B9",
          (dk_rev - dk_exp) - es("B9"), 1.0)

    # ---------------- row comparison ----------------
    # (danish_selector, eurostat construction, value, note)
    d74_d76 = es_sum(["D74PAY", "D76PAY"])
    row_specs = [
        # --- expenditure ---
        ("exp", "cons_publ", None, "P3", es("P3"), "direct"),
        ("exp", "subs", None, "D3PAY", es("D3PAY"), "direct"),
        ("exp", "transfer_to_hh", None, "D62PAY + D7PAY - (D74PAY+D76PAY)",
         combine((es("D62PAY"), 1), (es("D7PAY"), 1), (d74_d76, -1)),
         "proxy split: no counterpart-sector breakdown of D62/D7 in gov_10a_main"),
        ("exp", "transfer_to_row", None, "D74PAY + D76PAY", d74_d76,
         "proxy: internat. cooperation + EU own resources = transfers to RoW"),
        ("exp", "transfer_to_hh + transfer_to_row", None, "D62PAY + D7PAY",
         combine((es("D62PAY"), 1), (es("D7PAY"), 1)), "sum is split-free"),
        ("exp", "interest", None, "D41PAY", es("D41PAY"), "direct"),
        ("exp", "invest", None, "P51G", es("P51G"), "direct"),
        ("exp", "invent_change", None, "P52_P53", es("P52_P53"),
         "Eurostat bundles valuables (P53) with inventories (P52)"),
        ("exp", "np_acquis", None, "NP", es("NP"), "direct"),
        ("exp", "cap_transfer_to_dom", None, "D9PAY - D9PAY_S2",
         combine((es("D9PAY"), 1), (es("D9PAY_S2"), -1)),
         "counterpart split (S2) - not delivered for DK 2020 if blank"),
        ("exp", "cap_transfer_to_row", None, "D9PAY_S2", es("D9PAY_S2"),
         "counterpart split (S2) - not delivered for DK 2020 if blank"),
        ("exp", "cap_transfer_to_dom + cap_transfer_to_row", None, "D9PAY",
         es("D9PAY"), "sum is split-free"),
        ("exp_eu", "subs_other_production_eu", None, "D3REC_S212",
         es("D3REC_S212"),
         "EU-paid subsidies never touch S13; gov_10a_main shows them as memo "
         "item 'subsidies revenue from EU institutions'"),
        # --- revenue ---
        ("rev", "interest", None, "D41REC", es("D41REC"), "direct"),
        ("rev", "dividends + income_quasi_corp", None, "D42REC", es("D42REC"),
         "D42REC not delivered for DK 2020; see bundle row below"),
        ("rev", "rent", None, "D45REC", es("D45REC"),
         "D45REC not delivered for DK 2020; see bundle row below"),
        ("rev", "dividends + income_quasi_corp + rent", None, "D42_TO_D45REC",
         es("D42_TO_D45REC"),
         "for DK only the D42-D45 bundle is delivered in gov_10a_main; the "
         "Danish D421/D422/D45 detail needs another source or a fixed split"),
        ("rev", "tax_indirect_vat", None, "taxag S13 D211",
         es("D211", es_tax13), "direct (gov_10a_taxag; D211REC not delivered "
         "for DK in gov_10a_main)"),
        ("rev", "tax_indirect_products", None, "taxag S13 D212 + D214",
         es_sum(["D212", "D214"], es_tax13),
         "Danish trans_esa label 'D214' is imprecise: the row also contains "
         "the import excises recorded in S13 (taxag D212 = 37.396 bn)"),
        ("rev", "tax_indirect_other_production", None, "D29REC", es("D29REC"),
         "direct"),
        ("rev", "tax_direct_corp", None,
         "taxag S13 D51B_C2 (corporate income taxes)",
         es("D51B_C2", es_tax13), "grouping: PAL is NOT here, see next row"),
        ("rev", "tax_direct_source + tax_direct_other_labor + tax_direct_pension",
         None, "taxag S13 D51A_C1 + D51D",
         combine((es("D51A_C1", es_tax13), 1), (es("D51D", es_tax13), 1)),
         "Eurostat books the Danish PAL pension-yield tax under household "
         "income taxes (D51A_C1), not corporate; D51D adds lottery/gambling"),
        ("rev", "all five tax_direct D51 rows", None, "taxag S13 D51",
         es("D51", es_tax13), "sum is grouping-free"),
        ("rev", "property_value + vehicles + media (D59)", None,
         "taxag S13 D59", es("D59", es_tax13),
         "sum (D59REC not delivered for DK in gov_10a_main); subitem detail "
         "only partially in taxag D59A-F"),
        ("rev", "soc_cont", None, "D61REC", es("D61REC"), "direct"),
        ("rev", "transfers_from_dom", None, "D7REC - D7REC_S212",
         combine((es("D7REC"), 1), (es("D7REC_S212"), -1)),
         "proxy: S212 counterpart published"),
        ("rev", "transfers_from_row", None, "D7REC_S212", es("D7REC_S212"),
         "proxy: EU institutions only; other RoW counterparts not split"),
        ("rev", "transfers_from_dom + transfers_from_row", None, "D7REC",
         es("D7REC"), "sum is split-free"),
        ("rev", "tax_capital", None, "D91REC", es("D91REC"), "direct"),
        ("rev", "cap_transfers_from_dom", None, "D92_D99REC - D9REC_S2",
         combine((es("D92_D99REC"), 1), (es("D9REC_S2"), -1)),
         "counterpart split (S2) - not delivered for DK 2020 if blank"),
        ("rev", "cap_transfers_from_row", None, "D9REC_S2", es("D9REC_S2"),
         "counterpart split (S2) - not delivered for DK 2020 if blank"),
        ("rev", "cap_transfers_from_dom + cap_transfers_from_row", None,
         "D92_D99REC", es("D92_D99REC"), "sum is split-free"),
        ("rev", "cons_capital", None, "P51C", es("P51C"), "direct"),
        ("rev_eu", "tax_import", None, "taxag S212 D212",
         es("D212", es_tax212),
         "import duties are collected for the EU: recorded in sector S212, "
         "not S13"),
        # --- totals ---
        ("total", "sum of exp rows (national)", None, "composed", dk_exp, "n/a"),
        ("total", "sum of rev rows (national)", None, "composed", dk_rev, "n/a"),
        ("total", "rev - exp (national rows)", None, "B9", es("B9"),
         "Danish sheet balances against B9 net lending"),
    ]

    # Map Danish selectors to values.
    def dk_for(selector: str, balance: str) -> float | None:
        parts = [p.strip() for p in selector.split("+")]
        try:
            if selector == "sum of exp rows (national)":
                return dk_exp
            if selector == "sum of rev rows (national)":
                return dk_rev
            if selector == "rev - exp (national rows)":
                return dk_rev - dk_exp
            if selector == "all five tax_direct D51 rows":
                return (dk_val("tax_direct_source")
                        + dk_val("tax_direct_other_labor")
                        + dk_val("tax_direct_corp")
                        + dk_val("tax_direct_pension"))
            if selector == "property_value + vehicles + media (D59)":
                return (dk_val("tax_direct_property_value")
                        + dk_val("tax_direct_vehicles")
                        + dk_val("tax_direct_media"))
            if selector == "interest":
                sel = dk[(dk["trans"] == "interest") & (dk["balance"] == balance)]
                return float(sel["value"].sum())
            return sum(dk_val(p) for p in parts)
        except KeyError:
            return None

    row_records = []
    for balance, selector, _, es_expr, es_v, note in row_specs:
        d = dk_for(selector, balance)
        row_records.append({
            "balance": balance, "danish_rows": selector,
            "eurostat_construction": es_expr,
            "dk_bn_dkk": None if d is None else round(d, 3),
            "eurostat_bn_dkk": None if es_v is None else round(es_v, 3),
            "diff": (None if d is None or es_v is None
                     else round(es_v - d, 3)),
            "pct_diff": (None if d in (None, 0) or es_v is None
                         else round(100 * (es_v - d) / d, 3)),
            "note": note,
        })
    rows_cmp = pd.DataFrame(row_records)

    # ---------------- cons_publ components (disagg sheet) ----------------
    # The Danish sheet stores signed contributions to the P3 formula
    # (P3 = D1+P51c+P2+D29-D39+D632-P11-P131-P12); Eurostat publishes
    # positive levels, so the negative components carry sign -1 here.
    comp_map = [
        ("D1", "D1PAY", es("D1PAY"), 1),
        ("P51c", "P51C", es("P51C"), 1),
        ("P2", "P2", es("P2"), 1),
        ("D29", "D29PAY", es("D29PAY"), 1),
        ("D39", "-D39REC", es("D39REC"), -1),
        ("D632", "D632PAY", es("D632PAY"), 1),
        ("P11, P131", "-(P11 + P131)", es_sum(["P11", "P131"]), -1),
        ("P12", "-P12", es("P12"), -1),
    ]
    comp_records = []
    for esa, es_expr, es_v, sign in comp_map:
        d = float(dis_c[esa])
        e = None if es_v is None else sign * es_v
        comp_records.append({
            "danish_trans_esa": esa, "eurostat_construction": es_expr,
            "dk_bn_dkk": round(d, 3),
            "eurostat_bn_dkk": None if e is None else round(e, 3),
            "diff": None if e is None else round(e - d, 3),
            "pct_diff": (None if e is None or d == 0
                         else round(100 * (e - d) / d, 3)),
        })
    comp_cmp = pd.DataFrame(comp_records)

    # ---------------- tax detail sheet (taxag subitems) ----------------
    tax_items = ["D2", "D21", "D211", "D212", "D214", "D29",
                 "D5", "D51", "D51A", "D51A_C1", "D51B", "D51B_C2",
                 "D51C", "D51C1", "D51C2", "D51C3", "D51D", "D51E",
                 "D59", "D59A", "D59D", "D59F", "D61", "D91"]
    tax_records = []
    for item in tax_items:
        tax_records.append({
            "na_item": item,
            "S13_bn_dkk": (None if es("D2", es_tax13) is None else
                           (round(es(item, es_tax13), 3)
                            if es(item, es_tax13) is not None else None)),
            "S212_bn_dkk": (round(es(item, es_tax212), 3)
                            if es(item, es_tax212) is not None else None),
        })
    tax_detail = pd.DataFrame(tax_records)

    # ---------------- EU-27 coverage ----------------
    probe = load_raw("gov_10a_main_eu27_coverage_probe_2020.json")
    tprobe = load_raw("gov_10a_taxag_eu27_coverage_probe_2020.json")
    yprobe = load_raw("gov_10a_main_eu27_year_probe_TE.json")
    se_main = load_raw("gov_10a_main_SE_2020.json").set_index("na_item")["value"]

    cov_rows = []
    for geo in EU27:
        have = set(probe[probe.geo == geo]["na_item"])
        have_tax13 = set(tprobe[(tprobe.geo == geo)
                                & (tprobe.sector == "S13")]["na_item"])
        have_tax212 = set(tprobe[(tprobe.geo == geo)
                                 & (tprobe.sector == "S212")]["na_item"])
        missing_main = [i for i in NEEDED_MAIN_ITEMS if i not in have]
        missing_tax = [i for i in NEEDED_TAX_ITEMS if i not in have_tax13]
        missing_split = [i for i in SPLIT_ITEMS if i not in have]
        yg = yprobe[yprobe.geo == geo]
        years = sorted(yg["time"].astype(int))
        cov_rows.append({
            "geo": geo,
            "main_items_missing": ", ".join(missing_main),
            "taxag_S13_missing": ", ".join(missing_tax),
            "taxag_S212_D212": "D212" in have_tax212,
            "split_items_missing": ", ".join(missing_split),
            "years_TE": (f"{years[0]}-{years[-1]} (n={len(years)})"
                         if years else "none"),
            "complete_core_2020": not missing_main and not missing_tax,
        })
    coverage = pd.DataFrame(cov_rows)

    # Sweden full-slice availability of everything the pilot mapping used.
    used_main = (NEEDED_MAIN_ITEMS
                 + SPLIT_ITEMS
                 + ["P11", "P131", "P12", "P11_P12_P131"])
    se_missing = [i for i in used_main if i not in se_main.index]

    # ---------------- usage sheet ----------------
    usage = pd.DataFrame([
        {"item": "file", "detail": "data/preprocessing/data/government_finances.xlsx, sheets 'gov_fin' (consumed) and 'gov_fin_disagg' (DST provenance; NOT consumed)"},
        {"item": "columns", "detail": "year, balance (exp/rev/exp_eu/rev_eu), trans, trans_txt, trans_esa, trans_esa_txt, value"},
        {"item": "years / units", "detail": "2020 only (34 rows on gov_fin); values in bn DKK"},
        {"item": "read_data.py lines 427-538", "detail": "builds ~28 scalar time series (vGov2Foreign, vGovInv, vGovSub, vtVAT, vtDirect, vtIndirect, vG, vTrans, vCont, vtCorp, vtPAL, ...) by filtering trans/balance"},
        {"item": "read_data.py lines 545-553", "detail": "re-reads sheet 0 (labelled 'disagg' but same sheet) and splits the two tax_direct_other_labor rows via trans_txt ('labour market fund' -> vtAM, 'other' -> vtPersIncRest)"},
        {"item": "model needs", "detail": "scalar government revenue/expenditure series by ESA transaction; no industry dimension anywhere in this input"},
        {"item": "MAKRO caveat", "detail": "read_data.py:429-433 notes the values come from the MAKRO model, not raw DST - number gaps against Eurostat are expected a priori"},
    ])

    # ---------------- totals sheet ----------------
    totals = pd.DataFrame([
        {"item": "DK sum exp (national)", "bn_dkk": round(dk_exp, 3)},
        {"item": "DK sum rev (national)", "bn_dkk": round(dk_rev, 3)},
        {"item": "DK exp_eu", "bn_dkk": round(dk_exp_eu, 3)},
        {"item": "DK rev_eu", "bn_dkk": round(dk_rev_eu, 3)},
        {"item": "DK rev - exp", "bn_dkk": round(dk_rev - dk_exp, 3)},
        {"item": "ES TE", "bn_dkk": round(es("TE"), 3)},
        {"item": "ES TR", "bn_dkk": round(es("TR"), 3)},
        {"item": "ES B9", "bn_dkk": round(es("B9"), 3)},
    ])
    totals = pd.concat(
        [totals, pd.DataFrame(checks).rename(columns={"check": "item"})],
        ignore_index=True)

    # ---------------- anomalies (data-driven, finalized after inspection) ----
    anomalies_rows = []

    def anomaly(name: str, detail: str) -> None:
        anomalies_rows.append({"anomaly": name, "detail": detail})

    anomaly("Numbers match exactly, contrary to the MAKRO expectation",
            "The mapping doc predicted concept-not-number match because the "
            "Danish values come from MAKRO. In fact every mappable row "
            "reconciles to the third decimal (bn DKK) except interest "
            "revenue: D41REC 14.337 vs Danish 14.249 (+0.088 bn, +0.62%), "
            "which also accounts for the entire B9 gap (8.434 vs 8.348). "
            "MAKRO evidently passes national-accounts levels through "
            "unchanged for this input; only the interest-revenue line "
            "deviates (vintage or FISIM treatment).")
    anomaly("PAL pension-yield tax is a household tax in Eurostat",
            "Danish groups PAL (~48.3 bn) with corporate taxes conceptually "
            "close to read_data.py's vtPAL; Eurostat books it under "
            "D51A_C1 taxes on individual/household income INCLUDING HOLDING "
            "GAINS. Grouping-corrected rows match exactly: tax_direct_corp "
            "= D51B_C2 (67.720), and source+other_labor+pension = D51A_C1 + "
            "D51D. An EU rebuild cannot recover PAL as a separate series "
            "from gov_10a_taxag alone - it is dissolved in D51A_C1.")
    anomaly("Danish 'D214' row actually contains D212 + D214",
            "tax_indirect_products (87.831) = taxag S13 D212 (37.396, "
            "import excises recorded in S13) + D214 (50.435). The Danish "
            "trans_esa label is imprecise; the separate rev_eu tax_import "
            "row (3.089) is the S212 part of D212 (duties collected for "
            "the EU). Both reproduce exactly once read this way.")
    anomaly("Danish trans_esa 'D22+D99' is a typo",
            "The capital-transfer rows are labelled D22+D99; D22 is a "
            "products-tax code that cannot appear here. ESA capital "
            "transfers paid are D9 = D92 investment grants + D99 other; the "
            "label should read D92+D99. The row sums behave exactly as D9 "
            "(D9PAY 13.916, D92_D99REC -5.532, both exact).")
    anomaly("Counterpart splits (dom vs RoW) are the real structural gap",
            "gov_10a_main has no counterpart-sector dimension. The published "
            "partial items do not close it for DK 2020: D9PAY_S2/D9REC_S2 "
            "carry no value, and the EU-institution proxy for current "
            "transfers (D74PAY+D76PAY = 21.022) recovers only half of the "
            "Danish transfer_to_row (42.660) - Danish RoW transfers include "
            "D62 benefits paid abroad and non-EU D7. The dom+row SUMS are "
            "exact (D62PAY+D7PAY = 463.586, D7REC = 24.009, D9PAY, "
            "D92_D99REC). An EU rebuild needs either nasa_10_nf_tr S2 "
            "counterpart data or a fixed-share split for the four "
            "dom/row pairs.")
    anomaly("EU flows sit in sector S212, and one has no value",
            "Danish exp_eu/rev_eu rows never touch S13 in ESA. tax_import "
            "reconciles exactly against taxag sector S212 D212 (3.089). But "
            "subs_other_production_eu (7.035, CAP subsidies paid by the EU "
            "-> read_data.py vtCAP_prodsubsidy) has NO delivered value: "
            "D3REC_S212 carries no observation for DK or SE 2020. Candidate "
            "replacement sources: nasa_10_nf_tr D39 received by "
            "resident sectors net of gov D39PAY, or CAP budget data.")
    anomaly("D42/D45 detail not delivered for DK",
            "Danish splits dividends (D421, 5.755 with quasi-corp) and rent "
            "(D45, 0.533); for DK gov_10a_main delivers only the bundle "
            "D42_TO_D45REC (6.288, exact match to the Danish sum). "
            "read_data.py consumes vtDividends, vGovRevQuasi and vGovRent "
            "separately, so an EU rebuild needs another source (e.g. "
            "nasa_10_nf_tr D42/D45 for S13) or a fixed-share split.")
    anomaly("P52 vs P52_P53",
            "Eurostat publishes changes in inventories only bundled with "
            "acquisitions of valuables (P52_P53); the Danish row is pure "
            "P52. Both are 0.000 for DK 2020, so immaterial here.")
    anomaly("Sign convention in the disagg sheet",
            "gov_fin_disagg stores signed contributions to the P3 formula "
            "(D39 -3.197, P11/P131 -58.228, P12 -21.391); Eurostat "
            "publishes positive levels. With signs applied, all 8 "
            "components match exactly and sum to cons_publ 576.099.")

    # ---------------- readme ----------------
    readme = pd.DataFrame([
        {"key": "title", "value": "Reconciliation: Eurostat gov_10a_main (+ gov_10a_taxag) vs government_finances.xlsx, Denmark 2020"},
        {"key": "created", "value": created},
        {"key": "created_by", "value": "data/preprocessing/scripts/reconcile_government_finances_dk_2020.py"},
        {"key": "purpose", "value": "Pilot test of the eu_data_mapping.md 'OK' verdict: can gov_10a_main replace the Danish government_finances.xlsx input for any EU country?"},
        {"key": "danish_source", "value": "data/preprocessing/data/government_finances.xlsx (year=2020, sheet gov_fin; values from the MAKRO model, not raw DST)"},
        {"key": "eurostat_sources", "value": "gov_10a_main (S13, MIO_NAC) and gov_10a_taxag (S13+S212, tax detail) via the Eurostat dissemination API (JSON-stat 2.0)"},
        {"key": "eurostat_retrieval_date", "value": retrieval_date},
        {"key": "raw_data", "value": "data/preprocessing/data/government_finances_raw/DK/2020/ (README.md + manifest.json with URLs, params, SHA-256)"},
        {"key": "units", "value": "bn DKK on both sides (Eurostat MIO_NAC / 1000)"},
        {"key": "colleague_reference", "value": "na_item mapping seeded from data/read_eurostat_data/government_data.py (colleague's EU-core reference implementation)"},
        {"key": "headline", "value": "Every mappable row reconciles EXACTLY (to the third decimal, bn DKK) once four re-readings are applied (PAL under D51A_C1; D212 inside the Danish 'D214' row; D42-D45 as a bundle; signed disagg components) - except interest revenue D41REC (+0.088 bn, +0.62%), which is the entire B9 gap. Remaining gaps are structural: dom/RoW counterpart splits and the EU-paid CAP subsidy row have no gov_10a_* source."},
        {"key": "sheets", "value": "gov_fin_file_usage | totals (sums + identity checks) | rows | cons_publ_components | tax_detail | eu27_coverage | anomalies"},
    ])

    anomalies = pd.DataFrame(anomalies_rows)

    with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
        readme.to_excel(xl, sheet_name="readme", index=False)
        usage.to_excel(xl, sheet_name="gov_fin_file_usage", index=False)
        totals.to_excel(xl, sheet_name="totals", index=False)
        rows_cmp.to_excel(xl, sheet_name="rows", index=False)
        comp_cmp.to_excel(xl, sheet_name="cons_publ_components", index=False)
        tax_detail.to_excel(xl, sheet_name="tax_detail", index=False)
        coverage.to_excel(xl, sheet_name="eu27_coverage", index=False)
        anomalies.to_excel(xl, sheet_name="anomalies", index=False)
    print(f"wrote {OUT}")

    # ---------------- console report ----------------
    pd.set_option("display.width", 250)
    print("\nROW COMPARISON (bn DKK):")
    print(rows_cmp.to_string(index=False))
    print("\nCONS_PUBL COMPONENTS (disagg sheet, bn DKK):")
    print(comp_cmp.to_string(index=False))
    print("\nIDENTITY CHECKS:")
    print(pd.DataFrame(checks).to_string(index=False))
    print("\nTAX DETAIL (taxag, bn DKK):")
    print(tax_detail.to_string(index=False))
    print("\nEU-27 coverage (countries NOT complete for core items 2020):")
    inc = coverage[~coverage["complete_core_2020"]]
    print(inc.to_string(index=False) if len(inc) else "  none - all 27 complete")
    print("\nSweden: pilot na_items missing from SE 2020 full slice:")
    print(f"  {se_missing if se_missing else 'none - all present'}")
    n_fail = sum(1 for c in checks if c["result"] == "FAIL")
    print(f"\nchecks: {len(checks) - n_fail}/{len(checks)} PASS")


if __name__ == "__main__":
    main()
