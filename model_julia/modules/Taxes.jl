# Set direct, capital, product, and production tax rules.
# Read prepared gross tax and subsidy flows.
# Keep data construction in TaxesData.jl.
include("TaxesSettings.jl")

module Taxes

using SquareModels
import ..Capital:
  capital_k_i,
  qK_k_i,
  tK_k_i
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fq
import ..InputOutput:
  industry,
  product,
  product_tax_p_u,
  qPurchaserUse_p_u,
  tNetProduct,
  use
import ..Intermediates:
  intermediate_m_i,
  qM_m_i,
  tM_m_i
import ..Labor:
  labor_l_i,
  qL_l_i,
  tL_l_i,
  vHhWages,
  vRoWNetWages
import ..Production:
  vtProductionOther_i
import ..ProductionSettings:
  capital_type,
  intermediate_type,
  labor_type,
  production_data_dir
import ..TaxesSettings:
  production_subsidy_input_map,
  production_tax_input_map
import ..model
import ..SectorAccounts:
  fin_instrument,
  vtCorp,
  vtDirect,
  vtHhIncome,
  vtRoWIncome,
  vtCap,
  vCurrentIncomeWealthTaxes,
  vFinPosition_s_f,
  vGrossOpSurplusMixedIncome
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const production_gva_file = joinpath(production_data_dir, "production_gva.csv")
const production_taxes_file = joinpath(production_data_dir, "production_taxes.csv")
const product_taxes_file = joinpath(production_data_dir, "product_taxes.csv")

const vProductionTax_c_i_data = read_cells(production_taxes_file, "vProductionTax_c_i")
const vProductionSubsidy_c_i_data = read_cells(production_taxes_file, "vProductionSubsidy_c_i")
const vProductionSubsidy_c_data = read_cells(production_taxes_file, "vProductionSubsidy_c")
const vProductionTax_data = read_cells(production_taxes_file, "vProductionTax")
const vtK_k_i_data = read_cells(production_taxes_file, "vtK_k_i")
const vtL_l_i_data = read_cells(production_taxes_file, "vtL_l_i")
const vtM_m_i_data = read_cells(production_taxes_file, "vtM_m_i")
const vtProductionOther_i_data = read_cells(production_taxes_file, "vtProductionOther_i")
const vtProduction_i_data = read_cells(production_gva_file, "vProductionTax_i")
const vtProduct_p_u_data = read_cells(product_taxes_file, "vtProduct_p_u")
const vProductSubsidy_p_u_data = read_cells(product_taxes_file, "vProductSubsidy_p_u")
const vNetProductTax_p_u_data = read_cells(product_taxes_file, "vNetProductTax_p_u")
const vNetProductTax_u_data = read_cells(product_taxes_file, "vNetProductTax_u")
const vtProduct_data = read_cells(product_taxes_file, "vtProduct")
const vProductSubsidy_data = read_cells(product_taxes_file, "vProductSubsidy")
const vtRoWProduct_data = read_cells(product_taxes_file, "vtRoWProduct")
const vRoWProductSubsidy_data = read_cells(product_taxes_file, "vRoWProductSubsidy")
const vRoWProductionSubsidy_data = read_cells(product_taxes_file, "vRoWProductionSubsidy")

# ============================================================================
# Indices
# ============================================================================
const production_tax_class = sort(collect(keys(production_tax_input_map)))
const production_subsidy_class = sort(collect(keys(production_subsidy_input_map)))
const corporation_sector = [:FinCorp, :NonFinCorp]

