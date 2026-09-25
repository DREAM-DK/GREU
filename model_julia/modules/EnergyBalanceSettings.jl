# Static energy-account sets and PEFA source mappings.
# Keep the fetch and the balance checks in EnergyBalanceData.jl.

module EnergyBalanceSettings

const energy_balance_data_dir = joinpath(@__DIR__, "..", "data", "energy_balance")

# Point to the PEFA dataset in Eurostat's data portal.
const eurostat_pefa_dataset = "env_ac_pefasu"

# PEFA publishes terajoules. The model wants petajoules.
# We convert once on loading in the data.
const source_unit = "TJ"
const pj_per_source_unit = 1e-3

# PEFA is a physical flow account, so every resident activity conserves energy:
# what is taken in must come out again (Thermodynamics!). 
# Total input therefore equals total output for each activity - but only when also accounting for residuals.
# This is why R30 transformation losses sit in source_product beside the energy prodocts.

# Individual products do not balance within an activity, because activities transform
# one product into another: a factory takes in coal and transforms it into electricity.

# The balance holds for resident activities (agriculture, industry, transport, etc.) only. 
# The boundary accounts (environment, rest of world, inventories) below
# are where energy enters and leaves the economy, so they do not balance and
# must not be checked. This is because boundary accounts are more like bookkeeping
# entries than like activities.

# Tolerance is relative to the activity's own throughput, with an absolute floor:
# NACE sections T (households as employers) and U (extraterritorial bodies) report
# zero energy, and a purely relative tolerance would divide by zero.
const activity_balance_rtol = 1e-4
const activity_balance_atol = 1e-3



# ========================================
# Energy products
# ========================================
# See bottom of code for description!

# Natural inputs cross the boundary from the environment into the economy.
const natural_input = ["N01", "N02", "N03", "N04", "N05", "N06", "N07"]

# Energy products circulate inside the economy. Only these carry money: 
# the monetary account has no price for a natural input or a residual.
const energy_product = [
  "P08", "P09", "P10", "P11", "P12", "P13", "P14", "P15", "P16", "P17",
  "P18", "P19", "P20", "P21", "P22", "P23", "P24", "P25", "P26", "P27",
]

# Residuals leave the economy again. R30 carries losses and dissipative heat
# and is the largest single flow in the whole account.
const residual = ["R28", "R29", "R30", "R31"]

const source_product = [natural_input; energy_product; residual]

# Build lookup table for product groups.
const product_group = Dict(
  vcat(
    [code => :natural_input for code in natural_input],
    [code => :energy_product for code in energy_product],
    [code => :residual for code in residual],
  ),
)
@assert length(product_group) == length(source_product) "each source product needs exactly one group"

# Group totals. PEFA reports them beside the cells, so adding them double counts.
# EPRD_OUSE is energy products for own use.
const source_product_aggregate = [
  "N00", "P00", "R00", "N00_P00_R00", "EPRD_OUSE",
]
@assert isempty(intersect(source_product, source_product_aggregate)) "aggregates must stay out of the cells"


# Not an aggregate. SD_IO is the discrepancy PEFA books when a country's supply
# and use do not close (supply - use ≠ 0). It adds the missing amount, so it
# double counts nothing: it is what makes the account close.
# Denmark reports SD_IO = 0, so a check on Denmark alone cannot show it. Other
# countries fail the balance without it (12 of 34 on the last check, 2026-09-04).
# Keep it out of source_product: it is not an energy product, so it gets no
# product variable, price or emission factor. Keep it in the balance sum: the
# account does not close without it. The model reads it once per account, as
# qEDiscrepancy_d on the supply side, so the model asserts the same balance as
# the data step.
const discrepancy_product = "SD_IO"
@assert discrepancy_product ∉ [source_product; source_product_aggregate] "the discrepancy is neither a product nor an aggregate"


# =======================================
# Activities
# =======================================

# PEFA and the model spell the compound NACE groups differently, and PEFA is not
# even consistent with itself: C10-C12 and E37-E39 use a hyphen, C31_C32 and J59_J60 use underscore.
# Both appear in the same table, same year.
# The model uses hyphenation, so we do too.

canonical_activity_code(code::AbstractString) =
  replace(code, r"^([A-U])(\d{2})[-_]\1(\d{2})$" => s"\1\2-\3")


# Both separators occur in PEFA's nace_r2 dimension.
# A rule that knew only one would drop industries silently.
@assert all(canonical_activity_code(pefa) == model for (pefa, model) in [
  "C10-C12" => "C10-12", "C13-C15" => "C13-15", "E37-E39" => "E37-39",
  "N80-N82" => "N80-82", "R90-R92" => "R90-92",
  "C31_C32" => "C31-32", "J59_J60" => "J59-60", "J62_J63" => "J62-63",
  "M69_M70" => "M69-70", "M74_M75" => "M74-75", "Q87_Q88" => "Q87-88",
]) "PEFA activity codes must normalise to the model's spelling"

# Household, boundary and aggregate codes also contain separators and must pass unchanged.
@assert all(canonical_activity_code(code) == code for code in [
  "A", "B", "C16", "D", "L", "L68A", "T", "U",
  "HH", "HH_HEAT", "HH_TRA", "HH_OTH",
  "ENV", "ROW_ACT", "CH_INV_PA",
  "TOTAL", "NRG_FLOW", "SD_SU", "G-U_X_H",
]) "only NACE industry codes may be rewritten"





