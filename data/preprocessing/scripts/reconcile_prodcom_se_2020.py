"""Reconcile Eurostat PRODCOM division 16 (Sweden 2020) against the GREU
public-core CPA_C16 monetary residual.

Question: what share of Sweden's CPA_C16 production/export value is
energy-relevant wood products (chips/particles, pellets/briquettes) vs
non-energy wood products (sawnwood, boards, joinery, packaging, ...)?
The Sweden public-core package retains 42.763 bn SEK of unmatched CPA_C16
SUT money (chiefly the 40.665 bn SEK export control) as an explicit
residual; PRODCOM product detail is piloted here as a possible EU-wide
splitting key.

Inputs (all pre-existing, read-only):
- data/preprocessing/data/prodcom_raw/SE/2020/  (raw PRODCOM deliveries,
  see download_prodcom_se_2020.py)
- data/preprocessing/data/eu_core_raw/SE/2020/ert_bil_eur_a_SEK_2020.csv
  (2020 average SEK/EUR rate)
- data/preprocessing/data/energy_money_se2020_public_core_reconciliation.xlsx
  (SUT CPA_C16 controls: valuation_controls, user_controls)
- data/preprocessing/data/eu_core/SE/energy_and_emissions.xlsx
  (the explicit monetary_residual_CPA_C16 rows)

Output:
- data/preprocessing/data/prodcom_se2020_c16_reconciliation.xlsx

Run:  python data/preprocessing/scripts/reconcile_prodcom_se_2020.py
"""

from __future__ import annotations

import html
import json
from pathlib import Path
import re

import pandas as pd

DATA = Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "prodcom_raw" / "SE" / "2020"
ERT_CSV = DATA / "eu_core_raw" / "SE" / "2020" / "ert_bil_eur_a_SEK_2020.csv"
SE_AUDIT = DATA / "energy_money_se2020_public_core_reconciliation.xlsx"
SE_ENERGY = DATA / "eu_core" / "SE" / "energy_and_emissions.xlsx"
OUT = DATA / "prodcom_se2020_c16_reconciliation.xlsx"
CREATION_DATE = "2026-07-31"

# Energy-relevant PRODCOM codes under NACE division 16. Both list vintages of
# "wood in chips or particles" are included; Sweden 2020 reports under
# 16102503/16102505. Chips are an UPPER bound for energy relevance: they are
# also the main feedstock of the pulp and particleboard industries.
ENERGY_CODES = {
    "16102303": "Coniferous wood in chips or particles (list vintage A)",
    "16102305": "Non-coniferous wood in chips or particles (list vintage A)",
    "16102503": "Coniferous wood in chips or particles (list vintage B)",
    "16102505": "Non-coniferous wood in chips or particles (list vintage B)",
    "16291500": "Pellets and briquettes of pressed/agglomerated wood and vegetable waste",
}
# Fuel wood proper (logs/faggots, CPA 02.20.14) is FORESTRY output, outside
# PRODCOM's manufacturing scope, and therefore cannot appear in division 16.

EU27 = [
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE",
    "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT",
    "RO", "SK", "SI", "ES", "SE",
]  # Comext uses GR, not EL

SUPPRESSED_FLAGS = {":C", ":U"}


def load_rate() -> float:
    ert = pd.read_csv(ERT_CSV)
    rate = float(ert.loc[0, "OBS_VALUE"])
    assert 8 < rate < 13, f"implausible SEK/EUR rate {rate}"
    return rate


def load_labels() -> dict[str, str]:
    text = (RAW / "cxt_prodcom2_sold_codelist.xml").read_text(encoding="utf-8")
    labels: dict[str, str] = {}
    for m in re.finditer(
        r'<s:Code[^>]*\bid="(\d{8})"[^>]*>(.*?)</s:Code>', text, re.S
    ):
        name = re.search(r'<c:Name xml:lang="en">(.*?)</c:Name>', m.group(2))
        if name:
            labels[m.group(1)] = html.unescape(name.group(1))
    return labels


def eur_to_bn_sek(eur: float | None, rate: float) -> float | None:
    return None if eur is None or pd.isna(eur) else eur * rate / 1e9


