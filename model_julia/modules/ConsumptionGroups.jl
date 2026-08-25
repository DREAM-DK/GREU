# Allocate resident consumption through a small CES tree.
# Use fixed product coefficients within each leaf group.
# Split tourist demand across products with fixed shares.
# Exclude the total consumption and saving choice.

module ConsumptionGroups

using SquareModels
import ..DataUtils: read_series
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  pC,
  pPurchaserUse_p_u,
  product,
  qC,
  qC_p,
  qCTourist,
  vCTourist
import ..model
import ..SectorAccountsSettings: sector_accounts_data_dir
import ..Tags: ForecastConstant
import ..Time: t, t1, T

# ============================================================================
# Read data
# ============================================================================

const sector_accounts_file = joinpath(sector_accounts_data_dir, "sector_accounts.csv")
const vHhConsumption_data = read_series(sector_accounts_file, "vHhConsumption", t)

# ============================================================================
# Indices
# ============================================================================

const consumption_group = [:goods, :services]
const consumption_nest = [:total]
const top_consumption_nest = :total
const inner_consumption_nest = Symbol[]
const consumption_node = consumption_group
const consumption_product = sort(unique(p for (p, year) in keys(qC_p)))

const consumption_nest_children = Dict(
  :total => consumption_group,
)
const consumption_parent = Dict(
  child => nest
  for (nest, children) in consumption_nest_children
  for child in children
)
const product_by_consumption_group = Dict(
  :goods => product[1:8],
  :services => product[9:end],
)
const active_product_by_consumption_group = Dict(
  group => intersect(products, consumption_product)
  for (group, products) in product_by_consumption_group
)
const consumption_group_by_product = Dict(
  p => group
  for (group, products) in product_by_consumption_group
  for p in products
)

@assert Set(keys(consumption_nest_children)) == Set(consumption_nest) "Each consumption nest needs children"
@assert Set(keys(consumption_parent)) == Set(consumption_node) "Each non-root consumption node needs one parent"
@assert Set(keys(consumption_group_by_product)) == Set(product) "Consumption groups must cover all products"
@assert (
  sum(length, values(product_by_consumption_group)) == length(product)
) "A product must be in only one consumption group"

# ============================================================================
# Variables
# ============================================================================

const ConsumptionGroupsTag = Tag(:ConsumptionGroups)

@variables model :: (ConsumptionGroupsTag, GrowthAdjusted) begin
  qCNode_a[a=consumption_node, t=t], "Resident consumption quantity by CES node."
  qCTourist_p[p=consumption_product, t=t], "Tourist consumption quantity by product."
end

@variables model :: (ConsumptionGroupsTag, InflationAdjusted) begin
  pCNode_a[a=consumption_node, t=t], "Resident consumption price by CES node."
end

@variables model :: ConsumptionGroupsTag begin
  uCNode_a[a=consumption_node, t=t] :: ForecastConstant, "CES share by non-root consumption node."
  uCProduct_p[p=consumption_product, t=t] :: ForecastConstant, "Fixed product coefficient within its consumption group."
  uCTourist_p[p=consumption_product, t=t] :: ForecastConstant, "Fixed product share of tourist consumption."
  eCNest_n[n=consumption_nest], "Substitution elasticity by consumption nest."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  source_consumption = vHhConsumption_data[t1-first(t)+1]
  @assert !isnothing(source_consumption) "Source household consumption must exist at t1"
  @assert source_consumption > 0 "Source household consumption must be positive"
  db[qC[t1]] = source_consumption

  source_product_total = sum(db[qC_p[p,t1]] for p in consumption_product)
  @assert source_product_total > 0 "Source product consumption must be positive"
  db[uCTourist_p] .= [
    db[qC_p[p,t1]] / source_product_total
    for p in consumption_product, year in t
  ]
  db[eCNest_n] .= 2.0

  db[qCNode_a[consumption_group,t1]] .= [
    source_consumption * sum(
      db[qC_p[p,t1]] for p in active_product_by_consumption_group[group]
    ) /
      source_product_total
    for group in consumption_group
  ]
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================

