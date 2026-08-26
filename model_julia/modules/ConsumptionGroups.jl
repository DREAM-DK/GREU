# Allocate resident consumption through a small CES tree.
# Use fixed product coefficients within each leaf group.
# Split tourist demand across products with fixed shares.
# Exclude the total consumption and saving choice.
include(joinpath(@__DIR__, "ConsumptionGroupsSettings.jl"))

module ConsumptionGroups

using SquareModels
import ..ConsumptionGroupsSettings: consumption_nesting, product_by_consumption_group
import ..DataUtils: read_series
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  pC,
  pPurchaserUse_p_u,
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

const parent = Dict(
  child => nest
  for (nest, spec) in consumption_nesting
  for child in spec.children
)
const topNest = only(n for n in keys(consumption_nesting) if !haskey(parent, n))
const node = sort(unique(
  child
  for spec in values(consumption_nesting)
  for child in spec.children
))
const consumption_product = sort(unique(p for (p, year) in keys(qC_p)))

const active_product_by_consumption_group = Dict(
  group => intersect(products, consumption_product)
  for (group, products) in product_by_consumption_group
)
const consumption_group_by_product = Dict(
  p => group
  for (group, products) in product_by_consumption_group
  for p in products
)

# ============================================================================
# Variables
# ============================================================================

const ConsumptionGroupsTag = Tag(:ConsumptionGroups)

@variables model :: (ConsumptionGroupsTag, GrowthAdjusted) begin
  qCNode_a[a=node, t=t], "Resident consumption quantity by CES node."
  qCTourist_p[p=consumption_product, t=t], "Tourist consumption quantity by product."
end

@variables model :: (ConsumptionGroupsTag, InflationAdjusted) begin
  pCNode_a[a=node, t=t], "Resident consumption price by CES node."
end

@variables model :: ConsumptionGroupsTag begin
  uCNode_a[a=node, t=t] :: ForecastConstant, "CES share by non-root consumption node."
  uCProduct_p[p=consumption_product, t=t] :: ForecastConstant, "Fixed product coefficient within its consumption group."
  uCTourist_p[p=consumption_product, t=t] :: ForecastConstant, "Fixed product share of tourist consumption."
  eC[n=collect(keys(consumption_nesting))], "Substitution elasticity by consumption nest."
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
  db[eC] .= only(values(consumption_nesting)).elasticity

  # Group prices set the quantity units for calibration.
  db[pCNode_a] .= 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    qCNode_a[a=node, t=t1:T],
    qCNode_a[a,t] * pCNode_a[a,t]^eC[parent[a]] ==
      uCNode_a[a,t] * qC[t] * pC[t]^eC[parent[a]]

    pC[t=t1:T],
    pC[t] * qC[t] == ∑(pCNode_a[a,t] * qCNode_a[a,t] for a in consumption_nesting[topNest].children)

    # A leaf price values its fixed resident product bundle.
    pCNode_a[g=node, t=t1:T],
    pCNode_a[g,t] * qCNode_a[g,t] == ∑(
      pPurchaserUse_p_u[p,:C,t] * (qC_p[p,t] - qCTourist_p[p,t])
      for p in active_product_by_consumption_group[g]
    )

    # Tourist demand uses a fixed product split outside the resident CES tree.
    qCTourist_p[p=consumption_product, t=t1:T],
    qCTourist_p[p,t] == uCTourist_p[p,t] * qCTourist[t]
    qC_p[p=consumption_product, t=t1:T],
    qC_p[p,t] - qCTourist_p[p,t] == uCProduct_p[p,t] * qCNode_a[consumption_group_by_product[p],t]

    vCTourist[t=t1:T],
    vCTourist[t] == qCTourist[t] * ∑(
      pPurchaserUse_p_u[p,:C,t] * uCTourist_p[p,t] for p in consumption_product
    )

    # Post-solve identities and bounds.
    @test_constraint("Tourist product shares must sum to one"; atol=1e-10, rtol=0)
    qCTourist[t=t1:T], ∑(uCTourist_p[p,t] for p in consumption_product) == 1
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  # Identify CES shares while group prices set the base-year quantity units.
  block = define_equations()

  @endo_exo_swap! block begin
    uCNode_a[:,t1], pCNode_a[:,t1]
    uCProduct_p[p=consumption_product, t=[t1]], qC_p[p=consumption_product, t=[t1]]
    qCTourist[t1], vCTourist[t1]
  end

  return block
end

end # module