def build_code_detail(rate: float) -> pd.DataFrame:
    raw = pd.read_csv(RAW / "ds-059358_SE_2020_all_products.csv", dtype=str)
    d16 = raw[raw["product"].str.startswith("16")].copy()
    wide = d16.pivot_table(
        index="product", columns="indicators", values="OBS_VALUE",
        aggfunc="first",
    ).reset_index()
    labels = load_labels()

    for col in ["PRODVAL", "EXPVAL", "IMPVAL", "PRODQNT", "EXPQNT", "IMPQNT"]:
        if col not in wide.columns:
            wide[col] = pd.NA
        wide[col] = pd.to_numeric(wide[col], errors="coerce")
    for col in ["PVALFLAG", "PQNTFLAG", "QNTUNIT"]:
        if col not in wide.columns:
            wide[col] = pd.NA

    def prod_status(row) -> str:
        flag = row["PVALFLAG"]
        if pd.notna(row["PRODVAL"]):
            return "observed"
        if isinstance(flag, str) and flag in SUPPRESSED_FLAGS:
            return f"suppressed ({flag})"
        if isinstance(flag, str):
            return f"flagged ({flag})"
        return "no production row"

    wide["group"] = wide["product"].map(
        lambda c: "energy-relevant" if c in ENERGY_CODES else "non-energy"
    )
    wide["label"] = wide["product"].map(labels).fillna("(label not in codelist)")
    wide["prodval_status"] = wide.apply(prod_status, axis=1)
    wide["prodval_bn_sek"] = wide["PRODVAL"].map(lambda v: eur_to_bn_sek(v, rate))
    wide["expval_bn_sek"] = wide["EXPVAL"].map(lambda v: eur_to_bn_sek(v, rate))
    wide["impval_bn_sek"] = wide["IMPVAL"].map(lambda v: eur_to_bn_sek(v, rate))

    cols = [
        "product", "label", "group", "prodval_status",
        "PRODVAL", "prodval_bn_sek", "EXPVAL", "expval_bn_sek",
        "IMPVAL", "impval_bn_sek", "PRODQNT", "EXPQNT", "IMPQNT",
        "QNTUNIT", "PVALFLAG", "PQNTFLAG",
    ]
    detail = wide[cols].sort_values("product").reset_index(drop=True)
    return detail


def build_summary(detail: pd.DataFrame, rate: float) -> pd.DataFrame:
    rows = []
    for group, sub in detail.groupby("group"):
        rows.append({
            "group": group,
            "codes_with_data": len(sub),
            "codes_prodval_observed": int(sub["PRODVAL"].notna().sum()),
            "codes_prodval_suppressed": int(
                sub["prodval_status"].str.startswith("suppressed").sum()
            ),
            "prodval_eur": sub["PRODVAL"].sum(),
            "prodval_bn_sek": eur_to_bn_sek(sub["PRODVAL"].sum(), rate),
            "expval_eur": sub["EXPVAL"].sum(),
            "expval_bn_sek": eur_to_bn_sek(sub["EXPVAL"].sum(), rate),
            "impval_eur": sub["IMPVAL"].sum(),
            "impval_bn_sek": eur_to_bn_sek(sub["IMPVAL"].sum(), rate),
        })
    total = {
        "group": "TOTAL division 16",
        "codes_with_data": len(detail),
        "codes_prodval_observed": int(detail["PRODVAL"].notna().sum()),
        "codes_prodval_suppressed": int(
            detail["prodval_status"].str.startswith("suppressed").sum()
        ),
        "prodval_eur": detail["PRODVAL"].sum(),
        "prodval_bn_sek": eur_to_bn_sek(detail["PRODVAL"].sum(), rate),
        "expval_eur": detail["EXPVAL"].sum(),
        "expval_bn_sek": eur_to_bn_sek(detail["EXPVAL"].sum(), rate),
        "impval_eur": detail["IMPVAL"].sum(),
        "impval_bn_sek": eur_to_bn_sek(detail["IMPVAL"].sum(), rate),
    }
    summary = pd.DataFrame(rows + [total])
    ener = summary.loc[summary["group"] == "energy-relevant"].iloc[0]
    summary["share_of_div16_prodval"] = (
        summary["prodval_eur"] / total["prodval_eur"]
    )
    summary["share_of_div16_expval"] = (
        summary["expval_eur"] / total["expval_eur"]
    )
    assert ener["expval_eur"] > 0, "no energy-relevant export value found"
    return summary


