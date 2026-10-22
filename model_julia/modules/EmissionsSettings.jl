# Static sets and Eurostat source settings for the emissions account.
# Greenhouse gases only. The source also carries air pollutants, which are left out on purpose.
# Keep the fetch and the checks in EmissionsData.jl, and the equations in Emissions.jl.

module EmissionsSettings

import ..EnergyBalanceSettings: residual, source_product

const emissions_data_dir = joinpath(@__DIR__, "..", "data", "emissions")

# Point to the air emissions accounts in Eurostat's data portal.
# They report emissions by industry and by household purpose, not by fuel.
const eurostat_air_dataset = "env_ac_ainah_r2"

# Eurostat reports thousand tonnes. The model keeps emissions in kilotonnes, so no conversion is needed.
const emission_unit = "THS_T"


# =============================
# Gases
# =============================

# The reported greenhouse gas total. 
# Read it beside its parts, because it can differ from their sum.
const reported_total = "GHG"

# The six parts of the total, in CO2 equivalents. 
# CO2 here is fossil only.
const co2_equivalent_gas = ["CO2", "CH4_CO2E", "N2O_CO2E", "HFC_CO2E", "PFC_CO2E", "NF3_SF6_CO2E"]

# Methane and nitrous oxide in tonnes of gas. 
# Read them only to check the warming potentials against the source.
const mass_gas = ["CH4", "N2O"]

# Biogenic CO2. 
# Keep it outside the greenhouse gas total, and never subtract it from fossil CO2.
const biogenic_co2 = "CO2_BIO"

# Fossil CO2. In this source, CO2 without a suffix is fossil only.
const fossil_co2 = "CO2"


const source_gas = [reported_total; co2_equivalent_gas; mass_gas; biogenic_co2]
@assert allunique(source_gas) "each gas code must appear once"


# The source's total for the whole economy: all industries plus households.
const economy_total = "TOTAL_HH"

# Eurostat rounds each cell to 0.00001 kt, so sums of cells agree with the source's own totals to well within 0.001 kt, one tonne.
const sum_atol = 1e-3



# ===============================================
# Weights for methane and nitrous oxide
# ===============================================

# Global warming potentials over 100 years, from the IPCC's fifth assessment report (AR5).
# They turn tonnes of gas into tonnes of CO2 equivalents.
# The data step checks them against the ratio the source implies.
const warming_potential = [
  (gas = "CH4", co2_equivalent = "CH4_CO2E", factor = 28.0),
  (gas = "N2O", co2_equivalent = "N2O_CO2E", factor = 265.0),
]
const warming_potential_rtol = 1e-3
@assert Set(w.gas for w in warming_potential) == Set(mass_gas) "each gas in tonnes needs one warming potential"
@assert all(w.co2_equivalent in co2_equivalent_gas for w in warming_potential) "each warming potential must point to a part of the total"




# =============================
# Burned fuel
# =============================

# Emission factors multiply the fuel that is burned. PEFA calls it emission-relevant use.
# Total use also counts fuel that is turned into other products, such as crude oil in a refinery.
const emission_relevant_flow = "ER_USE"

# Waste has no use other than burning, so all its use counts as burned.
# Incineration plants can book the waste they burn as transformation use, which emission-relevant use leaves out.
const waste_product = ["R28", "R29"]
@assert waste_product ⊆ residual "waste codes must be PEFA residual codes"




# =============================
# Emission factors
# =============================

