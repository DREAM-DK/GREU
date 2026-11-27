# Let fixed amounts follow nominal GDP in a shock.
# The amounts are production taxes and subsidies by class and industry, other net production
# taxes by industry, and net pension saving. The base model holds each on an exogenous path.
# Tax rates per unit of an input are not in scope.
# Load this module only. A shock file adds its equations and sets the ratios from the baseline.
module GDPIndexation

using SquareModels
import ..FixedBasePriceAggregates: vGDP
import ..InputOutput: industry
import ..model
import ..Production: vntProductionOther_i
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
const GDPIndexationTag = Tag(:GDPIndexation)

@variables model :: GDPIndexationTag begin
  rtProduction2GDP_c_i[(c,i,t)=vtProduction_c_i], "Production tax relative to GDP by class and industry."
  rsProduction2GDP_c_i[(c,i,t)=vsProduction_c_i], "Production subsidy relative to GDP by class and industry."
  rntProductionOther2GDP_i[i=industry, t=t], "Other net production taxes relative to GDP by industry."
  rNetPensionSaving2GDP[t], "Net pension saving relative to GDP."
end

# ============================================================================
# Assign data
# ============================================================================
# The module has no source data. The baseline sets all values. See define_calibration.
function assign_data!(db)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Government revenue. These amounts do not enter the costs of firms.
    vtProduction_c_i[c=production_tax_class, i=industry, t=t1:T],
    vtProduction_c_i[c,i,t] == rtProduction2GDP_c_i[c,i,t] * vGDP[t]

    vsProduction_c_i[c=production_subsidy_class, i=industry, t=t1:T],
    vsProduction_c_i[c,i,t] == rsProduction2GDP_c_i[c,i,t] * vGDP[t]

    # Costs of firms. This amount enters the marginal cost of each industry.
    vntProductionOther_i[i=industry, t=t1:T],
    vntProductionOther_i[i,t] == rntProductionOther2GDP_i[i,t] * vGDP[t]

    # Households.
    vNetPensionSaving[t=t1:T], vNetPensionSaving[t] == rNetPensionSaving2GDP[t] * vGDP[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
# Solve this block alone on a baseline. All other variables keep their baseline values.
function define_calibration(base=define_equations())
  block = copy(base)

  # The baseline path of each amount sets its ratio to GDP.
  @endo_exo_swap! block begin
    rtProduction2GDP_c_i[:,:,t1:T], vtProduction_c_i[:,:,t1:T]
    rsProduction2GDP_c_i[:,:,t1:T], vsProduction_c_i[:,:,t1:T]
    rntProductionOther2GDP_i[:,t1:T], vntProductionOther_i[:,t1:T]
    rNetPensionSaving2GDP[t1:T], vNetPensionSaving[t1:T]
  end

  return block
end

end # module
