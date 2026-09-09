# Define production factors, nests, and source settings.
# Put energy and materials in separate intermediate-input leaves.
# Keep equations and country data in their own modules.
module ProductionSettings

using CSV
using DataFrames

import ..InputOutputSettings:
  product,
  product_sections,
  source_industry,
  industry_sections,
  products_in_sections
import ..Settings: calibration_year

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
# Energy is still defined economically as mining/quarrying and electricity/gas,
# but the selected products may now be more detailed than A21.
const energy_product = products_in_sections([:B, :D])
const intermediate_type = [:energy, :materials]
@assert !isempty(energy_product) && energy_product ⊆ product "Energy products must be input-output products"

const full_nesting = Dict(
  :KE => (children = [:equipment, :energy], elasticity = 0.7),
  :KEL => (children = [:KE, :labor], elasticity = 0.7),
  :KELB => (children = [:KEL, :structures], elasticity = 0.7),
  :KELBM => (children = [:KELB, :materials], elasticity = 0.7),
)

# ============================================================================
# Data-driven nest pruning
# ============================================================================
# A CES nest whose children all have zero base-year value cannot price itself:
# pProd[n] * qProd[n] == 0 holds for any pProd[n], and the uProd calibration row
# loses its derivative with respect to uProd. 
const factor_leaf = [:equipment, :structures, :labor, :energy, :materials]
const factor_tolerance = 1e-6

# Each file stores (leaf, industry, year) in its `indices` column.
const factor_sources = [
  (joinpath(production_data_dir, "production_capital.csv"), "qK_k_i"),
  (joinpath(production_data_dir, "production_labor.csv"), "qL_l_i"),
  (joinpath(production_data_dir, "production_intermediate_product_split.csv"), "qM_m_i"),
]

"""Base-year value of each production leaf by industry.

Return `nothing` when the production data has not been built yet, so that this
module still loads during a data refresh and while the industry resolver runs.
"""
function base_factor_values()
  values = Dict{Tuple{Symbol,Symbol},Float64}()
  for (file, var) in factor_sources
    isfile(file) || return nothing
    for row in eachrow(CSV.read(file, DataFrame))
      string(row.variable) == var || continue
      parts = split(String(row.indices), ',')
      length(parts) == 3 || continue
      parse(Int, parts[3]) == calibration_year || continue
      leaf = Symbol(parts[1])
      leaf in factor_leaf || continue
      key = (leaf, Symbol(parts[2]))
      values[key] = get(values, key, 0.0) + Float64(row.value)
    end
  end
  return values
end

"""Prune a nest map to the leaves an industry actually uses.

Drop leaves with no base-year value, drop nests that lose every child, and
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

const base_factors = base_factor_values()

live_leaves(i) =
  isnothing(base_factors) ? Set(factor_leaf) :
  Set(f for f in factor_leaf if abs(get(base_factors, (f, i), 0.0)) > factor_tolerance)

  const production_nesting = Dict(
    i => if isnothing(base_factors)
      industry_sections[i] == Set([:T]) ?
        Dict(:KELBM => (children = [:labor], elasticity = 0.7)) : Dict(full_nesting)
    else
      live = live_leaves(i)
      isempty(live) ? Dict(:KELBM => (children = [:labor], elasticity = 0.7)) :
                      prune_nesting(full_nesting, live)
    end
    for i in source_industry
  )

if !isnothing(base_factors)
  collapsed = [i for i in source_industry if length(production_nesting[i]) < length(full_nesting)]
  isempty(collapsed) ||
    @info "Collapsed production nests for unused factors" industries = join(string.(collapsed), ", ")
  # An industry with no factors at all cannot be given a well-posed tree here.
  # It must be kept out of the model industry set; see InputOutput.jl.
  empty_industries = [i for i in source_industry if isempty(live_leaves(i))]
  isempty(empty_industries) ||
    @warn "Industries with no production factors in the calibration year" industries = join(string.(empty_industries), ", ")
end

@assert all(!isempty(nests) for nests in values(production_nesting)) "Every industry needs at least one production nest"

@assert allunique([capital_type; labor_type; intermediate_type]) "Production factor labels must be unique"
@assert all(
  isfinite(spec.elasticity) && spec.elasticity > 0 && allunique(spec.children)
  for spec in Iterators.flatten(values(nests) for nests in values(production_nesting))
) "Each production nest needs a positive elasticity and unique children"

end # module