# Static index definitions shared by Government, GovernmentSubsectors, and their data files.
module GovernmentSettings

const government_data_dir = joinpath(@__DIR__, "..", "data", "government")

const government_dataset_code = "gov_10a_main"
const government_unit         = "MIO_EUR"
const government_sector       = "S13"    # General government

# Subsectors of government sector.
const gov_subsectors = ["S1311", "S1312", "S1313"]
const gov_subsector_map = Dict(
  "S1311" => "CentralGov",
  "S1312" => "StateGov",
  "S1313" => "LocalGov",
)
const gov_subsector = [Symbol(gov_subsector_map[s]) for s in gov_subsectors]


# ---------------------------------------------------------------------------
# ESA 2010 na_item codes for general government accounts.
# Ordered as they appear in the source dataset (gov_10a_main).
# ---------------------------------------------------------------------------

# Net lending/net borrowing accounting identity
const identity_na_items = ["B9", "TR", "TE"]

# Revenue components
const revenue_na_items = [
  "P11_P12_P131",   # Market output, own-use output, and payments for non-market output
  "D2REC",          # Taxes on production and imports (received)
  "D39REC",         # Other subsidies on production (received)
  "D5REC",          # Current taxes on income, wealth, etc. (received)
  "D61REC",         # Net social contributions (received)
  "D7REC",          # Other current transfers (received)
  "D91REC",         # Capital taxes (received)
  "D92_D99REC",     # Other capital transfers and investment grants (received)
  "D51A_C1REC",     # Taxes on individual income and profits paid by households (received)
  "D51B_C2REC",     # Taxes on income and profits paid by corporations (received)
  "D21REC",         # Taxes on products (received)
  "D29REC",         # Other taxes on production (received)
]

# Expenditure components
const expenditure_na_items = [
  "P2",             # Intermediate consumption; input for industry-sector shares
  "P51C",           # Consumption of fixed capital
  "D1PAY",          # Employee compensation; input for industry-sector shares
  "D29PAY",         # Other production taxes; input for industry-sector shares
  "D3PAY",          # Subsidies (paid)
  "D62_D632PAY",    # Social benefits other than social transfers in kind (paid)
  "D632PAY",        # Social transfers in kind via market producers (paid)
  "D7PAY",          # Other current transfers (paid)
  "D8",             # Adjustment for the change in pension entitlements
  "D9PAY",          # Capital transfers (paid)
  "NP",             # Net acquisitions of non-financial non-produced assets
]

const all_na_items = vcat(identity_na_items, revenue_na_items, expenditure_na_items)

# ---------------------------------------------------------------------------
# Eurostat na_item code → model variable name
# ---------------------------------------------------------------------------
const na_item_to_var = Dict(
  # Net lending/net borrowing identity
  "B9"           => :vGovBalance,
  "TR"           => :vGovRevenue,
  "TE"           => :vGovExpenditure,
  # Revenue components
  "P11_P12_P131" => :vGovSalesRev,
  "D2REC"        => :vtIndirect,
  "D39REC"       => :vGovOthSubRev,
  "D5REC"        => :vtDirect,
  "D61REC"       => :vGovSocialContRev,
  "D7REC"        => :vGovOthCurrentTransRev,
  "D91REC"       => :vtCap,
  "D92_D99REC"   => :vGovCapRev,
  "D51A_C1REC"   => :vtHhIncome,
  "D51B_C2REC"   => :vtCorp,
  "D21REC"       => :vGovProductTax,
  "D29REC"       => :vGovOthProductionTax,
  # Expenditure components
  "P2"           => :vGovIntermediateCons,
  "P51C"         => :vGovDepr,
  "D1PAY"        => :vGovEmplComp,
  "D29PAY"       => :vGovOthProdTax,
  "D3PAY"        => :vGovSub,
  "D62_D632PAY"  => :vGovSocBenefitExp,
  "D632PAY"      => :vSocTransKind,
  "D7PAY"        => :vGovOthCurrentTransExp,
  "D8"           => :vGovAdjExp,
  "D9PAY"        => :vGovCapTransExp,
  "NP"           => :vGovNetAcquisitions,
)

end # module
