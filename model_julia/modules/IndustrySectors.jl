# Share industries across sectors for operating surplus, investment, and capital.
# Include households and NPISH in the same industry allocation.
# Keep sector budget and portfolio equations in their sector modules.

module IndustrySectors

using SquareModels
import ..Capital: pI_k, qK_k_i, vI_k_i
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry, vINV, vY_i
import ..Intermediates: vM_i
import ..Labor: vWages_i
import ..model
import ..Production: vtProductionOther_i
import ..ProductionSettings: capital_type
import ..SectorAccounts: vGrossOpSurplusMixedIncome, vI_s
import ..SectorAccountsSettings: sector_accounts_data_dir
import ..Settings: calibration_year
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const industry_sector_share_file = joinpath(sector_accounts_data_dir, "industry_sector_shares.csv")
const uIndustrySector_s_i_data = read_cells(industry_sector_share_file, "uIndustrySector_s_i")

# ============================================================================
# Indices
# ============================================================================
const mapped_sector = [:FinCorp, :NonFinCorp, :Gov, :Hh]
const share_year = sort(unique(year for ((_,_,year), _) in uIndustrySector_s_i_data))

@assert calibration_year in share_year "Industry-sector shares must include the calibration year"
@assert all(
  haskey(uIndustrySector_s_i_data, (s, i, year))
  for s in mapped_sector, i in industry, year in share_year
) "Industry-sector share data must contain each sector, industry, and source year"
@assert all(0.0 <= value <= 1.0 for value in values(uIndustrySector_s_i_data)) "Shares must be between zero and one"
@assert all(
  isapprox(sum(uIndustrySector_s_i_data[s,i,year] for s in mapped_sector), 1.0; atol = 1e-12, rtol = 0)
  for i in industry, year in share_year
) "Sector shares must sum to one for each industry and year"

# ============================================================================
# Variables
# ============================================================================
const IndustrySectorsTag = Tag(:IndustrySectors)

@variables model :: (IndustrySectorsTag, ForecastConstant) begin
  fGrossOpSurplus_s[s=mapped_sector, t=t], "Factor from industry operating surplus to sector operating surplus."
  uIndustrySector_s_i[s=mapped_sector, i=industry, t=t], "Industry share assigned to each sector."
  uINV_s[s=mapped_sector, t=t], "Sector share of inventory investment."
end

@variables model :: (IndustrySectorsTag, GrowthAdjusted, InflationAdjusted) begin
  vGrossOpSurplus_i[i=industry, t=t], "Gross operating surplus by industry."
  vY_s[s=mapped_sector, t=t], "Output by sector."
  vM_s[s=mapped_sector, t=t], "Intermediate input spend by sector."
  vWages_s[s=mapped_sector, t=t], "Wages by sector."
  vtProductionOther_s[s=mapped_sector, t=t], "Other production taxes less subsidies by sector."
  vK_s[s=mapped_sector, t=t], "Replacement value of capital by sector."
  vIFixed_s[s=mapped_sector, t=t], "Fixed investment by sector."
  vINV_s[s=mapped_sector, t=t], "Inventory investment by sector."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, uIndustrySector_s_i, uIndustrySector_s_i_data)
  db[fGrossOpSurplus_s] .= 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Operating surplus.
    vGrossOpSurplus_i[i=industry, t=t1:T],
    vGrossOpSurplus_i[i,t] == vY_i[i,t] - vM_i[i,t] - vWages_i[i,t] - vtProductionOther_i[i,t]

    vY_s[s=mapped_sector, t=t1:T],
    vY_s[s,t] == ∑(uIndustrySector_s_i[s,i,t] * vY_i[i,t] for i in industry)

    vM_s[s=mapped_sector, t=t1:T],
    vM_s[s,t] == ∑(uIndustrySector_s_i[s,i,t] * vM_i[i,t] for i in industry)

    vWages_s[s=mapped_sector, t=t1:T],
    vWages_s[s,t] == ∑(uIndustrySector_s_i[s,i,t] * vWages_i[i,t] for i in industry)

    vtProductionOther_s[s=mapped_sector, t=t1:T],
    vtProductionOther_s[s,t] ==
      ∑(uIndustrySector_s_i[s,i,t] * vtProductionOther_i[i,t] for i in industry)

    vGrossOpSurplusMixedIncome[s=mapped_sector, t=t1:T],
    vGrossOpSurplusMixedIncome[s,t] == fGrossOpSurplus_s[s,t] * (
      vY_s[s,t] - vM_s[s,t] - vWages_s[s,t] - vtProductionOther_s[s,t])

    # Capital ownership uses the same industry shares as current activity.
    vK_s[s=mapped_sector, t=t1:T],
    vK_s[s,t] == ∑(
      uIndustrySector_s_i[s,i,t] * pI_k[k,t] * qK_k_i[k,i,t]
      for k in capital_type, i in industry
    )

    # Capital formation.
    vIFixed_s[s=mapped_sector, t=t1:T],
    vIFixed_s[s,t] ==
      ∑(uIndustrySector_s_i[s,i,t] * vI_k_i[k,i,t] for k in capital_type, i in industry)

    vINV_s[s=mapped_sector, t=t1:T], vINV_s[s,t] == uINV_s[s,t] * vINV[t]

    vI_s[s=mapped_sector, t=t1:T], vI_s[s,t] == vIFixed_s[s,t] + vINV_s[s,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    uINV_s[s=mapped_sector, t=[t1]], vI_s[s=mapped_sector, t=[t1]]
  end

  return block
end

end # module