@assert(
  Set(first(key) for key in keys(vProductionTax_c_i_data)) == Set(production_tax_class),
  "Tax matrix and settings must use the same classes",
)
@assert(
  Set(first(key) for key in keys(vProductionSubsidy_c_i_data)) == Set(production_subsidy_class),
  "Subsidy matrix and settings must use the same classes",
)
@assert all(>=(0), values(vProductionTax_c_i_data)) "Production tax matrix values must be nonnegative"
@assert all(>=(0), values(vProductionSubsidy_c_i_data)) "Production subsidy matrix values must be nonnegative"
@assert all(>=(0), values(vtRoWProduct_data)) "RoW production and import tax receipts must be nonnegative"
@assert all(>=(0), values(vRoWProductSubsidy_data)) "RoW product subsidy payments must be nonnegative"
@assert all(>=(0), values(vRoWProductionSubsidy_data)) "RoW production subsidy payments must be nonnegative"

# ============================================================================
# Variables
# ============================================================================
const TaxesTag = Tag(:Taxes)

@variables model :: (TaxesTag, ForecastConstant) begin
  tHhIncome[t], "Average and marginal household income tax rate."
  tCorp[t], "Average and marginal corporation tax rate."
  tRoWIncome[t], "Average rest-of-world income tax rate on net wages."
  tCap[t], "Average and marginal capital tax rate on household financial assets."
  tProduct_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Gross product tax per unit of purchaser use."
  tProductSubsidy_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Gross product subsidy per unit."
  uRoWProductTaxRecipient[t], "Share of gross product taxes received by RoW."
  uRoWProductSubsidyPayer[t], "Share of product subsidies paid by RoW."
  uRoWProductionSubsidyPayer[t], "Share of production subsidies paid by RoW."
end

@variables model :: (TaxesTag, GrowthAdjusted, InflationAdjusted, ForecastConstant) begin
  vProductionTax_c_i[c=production_tax_class, i=industry, t=t], "Production tax by class and industry."
  vProductionSubsidy_c_i[c=production_subsidy_class, i=industry, t=t], "Production subsidy by class and industry."
end

@variables model :: (TaxesTag, GrowthAdjusted, InflationAdjusted) begin
  vtProduct_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Gross taxes on products by product and use (D.21)."
  vProductSubsidy_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Product subsidies by product and use (D.31)."
  vNetProductTax_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Net product taxes by product and use."
  vNetProductTax_u[u=use, t=t], "Net taxes on products by use (D.21 less D.31)."
  vtProduct[t], "Gross taxes on products (D.21)."
  vProductSubsidy[t], "Subsidies on products (D.31)."
  vProductionSubsidy[t], "Subsidies on production implied by gross taxes and net factor-tax payments (D.39)."
  vtRoWProduct[t], "Taxes on products received by the rest of the world."
  vRoWProductSubsidy[t], "Subsidies on products paid by the rest of the world."
  vRoWProductionSubsidy[t], "Subsidies on production paid by the rest of the world."
  vtIndirect[t], "Government taxes on production and imports (D.2)."

  vProductionSubsidy_c[c=production_subsidy_class, t=t], "Production subsidy by class."
  vProductionTax[t=t], "Production taxes paid by resident producers."
  vtK_k_i[(k,i,t)=tK_k_i], "Production tax less subsidy on capital stock."
  vtL_l_i[(l,i,t)=tL_l_i], "Production tax less subsidy on labor."
  vtM_m_i[(m,i,t)=tM_m_i], "Production tax less subsidy on intermediate inputs."
  vtProduction_i[i=industry, t=t], "Other production taxes less subsidies by industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, vtProduct_p_u, vtProduct_p_u_data)
  fill_cells!(db, vProductSubsidy_p_u, vProductSubsidy_p_u_data)
  fill_cells!(db, vNetProductTax_p_u, vNetProductTax_p_u_data)
  fill_cells!(db, vNetProductTax_u, vNetProductTax_u_data)
  fill_cells!(db, vtProduct, vtProduct_data)
  fill_cells!(db, vProductSubsidy, vProductSubsidy_data)
  fill_cells!(db, vProductionTax_c_i, vProductionTax_c_i_data)
  fill_cells!(db, vProductionSubsidy_c_i, vProductionSubsidy_c_i_data)
  fill_cells!(db, vProductionSubsidy_c, vProductionSubsidy_c_data)
  fill_cells!(db, vProductionTax, vProductionTax_data)
  fill_cells!(db, vtK_k_i, vtK_k_i_data)
  fill_cells!(db, vtL_l_i, vtL_l_i_data)
  fill_cells!(db, vtM_m_i, vtM_m_i_data)
  fill_cells!(db, vtProductionOther_i, vtProductionOther_i_data)
  fill_cells!(db, vtProduction_i, vtProduction_i_data)
  fill_cells!(db, vtRoWProduct, vtRoWProduct_data)
  fill_cells!(db, vRoWProductSubsidy, vRoWProductSubsidy_data)
  fill_cells!(db, vRoWProductionSubsidy, vRoWProductionSubsidy_data)
  return nothing
