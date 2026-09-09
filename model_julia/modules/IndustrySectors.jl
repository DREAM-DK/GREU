# Share industries across sectors for operating surplus, investment, and capital.
# Include households and NPISH in the same industry allocation.
# Keep sector budget and portfolio equations in their sector modules.

module IndustrySectors

using SquareModels
import ..Capital: capital_k_i, pI_k, qK_k_i, rKDepr_k_i, vI_k_i
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fq
import ..InputOutput: industry, vINV, vY_i
import ..Intermediates: vM_i
import ..Labor: qL_l_i, vWages_i
import ..model
import ..Taxes:
  production_subsidy_class,
  vntProduction_i,
  vsProduction_c_i
import ..ProductionSettings: capital_type, labor_type
import ..SectorAccounts:
  sector,
  vConsumptionFixedCapital_s,
  vGrossOpSurplusMixedIncome,
  vI_s
import ..SectorAccountsSettings: sector_accounts_data_dir
import ..Settings: calibration_year
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const industry_sector_share_file = joinpath(sector_accounts_data_dir, "industry_sector_shares.csv")
const non_financial_transactions_file = joinpath(sector_accounts_data_dir, "non_financial_transactions.csv")
const rIndustrySector_s_i_data = read_cells(industry_sector_share_file, "rIndustrySector_s_i")
const non_financial_transactions_data = read_cells(non_financial_transactions_file, "NonFinancialTransactions")

# ============================================================================
# Indices
# ============================================================================
const share_year = sort(unique(year for ((_,_,year), _) in rIndustrySector_s_i_data))
const industry_sector_s_i = Set(
  (s, i) for ((s,i,_), value) in rIndustrySector_s_i_data if !iszero(value)
)
const vsProduction_s_data = Dict(
  (s,year) => value
  for ((s,item,direct,year), value) in non_financial_transactions_data
  if (s,) in select_axes(industry_sector_s_i, 1) && item == :D39 && direct == :RECV
)

@assert calibration_year in share_year "Industry-sector shares must include the calibration year"
@assert all(
  haskey(rIndustrySector_s_i_data, (s, i, year))
  for (s,) in select_axes(keys(rIndustrySector_s_i_data), 1), i in industry, year in share_year
) "Industry-sector share data must contain each sector, industry, and source year"
@assert all(
  haskey(vsProduction_s_data, (s, year))
  for (s,) in select_axes(industry_sector_s_i, 1), year in share_year
) "Production subsidy data must contain each sector and source year"
@assert all(0.0 <= value <= 1.0 for value in values(rIndustrySector_s_i_data)) "Shares must be between zero and one"
@assert all(>=(0), values(vsProduction_s_data)) "Production subsidies must be nonnegative"
@assert all(
  isapprox(
    sum(rIndustrySector_s_i_data[s,i,year] for s in sector if (s,i) in industry_sector_s_i),
    1.0; atol = 1e-12, rtol = 0,
  )
  for i in industry, year in share_year
) "Sector shares must sum to one for each industry and year"

# ============================================================================
# Variables
# ============================================================================
const IndustrySectorsTag = Tag(:IndustrySectors)

@variables model :: (IndustrySectorsTag, ForecastConstant) begin
  rIndustrySector_s_i[s=sector, i=industry, t=t; (s,i) in industry_sector_s_i], "Industry share assigned to each sector."
end

@variables model :: (IndustrySectorsTag, GrowthAdjusted, InflationAdjusted) begin
  vGrossOpSurplus_i[i=industry, t=t], "Gross operating surplus by industry."
  vY_s[s=sector, t=t; s in first.(industry_sector_s_i)], "Output by sector."
  vM_s[(s,t)=vY_s], "Intermediate input spend by sector."
  vWages_s[(s,t)=vY_s], "Wages by sector."
  vntProduction_s[(s,t)=vY_s], "Other production taxes less subsidies by sector."
  vtProduction_s[(s,t)=vY_s], "Other production taxes by payer sector."
  vsProduction_s[(s,t)=vY_s], "Other production subsidies by recipient sector."
  vK_s[(s,t)=vY_s], "Replacement value of capital by sector."
  vIFixed_s[(s,t)=vY_s], "Fixed investment by sector."
  vINV_s[(s,t)=vY_s], "Inventory investment by sector."
end