# CO2 per unit of burned fuel: IPCC 2006 default values (2006 IPCC Guidelines,
# Volume 2, Table 1.4). The 2019 Refinement did not change them.
# They are imported constants, not Eurostat data.
# Keep them in kg/TJ, as IPCC publishes them, so each value can be checked against the source.
# Where a PEFA product covers several fuels, the factor follows the fuel that is burned, not the label.
const co2_kg_per_tj = [
  # Fossil.
  (product = "N01", gas = "CO2", kg_per_tj = 56_100.0),   # natural gas: fuel burned at the fields is gas
  (product = "P08", gas = "CO2", kg_per_tj = 94_600.0),   # other bituminous coal
  (product = "P09", gas = "CO2", kg_per_tj = 94_600.0),   # other bituminous coal: P09 can hold hard coal
  (product = "P10", gas = "CO2", kg_per_tj = 56_100.0),   # natural gas: town gas made from natural gas
  (product = "P11", gas = "CO2", kg_per_tj = 107_000.0),  # coke oven coke
  (product = "P12", gas = "CO2", kg_per_tj = 73_300.0),   # crude oil
  (product = "P13", gas = "CO2", kg_per_tj = 56_100.0),   # natural gas
  (product = "P14", gas = "CO2", kg_per_tj = 69_300.0),   # motor gasoline
  (product = "P15", gas = "CO2", kg_per_tj = 71_500.0),   # jet kerosene
  (product = "P16", gas = "CO2", kg_per_tj = 73_300.0),   # naphtha
  (product = "P17", gas = "CO2", kg_per_tj = 74_100.0),   # gas/diesel oil
  (product = "P18", gas = "CO2", kg_per_tj = 74_100.0),   # gas/diesel oil
  (product = "P19", gas = "CO2", kg_per_tj = 77_400.0),   # residual fuel oil
  (product = "P20", gas = "CO2", kg_per_tj = 57_600.0),   # refinery gas
  (product = "P21", gas = "CO2", kg_per_tj = 97_500.0),   # petroleum coke
  (product = "R29", gas = "CO2", kg_per_tj = 91_700.0),   # municipal waste, non-biomass part
  # Biogenic.
  (product = "P23", gas = biogenic_co2, kg_per_tj = 112_000.0),  # wood and wood waste
  (product = "P24", gas = biogenic_co2, kg_per_tj = 70_800.0),   # biogasoline and biodiesel
  (product = "P25", gas = biogenic_co2, kg_per_tj = 54_600.0),   # other biogas
  (product = "R28", gas = biogenic_co2, kg_per_tj = 100_000.0),  # municipal waste, biomass part
]

# Nuclear fuel gives no CO2.
const no_co2_product = ["P22"]

# kg/TJ divided by 1000 is kt/PJ. The data step converts once, when it reads the table.
const kt_per_pj_per_kg_per_tj = 1e-3

@assert allunique(r.product for r in co2_kg_per_tj) "each product needs at most one CO2 factor"
@assert all(r.product in source_product for r in co2_kg_per_tj) "each factor must point to a PEFA product"
@assert all(r.gas in ("CO2", biogenic_co2) for r in co2_kg_per_tj) "each factor gives fossil or biogenic CO2"
@assert isdisjoint(no_co2_product, [r.product for r in co2_kg_per_tj]) "a product without CO2 cannot have a factor"
# A factor of 1000 is the easiest error here. Every fuel factor lies well inside 10-200 kt/PJ.
@assert all(10 <= r.kg_per_tj * kt_per_pj_per_kg_per_tj <= 200 for r in co2_kg_per_tj) "each factor must be between 10 and 200 kt/PJ"




# =============================
# Process rest
# =============================

# Fossil CO2 not from fuel is the reported CO2 minus the CO2 from burned fuel.
# The energy and emission tables can place a little fuel in different industries, 
# so a small negative rest is kept as it is. A rest below minus this share of the country's fossil CO2 means a factor or a mapping is wrong.
const max_negative_rest_share = 0.005


# =============================
# Reconciliation to the inventory
# =============================

# The bridge from the air emissions account, which follows the residence principle,
# to the inventory reported to the UN, which follows the territory principle.
const eurostat_bridge_dataset = "env_ac_aibrid_r2"

# The residence total, the inventory total with land use, and land use itself.
# The inventory total without land use is the second minus the third.
const residence_total = "AEMIS_RES"
const inventory_total = "AEMIS_TER_LULUCF"
const lulucf_total = "LULUCF"

# Residents' fuel bought abroad, all transport modes together.
const resident_abroad_total = "AEMIS_RES_ABR"

# The reconciliation items, named as in the GAMS model, and the bridge codes they hold.
# The items are subtracted from the residence total. Fuel that non-residents buy in the
# country adds to the territory, so it enters border trade with a minus.
# Other differences are what is left, so the inventory total is met exactly.
const bridge_item = [
  (item = :Bunkering, code = ["AEMIS_RES_ABR_WTR", "AEMIS_RES_ABR_LTR", "AEMIS_RES_ABR_FWTR"], sign = 1.0),
  (item = :InternationalAviation, code = ["AEMIS_RES_ABR_ATR"], sign = 1.0),
  (item = :BorderTrade, code = ["AEMIS_TER_NRES"], sign = -1.0),
]
@assert allunique(c for r in bridge_item for c in r.code) "each bridge code belongs to one item"




end # module EmissionsSettings


