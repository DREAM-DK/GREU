# Define costs from a change in the capital growth rate.
# Add output loss and exact marginal terms through Production and Capital hooks.
# Exclude capital accumulation, investment shares, and the base user cost.
module CapitalAdjustmentCosts

using SquareModels
import ..Capital:
  pKAdjCost_k_i,
  qK_k_i,
  rHurdleRate_i
import ..GrowthInflationAdjustment: GrowthAdjusted, fp, fq
import ..InputOutput: industry
import ..Production: pProd, qProductionLoss, qK_k_i_data, topNest
import ..ProductionSettings: capital_type
import ..model
import ..Time: t1, T, tBase
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CapitalAdjustmentCostsTag = Tag(:CapitalAdjustmentCosts)

@variables model :: (CapitalAdjustmentCostsTag, GrowthAdjusted) begin
  qKAdjCost_k_i[(k,i,t)=qK_k_i], "Capital adjustment cost by type and industry."
end

@variables model :: CapitalAdjustmentCostsTag begin
  fKAdjCost[(k,i,t)=qK_k_i] :: ForecastConstant, "Adjustment-cost factor by capital type and industry."
  rKCapitalGrowthChange[(k,i,t)=qK_k_i], "Change in the capital growth rate by type and industry."
  dKAdjCost2dK[(k,i,t)=qK_k_i], "Adjustment-cost derivative for current capital by type and industry."
  dKAdjCost2dKLag[(k,i,t)=qK_k_i], "One-period-ahead adjustment-cost derivative by type and industry."
  dKAdjCost2dKLag2[(k,i,t)=qK_k_i], "Two-period-ahead adjustment-cost derivative by type and industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[fKAdjCost] .= 10
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  setindex!.(Ref(start_values), 0, tagged(model, CapitalAdjustmentCostsTag))
  return nothing
end

# ============================================================================
# Capital growth momentum in the base year
# ============================================================================
# Reference growth for the first model year, as a gross factor (1 + growth).
# Industry part: median yearly capital growth over the last `momentum_years` data years.
#   The median keeps persistent trends (e.g. shrinking building stocks) and ignores
#   single one-off years (e.g. a -23% year).
# Common part: one shift for all series, chosen so the capital-weighted momentum equals
#   aggregate base-year growth. The economy then continues from where it actually was.
# Each series is capped at trend growth +/- `momentum_cap`, so a multi-year building
#   boom is not carried forward.
const momentum_years = 4
const momentum_cap = 0.05

_median(x) = (s = sort(collect(x)); n = length(s); isodd(n) ? s[(n+1)÷2] : (s[n÷2] + s[n÷2+1]) / 2)
_kdata(k, i, year) = get(qK_k_i_data, (k, i, year), 0.0)
const momentum_window = (tBase-momentum_years+1):tBase

# Series with positive capital in every year of the window and the year before.
const momentum_pairs = [(k, i) for (k, i, year) in keys(qK_k_i_data)
  if year == tBase && all(y -> _kdata(k, i, y) > 0, (first(momentum_window)-1):tBase)]

_growth(k, i, year) = _kdata(k, i, year) / _kdata(k, i, year-1) - 1
const aggregate_base_growth = sum(_kdata(k, i, tBase) for (k, i) in momentum_pairs) /
                              sum(_kdata(k, i, tBase-1) for (k, i) in momentum_pairs) - 1
const median_growth = Dict((k, i) => _median(_growth(k, i, y) for y in momentum_window) for (k, i) in momentum_pairs)

_capped(g) = clamp(g, (fq - 1) - momentum_cap, (fq - 1) + momentum_cap)
_weighted_momentum(shift) = sum(_capped(median_growth[p] + shift) * _kdata(p..., tBase-1) for p in momentum_pairs) /
                            sum(_kdata(p..., tBase-1) for p in momentum_pairs)

