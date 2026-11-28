# Define production factors, nests, and source settings.
# Put energy and materials in separate intermediate-input leaves.
# Keep equations and country data in their own modules.
module ProductionSettings

import ..InputOutputSettings: product, product_members, source_industry, industry_members, industries_in_sections

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

# Labor types by education. They must match the names in labor_type_shares.csv.
const labor_type = [:unskilled, :skilled, :tertiary]
const intermediate_type = [:energy, :materials]
const product_to_intermediate_type = Dict(
  p => (product_members[p] ⊆ ("B", "C19", "D") ? :energy : :materials) for p in product
)

const full_nesting = Dict(
  :nonTertiary => (children = [:unskilled, :skilled], elasticity = 1.5),
  :labor => (children = [:nonTertiary, :tertiary], elasticity = 1.5),
  :KE => (children = [:equipment, :energy], elasticity = 0.7),
  :KEL => (children = [:KE, :labor], elasticity = 0.6),
  :KELB => (children = [:KEL, :structures], elasticity = 0.5),
  :KELBM => (children = [:KELB, :materials], elasticity = 0.5),
)

# ============================================================================
# Elasticities by sector
# ============================================================================
# Sector values replace the defaults in full_nesting. KE takes the GAMS MKE value.
# Industries outside these sectors, such as water and waste (E), keep the defaults.
const sector_elasticity = Dict(
  :other => (;),
  :agriculture => (KELBM = 0.00, KELB = 0.07, KEL = 0.67),
  :manufacturing => (KELBM = 1.30, KELB = 0.23, KEL = 0.51),
  # Food processing has a limited ability to switch from primary inputs.
  :food => (KELBM = 0.10, KELB = 0.23, KEL = 0.51),
  :services => (KELBM = 0.66, KELB = 0.59, KEL = 1.17),
  :construction => (KELBM = 0.88, KELB = 0.90, KEL = 0.82, KE = 0.73),
  :extraction => (KELBM = 0.51, KELB = 0.02, KEL = 0.29),
  :energy => (KELBM = 0.24, KELB = 0.10, KEL = 0.10),
  # Maritime transport uses the service values.
  :shipping => (KELBM = 0.66, KELB = 0.59, KEL = 1.17),
  :housing => (KELBM = 0.10, KELB = 0.10, KEL = 0.10, KE = 0.10),
)

industries_with_members(codes) = [i for (i, members) in industry_members if members ⊆ codes]

# Later entries replace earlier ones.
const elasticity_sector = merge(
  Dict(i => :other for i in source_industry),
  Dict(i => :services for i in industries_in_sections(Symbol.('G':'U'))),
  Dict(i => :agriculture for i in industries_in_sections([:A])),
  Dict(i => :extraction for i in industries_in_sections([:B])),
  Dict(i => :manufacturing for i in industries_in_sections([:C])),
  Dict(i => :food for i in industries_with_members(["C10-12"])),
  Dict(i => :energy for i in industries_in_sections([:D])),
  Dict(i => :construction for i in industries_in_sections([:F])),
  Dict(i => :shipping for i in industries_with_members(["H50"])),
  Dict(i => :housing for i in industries_in_sections([:L])),
)

"""Return the full nest map with the elasticities of the sector of industry `i`."""
industry_nesting(i) = Dict(
  n => (children = spec.children, elasticity = get(sector_elasticity[elasticity_sector[i]], n, spec.elasticity))
  for (n, spec) in full_nesting
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
@assert all(allunique(spec.children) for spec in values(full_nesting)) "Each production nest needs unique children"
@assert all(keys(nests) ⊆ keys(full_nesting) for nests in values(sector_elasticity)) "Sector elasticities must use known nests"
@assert all(
  isfinite(spec.elasticity) && spec.elasticity >= 0
  for i in source_industry for spec in values(industry_nesting(i))
) "Each production nest needs a finite, non-negative elasticity"

end # module
