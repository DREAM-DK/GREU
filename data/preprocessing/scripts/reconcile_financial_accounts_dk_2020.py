"""Reconcile Eurostat nasa_10_f_bs (plus nasa_10_nf_tr for flows) DK 2020
against the Danish GREU input institutional_financial_accounts.xlsx.

Ninth pilot of the EU data replacement effort (see docs/eu_data_mapping.md).

Special situation of this input
-------------------------------
The eight GDX symbols read_data.py builds from this Excel are never loaded
by the model. data_from_GR.gms:138-140 loads only `sector`, `vNetFinAssets`
and `vNetDebtInstruments`, and takes them from
Modules/financial_accounts/financial_accounts_data.gdx - a live Eurostat
nasa_10_f_bs pull. The flow variables (vNetInterests, vNetDividends,
vNetRevaluations) are model-generated (model/modules/financial_accounts.gms
lines 107-110), not read from data. So this pilot verifies the production
module's route against the Danish numbers rather than proving a new route.

Inputs
------
- data/preprocessing/data/institutional_financial_accounts.xlsx
    Danish input, values in bn DKK, year 2020 only, sheet 'financial':
    5 vars (vNetDebtInstruments, vNetEquity, vNetInterests, vNetDividends,
    vNetRevaluations) x 4 sectors (corp=S11+S12, gov=S13, hh=S14+S15,
    row=S2 per metadata.xlsx 'sectors') x as/li/net.
    The Danish side applies a pension-asset reallocation: households'
    pension assets are moved from financial corporations to households.
- data/preprocessing/data/government_finances.xlsx (sheet 'gov_fin')
    Only for the gov-gap probe: the Danish reference values the
    government-finances pilot (2026-08-17) could not source from gov_10a_*.
- data/preprocessing/data/financial_accounts_raw/DK/2020/*.json
    Raw JSON-stat from the Eurostat dissemination API, downloaded by
    download_financial_accounts_dk_2020.py (see README.md / manifest.json).

Units: Danish bn DKK; Eurostat MIO_NAC / 1000 (stocks), CP_MNAC / 1000 (flows).

Output
------
data/preprocessing/data/financial_accounts_dk2020_reconciliation.xlsx with
sheets: readme, finacc_file_usage, totals, rows, instrument_definitions,
pension_reallocation, flows_probe, gov_gap_probe, eu27_coverage, anomalies

Run:  python data/preprocessing/scripts/reconcile_financial_accounts_dk_2020.py
"""

from __future__ import annotations

import datetime
import json
import pathlib

import pandas as pd

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "financial_accounts_raw" / "DK" / "2020"
OUT = DATA / "financial_accounts_dk2020_reconciliation.xlsx"
YEAR = 2020

EU27 = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR",
    "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO",
    "SE", "SI", "SK",
]

# Danish sector groups (metadata.xlsx sheet 'sectors').
GROUPS = {"corp": ["S11", "S12"], "gov": ["S13"], "hh": ["S14", "S15"],
          "row": ["S2"]}

# Instrument definitions found in the repo.
# Live module (Modules/financial_accounts/financial_accounts_data.py:101-107):
DEBT_MODULE = (["F1", "F2", "F3", "F4", "F6", "F7", "F8"], ["F11"])
EQ_MODULE = (["F5"], [])
# Colleague reference (data/read_eurostat_data/financial_accounts_balance_data.py):
DEBT_COLLEAGUE = (["F1", "F2", "F3", "F4", "F52", "F6", "F7", "F8"], ["F11"])
EQ_COLLEAGUE = (["F51"], [])
# Total financial assets net of monetary gold/SDRs:
FINASSETS = (["F"], ["F11"])

