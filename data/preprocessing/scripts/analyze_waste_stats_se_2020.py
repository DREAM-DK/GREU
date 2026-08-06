"""Analyze EU-wide statistics on NACE E37-E39 output composition, SE 2020.

Feasibility question: can public EU-wide data characterize how much of the
Sweden 2020 public-core CPA_E37-E39 supply-side monetary control
(60.156 bn SEK, the largest item of the 102.567 bn SEK supply-side
unmatched residual) is plausibly energy-relevant?

    python data/preprocessing/scripts/analyze_waste_stats_se_2020.py

Inputs (never modified):
- data/preprocessing/data/waste_stats_raw/SE/2020/  (raw JSON-stat, see
  download_waste_stats_se_2020.py)
- data/preprocessing/data/eu_core_raw/SE/2020/naio_10_cp15_SE_2020.json
  (to re-derive the 60.156 bn SEK control from source)
- data/preprocessing/data/eu_core_raw/SE/2020/ert_bil_eur_a_SEK_2020.csv
  (2020 average EUR->SEK rate)
- data/preprocessing/data/eu_core/SE/energy_money_manifest.json
  (package residual figures for comparison)

Output (new file):
- data/preprocessing/data/waste_stats_se2020_e37e39_feasibility.xlsx
"""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pandas as pd


DATA = Path(__file__).resolve().parents[1] / "data"
RAW = DATA / "waste_stats_raw" / "SE" / "2020"
CORE_RAW = DATA / "eu_core_raw" / "SE" / "2020"
PACKAGE_MANIFEST = DATA / "eu_core" / "SE" / "energy_money_manifest.json"
OUT = DATA / "waste_stats_se2020_e37e39_feasibility.xlsx"

# Documented in docs/eu_data_mapping.md (Sweden section, 2026-07-31): the
# use-side CPA_E37-E39 unmatched residual. Not stored in the package
# manifest per CPA, hence cited as a reference constant.
USE_SIDE_E37E39_RESIDUAL_BN_SEK = 54.357

# Generous upper-bound market price for waste-derived fuel, SEK/GJ. Actual
# Swedish waste fuel typically trades at zero or NEGATIVE prices (energy
# plants charge gate fees for accepting waste), so this deliberately
# overstates the value of waste fuel possibly sold by E38 units.
WASTE_FUEL_UPPER_PRICE_SEK_PER_GJ = 20.0


def jsonstat_to_df(path: Path) -> pd.DataFrame:
    payload = json.loads(path.read_text(encoding="utf-8"))
    dims = payload["id"]
    sizes = payload["size"]
    names = {
        d: sorted(
            payload["dimension"][d]["category"]["index"],
            key=lambda c, d=d: payload["dimension"][d]["category"]["index"][c],
        )
        for d in dims
    }
    labels = {
        d: payload["dimension"][d]["category"].get("label", {}) for d in dims
    }
    rows = []
    for key, value in payload["value"].items():
        k = int(key)
        pos = []
        for s in reversed(sizes):
            pos.append(k % s)
            k //= s
        pos.reverse()
        rows.append(
            {d: names[d][pos[i]] for i, d in enumerate(dims)} | {"value": value}
        )
    df = pd.DataFrame(rows)
    df.attrs["labels"] = labels
    return df


def eur_sek_rate() -> float:
    fx = pd.read_csv(CORE_RAW / "ert_bil_eur_a_SEK_2020.csv")
    assert (fx["currency"] == "SEK").all() and (
        fx["TIME_PERIOD"] == 2020
    ).all()
    return float(fx["OBS_VALUE"].iloc[0])


def control_from_cp15() -> tuple[float, float]:
    """Re-derive the E37-39 diagonal control and total CPA supply, bn SEK."""
    df = jsonstat_to_df(CORE_RAW / "naio_10_cp15_SE_2020.json")
    nac = df[df["unit"] == "MIO_NAC"]
    diag = nac[
        (nac["ind_impv"] == "E37-39") & (nac["prd_amo"] == "CPA_E37-39")
    ]["value"]
    total = nac[
        (nac["ind_impv"] == "TOTAL") & (nac["prd_amo"] == "CPA_E37-39")
    ]["value"]
    return float(diag.iloc[0]) / 1000.0, float(total.iloc[0]) / 1000.0


