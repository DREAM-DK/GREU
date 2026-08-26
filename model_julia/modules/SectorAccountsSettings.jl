# Static index definitions shared by SectorAccounts.jl and SectorAccountsData.jl
module SectorAccountsSettings

const sector_accounts_data_dir = joinpath(@__DIR__, "..", "data", "sector_accounts")

# Eurostat dataset identifiers and units for the two source datasets.
const fin_transactions_dataset_code   = "nasa_10_nf_tr"
const fin_transactions_unit           = "CP_MEUR"
const fin_transactions_dataset_code_2 = "nasa_10_f_tr"
const fin_transactions_unit_2         = "MIO_EUR"
const fin_other_changes_dataset_code  = "nasa_10_f_oc"
const fin_other_changes_unit          = "MIO_EUR"
const fin_revaluation_dataset_code    = "nasa_10_f_gl"
const fin_revaluation_unit            = "MIO_EUR"
const fin_bal_dataset_code            = "nasa_10_f_bs"
const fin_bal_unit                    = "MIO_EUR"
const cell_tolerance                  = 1e-6

# ESA 2010 institutional sectors to download. S14 and S15 (NPISH) are merged
# into a single Households aggregate.
const raw_sectors = ["S11", "S12", "S13", "S14", "S15", "S2"]
const sector_map  = Dict(
  "S11" => "NonFinCorp",  # Non-financial corporations
  "S12" => "FinCorp",     # Financial corporations
  "S13" => "Gov",         # General government
  "S14" => "Hh",          # Households
  "S15" => "Hh",          # Non-profit institutions serving households (merged into Hh)
  "S2"  => "RoW",         # Rest of the world
)

# Financial position (asset/liability side) codes as they appear in nasa_10_f_bs.
const fin_bal_raw_finpos = ["ASS", "LIAB"]
const finpos_map = Dict(
  "ASS"  => "Assets",
  "LIAB" => "Liab",
)

# All ESA transaction and balance codes requested from Eurostat.
const fin_transactions_na_items = [
  "B9", "B8G", "D9", "P5G", "NP", "B6G", "P3", "D8", "B5G", "D5",
  "D6", "D61", "D62", "D63", "D7", "B2A3G", "D1", "D2", "D3", "D4",
  "D41", "D42", "D43", "D44", "D45", "P6", "P7",
]
const fin_bal_na_items = ["F", "F1", "F11", "F2", "F3", "F4", "F5", "F51", "F52", "F6", "F7", "F8"]
const fin_tr_na_items  = replace(fin_bal_na_items, "F" => "F_TR") # nasa_10_f_tr publishes the F aggregate as F_TR rather than F.

# ---------------------------------------------------------------------------
# Property income (vFinIncome_f): D.4 receipts (al=Assets) or payments (al=Liab)
# split by instrument category.
#
# Instrument–income mapping (ESA 2010 convention):
#   F.1/F.2/F.3/F.4/F.8  →  D.41 (interest)
#   F.51                 →  D.42 (dividends) + D43 (reinvested earnings)
#   F.52/F.6             →  D.44 (investment fund income)
#   F.7                  →  no associated income flow
# ---------------------------------------------------------------------------
const fin_transactions_equity_income_items = ["D42"]                       # Distributed income of corporations (ESA D.42); mapped to F51 (equity)
const fin_transactions_debt_income_items   = ["D41", "D43", "D44", "D45"]  # Interest, reinvested earnings, investment fund income, rent; mapped to debt instruments

# ---------------------------------------------------------------------------
# Financial positions (vFinPosition_f): balance-sheet stocks by instrument,
# split into Debt and Equity.
#
# Monetary gold (F.11, a subset of F.1) is excluded from all instrument totals
# because it has no domestic counterpart liability and distorts aggregates.
#
#   Equity ← F.51 (listed equity and investment fund shares)
#   Debt   ← F − F.51 − F.11
# ---------------------------------------------------------------------------
const fin_bal_equity_na_items = ["F51"]

# ---------------------------------------------------------------------------
# Transfer and cross-border income items used when constructing the sector 
# redistribution accounts.
# ---------------------------------------------------------------------------
const fin_transactions_transfer_items  = ["D5", "D61", "D62", "D7", "D8", "D9"]            # D.5 (current taxes), D.6 (social contributions/benefits), D.7 (other current transfers), D.8 (adjustment for pension entitlements), D.9 (capital transfers)
const fin_transactions_row_nonwage_items = ["D2", "D3", "D5", "D6", "D7", "D8", "D9"] # RoW primary income and current transfers, excluding wages (D.1) and property income (D.4)

end # module
