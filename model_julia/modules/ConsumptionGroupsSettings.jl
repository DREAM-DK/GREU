# Define the resident consumption tree and its product groups.
# Keep equations and source data in their own modules.
module ConsumptionGroupsSettings

import ..InputOutputSettings: product

const consumption_nesting = Dict(
  :total => (children = [:goods, :services], elasticity = 0.5),
)

const product_by_consumption_group = Dict(
  :goods => product[1:8],
  :services => product[9:end],
)

end # module
