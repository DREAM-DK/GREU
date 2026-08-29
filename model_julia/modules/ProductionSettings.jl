# Define production factors, nests, and source settings.
# Put energy and materials in separate intermediate-input leaves.
# Keep equations and country data in their own modules.
module ProductionSettings

import ..InputOutputSettings: product, section_to_industry, source_industry

const production_data_dir = joinpath(@__DIR__, "..", "data", "production")

# Capital enters production in the industry that owns the asset. The supply and
# use tables show the product supplier, so capital stocks and flows need their
# own source tables.
const capital_stock_dataset = "nama_10_nfa_st"
const capital_flow_dataset = "nama_10_a64_p5"

const stock_unit = "CRC_MEUR"
const stock_deflator_unit = "PYR_MEUR"
const flow_unit = "CP_MEUR"

# Gross value added by industry.
const gva_dataset = "nama_10_a64"
const gva_na_item = "B1G"
const production_tax_na_item = "D29X39"
const gva_unit = "CP_MEUR"
const gva_deflator_unit = "PYP_MEUR"
const gva_nace_to_industry = Dict(string(section) => i for (section, i) in section_to_industry)
@assert Set(values(gva_nace_to_industry)) == Set(source_industry) "GVA NACE map must cover each source industry"

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
const energy_product = [:B, :D]
const intermediate_type = [:energy, :materials]
@assert energy_product ⊆ product "Energy products must be input-output products"

# Each industry owns its nest map and each nest owns its elasticity. Equipment
# and energy pair in the first nest, then labor, structures, and materials
# enter one nest at a time. Most industries use this full tree.
const full_nesting = Dict(
  :KE => (children = [:equipment, :energy], elasticity = 0.7),
  :KEL => (children = [:KE, :labor], elasticity = 0.7),
  :KELB => (children = [:KEL, :structures], elasticity = 0.7),
  :KELBM => (children = [:KELB, :materials], elasticity = 0.7),
)

# Industry T (households as employers) reports only labor, so its top nest holds labor alone.
const production_nesting = Dict(
  i =>
    i == :iT ? Dict(
      :KELBM => (children = [:labor], elasticity = 0.7),
    ) :
    Dict(full_nesting)
  for i in source_industry
)

@assert allunique([capital_type; labor_type; intermediate_type]) "Production factor labels must be unique"

@assert all(
  isfinite(spec.elasticity) && spec.elasticity > 0 && allunique(spec.children)
  for spec in Iterators.flatten(values(nests) for nests in values(production_nesting))
) "Each production nest needs a positive elasticity and unique children"

end # module
