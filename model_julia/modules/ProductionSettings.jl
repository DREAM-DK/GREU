module ProductionSettings

import ..InputOutputSettings: industry, product

const production_data_dir = joinpath(@__DIR__, "..", "data", "production")

# Capital enters production in the industry that owns the asset. The supply and
# use tables show the product supplier, so capital stocks and flows need their
# own source tables.
const capital_stock_dataset = "nama_10_nfa_st"
const capital_flow_dataset = "nama_10_a64_p5"

const stock_unit = "CRC_MEUR"
const stock_deflator_unit = "PYR_MEUR"
const flow_unit = "CP_MEUR"

# These non-overlapping ESA asset groups add to total fixed assets.
const stock_asset_to_capital_type = Dict(
  "N11KN" => :structures,
  "N11MN" => :equipment,
  "N115N" => :equipment,
  "N117N" => :equipment,
)

const flow_asset_to_capital_type = Dict(
  "N11KG" => :structures,
  "N11MG" => :equipment,
  "N115G" => :equipment,
  "N117G" => :equipment,
)

const capital_type = sort(unique(values(flow_asset_to_capital_type)))
@assert Set(capital_type) == Set(values(stock_asset_to_capital_type)) "Stock and flow assets must use the same capital types"

# Keep each factor class as a set, even when it has one member. The nests name
# their factors directly and must change when either set changes.
const labor_type = [:labor]
const intermediate_type = [:intermediate]

# Each industry owns its nest map and each nest owns its elasticity. Most
# industries use the full tree. Real estate has no live equipment stock, and
# household production has no live capital or intermediate input in the source
# data.
const full_capital_nesting = Dict(
  :KL => (children = [:equipment, :labor], elasticity = 0.7),
  :KLB => (children = [:KL, :structures], elasticity = 0.7),
  :KLBM => (children = [:KLB, :intermediate], elasticity = 0.7),
)
const production_nesting = Dict(
  i =>
    i == :iL ? Dict(
      :KLB => (children = [:structures, :labor], elasticity = 0.7),
      :KLBM => (children = [:KLB, :intermediate], elasticity = 0.7),
    ) :
    i == :iT ? Dict(
      :KLBM => (children = [:labor], elasticity = 0.7),
    ) :
    Dict(full_capital_nesting)
  for i in industry
)

# Dummy weights for the fixed-investment product split. Construction supplies
# structures. Other products split across capital types in proportion to the
# capital-flow totals. Replace these weights when asset-product data arrive.
const investment_product_capital_weight = Dict(
  (p, k) => p == :F ? (k == :structures ? 1.0 : 0.0) : 1.0
  for p in product, k in capital_type
)

@assert allunique([capital_type; labor_type; intermediate_type]) "Production factor labels must be unique"

# Dummy weights for the intermediate-input product split. All products currently
# feed the single materials type. Replace these weights when energy arrives.
const intermediate_product_type_weight = Dict(
  (p, m) => 1.0
  for p in product, m in intermediate_type
)
@assert all(
  isfinite(spec.elasticity) && spec.elasticity > 0 && allunique(spec.children)
  for spec in Iterators.flatten(values(nests) for nests in values(production_nesting))
) "Each production nest needs a positive elasticity and unique children"
@assert all(
  isfinite(weight) && weight >= 0
  for weight in values(investment_product_capital_weight)
) "Investment-product weights must be finite and non-negative"
@assert all(
  isfinite(weight) && weight >= 0
  for weight in values(intermediate_product_type_weight)
) "Intermediate-product weights must be finite and non-negative"

end # module