function set_starting_values!(start_values)
  tourist_quantity = start_values[vCTourist[t1]]
  start_values[pC[t1:T]] .= 1.0
  start_values[pCNode_a] .= 1.0
  start_values[qCNode_a] .= [
    start_values[qCNode_a[a,t1]]
    for a in consumption_node, year in t
  ]

  start_values[qCTourist[t1:T]] .= tourist_quantity
  start_values[qCTourist_p] .= [
    start_values[uCTourist_p[p,t1]] * tourist_quantity
    for p in consumption_product, year in t
  ]
  @assert all(
    start_values[qC_p[p,t1]] - start_values[qCTourist_p[p,t1]] > 0
    for p in consumption_product
  ) "Initial resident product consumption must be positive"

  parent_quantity = Dict(
    top_consumption_nest => start_values[qC[t1]],
    (a => start_values[qCNode_a[a,t1]] for a in consumption_node)...,
  )
  start_values[uCNode_a] .= [
    start_values[qCNode_a[a,t1]] / parent_quantity[consumption_parent[a]]
    for a in consumption_node, year in t
  ]
  start_values[uCProduct_p] .= [
    (start_values[qC_p[p,t1]] - start_values[qCTourist_p[p,t1]]) /
      start_values[qCNode_a[consumption_group_by_product[p],t1]]
    for p in consumption_product, year in t
  ]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    # CES quantity demand from the root.
    qCNode_a[a=consumption_nest_children[top_consumption_nest], t=t1:T],
    qCNode_a[a,t] / qC[t] *
      (pCNode_a[a,t] / pC[t])^eCNest_n[top_consumption_nest] == uCNode_a[a,t]

    # CES quantity demand from each inner nest.
    qCNode_a[a=consumption_node, t=t1:T; consumption_parent[a] in inner_consumption_nest],
    qCNode_a[a,t] / qCNode_a[consumption_parent[a],t] *
      (pCNode_a[a,t] / pCNode_a[consumption_parent[a],t])^eCNest_n[consumption_parent[a]] ==
        uCNode_a[a,t]

    # Each nest value equals the value of its children.
    pC[t=t1:T],
    pC[t] == ∑(
      pCNode_a[a,t] * qCNode_a[a,t]
      for a in consumption_nest_children[top_consumption_nest]
    ) / qC[t]

    pCNode_a[n=inner_consumption_nest, t=t1:T],
    pCNode_a[n,t] == ∑(
      pCNode_a[a,t] * qCNode_a[a,t]
      for a in consumption_nest_children[n]
    ) / qCNode_a[n,t]

    # A leaf price values its fixed resident product bundle.
    pCNode_a[g=consumption_group, t=t1:T],
    pCNode_a[g,t] == ∑(
      pPurchaserUse_p_u[p,:C,t] * (qC_p[p,t] - qCTourist_p[p,t])
      for p in active_product_by_consumption_group[g]
    ) / qCNode_a[g,t]

    # Tourist demand uses a fixed product split outside the resident CES tree.
    qCTourist_p[p=consumption_product, t=t1:T], qCTourist_p[p,t] / qCTourist[t] == uCTourist_p[p,t]
    qC_p[p=consumption_product, t=t1:T],
    (qC_p[p,t] - qCTourist_p[p,t]) / qCNode_a[consumption_group_by_product[p],t] == uCProduct_p[p,t]

    vCTourist[t=t1:T],
    vCTourist[t] / qCTourist[t] == ∑(
      pPurchaserUse_p_u[p,:C,t] * uCTourist_p[p,t]
      for p in consumption_product
    )

    # Post-solve identities and bounds.
    @test_constraint("Tourist product shares must sum to one"; atol=1e-10, rtol=0)
    qCTourist[t=t1:T], ∑(uCTourist_p[p,t] for p in consumption_product) == 1

    @test_constraint("Resident product consumption must be positive"; atol=0, rtol=0)
    qC_p[p=consumption_product, t=t1:T], qC_p[p,t] - qCTourist_p[p,t] >= 1e-12

    @test_constraint("Consumption node prices must be positive"; atol=0, rtol=0)
    pCNode_a[a=consumption_node, t=t1:T], pCNode_a[a,t] >= 1e-12
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    uCNode_a[a=consumption_node, t=[t1]], qCNode_a[a=consumption_node, t=[t1]]
    uCProduct_p[p=consumption_product, t=[t1]], qC_p[p=consumption_product, t=[t1]]
    qCTourist[t1], vCTourist[t1]
  end

  return block
end

end # module
