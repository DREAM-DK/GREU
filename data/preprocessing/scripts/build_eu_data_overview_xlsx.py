"""Build docs/EU_data_overview.xlsx — a boss-friendly traffic-light overview.

Generates a three-sheet workbook (README, Summary, Detail) summarizing, for
every Danish input the GREU model consumes, where the EU-wide replacement
lives and how well it matches. All content is transcribed from the verified
findings in docs/eu_data_mapping.md and the six pilot reconciliation
workbooks under data/preprocessing/data/ — this script performs no new
analysis and computes no new numbers.

Re-run after future pilots change any verdict:

    python data/preprocessing/scripts/build_eu_data_overview_xlsx.py
"""

from __future__ import annotations

import datetime as dt
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

REPO_ROOT = Path(__file__).resolve().parents[3]
OUTPUT_PATH = REPO_ROOT / "docs" / "EU_data_overview.xlsx"
SOURCE_DOC = "docs/eu_data_mapping.md"

# Status vocabulary (traffic light). Every Status cell must use one of these.
STATUS_FILLS = {
    "MATCHES": "C6EFCE",      # green  — reproduces the Danish numbers (or already EU-sourced)
    "CLOSE MATCH": "E2EFDA",  # light green — small, understood, quantified differences
    "COARSER": "FFEB9C",      # yellow — same concept but less detail than the Danish data
    "CONSTRUCTED": "F8CBAD",  # orange — no direct source; built transparently from public controls
    "GAP": "FFC7CE",          # red    — no EU-wide source; needs construction method / decision
    "KEPT": "D9D9D9",         # grey   — not a Danish-statistics dependency; stays as-is
}

STATUS_MEANINGS = {
    "MATCHES": "The EU source reproduces the Danish numbers (well under 1% difference), "
               "or the input is already EU-sourced in the model.",
    "CLOSE MATCH": "Small differences remain, but they are quantified and understood "
                   "(e.g. a known concept difference of a few percent).",
    "COARSER": "The same concept exists EU-wide, but at less detail than the Danish data "
               "(e.g. fewer industries). Aggregation works; extra detail needs splitting keys.",
    "CONSTRUCTED": "No EU source publishes this directly. It is built transparently from public "
                   "control totals, with every assumption and residual disclosed (Sweden 2020 pilot).",
    "GAP": "No EU-wide source exists. Needs a construction method, an external input, "
           "or a decision from colleagues.",
    "KEPT": "Not a Statistics Denmark dependency — kept as-is (classification/concordance file).",
}

SUMMARY_HEADERS = [
    "#",
    "Danish input",
    "What it contains",
    "EU source",
    "Status",
    "Key evidence",
    "What is still missing",
]

