# Define a fee that firms pay abroad for each person they employ.
# The fee is a share by type and industry times a common value per person.
# The fee does not change the cost of an extra person, so labor demand does not react directly.
# IndustrySectors gives the payer sectors. The fee is zero in the baseline.
module LaborFee

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..IndustrySectors: rIndustrySector_s_i, vLaborFee_s
import ..InputOutput: industry
import ..Labor: nL_l_i
import ..ProductionSettings: labor_type
import ..model
import ..SectorAccounts: sector
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const LaborFeeTag = Tag(:LaborFee)

@variables model :: (LaborFeeTag, ForecastConstant) begin
  rLaborFee_l_i[(l,i,t)=nL_l_i], "Fee per person relative to the fee base by type and industry."
end

@variables model :: (LaborFeeTag, GrowthAdjusted, InflationAdjusted) begin
  vLaborFeeBase[t] :: ForecastConstant, "Fee base per person."
  vLaborFee_l_i[(l,i,t)=nL_l_i], "Fee paid abroad by type and industry."
  vLaborFee_i[i=industry, t=t], "Fee paid abroad by industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  setindex!.(Ref(db), 0, tagged(model, LaborFeeTag))
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    vLaborFee_l_i[l=labor_type, i=industry, t=t1:T],
    vLaborFee_l_i[l,i,t] == rLaborFee_l_i[l,i,t] * vLaborFeeBase[t] * nL_l_i[l,i,t]

    vLaborFee_i[i=industry, t=t1:T], vLaborFee_i[i,t] == ∑(vLaborFee_l_i[l,i,t] for l in labor_type)

    vLaborFee_s[s=sector, t=t1:T; (s,t) in keys(vLaborFee_s)],
    vLaborFee_s[s,t] == ∑(rIndustrySector_s_i[s,i,t] * vLaborFee_i[i,t] for i in industry)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  return copy(base)
end

end # module
