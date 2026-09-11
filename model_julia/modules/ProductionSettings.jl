# Define production factors, nests, and source settings.
# Put energy and materials in separate intermediate-input leaves.
# Keep equations and country data in their own modules.
module ProductionSettings

import ..InputOutputSettings: product, product_members

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

const labor_type = [:labor]
const intermediate_type = [:energy, :materials]
const product_to_intermediate_type = Dict(
  p => (product_members[p] ⊆ ("B", "C19", "D") ? :energy : :materials) for p in product
)

const full_nesting = Dict(
  :KE => (children = [:equipment, :energy], elasticity = 0.7),
  :KEL => (children = [:KE, :labor], elasticity = 0.7),
  :KELB => (children = [:KEL, :structures], elasticity = 0.7),
  :KELBM => (children = [:KELB, :materials], elasticity = 0.7),
)

# ============================================================================
# Nest pruning
# ============================================================================

"""Prune a nest map to the leaves an industry actually uses.

Drop leaves outside the retained factor set, drop nests that lose every child, and
collapse a nest holding a single surviving child into that child. Always keep
the outermost nest, because the model needs exactly one top node per industry.
"""
function prune_nesting(nests, live_leaf::Set{Symbol})
  parent_of = Dict(c => n for (n, spec) in nests for c in spec.children)
  top = only(n for n in keys(nests) if !haskey(parent_of, n))

  resolved = Dict{Symbol,Union{Nothing,Symbol}}()
  function resolve(n)
    haskey(resolved, n) && return resolved[n]
    haskey(nests, n) || return resolved[n] = (n in live_leaf ? n : nothing)
    kept = [c for c in (resolve(c) for c in nests[n].children) if !isnothing(c)]
    return resolved[n] =
      isempty(kept) ? nothing :
      (length(kept) == 1 && n != top) ? only(kept) : n
  end
  for n in keys(nests)
    resolve(n)
  end

  pruned = Dict{Symbol,NamedTuple{(:children, :elasticity),Tuple{Vector{Symbol},Float64}}}()
  for (n, spec) in nests
    resolved[n] === n || continue
    kept = Symbol[c for c in (resolved[c] for c in spec.children) if !isnothing(c)]
    pruned[n] = (children = kept, elasticity = spec.elasticity)
  end
  return pruned
end

@assert allunique([capital_type; labor_type; intermediate_type]) "Production factor labels must be unique"
@assert all(
  isfinite(spec.elasticity) && spec.elasticity > 0 && allunique(spec.children)
  for spec in values(full_nesting)
) "Each production nest needs a positive elasticity and unique children"

end # module