def load_sut_controls() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    valuation = pd.read_excel(SE_AUDIT, sheet_name="valuation_controls")
    valuation = valuation[valuation["cpa"] == "CPA_C16"]
    users = pd.read_excel(SE_AUDIT, sheet_name="user_controls")
    users = users[users["cpa"] == "CPA_C16"]
    energy = pd.read_excel(SE_ENERGY, sheet_name="ems_energy")
    residual = energy[
        (energy["product"] == "monetary_residual_CPA_C16")
        & (energy["bal"] == "use")
    ][["year", "bal", "flow", "indu", "basic", "ws_marg", "ener_tax",
       "vat", "purch"]]
    return valuation, users, residual


def build_sut_comparison(
    detail: pd.DataFrame,
    summary: pd.DataFrame,
    valuation: pd.DataFrame,
    users: pd.DataFrame,
    residual: pd.DataFrame,
    rate: float,
) -> pd.DataFrame:
    total = summary.loc[summary["group"] == "TOTAL division 16"].iloc[0]
    ener = summary.loc[summary["group"] == "energy-relevant"].iloc[0]

    sut_output_basic = float(valuation["TOTAL"].iloc[0])       # domestic output
    sut_supply_basic = float(valuation["TS_BP"].iloc[0])
    sut_supply_purch = float(valuation["TS_PP"].iloc[0])
    sut_imports = float(valuation["P7"].iloc[0])
    export_control = float(
        users.loc[users["user_block"] == "export", "purch_control"].iloc[0]
    )
    residual_total = float(residual["purch"].sum())
    residual_export = float(
        residual.loc[residual["flow"] == "export", "purch"].sum()
    )

    energy_share_exp = float(ener["expval_eur"] / total["expval_eur"])
    energy_share_prod = float(ener["prodval_eur"] / total["prodval_eur"])
    energy_exp_bn_sek = float(ener["expval_bn_sek"])

    rows = [
        ("SUT CPA_C16 domestic output, basic prices (naio_10_cp15 TOTAL)",
         sut_output_basic,
         "bn SEK", "Sweden public-core valuation_controls"),
        ("SUT CPA_C16 total supply, basic prices (TS_BP)",
         sut_supply_basic, "bn SEK", "= output + imports"),
        ("SUT CPA_C16 imports (P7)", sut_imports, "bn SEK", ""),
        ("SUT CPA_C16 total supply, purchaser prices (TS_PP)",
         sut_supply_purch, "bn SEK", ""),
        ("PRODCOM division 16 sold production (observed codes)",
         float(total["prodval_bn_sek"]), "bn SEK",
         "PRODVAL is ex-works ~ basic prices; excludes suppressed codes, "
         "micro-enterprises below PRODCOM thresholds and non-PRODCOM "
         "activity (services, secondary output)"),
        ("PRODCOM / SUT domestic-output ratio",
         float(total["prodval_bn_sek"]) / sut_output_basic, "ratio",
         "sanity check: same order of magnitude expected"),
        ("SUT CPA_C16 export control (naio_10_cp16 P6, purchaser)",
         export_control, "bn SEK",
         "entirely retained as monetary residual in the Sweden package"),
        ("PRODCOM division 16 exports (EXPVAL, FOB)",
         float(total["expval_bn_sek"]), "bn SEK",
         "trade statistics via PRODCOM; no confidentiality suppression "
         "observed on EXPVAL"),
        ("PRODCOM / SUT export ratio",
         float(total["expval_bn_sek"]) / export_control, "ratio",
         "sanity check"),
        ("Explicit monetary_residual_CPA_C16, use side (total)",
         residual_total, "bn SEK",
         "export + other_final_use + 2 industry rows - inventory"),
        ("  of which export row", residual_export, "bn SEK", ""),
        ("Energy-relevant share of division-16 exports (PRODCOM)",
         energy_share_exp, "share",
         "chips (both vintages) + pellets/briquettes; chips are an upper "
         "bound (also pulp/board feedstock)"),
        ("Energy-relevant share of division-16 sold production (PRODCOM)",
         energy_share_prod, "share",
         "UNDERSTATED: pellet production value is suppressed (:U)"),
        ("Energy-relevant exports, absolute", energy_exp_bn_sek, "bn SEK",
         "directly comparable to the export residual"),
        ("Plausibly energy-relevant part of the 40.665 bn SEK export "
         "residual", energy_share_exp * residual_export, "bn SEK",
         "= PRODCOM energy export share x export residual"),
        ("Plausibly energy-relevant part of the 42.763 bn SEK total "
         "residual (export-share basis)",
         energy_share_exp * residual_export
         + energy_share_prod * (residual_total - residual_export),
         "bn SEK",
         "export piece via export share; non-export pieces via production "
         "share (lower bound, pellets suppressed)"),
    ]
    return pd.DataFrame(rows, columns=["item", "value", "unit", "note"])


