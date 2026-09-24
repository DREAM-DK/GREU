# Define the resident consumption tree and its product groups.
# Keep equations and source data in their own modules.
module ConsumptionGroupsSettings

import ..InputOutputSettings: product, product_members, member_section

# Nesting and elasticity of the full consumption tree.
const full_consumption_nesting = Dict(
  :HouSer => (children = [:cHouEne, :cHou], elasticity = 0.3),
  :CarSer => (children = [:cCarEne, :cCar], elasticity = 0.3),
  :Goods => (children = [:cFood, :cNonFood], elasticity = 0.3),
  :GooTouSer => (children = [:Goods, :cSer], elasticity = 0.94),
  :NonHou => (children = [:GooTouSer, :CarSer], elasticity = 1.04),
  :total => (children = [:NonHou, :HouSer], elasticity = 0.3),
)

const leaf_by_member = Dict(
  "D" => :cHouEne,
  "C19" => :cCarEne,
  "L68A" => :cHou,
  "L68B" => :cHou,
  "C29" => :cCar,
  "A01" => :cFood,
  "C10-12" => :cFood,
)
const service_sections = Set(Symbol(string(c)) for c in 'I':'U')

member_leaf(code) =
  get(leaf_by_member, code, member_section(code) in service_sections ? :cSer : :cNonFood)

"""Return the one consumption leaf that holds every member of a product group."""
function product_leaf(p, members)
  leaves = unique(member_leaf.(members))
  @assert length(leaves) == 1 "Product $p covers consumption leaves $leaves. Use a finer industry resolution or merge these leaves."
  return only(leaves)
end

const consumption_leaf_by_product = Dict(p => product_leaf(p, product_members[p]) for p in product)
const product_by_consumption_leaf = Dict(
  leaf => [p for p in product if consumption_leaf_by_product[p] == leaf]
  for leaf in unique(values(consumption_leaf_by_product))
)
@assert all(
    isfinite(spec.elasticity) && spec.elasticity > 0 && allunique(spec.children)
    for spec in values(full_consumption_nesting)
) "Each consumption nest needs a positive elasticity and unique children"

@assert Set(values(leaf_by_member)) ⊆ setdiff(
  Set(c for spec in values(full_consumption_nesting) for c in spec.children),
  Set(keys(full_consumption_nesting)),
) "leaf_by_member names a leaf that the consumption tree does not contain"

end # module