# One row per input the model consumes (12 to replace + metadata.xlsx kept
# + the financial-accounts module that is already EU-sourced).
SUMMARY_ROWS = [
    (
        "io_long_format.xlsx",
        "The full input-output table: who buys what from whom, production and "
        "imports for 57 industries, plus wages, surplus and taxes",
        "FIGARO inter-country IO tables (naio_10_fcp_s3 / _u3 / _ii3)",
        "COARSER",
        "DK 2020: totals match to 0.1% or better (output 4,055 bn DKK, wages, "
        "public consumption, investment all exact); imports differ −22% due to "
        "re-export treatment",
        "FIGARO has 64 industries vs GREU's 57 custom ones — a different split, not "
        "simply more detail: GREU separates organic/conventional farming, 5 waste "
        "types and 8 transport industries that FIGARO/NACE lump into one code each, "
        "so those need an external splitting key even though FIGARO has more "
        "categories overall. Also to be decided: re-export handling, and the "
        "real-estate boundary — NACE 'L' bundles housing rental with other "
        "real-estate services, while GREU keeps them in two industries (68203, "
        "71000); the current mapping sends all of L to 68203, overstating housing "
        "output by ~94 bn DKK and understating business services by ~96 bn DKK in "
        "the DK 2020 check",
    ),
    (
        "io_energy_long_format.xlsx",
        "The energy part of the IO table in money terms: what each industry "
        "and household pays for each energy product",
        "No direct source exists. Constructed from Eurostat physical energy "
        "accounts (env_ac_pefasu) calibrated to national supply-use tables "
        "(naio_10_cp15/cp16)",
        "CONSTRUCTED",
        "SE 2020 package built and twice independently reviewed: all accounting "
        "identities close to machine precision, but 0 of the monetary cells are "
        "directly observed anywhere in public EU data",
        "Direct observation is impossible EU-wide; the method discloses its residuals "
        "(119 bn SEK use side, 103 bn SEK supply side, shown to be almost entirely "
        "non-energy money). Colleague sign-off on accepting these residuals",
    ),
    (
        "energy_and_emissions.xlsx",
        "Physical energy use (PJ), emissions and full price/tax decomposition "
        "by industry, energy product and purpose",
        "Physical: env_ac_pefasu (energy accounts). Emissions: env_ac_ainah_r2. "
        "Purpose split: JRC-IDEES-2023 + EU ETS registry. Prices/taxes: "
        "constructed (see price rows in Detail)",
        "COARSER",
        "DK 2020: physical energy −0.611% (2,237.8 vs 2,251.6 PJ); household "
        "totals +0.04%; fossil CO2 −0.007%",
        "The purpose split (heating / process / transport / ETS) and the price/tax "
        "layer are not published EU-wide and must be constructed; industry detail "
        "is coarser in 7 of 28 industry groups",
    ),
    (
        "non_energy_emissions.xlsx",
        "Process (non-energy) emissions by industry, incl. F-gases",
        "env_ac_ainah_r2 (air emissions accounts, total emissions by industry)",
        "COARSER",
        "DK 2020 (combined with energy emissions, the comparable boundary): "
        "fossil CO2 −0.007%, F-gases exact; CH4 +8.6% and N2O +3.2% source gaps "
        "remain (mostly agriculture)",
        "Eurostat publishes only total emissions; the energy vs non-energy split "
        "must be derived (total minus fuel-based estimate). CH4/N2O gap to "
        "investigate",
    ),
    (
        "emissions_bridge_items.xlsx",
        "Adjustment items bridging resident-principle emissions to national "
        "territory (border trade, international transport)",
        "env_ac_aibrid_r2 (air emissions bridging items — the exact same concept)",
        "MATCHES",
        "Exact concept match by design (both are the official accounts-to-inventory "
        "bridge). Number reconciliation is the next scheduled pilot",
        "Numeric pilot not yet run (smallest input; first item of the current phase)",
    ),
    (
        "employed.xlsx",
        "Employment and hours worked by industry, split employees / self-employed",
        "nama_10_a64_e (national-accounts employment by 64 industries)",
        "MATCHES",
        "DK 2020: hours −0.000% nationally, exact in 24 of 28 industry groups — and "
        "hours are the only per-industry content the model uses. Persons +3.52% "
        "(known concept difference)",
        "Six countries (DE, FR, BE, BG, LT, EE) publish hours at coarser industry "
        "level; the Danish person concept needs a colleague answer (affects one "
        "national scalar only)",
    ),
    (
        "fixed_assets.xlsx",
        "Capital stock by industry and 7 asset types",
        "nama_10_nfa_st (fixed asset stocks by industry and asset)",
        "COARSER",
        "Not yet piloted. Eurostat side is 21 industry groups (vs 64/57) and asset "
        "detail varies by country",
        "Industry detail; for countries without stock data a capital-stock "
        "estimation (PIM) from investment series may be needed",
    ),
    (
        "io_invest_long_format.xlsx",
        "Investment matrices: which industry produces the investment goods "
        "each industry buys",
        "None — investment matrices are not published EU-wide. Build from "
        "investment by industry × asset type plus an asset→product bridge",
        "GAP",
        "No EU-wide source exists (verified)",
        "Construction method needed: GFCF × asset bridge, balanced with the Danish "
        "matrix as prior (RAS) — the prior choice is a method decision for colleagues",
    ),
    (
        "ets.xlsx",
        "EU ETS by industry: verified emissions, free and bought allowances, "
        "implied carbon cost",
        "EU Union Registry public bulk data (EUTL) + EEA ETS data viewer",
        "CLOSE MATCH",
        "DK 2020: verified emissions +0.007%, free allocation +0.002%, 'bought' "
        "+0.002% — all reproduce almost exactly",
        "'Bought' is a derived shortfall proxy, not observed purchases; the carbon "
        "cost needs an external EUA price; the installation→industry mapping relies "
        "on a secondary source covering 97.6% of DK emissions",
    ),
    (
        "government_finances.xlsx",
        "Government expenditure and revenue by transaction type (wages, "
        "investment, subsidies, ...)",
        "gov_10a_main (main aggregates of general government)",
        "MATCHES",
        "Concept-exact by design (same ESA transaction codes). Caveat: the Danish "
        "numbers come from the MAKRO model, so a number pilot may show differences",
        "Numeric pilot not yet run (second item of the current phase); functional "
        "detail would use COFOG (gov_10a_exp) if needed",
    ),
    (
        "institutional_financial_accounts.xlsx",
        "Net financial positions by sector (households, firms, government, "
        "abroad) and instrument group",
        "nasa_10_f_bs (financial balance sheets) — the model's financial-accounts "
        "module already pulls this live from Eurostat",
        "MATCHES",
        "The download code already exists and runs in the model (financial-accounts "
        "module); this input can reuse it directly",
        "Caveat: 'MATCHES' means the live Eurostat connection is proven, not that "
        "this file is fully replaced yet. The existing module is Denmark-only so "
        "far, does not yet compute interest/dividend/revaluation flows (only "
        "current holdings), and is not yet wired into the model's data pipeline "
        "for this file. Also to replicate: the Danish pension-asset reallocation "
        "(move household pension assets from financial corporations to "
        "households; the detail needed for this is published under Eurostat's "
        "instrument code 'F6' — pension entitlements, not a spreadsheet cell)",
    ),
    (
        "EU_GR_data.gdx",
        "Marginal energy and CO2 tax rates (currently imported from the Danish "
        "GreenREFORM model as a stopgap)",
        "No direct EU counterpart. Constructed public-core GDX (average tax per "
        "PJ as explicit average=marginal assumption)",
        "CONSTRUCTED",
        "SE 2020: complete compatible GDX built; energy rate = allocated average "
        "tax/PJ, separate CO2 marginal rate recorded as unavailable (zero)",
        "A legal excise/ETS rate engine is needed before these can be treated as "
        "true policy rates rather than calibration rates",
    ),
    (
        "metadata.xlsx",
        "Classifications and concordances (GREU industries ↔ NACE, energy "
        "products ↔ Eurostat codes, consumption groups ↔ COICOP, ...)",
        "Kept — becomes the master EU concordance file; not a data dependency",
        "KEPT",
        "The existing maps already express the Danish structure in EU vocabulary — "
        "a big head start",
        "Four energy-product map fixes pending owner review (P18 gasoil, heat-pump "
        "ambient energy, a spelling, P10); the real-estate L↔68203 split is "
        "value-inconsistent and needs a note or split key",
    ),
    (
        "Financial-accounts module (data/Modules/financial_accounts)",
        "Live Eurostat pull feeding the model's financial accounts — listed for "
        "completeness",
        "nasa_10_f_bs via the Eurostat API (already implemented)",
        "MATCHES",
        "Already EU-sourced and running in the model — serves as the working "
        "template for every replaced input",
        "Nothing — out of scope of the replacement work",
    ),
]