def build_eu_coverage() -> pd.DataFrame:
    probe = pd.read_csv(
        RAW / "ds-059358_eu_coverage_probe_2020.csv", dtype=str
    )
    rows = []
    for geo in EU27:
        sub = probe[probe["reporter"] == geo]
        for product in ["16291500", "16101033"]:
            psub = sub[sub["product"] == product].set_index("indicators")[
                "OBS_VALUE"
            ]
            prodval = psub.get("PRODVAL")
            flag = psub.get("PVALFLAG")
            if prodval is not None:
                status = "observed"
            elif isinstance(flag, str) and flag in SUPPRESSED_FLAGS:
                status = f"suppressed ({flag})"
            elif len(psub):
                status = "trade only / flagged"
            else:
                status = "no rows"
            rows.append({
                "reporter": geo,
                "product": product,
                "rows_2020": len(psub),
                "prodval_status": status,
                "prodval_eur": prodval,
                "expval_eur": psub.get("EXPVAL"),
            })
    return pd.DataFrame(rows)


def build_anomalies(detail: pd.DataFrame, rate: float) -> pd.DataFrame:
    items: list[dict] = []

    suppressed = detail[detail["prodval_status"].str.startswith("suppressed")]
    for _, r in suppressed.iterrows():
        items.append({
            "severity": "WARN",
            "item": f"PRODVAL suppressed for {r['product']} ({r['group']})",
            "detail": (
                f"flag {r['PVALFLAG']}; label: {r['label'][:80]}. Suppressed "
                "value is NOT zero. Exports/imports remain observed: "
                f"EXPVAL {r['EXPVAL']}, IMPVAL {r['IMPVAL']} EUR."
            ),
        })

    if "16291500" in suppressed["product"].values:
        items.append({
            "severity": "WARN",
            "item": "Pellet production value (16291500) is suppressed (:U)",
            "detail": (
                "Sweden's sold-production value AND quantity for wood "
                "pellets/briquettes are low-reliability-suppressed for 2020. "
                "The energy-relevant share of PRODUCTION is therefore a "
                "lower bound (chips only). Export/import values for pellets "
                "are observed, so the EXPORT split is unaffected."
            ),
        })

    items.append({
        "severity": "INFO",
        "item": "Chips/particles are an upper bound for energy relevance",
        "detail": (
            "16102503/16102505 (and vintage codes 16102303/16102305) cover "
            "all wood chips/particles. In Sweden a large share feeds the "
            "pulp and particleboard industries, not energy conversion. "
            "Treating all chips as energy-relevant OVERSTATES the energy "
            "share; even so the share stays small."
        ),
    })
    items.append({
        "severity": "INFO",
        "item": "Fuel wood is outside PRODCOM division 16",
        "detail": (
            "Fuel wood in logs/faggots is CPA 02.20.14 (forestry), outside "
            "PRODCOM manufacturing scope. The GREU concordance maps PEFA P23 "
            "'wood and wood waste' to CPA_C16, so any fuel-wood money in the "
            "SUT sits under CPA_A02, not the CPA_C16 controls examined here."
        ),
    })
    items.append({
        "severity": "INFO",
        "item": "Valuation bases differ",
        "detail": (
            "PRODVAL is ex-works (~basic prices); EXPVAL is FOB; the SUT "
            "export control is at purchaser prices. Shares, not levels, are "
            "the deliverable; level ratios are sanity checks only."
        ),
    })
    items.append({
        "severity": "INFO",
        "item": "PRODCOM scope vs SUT scope",
        "detail": (
            "PRODCOM covers industrial sold production (enterprises above "
            "national thresholds); the SUT output control also contains "
            "small producers, secondary output of other industries, and "
            "services. PRODCOM division-16 sold production is expected to "
            "sit below the SUT domestic output control."
        ),
    })

    # vintage duplicate check: same label, multiple codes with nonzero PRODVAL
    nz = detail[detail["PRODVAL"].fillna(0) > 0]
    dup = nz[nz.duplicated("label", keep=False)].sort_values("label")
    for label, grp in dup.groupby("label"):
        items.append({
            "severity": "WARN",
            "item": "Possible list-vintage double counting",
            "detail": (
                f"codes {', '.join(grp['product'])} share label "
                f"'{label[:70]}' and all report nonzero PRODVAL; totals sum "
                "them all."
            ),
        })

    zero_prod_pos_exp = detail[
        (detail["PRODVAL"].fillna(-1) == 0) & (detail["EXPVAL"].fillna(0) > 0)
    ]
    if len(zero_prod_pos_exp):
        items.append({
            "severity": "INFO",
            "item": (
                f"{len(zero_prod_pos_exp)} codes report zero production but "
                "positive exports"
            ),
            "detail": (
                ", ".join(zero_prod_pos_exp["product"]) + ". Mostly legacy "
                "list-vintage codes whose trade mapping still delivers "
                "values (re-exports or vintage overlap); production is "
                "reported under the current-vintage code."
            ),
        })
    return pd.DataFrame(items)


