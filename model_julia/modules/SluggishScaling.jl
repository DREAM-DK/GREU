# Let fixed costs, production taxes, and net pension saving follow the economy slowly in a shock.
# The fixed cost follows the output of its industry. Production taxes and subsidies follow the
# output value of their industry. Net pension saving follows nominal GDP.
# Each amount closes a fixed share of the gap to its long-run level each year.
# Tax rates per unit of an input are not in scope.
# Load this module only. A shock file adds its equations and sets the ratios from the baseline.
module SluggishScaling

using SquareModels
import ..FixedBasePriceAggregates: vGDP
import ..InputOutput: industry, qY_i, vY_i
import ..model
import ..Production: qFixedCost_i, vntProductionOther_i
import ..SectorAccounts: vNetPensionSaving
import ..Taxes:
  production_subsidy_class,
  production_tax_class,
  vsProduction_c_i,
  vtProduction_c_i
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================
const SluggishScalingTag = Tag(:SluggishScaling)

@variables model :: SluggishScalingTag begin
  qFixedCost2qY_i[i=industry, t=t], "Long-run fixed cost relative to output by industry."
  vtProduction2vY_c_i[(c,i,t)=vtProduction_c_i], "Long-run production tax relative to output value by class and industry."
  vsProduction2vY_c_i[(c,i,t)=vsProduction_c_i], "Long-run production subsidy relative to output value by class and industry."
  vntProductionOther2vY_i[i=industry, t=t], "Long-run other net production taxes relative to output value by industry."
  vNetPensionSaving2vGDP[t], "Long-run net pension saving relative to GDP."

  rFixedCostAdjust, "Share of the gap between the fixed cost and its long-run level that closes in a year."
  rProductionTaxAdjust, "Share of the gap between a production tax and its long-run level that closes in a year."
  rNetPensionSavingAdjust, "Share of the gap between net pension saving and its long-run level that closes in a year."
end

# ============================================================================
# Assign data
# ============================================================================
# With a rate of 0.2, 0.4 per cent of a gap is left after 25 years. An amount is then close to
# its long-run level in 2050 after a shock in 2026. The baseline sets the ratios. See define_calibration.
function assign_data!(db)
  db[rFixedCostAdjust] = 0.2
  db[rProductionTaxAdjust] = 0.2
  db[rNetPensionSavingAdjust] = 0.2
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
# Model variables are adjusted for growth and inflation. The lag with no adjustment factor is
# last year's amount with trend growth added. A constant amount is then a steady state.
function define_equations()
  return @block model begin
    # Fixed costs follow the output of the industry.
    qFixedCost_i[i=industry, t=t1:T],
    qFixedCost_i[i,t] == rFixedCostAdjust * qFixedCost2qY_i[i,t] * qY_i[i,t]
      + (1 - rFixedCostAdjust) * qFixedCost_i[i,t-1]

    # Production taxes and subsidies follow the output value of the industry. The first two
    # are government revenue and cost. The third enters the marginal cost of the industry.
    vtProduction_c_i[c=production_tax_class, i=industry, t=t1:T],
    vtProduction_c_i[c,i,t] == rProductionTaxAdjust * vtProduction2vY_c_i[c,i,t] * vY_i[i,t]
      + (1 - rProductionTaxAdjust) * vtProduction_c_i[c,i,t-1]

    vsProduction_c_i[c=production_subsidy_class, i=industry, t=t1:T],
    vsProduction_c_i[c,i,t] == rProductionTaxAdjust * vsProduction2vY_c_i[c,i,t] * vY_i[i,t]
      + (1 - rProductionTaxAdjust) * vsProduction_c_i[c,i,t-1]

    vntProductionOther_i[i=industry, t=t1:T],
    vntProductionOther_i[i,t] == rProductionTaxAdjust * vntProductionOther2vY_i[i,t] * vY_i[i,t]
      + (1 - rProductionTaxAdjust) * vntProductionOther_i[i,t-1]

    # Net pension saving follows nominal GDP.
    vNetPensionSaving[t=t1:T],
    vNetPensionSaving[t] == rNetPensionSavingAdjust * vNetPensionSaving2vGDP[t] * vGDP[t]
      + (1 - rNetPensionSavingAdjust) * vNetPensionSaving[t-1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
# Solve this block alone on a baseline. All other variables keep their baseline values.
function define_calibration(base=define_equations())
  block = copy(base)

  # The baseline path of each amount sets its long-run ratio.
  @endo_exo_swap! block begin
    qFixedCost2qY_i[:,t1:T], qFixedCost_i[:,t1:T]
    vtProduction2vY_c_i[:,:,t1:T], vtProduction_c_i[:,:,t1:T]
    vsProduction2vY_c_i[:,:,t1:T], vsProduction_c_i[:,:,t1:T]
    vntProductionOther2vY_i[:,t1:T], vntProductionOther_i[:,t1:T]
    vNetPensionSaving2vGDP[t1:T], vNetPensionSaving[t1:T]
  end

  return block
end

end # module