def sbs_sheet(fx: float) -> tuple[pd.DataFrame, dict[str, float]]:
    df = jsonstat_to_df(RAW / "sbs_na_ind_r2_SE_2020.json")
    labels = df.attrs["labels"]["nace_r2"]
    wide = (
        df.pivot_table(
            index="nace_r2", columns="indic_sb", values="value",
            aggfunc="first",
        )
        .reindex(
            [
                "E", "E36", "E37", "E38", "E381", "E3811", "E3812",
                "E382", "E3821", "E3822", "E383", "E3831", "E3832", "E39",
            ]
        )
    )
    wide.insert(0, "nace_label", [labels.get(c, "") for c in wide.index])
    wide["production_bn_SEK"] = wide["V12120"] * fx / 1000.0
    wide["turnover_bn_SEK"] = wide["V12110"] * fx / 1000.0
    e_total = float(
        wide.loc[["E37", "E38", "E39"], "V12120"].sum()
    )
    wide["share_of_E37_E39_production_pct"] = (
        wide["V12120"] / e_total * 100.0
    ).where(wide.index.isin(
        ["E37", "E38", "E381", "E3811", "E3812", "E382", "E3821", "E3822",
         "E383", "E3831", "E3832", "E39"]
    ))
    key = {
        "sbs_E37_E39_production_MEUR": e_total,
        "sbs_E37_E39_production_bn_SEK": e_total * fx / 1000.0,
        "sbs_E382_production_bn_SEK": float(
            wide.loc["E382", "V12120"] * fx / 1000.0
        ),
        "sbs_E383_production_bn_SEK": float(
            wide.loc["E383", "V12120"] * fx / 1000.0
        ),
    }
    return wide.reset_index(), key


def wastrt_sheet() -> tuple[pd.DataFrame, dict[str, float]]:
    trt = jsonstat_to_df(RAW / "env_wastrt_SE_2020.json")
    labels = trt.attrs["labels"]["wst_oper"]
    wide = trt.pivot_table(
        index="wst_oper", columns="waste", values="value", aggfunc="first"
    ).reindex(
        ["TRT", "DSP_L_OTH", "DSP_L", "DSP_I", "DSP_OTH",
         "RCV_E", "RCV_R_B", "RCV_R", "RCV_B"]
    )
    wide.insert(0, "operation_label", [labels.get(c, "") for c in wide.index])
    for col in ("TOTAL", "TOT_X_MIN"):
        wide[f"share_of_treated_{col}_pct"] = (
            wide[col] / wide.loc["TRT", col] * 100.0
        )
    gen = jsonstat_to_df(RAW / "env_wasgen_SE_2020.json")
    gen_tot = gen[gen["nace_r2"] == "TOT_NACE_HH"] if (
        "TOT_NACE_HH" in set(gen["nace_r2"])
    ) else gen[gen["nace_r2"] == "TOTAL_HH"]
    key = {
        "waste_treated_total_kt": float(wide.loc["TRT", "TOTAL"]) / 1000.0,
        "waste_treated_x_mineral_kt": float(
            wide.loc["TRT", "TOT_X_MIN"]
        ) / 1000.0,
        "energy_recovery_R1_kt": float(wide.loc["RCV_E", "TOT_X_MIN"]) / 1000.0,
        "energy_recovery_share_total_pct": float(
            wide.loc["RCV_E", "TOTAL"] / wide.loc["TRT", "TOTAL"] * 100.0
        ),
        "energy_recovery_share_x_mineral_pct": float(
            wide.loc["RCV_E", "TOT_X_MIN"]
            / wide.loc["TRT", "TOT_X_MIN"] * 100.0
        ),
        "waste_generated_total_kt": (
            float(gen_tot[gen_tot["waste"] == "TOTAL"]["value"].iloc[0])
            / 1000.0
            if len(gen_tot) else float("nan")
        ),
    }
    return wide.reset_index(), key