# The cap makes the weighted momentum nonlinear in the shift, so iterate to the aggregate target.
const momentum_shift = let shift = 0.0
  for _ in 1:100
    shift += aggregate_base_growth - _weighted_momentum(shift)
  end
  @assert abs(_weighted_momentum(shift) - aggregate_base_growth) < 1e-10 "Capital momentum shift did not converge"
  shift
end

const kMomentum = Dict(p => 1 + _capped(median_growth[p] + momentum_shift) for p in momentum_pairs)

# Series without a full history arrive with the aggregate base-year growth.
kMomentum_or_aggregate(k, i) = get(kMomentum, (k, i), 1 + aggregate_base_growth)

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    rKCapitalGrowthChange[k=capital_type, i=industry, t=t1:T; t > tBase+1],
    rKCapitalGrowthChange[k,i,t] == qK_k_i[k,i,t] / qK_k_i[k,i,t-1]*fq - qK_k_i[k,i,t-1] / qK_k_i[k,i,t-2]*fq

    # The year after the base year measures capital growth against the momentum the
    # economy arrives with (see kMomentum), not against one noisy data year.
    rKCapitalGrowthChange[k=capital_type, i=industry, t=t1:T; t == tBase+1],
    rKCapitalGrowthChange[k,i,t] == qK_k_i[k,i,t] / qK_k_i[k,i,t-1]*fq - kMomentum_or_aggregate(k, i)

    # No growth change in the base year itself: the data year carries no adjustment cost.
    rKCapitalGrowthChange[k=capital_type, i=industry, t=t1:T; t <= tBase],
    rKCapitalGrowthChange[k,i,t] == 0

    qKAdjCost_k_i[k=capital_type, i=industry, t=t1:T],
    qKAdjCost_k_i[k,i,t] == fKAdjCost[k,i,t] / 2 * rKCapitalGrowthChange[k,i,t]^2 * qK_k_i[k,i,t-1]/fq

    dKAdjCost2dK[k=capital_type, i=industry, t=t1:T],
    dKAdjCost2dK[k,i,t] == fKAdjCost[k,i,t] * rKCapitalGrowthChange[k,i,t]

    dKAdjCost2dKLag[k=capital_type, i=industry, t=t1:(T-1)],
    dKAdjCost2dKLag[k,i,t] == fKAdjCost[k,i,t+1] * (rKCapitalGrowthChange[k,i,t+1]^2 / 2
                                   - rKCapitalGrowthChange[k,i,t+1] * (
                                     qK_k_i[k,i,t+1] / qK_k_i[k,i,t]*fq
                                     + qK_k_i[k,i,t] / qK_k_i[k,i,t-1]*fq))

    dKAdjCost2dKLag2[k=capital_type, i=industry, t=t1:(T-2)],
    dKAdjCost2dKLag2[k,i,t] ==
      fKAdjCost[k,i,t+2] * rKCapitalGrowthChange[k,i,t+2] * (qK_k_i[k,i,t+1] / qK_k_i[k,i,t]*fq)^2

    qProductionLoss[i=industry, t=t1:T], qProductionLoss[i,t] == ∑(qKAdjCost_k_i[k,i,t] for k in capital_type)

    pKAdjCost_k_i[k=capital_type, i=industry, t=(t1+1):(T-1)],
    pKAdjCost_k_i[k,i,t] == pProd[topNest[i],i,t-1]/fp * dKAdjCost2dK[k,i,t-1]
                              + dKAdjCost2dKLag[k,i,t-1] / (1 + rHurdleRate_i[i,t]) *
                                pProd[topNest[i],i,t]
                              + dKAdjCost2dKLag2[k,i,t-1] /
                                ((1 + rHurdleRate_i[i,t]) * (1 + rHurdleRate_i[i,t+1])) *
                                pProd[topNest[i],i,t+1]*fp

    pKAdjCost_k_i[k=capital_type, i=industry, t=T; T > t1], pKAdjCost_k_i[k,i,t] == 0
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  return copy(base)
end
end # module