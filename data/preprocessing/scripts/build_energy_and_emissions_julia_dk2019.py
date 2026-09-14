"""Write the Julia energy account in the shape of energy_and_emissions.xlsx.

Denmark, 2019. Reads the CSV the Julia data step writes and lays it out with the
same 23 columns as the Danish file, so progress shows as columns filling in.
Today only `pj` is filled: emissions are the next Julia phase, and no source
publishes the money columns.

The whole account goes in, not only the part the Danish file carries. PEFA also
books fossil natural inputs (`N01` etc.) and losses returned to nature (`R30`),
and each resident account only balances with them. They are identifiable by
product code.

Run:  python data/preprocessing/scripts/build_energy_and_emissions_julia_dk2019.py
"""
import re
import subprocess
from datetime import date
from pathlib import Path

import pandas as pd

JULIA_REPO = Path("C:/GREU_JULIA")
SOURCE_CSV = JULIA_REPO / "model_julia/data/energy_balance/energy_balance.csv"
SETTINGS_JL = JULIA_REPO / "model_julia/modules/EnergyBalanceSettings.jl"
DATA_DIR = Path(__file__).resolve().parents[1] / "data"
OUTPUT = DATA_DIR / "energy_and_emissions_julia_dk2019.xlsx"
DANISH_FILE = DATA_DIR / "energy_and_emissions.xlsx"
YEAR = 2019

# The Danish file's columns, in its order.
COLUMNS = [
    "year", "bal", "flow", "indu", "purp", "product",
    "ch4", "co2_bio", "co2_xbio", "n2o", "co2_eq",
    "pj",
    "basic", "ws_marg", "ret_marg", "mvs_marg",
    "ener_tax", "co2_tax", "so2_tax", "nox_tax", "pso_tax", "vat", "purch",
]

# Account -> (flow, indu), per side. The Danish file leaves indu blank for
# import, export and inventories, and uses `env` for nature.
SUPPLY_FLOW = {
    "environment": ("other_supply", "env"),
    "rest_of_world": ("import", None),
    "inventories": ("invent_change", None),
    "households": ("production", "households"),  # residuals only; no Danish row
}
USE_FLOW = {
    "environment": ("residual_to_env", "env"),  # losses back to nature; no Danish flow
    "rest_of_world": ("export", None),
    "inventories": ("invent_change", None),
}
# Households: the Danish file splits car energy from housing energy.
HOUSEHOLD_INDU = {"transport": "cCarEne", "heating": "cHouEne", "other": "cHouEne"}


def is_industry(account):
    return re.fullmatch(r"i[A-U]", account) is not None


def read_cells(variable, names):
    df = pd.read_csv(SOURCE_CSV)
    df = df[df["variable"] == variable]
    parts = df["indices"].str.split(",", expand=True)
    parts.columns = names
    out = parts.assign(value=df["value"].to_numpy())
    out["year"] = out["year"].astype(int)
    return out[out["year"] == YEAR].reset_index(drop=True)


def supply_rows(sup):
    def keys(account):
        if is_industry(account):
            return ("production", account)
        if account not in SUPPLY_FLOW:
            raise ValueError(f"no supply mapping for account {account!r}")
        return SUPPLY_FLOW[account]

    flow, indu = zip(*sup["account"].map(keys))
    return pd.DataFrame({
        "year": YEAR, "bal": "sup", "flow": flow, "indu": indu, "purp": None,
        "product": sup["product"], "pj": sup["value"],
    })


def use_rows(use):
    def keys(account, purpose):
        if is_industry(account):
            return ("cons_inter", account, "unspecified")
        if account == "households":
            return ("cons_hh", HOUSEHOLD_INDU[purpose], purpose)
        if account not in USE_FLOW:
            raise ValueError(f"no use mapping for account {account!r}")
        return (*USE_FLOW[account], None)

    flow, indu, purp = zip(*(keys(a, m) for a, m in zip(use["account"], use["purpose"])))
    return pd.DataFrame({
        "year": YEAR, "bal": "use", "flow": flow, "indu": indu, "purp": purp,
        "product": use["product"], "pj": use["value"],
    })