@variables model :: (IndustrySectorsTag, ForecastConstant) begin
  uINV_s[(s,t)=vY_s], "Sector share of inventory investment."
end

@variables model :: (IndustrySectorsTag, GrowthAdjusted) begin
  qL_s[(s,t)=vY_s], "Employees by sector."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, rIndustrySector_s_i, rIndustrySector_s_i_data)
  fill_cells!(db, vsProduction_s, vsProduction_s_data)

  initial_capital_values = [
    sum(
      db[rIndustrySector_s_i[s,i,t1]] * db[pI_k[k,t1-1]] * db[qK_k_i[k,i,t1-1]]
      for (k,i) in capital_k_i if (s,i) in industry_sector_s_i;
      init=0.0,
    )
    for (s,) in select_axes(vK_s, 1)
  ]
  db[vK_s[:,t1-1]] .= initial_capital_values
  return nothing
end

function set_residual_tolerances!(tolerances)
  # A subsidy-specific sector map can reduce the remaining source gaps.
  tolerances[vsProduction_s] = 800.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Operating surplus.
    vGrossOpSurplus_i[i=industry, t=t1:T],
    vGrossOpSurplus_i[i,t] == vY_i[i,t] - vM_i[i,t] - vWages_i[i,t] - vntProduction_i[i,t]

    vY_s[s=sector, t=t1:T],
    vY_s[s,t] == ∑(rIndustrySector_s_i[s,i,t] * vY_i[i,t] for i in industry)

    vM_s[s=sector, t=t1:T],
    vM_s[s,t] == ∑(rIndustrySector_s_i[s,i,t] * vM_i[i,t] for i in industry)

    vWages_s[s=sector, t=t1:T],
    vWages_s[s,t] == ∑(rIndustrySector_s_i[s,i,t] * vWages_i[i,t] for i in industry)

    qL_s[s=sector, t=t1:T],
    qL_s[s,t] == ∑(rIndustrySector_s_i[s,i,t] * qL_l_i[l,i,t] for l in labor_type, i in industry)

    vntProduction_s[s=sector, t=t1:T],
    vntProduction_s[s,t] ==
      ∑(rIndustrySector_s_i[s,i,t] * vntProduction_i[i,t] for i in industry)

    vsProduction_s[s=sector, t=t1:T],
    vsProduction_s[s,t] == ∑(
      rIndustrySector_s_i[s,i,t] * vsProduction_c_i[c,i,t]
      for c in production_subsidy_class, i in industry
    )

    vtProduction_s[s=sector, t=t1:T],
    vtProduction_s[s,t] == vntProduction_s[s,t] + vsProduction_s[s,t]

    vGrossOpSurplusMixedIncome[s=sector, t=t1:T; (s,t) in keys(vY_s)],
    vGrossOpSurplusMixedIncome[s,t] == vY_s[s,t] - vM_s[s,t] - vWages_s[s,t] - vntProduction_s[s,t]

    # Capital ownership uses the same industry shares as current activity.
    vK_s[s=sector, t=t1:T],
    vK_s[s,t] == ∑(
      rIndustrySector_s_i[s,i,t] * pI_k[k,t] * qK_k_i[k,i,t]
      for k in capital_type, i in industry
    )

    vConsumptionFixedCapital_s[s=sector, t=t1:T; (s,t) in keys(vK_s)],
    vConsumptionFixedCapital_s[s,t] == ∑(
      rIndustrySector_s_i[s,i,t] * pI_k[k,t] * rKDepr_k_i[k,i,t] * qK_k_i[k,i,t-1]/fq
      for k in capital_type, i in industry
    )

    # Capital formation.
    vIFixed_s[s=sector, t=t1:T],
    vIFixed_s[s,t] ==
      ∑(rIndustrySector_s_i[s,i,t] * vI_k_i[k,i,t] for k in capital_type, i in industry)

    vINV_s[s=sector, t=t1:T], vINV_s[s,t] == uINV_s[s,t] * vINV[t]

    vI_s[s=sector, t=t1:T; (s,t) in keys(vINV_s)], vI_s[s,t] == vIFixed_s[s,t] + vINV_s[s,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    uINV_s[s=sector, t=[t1]], vI_s[s=sector, t=[t1]; (s,t) in keys(uINV_s)]
  end

  return block
end

end # module