const households = :households

# Households are the only place PEFA observes purpose. Industry rows carry no purpose split at all.
const household_purpose = Dict(
  "HH_HEAT" => :heating,
  "HH_TRA" => :transport,
  "HH_OTH" => :other,
)

# An explicit member, not a missing value. Industry purpose is a construction job,
# and keeping the slot means filling it later changes the aggregation step alone, never the shape of the account.
const unspecified = :unspecified

const purpose = [
  :heating,
  :transport,
  :other,
  unspecified,
]
@assert Set(values(household_purpose)) ⊆ Set(purpose) "household purposes must be in the purpose set"


# Household activity codes, as PEFA spells them.
const source_household = collect(keys(household_purpose))



# =======================================
# Boundary accounts
# =======================================

# Energy enters and leaves the resident economy through three accounts. They are
# the counterparts of the flows the activities balance against: an activity that
# takes in wind gets it from ENV, and one that gives off waste heat gives it to
# ENV. They do not balance, and must stay out of the activity balance check.
#
# The model needs them. energy_and_emissions (data from Statistics Denmark) has flow = other_supply, import,
# export and invent_change, and the GAMS model has demand codes xEne and
# invt_ene. Denmark 2020 confirms the fit: ROW_ACT (energy_and_emissions) use is 402.5 PJ against the
# Danish export of 402.3 PJ (Eurostat data).
#
# ENV supply is wider than the Danish other_supply: it also carries fossil
# natural inputs. The matching subset is the renewable natural inputs
# N03 + N04 + N05 + N07, which equal Danish renewable + heat_pump exactly.
const boundary_account = Dict(
  "ENV" => :environment,          # natural inputs in, residuals and losses out
  "ROW_ACT" => :rest_of_world,    # supply is imports, use is exports
  "CH_INV_PA" => :inventories,    # changes in stocks
)
const source_boundary = collect(keys(boundary_account))

# Totals and memo items. Each re-counts what the activities and boundary
# accounts already hold, so taking any of them double counts.
#
# TOTAL covers the NACE activities and leaves households out. Denmark 2020 has
# TOTAL 1857.2 PJ and HH 253.8 PJ, which give 2111.0 PJ of resident throughput.
# Add HH to TOTAL before you use either as a control sum.
#
# NRG_FLOW is the all-flow total. It adds the boundary accounts to the resident
# throughput: 2111.0 + ENV 379.7 + ROW_ACT 1167.7 + CH_INV_PA 44.5 = 3702.8 PJ.
# Nothing the model uses is comparable with it.
#
# G-U_X_H is "Services (except transportation and storage), so G to U except H".
# SD_SU is not a total. It is the discrepancy PEFA books per product for the whole economy,
# as SD_IO is per account. It belongs to no account, so it stays out the account set.
# But economy-wide supply only equals use per product with SD_SU in the sum.
#
# None of them is a key in the activity lookup, so they drop out when codes are mapped. 

#PEFA also publishes USE_TRS, USE_END and ER_USE. They re-cut the same use flow,
# so taking them alongside USE would double count.
const supply_flow = "SUP"
const use_flow = "USE"

end # module




# PEFA source product codes
# N01: Fossile non-renewable natural energy inputs (e.g. crude oil, natural gas, coal)
# N02: Nuclear non-renewable natural energy inputs 
# N03: Hydro-based renewable natural energy inputs
# N04: Wind-based renewable natural energy inputs
# N05: Solar-based renewable natural energy inputs
# N06: Biomass-based renewable natural energy inputs
# N07: Other renewable natural energy inputs (e.g. geothermal, tidal, wave)

# P08: Hard coal
# P09: Brown coal & peat
# P10: Derived/manufactured gases
# P11: Secondary coal products
# P12: Crude oil
# P13: Natural gas without bio-components
# P14: Motor spirit (gasoline) 
# P15: Kerosenes
# P16: Naphtha
# P17: Transport Diesel (without bio)
# P18: Heating and other gasoil (without bio)
# P19: Residual fuel oil
# P20: Refinery gas, ethane and LPG
# P21: Other petroleum products, additives, refinery feedstocks
# P22: Nuclear fuel
# P23: Wood, wood waste, other solid biomass, charcoal
# P24: Liquid biofuels
# P25: Biogas
# P26: Electrical energy
# P27: Heat

# R28: Renewable waste (non-crude/biomass waste elements)
# R29: Non-renewable waste (e.g. industrial or municipal plastic waste incinerated for heat)
# R30: Energy losses of all kinds (losses during extraction, transformation, distribution, and dissipative heat)
# R31: Energy incorporated in products for non-energy use




# A: Agriculture, forestry and fishing
# B: Mining and quarrying
# C: Manufacturing
# D: Electricity, gas, steam and air conditioning supply
# E: Water, sewage and waste management
# F: Construction
# G: Wholesale and retail trade
# H: Transportation and storage
# I: Accommodation and food service activities
# J: Information and communication
# K: Financial and insurance activities
# L: Real estate activities
# M: Professional, scientific and technical activities
# N: Administrative and support service activities
# O: Public administration and defence
# P: Education
# Q: Human health and social work activities
# R: Arts, entertainment and recreation
# S: Other service activities
# T: Hoiusehold-employer and own-use production activies
# U: Extraterritorial organisations and bodies