def epea_sheet() -> tuple[pd.DataFrame, dict[str, float]]:
    frames = []
    for code, sector in [
        ("env_ac_pepsgg1", "general government + NPISH"),
        ("env_ac_pepssp1", "specialist producers (corporations)"),
    ]:
        df = jsonstat_to_df(RAW / f"{code}_SE_2020.json")
        labels = df.attrs["labels"]["env_econ"]
        df = df[df["unit"] == "MIO_NAC"].copy()
        df["dataset"] = code
        df["sector"] = sector
        df["env_econ_label"] = df["env_econ"].map(labels)
        frames.append(df)
    both = pd.concat(frames, ignore_index=True)
    both = both[both["ceparema"].isin(["TOT_CEPA", "CEPA2", "CEPA3"])]
    both = both[
        ["dataset", "sector", "ceparema", "env_econ", "env_econ_label",
         "value"]
    ].rename(columns={"value": "MIO_SEK"})
    both["bn_SEK"] = both["MIO_SEK"] / 1000.0

    def val(ds: str, cepa: str, item: str) -> float:
        sel = both[
            (both["dataset"] == ds)
            & (both["ceparema"] == cepa)
            & (both["env_econ"] == item)
        ]["bn_SEK"]
        return float(sel.iloc[0]) if len(sel) else float("nan")

    key = {
        "epea_gov_CEPA3_output_bn_SEK": val("env_ac_pepsgg1", "CEPA3",
                                            "EPS_P1"),
        "epea_gov_CEPA3_nonmarket_bn_SEK": val("env_ac_pepsgg1", "CEPA3",
                                               "EPS_P13"),
        "epea_sp_CEPA3_market_output_bn_SEK": val("env_ac_pepssp1", "CEPA3",
                                                  "EPS_P11"),
        "epea_sp_CEPA3_secondary_activity_bn_SEK": val(
            "env_ac_pepssp1", "CEPA3", "EPS_P11_SA"
        ),
        "epea_gov_CEPA2_output_bn_SEK": val("env_ac_pepsgg1", "CEPA2",
                                            "EPS_P1"),
        "epea_sp_CEPA2_market_output_bn_SEK": val("env_ac_pepssp1", "CEPA2",
                                                  "EPS_P11"),
    }
    key["epea_CEPA2_CEPA3_all_sectors_bn_SEK"] = (
        key["epea_gov_CEPA3_output_bn_SEK"]
        + key["epea_sp_CEPA3_market_output_bn_SEK"]
        + key["epea_gov_CEPA2_output_bn_SEK"]
        + key["epea_sp_CEPA2_market_output_bn_SEK"]
    )
    # Sweden reports no EPS_REC_BYPR (by-product revenue) anywhere.
    key["epea_by_product_revenue_reported"] = float(
        (both["env_econ"] == "EPS_REC_BYPR").sum()
    )
    return both, key


def egss_sheet() -> tuple[pd.DataFrame, dict[str, float]]:
    df = jsonstat_to_df(RAW / "env_ac_egss2_SE_2020.json")
    labels = df.attrs["labels"]["ceparema"]
    e = df[
        (df["nace_r2"] == "E") & (df["unit"] == "MIO_NAC")
        & (df["na_item"].isin(["P1", "B1G", "P6"]))
        & (df["ty"].isin(["TOT_EGSS", "MKT"]))
    ].copy()
    e["ceparema_label"] = e["ceparema"].map(labels)
    wide = e.pivot_table(
        index=["ceparema", "ceparema_label"], columns=["na_item", "ty"],
        values="value", aggfunc="first",
    )
    wide.columns = [f"{a}_{b}_MIO_SEK" for a, b in wide.columns]
    order = ["TOTAL", "TOT_CEPA", "CEPA2", "CEPA3", "TOT_CREMA",
             "CREMA13", "CREMA13A", "CREMA14"]
    wide = wide.reset_index()
    wide["order"] = wide["ceparema"].map(
        {c: i for i, c in enumerate(order)}
    )
    wide = (
        wide.sort_values("order", na_position="last")
        .drop(columns="order")
    )

    def p1(cepa: str, ty: str = "MKT") -> float:
        col = f"P1_{ty}_MIO_SEK"
        sel = wide[wide["ceparema"] == cepa][col]
        return float(sel.iloc[0]) / 1000.0 if len(sel) else float("nan")

    key = {
        "egss_E_total_output_bn_SEK": p1("TOTAL", "TOT_EGSS"),
        "egss_E_CEPA2_wastewater_bn_SEK": p1("CEPA2"),
        "egss_E_CEPA3_waste_bn_SEK": p1("CEPA3"),
        "egss_E_CREMA14_materials_bn_SEK": p1("CREMA14", "TOT_EGSS"),
        "egss_E_CREMA13A_renewable_energy_bn_SEK": p1("CREMA13A",
                                                      "TOT_EGSS"),
    }
    return wide, key