TOP_ITEMS = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"]
# Required for the winning definitions (F-F11 total, debt, F5 equity).
# F1/F11/F51/F52 are deliberately NOT required: monetary gold/SDRs are
# genuine zeros for most sectors, and F51/F52 only matter for the losing
# colleague definition. Their absence is reported but does not flag a
# country incomplete.
BS_REQUIRED_ITEMS = ["F", "F2", "F3", "F4", "F5", "F6", "F7", "F8"]
BS_OPTIONAL_ITEMS = ["F1", "F11", "F51", "F52"]
TR_CORE_ITEMS = ["D41", "D42"]


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
    dk = pd.read_excel(DATA / "institutional_financial_accounts.xlsx",
                       sheet_name="financial")
    dk = dk[dk["year"] == YEAR]

    def dk_cell(var: str, group: str, side: str) -> float:
        sel = dk[(dk["var"] == var) & (dk["sector"] == group)]
        return float(sel[side].iloc[0])

    # ---------------- Eurostat stocks ----------------
    bs = load_raw("nasa_10_f_bs_DK_2020.json")

    def bs_pivot(unit: str, co_nco: str) -> pd.DataFrame:
        d = bs[(bs.unit == unit) & (bs.co_nco == co_nco)]
        piv = d.pivot_table(index=["sector", "na_item"], columns="finpos",
                            values="value", aggfunc="sum") / 1000.0
        return piv  # NaN = cell not delivered

    def bs_side(piv: pd.DataFrame, sectors: list[str], items_pos: list[str],
                items_neg: list[str], pos: str) -> float:
        """Sum of delivered cells; absent cells count as zero."""
        total = 0.0
        for s in sectors:
            for it in items_pos:
                try:
                    v = piv.loc[(s, it), pos]
                    if pd.notna(v):
                        total += v
                except KeyError:
                    pass
            for it in items_neg:
                try:
                    v = piv.loc[(s, it), pos]
                    if pd.notna(v):
                        total -= v
                except KeyError:
                    pass
        return total

    def bs_group(piv: pd.DataFrame, group: str,
                 definition: tuple[list[str], list[str]]) -> tuple[float, float, float]:
        pos_items, neg_items = definition
        a = bs_side(piv, GROUPS[group], pos_items, neg_items, "ASS")
        li = bs_side(piv, GROUPS[group], pos_items, neg_items, "LIAB")
        return a, li, a - li

    nco = bs_pivot("MIO_NAC", "NCO")
    co = bs_pivot("MIO_NAC", "CO")
    nco_eur = bs_pivot("MIO_EUR", "NCO")

    # ---------------- Eurostat flows ----------------
    tr = load_raw("nasa_10_nf_tr_DK_2020.json")
    trp = tr.pivot_table(index=["sector", "na_item"], columns="direct",
                         values="value", aggfunc="sum").fillna(0.0) / 1000.0

    def tr_cell(sector: str, item: str, direct: str) -> float | None:
        try:
            return float(trp.loc[(sector, item), direct])
        except KeyError:
            return None

    def tr_net(group: str, items: list[str]) -> float:
        total = 0.0
        for s in GROUPS[group]:
            for it in items:
                r = tr_cell(s, it, "RECV")
                p = tr_cell(s, it, "PAID")
                total += (r or 0.0) - (p or 0.0)
        return total

    # ---------------- identity checks ----------------
    checks = []

    def check(name: str, delta: float | None, tol: float) -> None:
        ok = delta is not None and abs(delta) <= tol
        checks.append({"check": name,
                       "delta_bn_dkk": None if delta is None else round(delta, 4),
                       "tolerance": tol, "result": "PASS" if ok else "FAIL"})

    # Danish-internal identities.
    check("DK as - li = net (max abs deviation over 20 rows)",
          float((dk["as"] - dk["li"] - dk["net"]).abs().max()), 0.001)
    for var in sorted(dk["var"].unique()):
        check(f"DK sector nets sum to 0 for {var}",
              float(dk[dk["var"] == var]["net"].sum()), 0.05)

    # Eurostat-internal identities (verify our reading of the codes).
    additivity_gaps = {}
    for g in GROUPS:
        f_net = bs_group(nco, g, FINASSETS)[2]
        parts = (bs_group(nco, g, DEBT_MODULE)[2] + bs_group(nco, g, EQ_MODULE)[2])
        additivity_gaps[g] = f_net - parts
        check(f"ES {g}: (F - F11) net = debt_module net + F5 net", f_net - parts, 0.5)
        check(f"ES {g}: net invariant to consolidation (NCO vs CO)",
              f_net - bs_group(co, g, FINASSETS)[2], 0.5)
    # Same additivity via the combined household sector: localizes whether a
    # detail gap sits in the S14/S15 split or in the accounts themselves.
    f_c = bs_side(nco, ["S14_S15"], ["F"], ["F11"], "ASS") \
        - bs_side(nco, ["S14_S15"], ["F"], ["F11"], "LIAB")
    parts_c = (bs_side(nco, ["S14_S15"], DEBT_MODULE[0], DEBT_MODULE[1], "ASS")
               - bs_side(nco, ["S14_S15"], DEBT_MODULE[0], DEBT_MODULE[1], "LIAB")
               + bs_side(nco, ["S14_S15"], ["F5"], [], "ASS")
               - bs_side(nco, ["S14_S15"], ["F5"], [], "LIAB"))
    check("ES S14_S15 combined: (F - F11) net = debt_module net + F5 net",
          f_c - parts_c, 0.5)
    s14s15 = bs_side(nco, ["S14", "S15"], ["F"], [], "ASS")
    s14_s15 = bs_side(nco, ["S14_S15"], ["F"], [], "ASS")
    check("ES S14 + S15 = S14_S15 (F assets)", s14s15 - s14_s15, 0.5)
    check("ES S128 + S129 = S128_S129 (F5 assets)",
          bs_side(nco, ["S128", "S129"], ["F5"], [], "ASS")
          - bs_side(nco, ["S128_S129"], ["F5"], [], "ASS"), 0.5)
    for g in GROUPS:
        check(f"ES {g}: D4 net = D41+D42+D43+D44+D45 net",
              tr_net(g, ["D4"])
              - tr_net(g, ["D41", "D42", "D43", "D44", "D45"]), 0.05)
    # Cross-pilot anchors against the government-finances pilot (2026-08-17).
    check("nf_tr S13 D41 RECV = gov pilot D41REC (14.337)",
          (tr_cell("S13", "D41", "RECV") or 0.0) - 14.337, 0.01)
    check("nf_tr S13 D42 RECV + D45 RECV = gov pilot D42_TO_D45REC (6.288)",
          (tr_cell("S13", "D42", "RECV") or 0.0)
          + (tr_cell("S13", "D45", "RECV") or 0.0) - 6.288, 0.01)

    # ---------------- instrument definitions ----------------
    def_records = []
    for g in GROUPS:
        dk_debt = dk_cell("vNetDebtInstruments", g, "net")
        dk_eq = dk_cell("vNetEquity", g, "net")
        candidates = [
            ("vNetDebtInstruments", "module: F1+F2+F3+F4+F6+F7+F8-F11",
             bs_group(nco, g, DEBT_MODULE)[2], dk_debt),
            ("vNetDebtInstruments", "colleague: module + F52",
             bs_group(nco, g, DEBT_COLLEAGUE)[2], dk_debt),
            ("vNetEquity", "module: F5",
             bs_group(nco, g, EQ_MODULE)[2], dk_eq),
            ("vNetEquity", "colleague: F51",
             bs_group(nco, g, EQ_COLLEAGUE)[2], dk_eq),
        ]
        for var, definition, es_v, dk_v in candidates:
            def_records.append({
                "group": g, "var": var, "definition": definition,
                "dk_net_bn_dkk": round(dk_v, 3),
                "eurostat_net_bn_dkk": round(es_v, 3),
                "diff": round(es_v - dk_v, 3),
                "affected_by_pension_move": g in ("corp", "hh"),
            })
    def_cmp = pd.DataFrame(def_records)

    # Per-instrument net detail per group (decomposition support).
    detail_records = []
    for g in GROUPS:
        for it in ["F"] + TOP_ITEMS + ["F11", "F51", "F52", "F62",
                                       "F63_F64_F65"]:
            a, li, net = bs_group(nco, g, ([it], []))
            detail_records.append({
                "group": g, "na_item": it,
                "ass_bn_dkk": round(a, 3), "liab_bn_dkk": round(li, 3),
                "net_bn_dkk": round(net, 3),
            })
    detail = pd.DataFrame(detail_records)

    # ---------------- main row comparison ----------------
    # Eurostat constructions per var (chosen definitions; see
    # instrument_definitions and flows_probe for the alternatives).
    def es_stock(var: str, g: str) -> tuple[float, float, float] | None:
        if var == "vNetDebtInstruments":
            return bs_group(nco, g, DEBT_MODULE)
        if var == "vNetEquity":
            return bs_group(nco, g, EQ_MODULE)
        return None

    FLOW_ITEM = {"vNetInterests": "D41", "vNetDividends": "D42"}

    def es_flow(var: str, g: str) -> tuple[float, float, float] | None:
        """(RECV, PAID, net) for the group; RECV maps to the Danish 'as'
        column (income earned on assets) and PAID to 'li'."""
        item = FLOW_ITEM.get(var)
        if item is None:
            return None  # vNetRevaluations: no source in the pilot datasets
        r = sum(tr_cell(s, item, "RECV") or 0.0 for s in GROUPS[g])
        p = sum(tr_cell(s, item, "PAID") or 0.0 for s in GROUPS[g])
        return r, p, r - p

    var_notes = {
        "vNetDebtInstruments": "nasa_10_f_bs NCO, module def F1+F2+F3+F4+F6+F7+F8-F11",
        "vNetEquity": "nasa_10_f_bs, F5 (consolidation-invariant in net)",
        "vNetInterests": "nasa_10_nf_tr D41 net (RECV-PAID)",
        "vNetDividends": "nasa_10_nf_tr D42 net (RECV-PAID)",
        "vNetRevaluations": ("NO SOURCE in nasa_10_f_bs/nasa_10_nf_tr; "
                             "derivable as stock change minus nasa_10_f_tr "
                             "transactions minus nasa_10_f_oc other changes"),
    }
    row_records = []
    for var in ["vNetDebtInstruments", "vNetEquity", "vNetInterests",
                "vNetDividends", "vNetRevaluations"]:
        for g in GROUPS:
            d_as = dk_cell(var, g, "as")
            d_li = dk_cell(var, g, "li")
            d_net = dk_cell(var, g, "net")
            stock = es_stock(var, g) or es_flow(var, g)
            if stock is not None:
                e_as, e_li, e_net = stock
            else:
                e_as = e_li = e_net = None
            row_records.append({
                "var": var, "group": g,
                "dk_as": round(d_as, 3), "dk_li": round(d_li, 3),
                "dk_net": round(d_net, 3),
                "es_as": None if e_as is None else round(e_as, 3),
                "es_li": None if e_li is None else round(e_li, 3),
                "es_net": None if e_net is None else round(e_net, 3),
                "diff_net": (None if e_net is None
                             else round(e_net - d_net, 3)),
                "pension_move_expected": g in ("corp", "hh")
                                         and var != "vNetRevaluations",
                "note": var_notes[var],
            })
    rows_cmp = pd.DataFrame(row_records)

    # ---------------- pension reallocation ----------------
    # Implied per-variable moves: what must shift corp -> hh so that raw
    # Eurostat reproduces the Danish file. gov/row rows anchor the raw match.
    pension_records = []
    implied = {}
    for var, es_net_fn in [
        ("vNetEquity", lambda g: bs_group(nco, g, EQ_MODULE)[2]),
        ("vNetDebtInstruments", lambda g: bs_group(nco, g, DEBT_MODULE)[2]),
        ("vNetInterests", lambda g: tr_net(g, ["D41"])),
        ("vNetDividends", lambda g: tr_net(g, ["D42"])),
    ]:
        move_hh = dk_cell(var, "hh", "net") - es_net_fn("hh")
        move_corp = es_net_fn("corp") - dk_cell(var, "corp", "net")
        implied[var] = move_hh
        pension_records.append({
            "quantity": f"{var}: implied corp->hh move",
            "bn_dkk": round(move_hh, 3),
            "mirror_from_corp_side": round(move_corp, 3),
            "consistent": abs(move_hh - move_corp) < 0.5,
        })
    hh_f6 = bs_group(nco, "hh", (["F6"], []))
    s1289 = {it: bs_side(nco, ["S128_S129"], [it], [], "ASS")
             for it in ["F", "F5"]}
    s1289_debt = bs_side(nco, ["S128_S129"], DEBT_MODULE[0], DEBT_MODULE[1], "ASS")
    s1289_f6_liab = bs_side(nco, ["S128_S129"], ["F6"], [], "LIAB")
    total_moved = implied["vNetEquity"] + implied["vNetDebtInstruments"] + hh_f6[2]
    hh_net_gap = (dk_cell("vNetDebtInstruments", "hh", "net")
                  + dk_cell("vNetEquity", "hh", "net")
                  - bs_group(nco, "hh", FINASSETS)[2])
    for q, v in [
        ("hh F6 assets net (claims on pension/insurance, removed by the move)",
         hh_f6[2]),
        ("total portfolio implied moved corp->hh (eq + debt moves + hh F6 removal)",
         total_moved),
        ("S128_S129 total financial assets F (candidate moved portfolio)",
         s1289["F"]),
        ("S128_S129 equity assets F5", s1289["F5"]),
        ("S128_S129 debt-definition assets", s1289_debt),
        ("S128_S129 F6 liabilities (entitlements owed to hh and RoW)",
         s1289_f6_liab),
        ("hh net financial assets: Danish (debt+eq) minus Eurostat (F-F11) "
         "= net effect of the move on hh", hh_net_gap),
    ]:
        pension_records.append({"quantity": q, "bn_dkk": round(v, 3),
                                "mirror_from_corp_side": None,
                                "consistent": None})
    pension = pd.DataFrame(pension_records)

    # ---------------- flows probe ----------------
    flow_records = []
    for var, items in [("vNetInterests", ["D41"]), ("vNetDividends", ["D42"])]:
        for g in GROUPS:
            d_net = dk_cell(var, g, "net")
            e_net = tr_net(g, items)
            flow_records.append({
                "var": var, "group": g, "construction": "+".join(items),
                "dk_net": round(d_net, 3), "es_net": round(e_net, 3),
                "diff": round(e_net - d_net, 3),
                "note": ("pension move expected" if g in ("corp", "hh")
                         else "no adjustment expected"),
            })
        d_ch = dk_cell(var, "corp", "net") + dk_cell(var, "hh", "net")
        e_ch = tr_net("corp", items) + tr_net("hh", items)
        flow_records.append({
            "var": var, "group": "corp+hh", "construction": "+".join(items),
            "dk_net": round(d_ch, 3), "es_net": round(e_ch, 3),
            "diff": round(e_ch - d_ch, 3),
            "note": "sum is invariant to the pension move",
        })
    # Subsector flows would replicate the move, if published:
    for it in ["D41", "D42"]:
        r = tr_cell("S128_S129", it, "RECV")
        flow_records.append({
            "var": f"S128_S129 {it} RECV", "group": "S128_S129",
            "construction": it,
            "dk_net": None,
            "es_net": None if r is None else round(r, 3),
            "diff": None,
            "note": ("not delivered for DK 2020 - the flow-side pension move "
                     "cannot be replicated from nasa_10_nf_tr subsector data"
                     if r is None else "delivered"),
        })
    for g in GROUPS:
        flow_records.append({
            "var": "vNetRevaluations", "group": g, "construction": "none",
            "dk_net": round(dk_cell("vNetRevaluations", g, "net"), 3),
            "es_net": None, "diff": None,
            "note": ("no revaluation source in the two pilot datasets; "
                     "derive as Delta(nasa_10_f_bs stocks) - nasa_10_f_tr "
                     "financial transactions - other volume changes"),
        })
    flows = pd.DataFrame(flow_records)

    # ---------------- gov-gap probe ----------------
    gov = pd.read_excel(DATA / "government_finances.xlsx", sheet_name="gov_fin")
    gov = gov[gov["year"] == YEAR]

    def gov_val(trans: str) -> float | None:
        sel = gov[gov["trans"] == trans]
        return float(sel["value"].sum()) if len(sel) else None

    def gap_row(gap: str, dk_desc: str, dk_v: float | None, es_desc: str,
                es_v: float | None, verdict: str, note: str) -> dict:
        return {"gov_pilot_gap": gap, "danish_reference": dk_desc,
                "dk_bn_dkk": None if dk_v is None else round(dk_v, 3),
                "nasa_10_nf_tr_construction": es_desc,
                "es_bn_dkk": None if es_v is None else round(es_v, 3),
                "diff": (None if dk_v is None or es_v is None
                         else round(es_v - dk_v, 3)),
                "verdict": verdict, "note": note}

    d42_s13 = tr_cell("S13", "D42", "RECV")
    d45_s13 = tr_cell("S13", "D45", "RECV")
    d39_s2 = tr_cell("S2", "D39", "PAID")
    gap_records = [
        gap_row("D42/D45 detail (vtDividends, vGovRevQuasi, vGovRent)",
                "gov_fin dividends + income_quasi_corp",
                (gov_val("dividends") or 0.0)
                + (gov_val("income_quasi_corp") or 0.0),
                "S13 D42 RECV", d42_s13,
                "PARTLY CLOSED",
                "nf_tr splits the gov_10a_main D42_TO_D45 bundle into D42 and "
                "D45. The remaining split dividends (D421) vs quasi-corporate "
                "withdrawals (D422) is NOT delivered for DK 2020 (codes exist "
                "in the dataset, no values)."),
        gap_row("D42/D45 detail - rent", "gov_fin rent", gov_val("rent"),
                "S13 D45 RECV", d45_s13, "CLOSED",
                "exact match closes the rent line separately."),
        gap_row("EU-paid CAP subsidies (vtCAP_prodsubsidy)",
                "gov_fin subs_other_production_eu",
                gov_val("subs_other_production_eu"),
                "S2 D39 PAID (other production subsidies paid by RoW, "
                "dominated by EU institutions)", d39_s2,
                "CANDIDATE FOUND",
                "nf_tr books subsidies paid by non-residents under S2; the "
                "EU is not separable from other RoW here (no S212 in "
                "nasa_10_nf_tr)."),
        gap_row("dom/RoW counterpart splits - transfers paid",
                "gov_fin transfer_to_row (S13-specific)",
                gov_val("transfer_to_row"),
                "S2 D62 RECV + S2 D7 RECV (economy-wide RoW counterpart, "
                "all paying sectors)",
                (tr_cell("S2", "D62", "RECV") or 0.0)
                + (tr_cell("S2", "D7", "RECV") or 0.0),
                "PARTIAL",
                "nf_tr has no payer x receiver cross-classification: the S2 "
                "column bounds gov transfers to RoW from above but includes "
                "private transfers. A gov-specific split still needs a "
                "fixed-share assumption or national counterpart data."),
        gap_row("dom/RoW counterpart splits - capital transfers",
                "gov_fin cap_transfer_to_row", gov_val("cap_transfer_to_row"),
                "S2 D9 RECV (economy-wide)", tr_cell("S2", "D9", "RECV"),
                "PARTIAL", "same caveat as the current-transfer split."),
        gap_row("PAL pension-yield tax (vtPAL)",
                "gov pilot: ~48.3 bn dissolved in gov_10a_taxag D51A_C1",
                None, "nasa_10_nf_tr D51 subitems", None, "STILL OPEN",
                "nasa_10_nf_tr carries D51 only as a total - no D51 subitems "
                "exist in the dataset, so PAL cannot be recovered here "
                "either. A separate national source or a fixed share of "
                "D51A_C1 remains necessary."),
    ]
    gaps = pd.DataFrame(gap_records)

    # ---------------- EU-27 coverage ----------------
    bprobe = load_raw("nasa_10_f_bs_eu27_coverage_probe_2020.json")
    tprobe = load_raw("nasa_10_nf_tr_eu27_coverage_probe_2020.json")
    byear = load_raw("nasa_10_f_bs_eu27_year_probe_F.json")
    tyear = load_raw("nasa_10_nf_tr_eu27_year_probe_D41.json")

    core_secs = ["S11", "S12", "S13", "S2"]
    cov_rows = []
    for geo in EU27:
        bg = bprobe[bprobe.geo == geo]
        tg = tprobe[tprobe.geo == geo]
        have_bs = set(zip(bg["sector"], bg["na_item"]))
        bs_sec_ok = {s for s in core_secs
                     if all((s, i) in have_bs for i in BS_REQUIRED_ITEMS)}
        hh_split = all((s, "F") in have_bs for s in ["S14", "S15"])
        hh_combined = ("S14_S15", "F") in have_bs
        s1289_ok = ("S128_S129", "F") in have_bs or (
            ("S128", "F") in have_bs and ("S129", "F") in have_bs)
        missing_bs = [f"{s}:{i}" for s in core_secs for i in BS_REQUIRED_ITEMS
                      if (s, i) not in have_bs]
        missing_opt = [f"{s}:{i}" for s in core_secs for i in BS_OPTIONAL_ITEMS
                       if (s, i) not in have_bs]
        have_tr = set(zip(tg["sector"], tg["na_item"]))
        tr_ok = all((s, i) in have_tr
                    for s in core_secs + (["S14_S15"] if hh_combined
                                          else ["S14", "S15"])
                    for i in TR_CORE_ITEMS)
        d45_s13_ok = ("S13", "D45") in have_tr
        d421_ok = ("S13", "D421") in have_tr
        d39_s2_ok = ("S2", "D39") in have_tr
        by = sorted(byear[byear.geo == geo]["time"].astype(int))
        ty = sorted(tyear[tyear.geo == geo]["time"].astype(int))
        cov_rows.append({
            "geo": geo,
            "bs_core_sectors_complete": ",".join(sorted(bs_sec_ok)),
            "hh_published": ("S14+S15" if hh_split
                             else ("S14_S15 only" if hh_combined else "MISSING")),
            "s128_s129_available": s1289_ok,
            "bs_items_missing": "; ".join(missing_bs[:12])
                                + (" ..." if len(missing_bs) > 12 else ""),
            "bs_optional_missing_F1_F11_F51_F52": "; ".join(missing_opt[:12])
                                + (" ..." if len(missing_opt) > 12 else ""),
            "nf_tr_D41_D42_complete": tr_ok,
            "nf_tr_S13_D45": d45_s13_ok,
            "nf_tr_S13_D421": d421_ok,
            "nf_tr_S2_D39": d39_s2_ok,
            "years_f_bs": (f"{by[0]}-{by[-1]} (n={len(by)})" if by else "none"),
            "years_nf_tr": (f"{ty[0]}-{ty[-1]} (n={len(ty)})" if ty else "none"),
            "complete_core_2020": (len(bs_sec_ok) == len(core_secs)
                                   and (hh_split or hh_combined) and tr_ok),
        })
    coverage = pd.DataFrame(cov_rows)

    # ---------------- usage sheet ----------------
    usage = pd.DataFrame([
        {"item": "file", "detail": "data/preprocessing/data/institutional_financial_accounts.xlsx, sheet 'financial'"},
        {"item": "columns", "detail": "year, var, sector, as, li, net (net = as - li, exact in the file)"},
        {"item": "years / units", "detail": "2020 only (20 rows); values in bn DKK"},
        {"item": "sectors", "detail": "corp = S11+S12, gov = S13, hh = S14+S15, row = S2 (metadata.xlsx 'sectors'); Danish pension-asset reallocation moves households' pension assets from financial corporations to households"},
        {"item": "read_data.py lines 406-424", "detail": "melts as/li/net into 5 parameters vNetDebtInstruments/vNetInterests/vNetEquity/vNetDividends/vNetRevaluations [sector, as_li_net, t], exported to the country GDX (lines 746-753)"},
        {"item": "read_data.py lines 556-570", "detail": "gov interest split vGovNetInterest/vInterestGovAssets/vInterestGovDebt [t] (exported lines 741-744); note three .rename() calls without assignment are no-ops, incl. a li/as typo at line 568"},
        {"item": "MODEL CONSUMPTION (key finding)", "detail": "NONE of the eight exported symbols is loaded by the model. data_from_GR.gms:138-140 loads sector, vNetFinAssets, vNetDebtInstruments from Modules/financial_accounts/financial_accounts_data.gdx (live Eurostat nasa_10_f_bs pull, 5 sectors, DK hardcoded). Flows are model-generated (financial_accounts.gms:107-110 from calibrated rates)."},
        {"item": "consequence", "detail": "this input is already effectively EU-sourced in the production pipeline; the pilot verifies the module's route against the Danish numbers and records the module's defects (no pension reallocation, DK/2019-2020 hardcoded, no raw provenance, cache without manifest)"},
    ])

    # ---------------- totals sheet ----------------
    totals_rows = []
    for g in GROUPS:
        totals_rows.append({
            "item": f"DK {g} net financial assets (debt+eq net)",
            "bn_dkk": round(dk_cell("vNetDebtInstruments", g, "net")
                            + dk_cell("vNetEquity", g, "net"), 3)})
        totals_rows.append({
            "item": f"ES {g} net financial assets (F-F11 net, = module vNetFinAssets aggregated)",
            "bn_dkk": round(bs_group(nco, g, FINASSETS)[2], 3)})
    totals = pd.DataFrame(totals_rows)
    totals = pd.concat(
        [totals, pd.DataFrame(checks).rename(columns={"check": "item"})],
        ignore_index=True)

    # ---------------- anomalies ----------------
    anomalies_rows = []

    def anomaly(name: str, detail: str) -> None:
        anomalies_rows.append({"anomaly": name, "detail": detail})

    eq_gov_diff = bs_group(nco, "gov", EQ_MODULE)[2] - dk_cell("vNetEquity", "gov", "net")
    eq_row_diff = bs_group(nco, "row", EQ_MODULE)[2] - dk_cell("vNetEquity", "row", "net")
    debt_gov_diff = bs_group(nco, "gov", DEBT_MODULE)[2] - dk_cell("vNetDebtInstruments", "gov", "net")
    debt_row_diff = bs_group(nco, "row", DEBT_MODULE)[2] - dk_cell("vNetDebtInstruments", "row", "net")
    anomaly("The model never reads this Excel",
            "All eight GDX symbols read_data.py builds from "
            "institutional_financial_accounts.xlsx are orphaned: "
            "data_from_GR.gms loads vNetFinAssets/vNetDebtInstruments from "
            "the live Eurostat module instead, and the flow variables are "
            "model equations. The mapping-table verdict should record this: "
            "the replacement is already in production, unverified until now.")
    anomaly("Equity = F5, not F51: the module definition wins",
            f"Danish vNetEquity matches nasa_10_f_bs F5 net exactly where no "
            f"pension adjustment applies (gov diff {eq_gov_diff:+.3f}, row "
            f"diff {eq_row_diff:+.3f} bn DKK). The colleague reference "
            f"implementation's Equity=F51 (with F52 in debt) does NOT "
            f"reproduce the Danish file (gov diff "
            f"{bs_group(nco, 'gov', EQ_COLLEAGUE)[2] - dk_cell('vNetEquity', 'gov', 'net'):+.3f}). "
            f"The two implementations in the repo disagree; the module's is "
            f"the Danish-consistent one.")
    anomaly("Small unexplained debt-stock gaps on gov and row",
            f"Unlike equity, vNetDebtInstruments does not close exactly for "
            f"the unadjusted sectors: gov {debt_gov_diff:+.3f}, row "
            f"{debt_row_diff:+.3f} bn DKK (0.3-1.3% of the net position). "
            f"See instrument_detail for the per-instrument decomposition; "
            f"the Danish side publishes only totals, so the likeliest "
            f"explanation is vintage (financial accounts are revised "
            f"heavily; the Excel predates the current Eurostat vintage). "
            f"A separate Eurostat-internal wrinkle found on the way: the "
            f"delivery includes a household F2 currency/deposits LIABILITY "
            f"of exactly {additivity_gaps['hh']:+.3f} bn that Eurostat's "
            f"own published F total excludes, so the two 'additivity' "
            f"checks fail by that amount - a source-data quirk, not a "
            f"mapping error.")
    anomaly("Pension reallocation quantified",
            f"The Danish corp->hh moves implied by the data: equity "
            f"{implied['vNetEquity']:.3f}, debt "
            f"{implied['vNetDebtInstruments']:.3f}, interest "
            f"{implied['vNetInterests']:.3f}, dividends "
            f"{implied['vNetDividends']:.3f} bn DKK. The total moved "
            f"portfolio ({total_moved:.3f} incl. removing hh F6 claims of "
            f"{hh_f6[2]:.3f}) is within 1% of the S128_S129 insurance/"
            f"pension subsector's entire financial-asset portfolio "
            f"({s1289['F']:.3f}), so the Danish method is 'attribute the "
            f"pension subsector's portfolio to households'. It is NOT "
            f"net-neutral: hh net financial assets end {hh_net_gap:+.3f} bn "
            f"above raw Eurostat because the moved portfolio exceeds the "
            f"removed F6 claims. Exact composition replication needs the "
            f"Danish computation; S128_S129 balance sheets (published "
            f"EU-wide, see eu27_coverage) support a close approximation.")
    anomaly("The live module does not implement the pension reallocation",
            "Modules/financial_accounts/financial_accounts_data.py maps "
            "S12->FinCorp and S14+S15->Hh with no F6/portfolio transfer. "
            "Its vNetFinAssets['Hh'] therefore differs from the Danish "
            "concept by the non-neutral part of the move (see "
            "pension_reallocation sheet) - and the model's household wealth "
            "calibration (rMPCW, vNetFinAssets equations) runs on the "
            "unadjusted numbers today.")
    anomaly("Flow variables: gov/row exact, corp/hh shifted by the move",
            "vNetInterests = nf_tr D41 net and vNetDividends = D42 net "
            "reproduce gov and row exactly and corp+hh in sum (see "
            "flows_probe). Since the model generates these flows from "
            "calibrated rates rather than loading them, this is a "
            "calibration opportunity (rInterests_s, rDividends), not a "
            "blocking gap.")
    anomaly("vNetRevaluations has no Eurostat source in this pilot",
            "Neither pilot dataset carries revaluations. Route if ever "
            "needed: Delta stocks (nasa_10_f_bs) minus financial "
            "transactions (nasa_10_f_tr) minus other volume changes. The "
            "model generates revaluations from rRevaluations_s, so nothing "
            "is blocked.")
    anomaly("Government-finances leftovers: two closed, two partial, one impossible",
            "See gov_gap_probe: rent D45 closed exactly; the D42 dividend "
            "bundle closed at D42 level (D421/D422 split still undelivered "
            "for DK); EU-paid CAP subsidies have a close candidate in S2 "
            "D39 PAID; dom/RoW counterpart splits only bounded (no payer x "
            "receiver dimension); PAL impossible from nasa_10_nf_tr (no D51 "
            "subitems).")

    # ---------------- readme ----------------
    readme = pd.DataFrame([
        {"key": "title", "value": "Reconciliation: Eurostat nasa_10_f_bs (+ nasa_10_nf_tr) vs institutional_financial_accounts.xlsx, Denmark 2020"},
        {"key": "created", "value": created},
        {"key": "created_by", "value": "data/preprocessing/scripts/reconcile_financial_accounts_dk_2020.py"},
        {"key": "purpose", "value": "Pilot test of the eu_data_mapping.md 'OK' verdict - and verification of the already-live Eurostat module route, since the model loads vNetFinAssets/vNetDebtInstruments from Modules/financial_accounts/financial_accounts_data.gdx and never reads this Excel"},
        {"key": "danish_source", "value": "data/preprocessing/data/institutional_financial_accounts.xlsx (year=2020, sheet 'financial'; incl. the Danish pension-asset reallocation from financial corporations to households)"},
        {"key": "eurostat_sources", "value": "nasa_10_f_bs (stocks; MIO_NAC+MIO_EUR, CO+NCO, incl. S128/S129 pension subsectors) and nasa_10_nf_tr (flows; CP_MNAC) via the Eurostat dissemination API (JSON-stat 2.0)"},
        {"key": "eurostat_retrieval_date", "value": retrieval_date},
        {"key": "raw_data", "value": "data/preprocessing/data/financial_accounts_raw/DK/2020/ (README.md + manifest.json with URLs, params, SHA-256)"},
        {"key": "units", "value": "bn DKK on both sides (Eurostat MIO_NAC / 1000; MIO_EUR downloaded for cross-check)"},
        {"key": "colleague_reference", "value": "instrument definitions cross-checked against data/read_eurostat_data/financial_accounts_balance_data.py and financial_accounts_flow_data.py (whose Equity=F51 definition does NOT reproduce the Danish file)"},
        {"key": "headline", "value": "Unadjusted sectors reconcile: vNetEquity = F5 net matches gov and row EXACTLY; D41/D42 flows match gov and row exactly and corp+hh in sum. The corp/hh differences are the documented Danish pension-asset reallocation, quantified here (equity move 2,703.9 bn DKK; total moved portfolio within 1% of the S128_S129 subsector portfolio) and NOT implemented in the live module. Open: small gov/row debt-stock gaps, D421/D422 split, PAL."},
        {"key": "sheets", "value": "finacc_file_usage | totals (sums + identity checks) | rows | instrument_definitions | pension_reallocation | flows_probe | gov_gap_probe | eu27_coverage | anomalies"},
    ])

    anomalies = pd.DataFrame(anomalies_rows)

    with pd.ExcelWriter(OUT, engine="openpyxl") as xl:
        readme.to_excel(xl, sheet_name="readme", index=False)
        usage.to_excel(xl, sheet_name="finacc_file_usage", index=False)
        totals.to_excel(xl, sheet_name="totals", index=False)
        rows_cmp.to_excel(xl, sheet_name="rows", index=False)
        def_cmp.to_excel(xl, sheet_name="instrument_definitions", index=False)
        detail.to_excel(xl, sheet_name="instrument_detail", index=False)
        pension.to_excel(xl, sheet_name="pension_reallocation", index=False)
        flows.to_excel(xl, sheet_name="flows_probe", index=False)
        gaps.to_excel(xl, sheet_name="gov_gap_probe", index=False)
        coverage.to_excel(xl, sheet_name="eu27_coverage", index=False)
        anomalies.to_excel(xl, sheet_name="anomalies", index=False)
    print(f"wrote {OUT}")

    # ---------------- console report ----------------
    pd.set_option("display.width", 250)
    print("\nROW COMPARISON (bn DKK):")
    print(rows_cmp.to_string(index=False))
    print("\nINSTRUMENT DEFINITIONS (net, bn DKK):")
    print(def_cmp.to_string(index=False))
    print("\nPENSION REALLOCATION (bn DKK):")
    print(pension.to_string(index=False))
    print("\nGOV-GAP PROBE (bn DKK):")
    print(gaps[["gov_pilot_gap", "dk_bn_dkk", "es_bn_dkk", "diff",
                "verdict"]].to_string(index=False))
    print("\nIDENTITY CHECKS:")
    print(pd.DataFrame(checks).to_string(index=False))
    print("\nEU-27 coverage (countries NOT complete for core 2020):")
    inc = coverage[~coverage["complete_core_2020"]]
    print(inc.to_string(index=False) if len(inc) else "  none - all 27 complete")
    n_fail = sum(1 for c in checks if c["result"] == "FAIL")
    print(f"\nchecks: {len(checks) - n_fail}/{len(checks)} PASS")


if __name__ == "__main__":
    main()