def build_readme(rate: float) -> pd.DataFrame:
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    rows = [
        ("purpose",
         "Pilot: can Eurostat PRODCOM split Sweden's CPA_C16 SUT "
         "production/export money into energy-relevant vs non-energy wood "
         "products? Feasibility only; no GREU input file is modified."),
        ("creation_date", CREATION_DATE),
        ("created_by",
         "data/preprocessing/scripts/reconcile_prodcom_se_2020.py"),
        ("downloader",
         "data/preprocessing/scripts/download_prodcom_se_2020.py"),
        ("raw_data_dir", "data/preprocessing/data/prodcom_raw/SE/2020"),
        ("retrieval_date", manifest["retrieval_date"]),
        ("dataset",
         "ESTAT DS-059358 'Sold production, exports and imports' (PRODCOM "
         "list, CPA 2.1 vintage), Eurostat Comext dissemination API"),
        ("endpoint_finding", manifest["endpoint_finding"]),
        ("licence", manifest["licence"]),
        ("sek_per_eur_2020",
         f"{rate} (ert_bil_eur_a, 2020 annual average, from "
         "eu_core_raw/SE/2020/ert_bil_eur_a_SEK_2020.csv)"),
        ("sut_controls_source",
         "energy_money_se2020_public_core_reconciliation.xlsx "
         "(valuation_controls, user_controls) and "
         "eu_core/SE/energy_and_emissions.xlsx (monetary_residual_CPA_C16)"),
        ("energy_code_definition",
         "; ".join(f"{c}: {n}" for c, n in ENERGY_CODES.items())),
        ("confidentiality_rule",
         "Suppressed cells (:C confidential, :U low-reliability) are "
         "reported as suppressed, never as zero; totals over observed codes "
         "only, with suppression counts alongside."),
    ]
    for name, meta in manifest["files"].items():
        rows.append((f"source_url [{name}]", meta["url"]))
    return pd.DataFrame(rows, columns=["key", "value"])


def main() -> None:
    rate = load_rate()
    detail = build_code_detail(rate)
    summary = build_summary(detail, rate)
    valuation, users, residual = load_sut_controls()
    sut = build_sut_comparison(detail, summary, valuation, users, residual,
                               rate)
    coverage = build_eu_coverage()
    anomalies = build_anomalies(detail, rate)
    readme = build_readme(rate)

    with pd.ExcelWriter(OUT, engine="openpyxl") as writer:
        readme.to_excel(writer, sheet_name="README", index=False)
        detail.to_excel(writer, sheet_name="code_detail", index=False)
        summary.to_excel(writer, sheet_name="energy_split_summary",
                         index=False)
        sut.to_excel(writer, sheet_name="sut_comparison", index=False)
        residual.to_excel(writer, sheet_name="c16_residual_rows", index=False)
        coverage.to_excel(writer, sheet_name="eu27_coverage", index=False)
        anomalies.to_excel(writer, sheet_name="anomalies_caveats",
                           index=False)

    print(f"written {OUT}")
    print("\n=== energy_split_summary ===")
    print(summary.to_string(index=False))
    print("\n=== sut_comparison ===")
    print(sut.to_string(index=False))
    print("\n=== EU-27 coverage (16291500 pellets) ===")
    pel = coverage[coverage["product"] == "16291500"]
    print(pel["prodval_status"].value_counts().to_string())
    missing = pel[pel["rows_2020"] == 0]["reporter"].tolist()
    print("reporters with no rows at all:", missing or "none")
    print(f"\n{len(anomalies)} anomaly/caveat items")


if __name__ == "__main__":
    main()