def nrg_sheet(fx: float) -> tuple[pd.DataFrame, dict[str, float]]:
    df = jsonstat_to_df(RAW / "nrg_bal_c_SE_2020.json")
    labels = df.attrs["labels"]["nrg_bal"]
    flows = ["PPRD", "IMP", "EXP", "GIC", "TI_E", "TI_EHG_E",
             "TI_EHG_MAPCHP_E", "TI_EHG_MAPH_E", "TI_EHG_APCHP_E",
             "TI_EHG_APE_E", "TI_EHG_APH_E", "FC_E", "FC_IND_E", "GEP"]
    sel = df[df["nrg_bal"].isin(flows)]
    wide = sel.pivot_table(
        index="nrg_bal", columns="siec", values="value", aggfunc="first"
    ).reindex(flows)
    wide.insert(0, "flow_label", [labels.get(c, "") for c in wide.index])
    # W6100_6220 already contains W6100 and W6220; add renewable W6210.
    wide["all_waste_TJ"] = wide["W6100_6220"] + wide["W6210"]
    ti = float(wide.loc["TI_EHG_E", "all_waste_TJ"])
    main_activity = float(
        wide.loc["TI_EHG_MAPCHP_E", "all_waste_TJ"]
        + wide.loc["TI_EHG_MAPH_E", "all_waste_TJ"]
    )
    key = {
        "waste_fuel_GIC_PJ": float(wide.loc["GIC", "all_waste_TJ"]) / 1000.0,
        "waste_fuel_to_elec_heat_PJ": ti / 1000.0,
        "waste_fuel_main_activity_plants_share_pct": (
            main_activity / ti * 100.0
        ),
        "waste_fuel_industry_final_use_PJ": float(
            wide.loc["FC_IND_E", "all_waste_TJ"]
        ) / 1000.0,
        "waste_fuel_upper_value_bn_SEK": (
            ti * WASTE_FUEL_UPPER_PRICE_SEK_PER_GJ / 1e6
        ),
    }
    return wide.reset_index(), key


def coverage_sheets() -> tuple[pd.DataFrame, pd.DataFrame]:
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    cov = pd.DataFrame(
        [
            {
                "dataset": ds,
                "eu27_countries_with_2020_observations": (
                    c["countries_with_observations"]
                ),
                "missing_members": ", ".join(c["missing"]) or "(none)",
                "probe_series": json.dumps(c["probe_series"]),
            }
            for ds, c in manifest["eu27_coverage"].items()
        ]
    )
    neg = pd.DataFrame(manifest["negative_probes"])
    return cov, neg