DETAIL_HEADERS = [
    "Danish input",
    "Variable / datapoint",
    "What it is",
    "EU source (exact dataset code)",
    "Status",
    "Match evidence",
    "Verified in",
    "Notes / next step",
]

# One row per variable/component with a distinct status.
DETAIL_ROWS = [
    # ------------------------------------------------------------- io_long_format
    (
        "io_long_format.xlsx",
        "Main IO flows (production + imports, 57 industries)",
        "Who buys what from whom, in basic prices",
        "FIGARO naio_10_fcp_ii3 (+ _s3/_u3 supply-use)",
        "COARSER",
        "DK 2020: total output 4,055.4 bn DKK exact; GDP +0.1%; 7 of 28 industry "
        "groups are coarser (34 of 57 GREU industries affected)",
        "figaro_dk2020_reconciliation.xlsx",
        "GREU industries that split one NACE code (organic/conventional farming, "
        "5 waste industries, 2 energy industries) need country splitting keys. "
        "Note the 64-vs-57 counts are a different split, not simply more detail: "
        "FIGARO's extra categories sit where GREU aggregates anyway (harmless), "
        "while in these 7 groupings GREU is the finer one and FIGARO gives only a "
        "combined total",
    ),
    (
        "io_long_format.xlsx",
        "Imports and re-exports",
        "Import rows of the IO table",
        "FIGARO (same tables, inter-country logic)",
        "COARSER",
        "DK 2020: imports −22% because Danish re-exports (239.8 bn DKK) have no "
        "FIGARO counterpart; −2.3% once re-exports are excluded",
        "figaro_dk2020_reconciliation.xlsx",
        "Decide re-export handling; import composition also differs (foreign "
        "margins as service rows vs embedded in goods prices)",
    ),
    (
        "io_long_format.xlsx",
        "Primary inputs (wages, gross surplus, other taxes)",
        "Value-added components per industry",
        "FIGARO valuation layers + nama_10_a64",
        "CLOSE MATCH",
        "DK 2020: wages (D1) 1,210.4 and gross surplus 824.0 bn DKK exact; "
        "real-estate boundary shifts ±45 bn between two industry groups",
        "figaro_dk2020_reconciliation.xlsx",
        "The L↔68203 real-estate boundary needs a split key (hit by 3 pilots). "
        "It is a mapping error, not a data gap: NACE 'L' bundles housing rental "
        "with other real-estate services, but GREU keeps these in two industries "
        "(68203 housing, 71000 business services) and the concordance currently "
        "routes all of L to 68203 — worth ~94 bn DKK too much housing output and "
        "~96 bn DKK too little business services for DK 2020",
    ),
    (
        "io_long_format.xlsx",
        "5-way product-tax split (5 named Danish taxes)",
        "tax_products split into 5 named taxes + VAT row",
        "None — FIGARO publishes one combined row (D21X31)",
        "GAP",
        "DK 2020: matches as a sum only (305.3 vs 302.2 bn DKK)",
        "figaro_dk2020_reconciliation.xlsx",
        "Needs an explicit tax engine or an agreed simplification of the model "
        "interface",
    ),
    (
        "io_long_format.xlsx",
        "Household consumption detail (12 GREU groups)",
        "Consumption split into the model's 12 groups",
        "nama_10_co3_p3 (consumption by COICOP purpose)",
        "COARSER",
        "Not yet piloted. Eurostat publishes 2–3 digit COICOP; the Danish map "
        "uses 4-digit",
        "—",
        "3-digit is expected to approximate the 12 groups; check group by group",
    ),
    # ----------------------------------------------------- io_energy_long_format
    (
        "io_energy_long_format.xlsx",
        "Energy IO table in money terms",
        "Energy spending per product × user, all value components",
        "Constructed: env_ac_pefasu physical backbone calibrated to "
        "naio_10_cp15/cp16 supply-use controls",
        "CONSTRUCTED",
        "SE 2020: 610.6 bn SEK purchaser value; every accounting identity closes "
        "to machine precision; 0 monetary cells directly observed",
        "energy_money_se2020_public_core_reconciliation.xlsx",
        "Disclosed residuals: 118.8 bn SEK (use) / 102.6 bn SEK (supply), shown by "
        "two follow-up pilots to be ≥85–98.5% non-energy money. Colleague "
        "acceptance recommended",
    ),
    # -------------------------------------------------------- energy_and_emissions
    (
        "energy_and_emissions.xlsx",
        "Physical energy use (PJ) by industry and product",
        "The physical energy backbone of the model",
        "env_ac_pefasu (physical energy flow accounts)",
        "CLOSE MATCH",
        "DK 2020: 2,237.8 vs 2,251.6 PJ (−0.611%) on the comparable boundary; "
        "supply and use balance on both sides",
        "eurostat_energy_emissions_dk2020_reconciliation.xlsx",
        "7 of 28 industry groups coarser; 4 product-map fixes pending owner review; "
        "no separate transmission-loss cell",
    ),
    (
        "energy_and_emissions.xlsx",
        "Household energy by purpose (heating / transport / appliances)",
        "The three household end uses",
        "env_ac_pefasu (HH_HEAT / HH_TRA / HH_OTH)",
        "CLOSE MATCH",
        "DK 2020: household total +0.039%; allocation differs (heating −6.9 PJ, "
        "appliances +6.7 PJ)",
        "eurostat_energy_emissions_dk2020_reconciliation.xlsx",
        "JRC-IDEES can serve as optional finer split key (residential subtotal "
        "−0.24%)",
    ),
    (
        "energy_and_emissions.xlsx",
        "Industry purpose split (heating, normal/special process, transport)",
        "How each industry uses its energy",
        "JRC-IDEES-2023 (analytical database, EU-27, 2000–2023)",
        "GAP",
        "DK 2020: combined process envelope +3.05% works, but exact GREU "
        "categories are constructed (heating proxy −81%, special process far "
        "too broad)",
        "jrc_idees_dk2020_purpose_reconciliation.xlsx",
        "Needs an owner-approved IDEES-process→GREU-purpose concordance with PEFA "
        "as the balancing control",
    ),
    (
        "energy_and_emissions.xlsx",
        "in_ETS purpose flag (energy used in ETS-regulated activity)",
        "Which energy use falls under the EU ETS",
        "EUTL Union Registry + installation→industry bridge",
        "GAP",
        "EUTL proves membership and emissions but publishes no fuel, PJ or "
        "energy-use field; best public industry bridge covers 97.6% of DK "
        "emissions but is secondary",
        "eutl_dk2020_reconciliation.xlsx",
        "Needs a maintained installation→industry concordance plus explicit "
        "fuel/emission-factor modelling",
    ),
    (
        "energy_and_emissions.xlsx",
        "Energy-related emissions by industry",
        "CO2 etc. from fuel combustion",
        "env_ac_ainah_r2 (total emissions, energy + process combined)",
        "COARSER",
        "DK 2020 on the combined boundary: fossil CO2 −0.007%, biogenic CO2 "
        "+0.0005%",
        "eurostat_energy_emissions_dk2020_reconciliation.xlsx",
        "Eurostat does not split energy vs process emissions; split must be "
        "derived (see non_energy_emissions row)",
    ),
    (
        "energy_and_emissions.xlsx",
        "Basic values of energy flows",
        "Energy value before margins and taxes",
        "naio_10_cp15 (national supply-use, broad energy products)",
        "CONSTRUCTED",
        "SE 2020: calibrated to SUT controls; identities close exactly. Known "
        "hole: Sweden publishes no breakdown at all for coal and crude oil "
        "(916.8 PJ flagged, valued at zero)",
        "energy_money_se2020_public_core_reconciliation.xlsx",
        "Controls are broad product families, not the model's fine products; "
        "26/27 countries have the tables (Bulgaria absent)",
    ),
    (
        "energy_and_emissions.xlsx",
        "Trade margins (wholesale / retail / motor-vehicle)",
        "Three separate margin layers per energy cell",
        "naio_10_cp15 publishes only one combined trade+transport margin (OTTM)",
        "CONSTRUCTED",
        "SE 2020: combined margin carried in the wholesale column only, retail "
        "and motor margins set to zero (documented compatibility encoding)",
        "energy_money_se2020_public_core_reconciliation.xlsx",
        "No EU source splits the three margins; this is a permanent simplification "
        "unless colleagues change the model interface",
    ),
    (
        "energy_and_emissions.xlsx",
        "Five energy taxes (energy / CO2 / SO2 / NOx / PSO)",
        "Named Danish tax layers per energy cell",
        "naio_10_cp15 net product-tax wedge + env_ac_taxind2 (payer totals) + "
        "TAXUD excise tables (PDF)",
        "CONSTRUCTED",
        "SE 2020: the whole non-VAT wedge carried as 'energy tax', other four "
        "zero; 10.4 bn SEK concept difference vs the environmental-tax accounts "
        "kept visible",
        "energy_money_se2020_public_core_reconciliation.xlsx",
        "Tax accounts identify payers, not products/rates; a legal excise/ETS "
        "engine is needed for named taxes and true marginal rates",
    ),
    (
        "energy_and_emissions.xlsx",
        "VAT per energy cell",
        "VAT on household energy purchases",
        "TAXUD official VAT rate tables + SUT tax-wedge cap",
        "CONSTRUCTED",
        "SE 2020: legal-rate estimate 29.77 vs calibrated 28.39 bn SEK — the "
        "1.375 bn difference is kept as a visible audit column",
        "energy_money_se2020_public_core_reconciliation.xlsx",
        "Statutory rate ≠ observed revenue: taxable base and business VAT "
        "recovery are modelled by an explicit incidence rule",
    ),
    (
        "energy_and_emissions.xlsx",
        "Energy prices (basic → purchaser decomposition)",
        "Observed market prices to anchor the valuation",
        "nrg_pc_202_c–205_c (electricity/gas price components), EC Weekly Oil "
        "Bulletin",
        "GAP",
        "DK 2020: direct price controls cover only 15.0% of PJ and 24.7% of "
        "purchaser value (electricity + road fuels); gas components missing for "
        "3 of 27 countries",
        "energy_money_dk2020_feasibility_gap.xlsx",
        "Prices lack industry/purpose detail; they serve as weights and "
        "validation, not as direct cell values",
    ),
    (
        "energy_and_emissions.xlsx",
        "Purchaser values",
        "Total price paid = basic + margins + taxes + VAT",
        "Derived identity (sum of the components above)",
        "CONSTRUCTED",
        "SE 2020: component identity closes to 7×10⁻¹⁵ bn SEK",
        "energy_money_se2020_public_core_reconciliation.xlsx",
        "Sound by construction once the components exist; quality is inherited "
        "from the component rows above",
    ),
    # ------------------------------------------------------- non_energy_emissions
    (
        "non_energy_emissions.xlsx",
        "Process emissions by industry (incl. F-gases)",
        "Emissions not from fuel combustion (cement, agriculture, F-gases)",
        "env_ac_ainah_r2 (covers total emissions incl. F-gases)",
        "COARSER",
        "DK 2020 combined boundary: F-gases exact (+0.001 kt); CH4 +8.6% and "
        "N2O +3.2% source discrepancies (mostly agriculture, +811 kt CO2e)",
        "eurostat_energy_emissions_dk2020_reconciliation.xlsx",
        "Derive non-energy = total − energy-related estimate; investigate the "
        "CH4/N2O vintage/adjustment gap",
    ),
    # ---------------------------------------------------- emissions_bridge_items
    (
        "emissions_bridge_items.xlsx",
        "Residence-to-territory bridge items",
        "Border trade and international transport adjustments",
        "env_ac_aibrid_r2 (air emissions bridging items)",
        "MATCHES",
        "Exact concept match by design — both are the official accounts↔inventory "
        "bridge. Number pilot is the next scheduled task",
        "—",
        "Smallest input; first pilot of the current phase",
    ),
    # ---------------------------------------------------------------- employed
    (
        "employed.xlsx",
        "Hours worked (employees / self-employed × industry)",
        "The only per-industry content the model actually uses (wage imputation "
        "ratio)",
        "nama_10_a64_e (THS_HW, SAL_DC/SELF_DC)",
        "MATCHES",
        "DK 2020: national total −0.000%; exact in 24 of 28 industry groups",
        "employment_dk2020_reconciliation.xlsx",
        "DE, FR, BE, BG, LT, EE publish hours at coarser level — distribute over "
        "person shares (mild: only a ratio enters the model)",
    ),
    (
        "employed.xlsx",
        "Persons employed",
        "Head counts (model uses only one national total)",
        "nama_10_a64_e (THS_PER)",
        "CLOSE MATCH",
        "DK 2020: uniform +3.52% concept gap (Danish column uses a non-standard "
        "person concept); hours match proves both sides are the same accounts",
        "employment_dk2020_reconciliation.xlsx",
        "Colleague question: which person concept does the Danish column use? "
        "Affects one national scalar only",
    ),
    # -------------------------------------------------------------- fixed_assets
    (
        "fixed_assets.xlsx",
        "Capital stock by industry × 7 asset types",
        "Machinery, buildings, transport equipment etc. per industry",
        "nama_10_nfa_st (fixed asset stocks)",
        "COARSER",
        "Not yet piloted. Eurostat is 21 industry groups vs 64/57; asset detail "
        "varies by country",
        "—",
        "May need capital-stock estimation (PIM) from investment series for "
        "countries with missing stock data",
    ),
    # ------------------------------------------------------ io_invest_long_format
    (
        "io_invest_long_format.xlsx",
        "Investment matrices (buildings / transport / other)",
        "Which industry produces the investment goods each industry buys",
        "None published EU-wide; GFCF by industry × asset exists "
        "(nama_10_nfa_st flows, FIGARO GFCF column)",
        "GAP",
        "No EU-wide investment matrices exist (verified)",
        "—",
        "Build from GFCF × asset→product bridge, balanced with the Danish matrix "
        "as prior (RAS) — the prior is a method decision for colleagues",
    ),
    # ----------------------------------------------------------------------- ets
    (
        "ets.xlsx",
        "Verified ETS emissions by industry",
        "Emissions regulated under the EU ETS",
        "Union Registry public bulk CSV (installation level)",
        "MATCHES",
        "DK 2020: 11,039.4 vs 11,038.6 kt CO2e (+0.0067%; difference is a later "
        "aviation revision)",
        "eutl_dk2020_reconciliation.xlsx",
        "Direct field; industry attribution relies on the bridge row below",
    ),
    (
        "ets.xlsx",
        "Free allowance allocation",
        "Allowances handed out for free",
        "Union Registry public bulk CSV",
        "MATCHES",
        "DK 2020: +0.0023%",
        "eutl_dk2020_reconciliation.xlsx",
        "Direct field",
    ),
    (
        "ets.xlsx",
        "Bought allowances",
        "Allowances installations had to buy",
        "Derived: max(verified emissions − free allocation, 0) per installation",
        "CLOSE MATCH",
        "DK 2020: +0.0020% — reproduces the Danish number, but as a shortfall "
        "proxy, not observed purchases (banking/transfers invisible)",
        "eutl_dk2020_reconciliation.xlsx",
        "Same derivation the Danish input evidently used; document it as a proxy",
    ),
    (
        "ets.xlsx",
        "Implied ETS cost / carbon tax",
        "Money value of the allowance shortfall",
        "No price field in the Registry; needs an external EUA price",
        "GAP",
        "GREU's number implies a uniform 231.83 DKK/t on the shortfall; applying "
        "the same rate to current data reproduces it to 5 decimals",
        "eutl_dk2020_reconciliation.xlsx",
        "Choose and document an official EUA price series (e.g. auction results)",
    ),
    (
        "ets.xlsx",
        "Installation → industry mapping",
        "Assigning each ETS installation to a model industry",
        "Registry publishes ETS activity codes, not NACE; best public bridge is "
        "the secondary EUETS.INFO/Zenodo package",
        "COARSER",
        "Bridge covers 94.9% of DK 2020 records and 97.6% of emissions; the "
        "broad 'combustion of fuels' code alone spans 336 records",
        "eutl_dk2020_reconciliation.xlsx",
        "Decide: maintain a reviewed concordance, or redesign ETS inputs at "
        "regulatory-activity level",
    ),
    # -------------------------------------------------------- government_finances
    (
        "government_finances.xlsx",
        "Government expenditure/revenue by ESA transaction",
        "Wages, investment, subsidies, transfers etc. of general government",
        "gov_10a_main (main aggregates of general government)",
        "MATCHES",
        "Concept-exact (same ESA transaction codes). Caveat: Danish values come "
        "from the MAKRO model, so numbers may not reproduce exactly",
        "—",
        "Numeric pilot scheduled (current phase); COFOG (gov_10a_exp) if "
        "functional detail is needed",
    ),
    # -------------------------------------- institutional_financial_accounts
    (
        "institutional_financial_accounts.xlsx",
        "Net financial positions by sector × instrument",
        "Who owns/owes what: households, firms, government, rest of world",
        "nasa_10_f_bs (financial balance sheets)",
        "MATCHES",
        "The model's financial-accounts module already pulls this live from "
        "Eurostat; the replacement can reuse that code directly. Caveat: the "
        "module is Denmark-only so far and does not yet compute interest/"
        "dividend/revaluation flows or wire into this file — a proven template, "
        "not a finished replacement",
        "—",
        "Replicate the pension-asset reallocation (move household pension assets "
        "from financial corporations to households; the needed detail is "
        "published under Eurostat's instrument code 'F6' — pension "
        "entitlements, not a spreadsheet cell)",
    ),
    (
        "institutional_financial_accounts.xlsx",
        "Interest and dividend flows",
        "Property-income flows between sectors (D41, D42)",
        "nasa_10_nf_tr (non-financial transactions by sector)",
        "MATCHES",
        "Concept match; not yet piloted numerically",
        "—",
        "Include in the financial-accounts pilot",
    ),
    # -------------------------------------------------------------- EU_GR_data
    (
        "EU_GR_data.gdx",
        "Marginal energy tax rates (tEAFG_REmarg)",
        "Marginal tax per PJ by product × user",
        "Constructed: allocated average energy tax / PJ",
        "CONSTRUCTED",
        "SE 2020: complete compatible GDX built with an explicit "
        "average=marginal assumption",
        "eu_core/SE/energy_money_manifest.json",
        "A legal excise-rate engine is needed to turn these into true policy "
        "rates",
    ),
    (
        "EU_GR_data.gdx",
        "Marginal CO2 tax rates (tCO2_REmarg)",
        "Marginal CO2 tax per unit by product × user",
        "None — no defensible EU-wide source at this grain",
        "GAP",
        "SE 2020: symbol delivered complete but zero, explicitly documented as "
        "unavailable",
        "eu_core/SE/energy_money_manifest.json",
        "Same excise/ETS engine as above would close this",
    ),
    # ---------------------------------------------------------------- metadata
    (
        "metadata.xlsx",
        "Classifications and concordances",
        "GREU↔NACE industries, energy products↔Eurostat codes, consumption↔COICOP, "
        "sectors/flows↔ESA",
        "Kept as the master EU concordance file",
        "KEPT",
        "The maps already express the model in EU vocabulary — this is what makes "
        "the whole replacement feasible",
        "—",
        "Pending: 4 energy-product map fixes (owner review), the L↔68203 "
        "real-estate split, extensions for EUTL activities and asset bridges, and "
        "a NACE Rev. 2.1 check",
    ),
]

