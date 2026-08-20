module ProductionSettings

const production_data_dir =  joinpath(@__DIR__, "..", "data", "production")
# ==========================================================================
# Eurostat datasets
# ==========================================================================
# Capital enters production from the perspective of the industry that owns the
# asset. The input-output table only knows the supplier, so both stock and
# investment are fetched separately here.

const capital_stock_dataset = "nama_10_nfa_st"   # -> qK_k_i
const capital_flow_dataset  = "nama_10_a64_p5"   # -> qI_k_i

const stock_unit = "CRC_MEUR"   # current replacement costs
const flow_unit  = "CP_MEUR"    # current prices
const stock_deflator_unit = "PYR_MEUR"   # previous year replacement costs

# ==========================================================================
# Assets
# ==========================================================================
# The model has two capital types, so the ESA 2010 asset hierarchy is collapsed
# onto them. These four codes are mutually exclusive and sum to total fixed
# assets (N11G), which must be excluded: an aggregate alongside its components
# double counts.

# Net assets used for capital stocks qK_k_i
const stock_asset_to_capital_type = Dict(
  "N11KN" => :structures,
  "N11MN" => :equipment,
  "N115N" => :equipment,
  "N117N" => :equipment,
)

# Gross assets used for investment flows qI_k_i
const flow_asset_to_capital_type = Dict(
  "N11KG" => :structures,
  "N11MG" => :equipment,
  "N115G" => :equipment,
  "N117G" => :equipment,
)



end # module