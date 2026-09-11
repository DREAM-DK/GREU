# Define the resident consumption tree and its product groups.
# Keep equations and source data in their own modules.
module ConsumptionGroupsSettings

import ..InputOutputSettings: product, product_sections

const consumption_nesting = Dict(
  :total => (children = [:goods, :services], elasticity = 0.5),
)

# A selected common group must not straddle the goods/services boundary.
const goods_sections = Set(Symbol(string(c)) for c in 'A':'H')
const service_sections = Set(Symbol(string(c)) for c in 'I':'U')
@assert all(product_sections[p] ⊆ goods_sections || product_sections[p] ⊆ service_sections for p in product) "A common product group straddles the goods/services boundary"
const product_by_consumption_group = Dict(
  :goods => [p for p in product if product_sections[p] ⊆ goods_sections],
  :services => [p for p in product if product_sections[p] ⊆ service_sections],
)

end # module