HEADER_FILL = PatternFill("solid", fgColor="1F4E79")
HEADER_FONT = Font(bold=True, color="FFFFFF", size=11)
THIN_BORDER = Border(*[Side(style="thin", color="BFBFBF")] * 4)
WRAP_TOP = Alignment(wrap_text=True, vertical="top")


def _autofit_row_heights(ws, widths, first_data_row=2):
    """Rough row-height estimate so wrapped text stays visible."""
    for row in ws.iter_rows(min_row=first_data_row):
        lines = 1
        for cell, width in zip(row, widths):
            if cell.value:
                text = str(cell.value)
                lines = max(lines, -(-len(text) // max(width - 2, 10)))
        row[0].parent.row_dimensions[row[0].row].height = min(15 * lines, 150)


def _write_table(ws, headers, rows, widths, status_col_idx):
    ws.append(headers)
    for cell in ws[1]:
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(wrap_text=True, vertical="center")
    for row in rows:
        ws.append(row)
    for col_idx, width in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(col_idx)].width = width
    for row in ws.iter_rows(min_row=2):
        for cell in row:
            cell.alignment = WRAP_TOP
            cell.border = THIN_BORDER
        status_cell = row[status_col_idx - 1]
        status = status_cell.value
        if status not in STATUS_FILLS:
            raise ValueError(f"Illegal status {status!r} in sheet {ws.title}")
        status_cell.fill = PatternFill("solid", fgColor=STATUS_FILLS[status])
        status_cell.font = Font(bold=True)
        status_cell.alignment = Alignment(vertical="top", horizontal="center",
                                          wrap_text=True)
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = f"A1:{get_column_letter(len(headers))}{ws.max_row}"
    _autofit_row_heights(ws, widths)


def build_workbook() -> Workbook:
    wb = Workbook()

    # ---------------------------------------------------------------- README
    ws = wb.active
    ws.title = "README"
    today = dt.date.today().isoformat()
    intro = [
        ("EU data overview — what we need, where it comes from, and how well it matches",),
        (),
        (f"Created: {today}. Generated by "
         "data/preprocessing/scripts/build_eu_data_overview_xlsx.py — re-run the "
         "script after new pilots; do not edit this file by hand.",),
        (),
        ("Purpose: the GREU model currently runs on Danish (Statistics Denmark) "
         "input data. To make the model usable by any EU member state, every "
         "Danish input must be replaced with data available EU-wide. This "
         "workbook lists every such input, the EU source found for it, and how "
         "well that source reproduces the Danish numbers in the completed pilot "
         "reconciliations (Denmark 2020 and Sweden 2020).",),
        (),
        ("Sheets: 'Summary' has one row per input file — the one-page view. "
         "'Detail' breaks each input into its individual variables/datapoints, "
         "because pieces of one file can have very different statuses.",),
        (),
        (f"All content is transcribed from {SOURCE_DOC} (the technical audit "
         "log) and the pilot reconciliation workbooks named in the 'Verified in' "
         "column, which live in data/preprocessing/data/. Every number is "
         "reproducible from the scripts in data/preprocessing/scripts/.",),
        (),
        ("Status legend:",),
    ]
    # Prose cells are left unwrapped so the text visually overflows across the
    # empty neighbouring columns; only the legend meanings wrap.
    for line in intro:
        ws.append(line)
    ws["A1"].font = Font(bold=True, size=14)
    for status, meaning in STATUS_MEANINGS.items():
        ws.append((status, meaning))
        row = ws.max_row
        cell = ws.cell(row=row, column=1)
        cell.fill = PatternFill("solid", fgColor=STATUS_FILLS[status])
        cell.font = Font(bold=True)
        cell.alignment = Alignment(horizontal="center", vertical="center")
        cell.border = THIN_BORDER
        ws.cell(row=row, column=2).alignment = WRAP_TOP
        ws.row_dimensions[row].height = 30
    ws.column_dimensions["A"].width = 18
    ws.column_dimensions["B"].width = 100

    # --------------------------------------------------------------- Summary
    ws_sum = wb.create_sheet("Summary")
    summary_rows = [(i + 1, *row) for i, row in enumerate(SUMMARY_ROWS)]
    _write_table(
        ws_sum,
        SUMMARY_HEADERS,
        summary_rows,
        widths=[4, 30, 42, 38, 14, 48, 48],
        status_col_idx=5,
    )

    # ---------------------------------------------------------------- Detail
    ws_det = wb.create_sheet("Detail")
    _write_table(
        ws_det,
        DETAIL_HEADERS,
        DETAIL_ROWS,
        widths=[26, 34, 34, 36, 14, 50, 40, 46],
        status_col_idx=5,
    )

    return wb


def main() -> None:
    wb = build_workbook()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    wb.save(OUTPUT_PATH)
    print(f"Wrote {OUTPUT_PATH}")
    print(f"Summary rows: {len(SUMMARY_ROWS)}; Detail rows: {len(DETAIL_ROWS)}")


if __name__ == "__main__":
    main()