def product_labels():
    text = SETTINGS_JL.read_text(encoding="utf-8")
    return dict(re.findall(r"^#\s*([NPR]\d{2}):\s*(.+?)\s*$", text, flags=re.MULTILINE))


def julia_commit():
    out = subprocess.run(["git", "-C", str(JULIA_REPO), "rev-parse", "--short", "HEAD"],
                         capture_output=True, text=True, check=True)
    return out.stdout.strip()


def main():
    assert OUTPUT != DANISH_FILE, "never overwrite the Danish input file"

    sup = read_cells("qESupply_e_d", ["product", "account", "year"])
    use = read_cells("qEUse_e_m_d", ["product", "purpose", "account", "year"])
    use_total = read_cells("qEUse_e_d", ["product", "account", "year"])["value"].sum()

    table = pd.concat([supply_rows(sup), use_rows(use)], ignore_index=True)
    table = table.reindex(columns=COLUMNS)
    table = table.sort_values(["bal", "flow", "indu", "purp", "product"],
                              na_position="first").reset_index(drop=True)

    total = table.groupby("bal")["pj"].sum()
    assert abs(total["sup"] - total["use"]) < 0.01, f"supply and use do not close: {total.to_dict()}"
    assert abs(total["use"] - use_total) < 1e-6, "the purpose split does not sum back to use"
    assert table["pj"].notna().all(), "every row carries pj"

    labels = product_labels()
    missing = sorted(set(table["product"]) - set(labels))
    assert not missing, f"no label in EnergyBalanceSettings.jl for {missing}"

    filled = ["pj"]
    empty = [c for c in COLUMNS[6:] if c not in filled]
    metadata = pd.DataFrame(
        [
            ("title", "Julia energy account for Denmark in the shape of energy_and_emissions.xlsx"),
            ("purpose", "Shows progress: columns fill in as the Julia modules are built"),
            ("country", "DK"),
            ("year", str(YEAR)),
            ("created", date.today().isoformat()),
            ("source", f"{SOURCE_CSV} (written by EnergyBalanceData.jl)"),
            ("source data", "Eurostat env_ac_pefasu, unit TJ, converted to PJ"),
            ("julia commit", julia_commit()),
            ("build script", "data/preprocessing/scripts/build_energy_and_emissions_julia_dk2019.py"),
            ("filled", ", ".join(filled)),
            ("empty: emissions", "ch4, co2_bio, co2_xbio, n2o, co2_eq -- next Julia phase"),
            ("empty: money", ", ".join(c for c in empty if c not in
                                        {"ch4", "co2_bio", "co2_xbio", "n2o", "co2_eq"})
             + " -- no source publishes them"),
            ("boundary", f"Whole account, {total['sup']:.1f} PJ. Includes fossil natural inputs "
                         "(N01, N02, N06) and losses to nature (R30), which the Danish file does not carry."),
            ("industry grain", "21 NACE sections (iA-iU), not the Danish 57 industries"),
            ("product codes", "PEFA prod_nrg codes, not the Danish 25 products; labels below"),
            ("purpose", "Households: heating, transport, other (Eurostat label for appliances). "
                        "Industry: unspecified -- no source publishes industry purpose"),
            ("households indu", "transport -> cCarEne; heating and other -> cHouEne, as the Danish file"),
            ("flow residual_to_env", "Not in the Danish file: losses the economy returns to nature"),
            ("flow production, households", "Not in the Danish file: residuals households give out"),
            ("", ""),
        ]
        + [(f"product {code}", label) for code, label in sorted(labels.items())],
        columns=["key", "value"],
    )

    with pd.ExcelWriter(OUTPUT, engine="openpyxl") as xl:
        table.to_excel(xl, sheet_name="ems_energy", index=False)
        metadata.to_excel(xl, sheet_name="metadata", index=False)

    print(f"wrote {OUTPUT}")
    print(f"  ems_energy: {len(table)} rows, supply {total['sup']:.3f} PJ, use {total['use']:.3f} PJ")
    print(table.groupby(["bal", "flow"])["pj"].agg(["size", "sum"]).round(3).to_string())


if __name__ == "__main__":
    main()