end

function set_residual_tolerances!(tolerances)
  # Sector accounts report whole EUR millions. Tax classes and industries use decimals.
  tolerances[vProductionTax] = 1.2
  tolerances[vProductionSubsidy_c] = 1.2
  tolerances[vNetProductTax_u] = 0.15
  # A common corporation rate does not reproduce each sector source value.
  tolerances[vCurrentIncomeWealthTaxes] = 2200.0
  # Government, sector-account, and production sources use different precision.
  tolerances[vtProduct] = 1.2
  tolerances[vProductSubsidy] = 1.2
  tolerances[vtIndirect] = 1.2
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Direct taxes. Policy rates set the payer amounts; the government total is bottom-up.
    vtHhIncome[t=t1:T],
    vtHhIncome[t] == tHhIncome[t] * (vHhWages[t] + vGrossOpSurplusMixedIncome[:Hh,t])

    vCurrentIncomeWealthTaxes[s=corporation_sector, t=t1:T],
    vCurrentIncomeWealthTaxes[s,t] == -tCorp[t] * vGrossOpSurplusMixedIncome[s,t]

    vtCorp[t=t1:T],
    vtCorp[t] == tCorp[t] * ∑(vGrossOpSurplusMixedIncome[s,t] for s in corporation_sector)
    @test_constraint("Corporation taxes sum over payer sectors"; atol=1e-6, rtol=1e-8)
    vtCorp[t=t1:T], vtCorp[t] == -∑(vCurrentIncomeWealthTaxes[s,t] for s in corporation_sector)
    vtRoWIncome[t=t1:T], vtRoWIncome[t] == tRoWIncome[t] * vRoWNetWages[t]
    vtDirect[t=t1:T], vtDirect[t] == vtHhIncome[t] + vtCorp[t] + vtRoWIncome[t]

    # Capital-transfer taxes. Household financial assets provide the simple base.
    vtCap[t=t1:T],
    vtCap[t] == tCap[t] * ∑(vFinPosition_s_f[:Hh,f,:Assets,t] for f in fin_instrument)

    # Product taxes and subsidies. Gross rates yield the observed net rate.
    vtProduct_p_u[p=product, u=use, t=t1:T; (p,u) in product_tax_p_u],
    vtProduct_p_u[p,u,t] == tProduct_p_u[p,u,t] * qPurchaserUse_p_u[p,u,t]
    vProductSubsidy_p_u[p=product, u=use, t=t1:T; (p,u) in product_tax_p_u],
    vProductSubsidy_p_u[p,u,t] == tProductSubsidy_p_u[p,u,t] * qPurchaserUse_p_u[p,u,t]
    vNetProductTax_p_u[p=product, u=use, t=t1:T; (p,u) in product_tax_p_u],
    vNetProductTax_p_u[p,u,t] == vtProduct_p_u[p,u,t] - vProductSubsidy_p_u[p,u,t]
    tNetProduct[p=product, u=use, t=t1:T; (p,u) in product_tax_p_u],
    tNetProduct[p,u,t] * qPurchaserUse_p_u[p,u,t] == vNetProductTax_p_u[p,u,t]

    vNetProductTax_u[u=use, t=t1:T],
    vNetProductTax_u[u,t] ==
      ∑(vtProduct_p_u[p,u,t] for p in product if (p,u) in product_tax_p_u) -
      ∑(vProductSubsidy_p_u[p,u,t] for p in product if (p,u) in product_tax_p_u)
    vtProduct[t=t1:T], vtProduct[t] == ∑(vtProduct_p_u[p,u,t] for (p,u) in product_tax_p_u)
    vProductSubsidy[t=t1:T],
    vProductSubsidy[t] == ∑(vProductSubsidy_p_u[p,u,t] for (p,u) in product_tax_p_u)
    vtRoWProduct[t=t1:T], vtRoWProduct[t] == uRoWProductTaxRecipient[t] * vtProduct[t]
    vRoWProductSubsidy[t=t1:T],
    vRoWProductSubsidy[t] == uRoWProductSubsidyPayer[t] * vProductSubsidy[t]

    # Production taxes and subsidies.
    vProductionSubsidy[t=t1:T],
    vProductionSubsidy[t] == vProductionTax[t] - ∑(vtProduction_i[i,t] for i in industry)
    vRoWProductionSubsidy[t=t1:T],
    vRoWProductionSubsidy[t] == uRoWProductionSubsidyPayer[t] * vProductionSubsidy[t]
    # Government indirect tax revenue is the government share of D.21 plus resident D.29.
    vtIndirect[t=t1:T], vtIndirect[t] == vtProduct[t] - vtRoWProduct[t] + vProductionTax[t]

    # Production tax and subsidy inputs.
    vProductionSubsidy_c[c=production_subsidy_class, t=t1:T],
    vProductionSubsidy_c[c,t] == ∑(vProductionSubsidy_c_i[c,i,t] for i in industry)

    @test_constraint("Production subsidies sum over classes"; atol=1.2, rtol=1e-8)
    vProductionSubsidy[t=[t1]],
    vProductionSubsidy[t] == ∑(vProductionSubsidy_c[c,t] for c in production_subsidy_class)

    vProductionTax[t=t1:T],
    vProductionTax[t] == ∑(vProductionTax_c_i[c,i,t] for c in production_tax_class, i in industry)

    vtK_k_i[k=capital_type, i=industry, t=t1:T],
    vtK_k_i[k,i,t] == tK_k_i[k,i,t] * qK_k_i[k,i,t-1]/fq

    vtL_l_i[l=labor_type, i=industry, t=t1:T], vtL_l_i[l,i,t] == tL_l_i[l,i,t] * qL_l_i[l,i,t]

    vtM_m_i[m=intermediate_type, i=industry, t=t1:T], vtM_m_i[m,i,t] == tM_m_i[m,i,t] * qM_m_i[m,i,t]

    vtProduction_i[i=industry, t=t1:T],
    vtProduction_i[i,t] == vtProductionOther_i[i,t]
      + ∑(vtK_k_i[k,i,t] for k in capital_type)
      + ∑(vtL_l_i[l,i,t] for l in labor_type)
      + ∑(vtM_m_i[m,i,t] for m in intermediate_type)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    tHhIncome[t1], vtHhIncome[t1]
    tCorp[t1], vtCorp[t1]
    tRoWIncome[t1], vtRoWIncome[t1]
    tCap[t1], vtCap[t1]
    tProduct_p_u[:,:,t1], vtProduct_p_u[:,:,t1]
    tProductSubsidy_p_u[:,:,t1], vProductSubsidy_p_u[:,:,t1]
    uRoWProductTaxRecipient[t1], vtRoWProduct[t1]
    uRoWProductSubsidyPayer[t1], vRoWProductSubsidy[t1]
    uRoWProductionSubsidyPayer[t1], vRoWProductionSubsidy[t1]

    tK_k_i[:,:,t1], vtK_k_i[:,:,t1]
    tL_l_i[:,:,t1], vtL_l_i[:,:,t1]
    tM_m_i[:,:,t1], vtM_m_i[:,:,t1]
  end

  return block
end
end # module