def main() -> None:
    fx = eur_sek_rate()
    control_bn, total_supply_bn = control_from_cp15()
    package = json.loads(PACKAGE_MANIFEST.read_text(encoding="utf-8"))
    q = package["quantitative_results"]
    supply_residual_bn = q["explicit_supply_side_monetary_residual_bn_SEK"]
    use_residual_total_bn = q["explicit_monetary_residual_bn_SEK"]

    sbs, sbs_key = sbs_sheet(fx)
    trt, trt_key = wastrt_sheet()
    epea, epea_key = epea_sheet()
    egss, egss_key = egss_sheet()
    nrg, nrg_key = nrg_sheet(fx)
    cov, neg = coverage_sheets()

    # ---- bounded estimate of the energy-relevant share of the control ----
    lower_bn = egss_key["egss_E_CREMA13A_renewable_energy_bn_SEK"]
    upper_bn = (
        lower_bn
        + sbs_key["sbs_E382_production_bn_SEK"]
        + nrg_key["waste_fuel_upper_value_bn_SEK"]
    )
    estimate = pd.DataFrame(
        [
            {
                "component": "control: E37-39 industry own production of "
                             "CPA_E37-39 (naio_10_cp15, basic prices)",
                "bn_SEK": control_bn,
                "pct_of_control": 100.0,
                "assumption": "re-derived from raw cp15 JSON; matches the "
                              "60.156 bn SEK figure in docs/eu_data_mapping.md",
            },
            {
                "component": "LOWER/central bound of energy-relevant output: "
                             "EGSS CReMA 13A 'production of energy from "
                             "renewable sources' within NACE section E",
                "bn_SEK": lower_bn,
                "pct_of_control": lower_bn / control_bn * 100.0,
                "assumption": "all of section E's renewable-energy output "
                              "assumed to sit in E37-E39 (not E36); this is "
                              "the only direct EU-wide monetary measure of "
                              "energy production output inside section E",
            },
            {
                "component": "upper-bound component 1: entire SBS E382 "
                             "(treatment & disposal) production value",
                "bn_SEK": sbs_key["sbs_E382_production_bn_SEK"],
                "pct_of_control": (
                    sbs_key["sbs_E382_production_bn_SEK"] / control_bn * 100.0
                ),
                "assumption": "counts ALL treatment/disposal revenue "
                              "(incl. landfill, composting, hazardous "
                              "treatment gate fees) as if energy-relevant, "
                              "because incineration-with-energy-recovery "
                              "gate fees sit inside E382 and E3821/E3822 "
                              "detail is not published for SE 2020",
            },
            {
                "component": "upper-bound component 2: notional market value "
                             "of all waste fuel burned for electricity/heat "
                             f"({nrg_key['waste_fuel_to_elec_heat_PJ']:.1f} "
                             "PJ x "
                             f"{WASTE_FUEL_UPPER_PRICE_SEK_PER_GJ:.0f} "
                             "SEK/GJ)",
                "bn_SEK": nrg_key["waste_fuel_upper_value_bn_SEK"],
                "pct_of_control": (
                    nrg_key["waste_fuel_upper_value_bn_SEK"]
                    / control_bn * 100.0
                ),
                "assumption": "waste fuel valued at a generous 20 SEK/GJ "
                              "although Swedish waste fuel trades near zero "
                              "or negative (receiving plants charge gate "
                              "fees); double-counts component 1 on purpose "
                              "to stay an upper bound",
            },
            {
                "component": "UPPER bound: sum of the three items above",
                "bn_SEK": upper_bn,
                "pct_of_control": upper_bn / control_bn * 100.0,
                "assumption": "deliberate double counting; true "
                              "energy-relevant share lies between the "
                              "bounds",
            },
            {
                "component": "implied minimum genuinely non-energy share "
                             "of the control",
                "bn_SEK": control_bn - upper_bn,
                "pct_of_control": (control_bn - upper_bn) / control_bn * 100.0,
                "assumption": "sewerage fees, waste collection charges, "
                              "remediation and recovered MATERIALS sales "
                              "(E383, secondary raw materials, not energy "
                              "products)",
            },
        ]
    )

    checks = pd.DataFrame(
        [
            ("EUR->SEK 2020 average (ert_bil_eur_a)", fx, ""),
            ("cp15 E37-39 diagonal control, bn SEK", control_bn,
             "reference: 60.156 in docs/eu_data_mapping.md"),
            ("cp15 total supply of CPA_E37-39, bn SEK", total_supply_bn,
             "reconciliation workbook valuation_controls TOTAL = 70.652"),
            ("package supply-side unmatched residual, bn SEK",
             supply_residual_bn, "energy_money_manifest.json"),
            ("control share of supply-side residual, %",
             control_bn / supply_residual_bn * 100.0, ""),
            ("package use-side unmatched residual (all CPA), bn SEK",
             use_residual_total_bn, "energy_money_manifest.json"),
            ("use-side CPA_E37-E39 residual, bn SEK",
             USE_SIDE_E37E39_RESIDUAL_BN_SEK,
             "docs/eu_data_mapping.md (not in manifest per CPA)"),
            ("SBS E37+E38+E39 production value, bn SEK",
             sbs_key["sbs_E37_E39_production_bn_SEK"],
             "covers 88% of the 60.156 control; SBS excludes some "
             "municipal units and NA adjustments"),
            ("EPEA CEPA2+CEPA3 output, gov + specialist producers, bn SEK",
             epea_key["epea_CEPA2_CEPA3_all_sectors_bn_SEK"],
             "exceeds the control because it includes waste/wastewater "
             "services produced OUTSIDE E37-E39 (secondary activity, "
             "e.g. D35 energy firms)"),
            ("EPEA by-product revenue (EPS_REC_BYPR) observations for SE",
             epea_key["epea_by_product_revenue_reported"],
             "Sweden does not report the one EPEA item that directly "
             "measures by-product (energy) revenue"),
            ("share of non-mineral waste treated with energy recovery, %",
             trt_key["energy_recovery_share_x_mineral_pct"],
             "env_wastrt R1/TRT, TOT_X_MIN"),
            ("waste fuel burned in main-activity (D35) plants, %",
             nrg_key["waste_fuel_main_activity_plants_share_pct"],
             "nrg_bal_c: energy transformation of waste happens in D35, "
             "not E38"),
        ],
        columns=["check", "value", "note"],
    )

    verdict = pd.DataFrame(
        [
            ("question", "Can public EU-wide data narrow the CPA_E37-E39 "
             "residual of the Sweden 2020 public-core package?"),
            ("answer", "The composition CAN be characterized with public "
             "EU-wide data, and the evidence says the residual is "
             "overwhelmingly non-energy: bounded estimate "
             f"{lower_bn:.1f}-{upper_bn:.1f} bn SEK "
             f"({lower_bn / control_bn * 100:.1f}%-"
             f"{upper_bn / control_bn * 100:.1f}%) of the "
             f"{control_bn:.3f} bn SEK control is plausibly "
             "energy-relevant; at least "
             f"{(control_bn - upper_bn) / control_bn * 100:.0f}% is "
             "water/sewerage/waste SERVICES and recovered-MATERIALS "
             "sales."),
            ("allocation verdict", "No EU-wide source provides a product "
             "split of E37-E39 output at CPA level that would let the "
             "builder ALLOCATE the money to energy products: EPEA's "
             "by-product item is unreported by SE, SBS lacks E3821/E3822 "
             "detail, and EGSS attributes only ~1.0 bn SEK to renewable "
             "energy production without a counterpart physical row. "
             "Recommendation to the owner: accept CPA_E37-E39 as a "
             "permanent disclosed non-energy residual, citing this "
             "evidence; optionally annotate the ~1.0 bn SEK (EGSS CReMA "
             "13A) as the documented energy-relevant ceiling of the "
             "diagonal control."),
            ("physical cross-check", "Sweden burns half its non-mineral "
             f"waste ({trt_key['energy_recovery_share_x_mineral_pct']:.0f}% "
             "R1) and feeds "
             f"{nrg_key['waste_fuel_to_elec_heat_PJ']:.1f} PJ of waste "
             "fuel to electricity/heat, but "
             f"{nrg_key['waste_fuel_main_activity_plants_share_pct']:.0f}% "
             "of it is burned in main-activity producer plants classified "
             "in NACE D35 - the energy REVENUE therefore accrues to D35, "
             "not E38, which is why the physical waste-to-energy "
             "prominence does not translate into E37-E39 energy output."),
            ("EU-27 generalizability", "EPEA production and nrg_bal_c 27/27; "
             "EGSS 26/27 (LU absent). Gaps elsewhere are cell-level "
             "confidentiality, not dataset-level: CY and IE publish SBS "
             "E37/E39 but suppress division E38; AT publishes env_wastrt "
             "2020 but not the RCV_E energy-recovery cell for the "
             "non-mineral aggregate (verified 2026-07-31). The method "
             "generalizes; where SBS/env_wastrt cells are suppressed, "
             "EPEA (27/27) and nrg_bal_c (27/27) still bound the "
             "composition."),
        ],
        columns=["item", "text"],
    )

    readme = pd.DataFrame(
        [
            ("purpose", "Feasibility evidence: composition of NACE E37-E39 "
             "output for Sweden 2020, to characterize the CPA_E37-E39 "
             "monetary residual of the public-core package"),
            ("created", dt.date.today().isoformat()),
            ("created_by", "data/preprocessing/scripts/"
             "analyze_waste_stats_se_2020.py"),
            ("raw_inputs", "data/preprocessing/data/waste_stats_raw/SE/2020/ "
             "(manifest.json holds URLs, filters, SHA-256, retrieval date "
             "2026-07-31)"),
            ("source_api", "https://ec.europa.eu/eurostat/api/dissemination/"
             "statistics/1.0/data/<code>"),
            ("datasets", "sbs_na_ind_r2, env_wasgen, env_wastrt, "
             "env_ac_pepsgg1, env_ac_pepssp1, env_ac_egss2, nrg_bal_c; "
             "negative probes: sbs_ovw_act, sbs_sc_ovw, env_ac_epneec, "
             "env_ac_pepsnsp1"),
            ("fx", f"EUR->SEK 2020 average {fx} from ert_bil_eur_a "
             "(eu_core_raw/SE/2020)"),
            ("units", "monetary values in bn SEK unless a column says "
             "MIO_SEK or M EUR (SBS V-codes are million EUR); physical "
             "waste in tonnes/kilotonnes; energy in TJ/PJ"),
            ("comparison_package", "data/preprocessing/data/eu_core/SE/ "
             "energy_money_manifest.json and docs/eu_data_mapping.md "
             "Sweden section"),
            ("sheets", "sbs_na_ind_r2 | env_wastrt_wasgen | env_ac_epea | "
             "env_ac_egss2 | nrg_bal_c | eu27_coverage | negative_probes | "
             "bounded_estimate | conclusions"),
        ],
        columns=["field", "value"],
    )

    with pd.ExcelWriter(OUT, engine="openpyxl") as writer:
        readme.to_excel(writer, sheet_name="README", index=False)
        sbs.to_excel(writer, sheet_name="sbs_na_ind_r2", index=False)
        trt.to_excel(writer, sheet_name="env_wastrt_wasgen", index=False)
        epea.to_excel(writer, sheet_name="env_ac_epea", index=False)
        egss.to_excel(writer, sheet_name="env_ac_egss2", index=False)
        nrg.to_excel(writer, sheet_name="nrg_bal_c", index=False)
        cov.to_excel(writer, sheet_name="eu27_coverage", index=False)
        neg.to_excel(writer, sheet_name="negative_probes", index=False)
        estimate.to_excel(writer, sheet_name="bounded_estimate", index=False)
        checks.to_excel(writer, sheet_name="conclusions", index=False,
                        startrow=0)
        verdict.to_excel(writer, sheet_name="conclusions", index=False,
                         startrow=len(checks) + 2)

    print(f"wrote {OUT}")
    print(f"control (cp15 E37-39 diagonal): {control_bn:.3f} bn SEK")
    print(f"bounded energy-relevant estimate: {lower_bn:.3f} - "
          f"{upper_bn:.3f} bn SEK "
          f"({lower_bn / control_bn * 100:.1f}% - "
          f"{upper_bn / control_bn * 100:.1f}%)")
    for name, key in [
        ("SBS", sbs_key), ("wastrt", trt_key), ("EPEA", epea_key),
        ("EGSS", egss_key), ("nrg_bal", nrg_key),
    ]:
        for k, v in key.items():
            print(f"  {name}: {k} = {v:.3f}"
                  if isinstance(v, float) else f"  {name}: {k} = {v}")


if __name__ == "__main__":
    main()
