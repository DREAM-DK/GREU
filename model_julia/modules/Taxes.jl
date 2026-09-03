# Set direct, capital, product, and production tax rules.
# Read prepared gross tax and subsidy flows.
# Keep data construction in TaxesData.jl.
include("TaxesSettings.jl")

module Taxes

using SquareModels
import ..Capital:
  capital_k_i,
  qK_k_i,
  ntK_k_i
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fq
import ..InputOutput:
  industry,
  origin,
  ordinary_uses,
  product,
  product_tax_p_u,
  purchaser_use_p_u_o,
  qPurchaserUse_p_u_o,
  ntProduct,
  use
import ..Intermediates:
  intermediate_m_i,
  qM_m_i,
  ntM_m_i
import ..Labor:
  labor_l_i,
  qL_l_i,
  ntL_l_i,
  vHhWages,
  vRoWNetWages
import ..Production:
  vntProductionOther_i
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
  vtCorp_s,
  vFinPosition_s_f,
  vGrossOpSurplusMixedIncome
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero

# ============================================================================
# Read data
# ============================================================================
const production_gva_file = joinpath(production_data_dir, "production_gva.csv")
const production_taxes_file = joinpath(production_data_dir, "production_taxes.csv")
const product_taxes_file = joinpath(production_data_dir, "product_taxes.csv")

const vtProduction_c_i_data = read_cells(production_taxes_file, "vtProduction_c_i")
const vsProduction_c_i_data = read_cells(production_taxes_file, "vsProduction_c_i")
const vsProduction_c_data = read_cells(production_taxes_file, "vsProduction_c")
const vtProduction_data = read_cells(production_taxes_file, "vtProduction")
const vntK_k_i_data = read_cells(production_taxes_file, "vntK_k_i")
const vntL_l_i_data = read_cells(production_taxes_file, "vntL_l_i")
const vntM_m_i_data = read_cells(production_taxes_file, "vntM_m_i")
const vntProductionOther_i_data = read_cells(production_taxes_file, "vntProductionOther_i")
const vntProduction_i_data = read_cells(production_gva_file, "vntProduction_i")
const vtProduct_p_u_o_data = read_cells(product_taxes_file, "vtProduct_p_u_o")
const vsProduct_p_u_o_data = read_cells(product_taxes_file, "vsProduct_p_u_o")
const vntProduct_p_u_o_data = read_cells(product_taxes_file, "vntProduct_p_u_o")
const vtProduct_p_u_data = read_cells(product_taxes_file, "vtProduct_p_u")
const vsProduct_p_u_data = read_cells(product_taxes_file, "vsProduct_p_u")
const vntProduct_p_u_data = read_cells(product_taxes_file, "vntProduct_p_u")
const vntProduct_u_data = read_cells(product_taxes_file, "vntProduct_u")
const vtProduct_data = read_cells(product_taxes_file, "vtProduct")
const vsProduct_data = read_cells(product_taxes_file, "vsProduct")
const vtRoWProduct_data = read_cells(product_taxes_file, "vtRoWProduct")
const vsRoWProduct_data = read_cells(product_taxes_file, "vsRoWProduct")
const vsRoWProduction_data = read_cells(product_taxes_file, "vsRoWProduction")

# ============================================================================
# Indices
# ============================================================================
const production_tax_class = sort(collect(keys(production_tax_input_map)))
const production_subsidy_class = sort(collect(keys(production_subsidy_input_map)))
const corporation_sector = [:FinCorp, :NonFinCorp]

@assert(
  Set(first(key) for key in keys(vtProduction_c_i_data)) == Set(production_tax_class),
  "Tax matrix and settings must use the same classes",
)
@assert(
  Set(first(key) for key in keys(vsProduction_c_i_data)) == Set(production_subsidy_class),
  "Subsidy matrix and settings must use the same classes",
)
@assert all(>=(0), values(vtProduction_c_i_data)) "Production tax matrix values must be nonnegative"
@assert all(>=(0), values(vsProduction_c_i_data)) "Production subsidy matrix values must be nonnegative"
@assert all(>=(0), values(vtRoWProduct_data)) "RoW production and import tax receipts must be nonnegative"
@assert all(>=(0), values(vsRoWProduct_data)) "RoW product subsidy payments must be nonnegative"
@assert all(>=(0), values(vsRoWProduction_data)) "RoW production subsidy payments must be nonnegative"

# ============================================================================
# Variables
# ============================================================================
const TaxesTag = Tag(:Taxes)

@variables model :: (TaxesTag, ForecastConstant) begin
  tHhIncome[t], "Average and marginal household income tax rate."
  tCorp_s[s=corporation_sector, t=t], "Average and marginal corporation tax rate by payer sector."
  tRoWIncome[t], "Average rest-of-world income tax rate on net wages."
  tCap[t], "Average and marginal capital tax rate on household financial assets."
  tProduct_p_u_o[p=product, u=use, o=origin, t=t; (p,u) in product_tax_p_u && (p,u,o) in purchaser_use_p_u_o], "Gross product tax per unit by origin."
  tsProduct_p_u_o[p=product, u=use, o=origin, t=t; (p,u) in product_tax_p_u && (p,u,o) in purchaser_use_p_u_o], "Gross product subsidy per unit by origin."
  uRoWProductTaxRecipient[t], "Share of gross product taxes received by RoW."
  uRoWProductSubsidyPayer[t], "Share of product subsidies paid by RoW."
  uRoWProductionSubsidyPayer[t], "Share of production subsidies paid by RoW."
end

@variables model :: (TaxesTag, GrowthAdjusted, InflationAdjusted, ForecastConstant) begin
  vtProduction_c_i[c=production_tax_class, i=industry, t=t], "Production tax by class and industry."
  vsProduction_c_i[c=production_subsidy_class, i=industry, t=t], "Production subsidy by class and industry."
end

@variables model :: (TaxesTag, GrowthAdjusted, InflationAdjusted) begin
  vCorpIncomeBeforeTax_s[s=corporation_sector, t=t], "Corporation income before tax."
  vCorpCapitalTaxDeduction_s[s=corporation_sector, t=t] :: ForecastZero, "Capital tax depreciation deduction."
  vCorpDebtTaxDeduction_s[s=corporation_sector, t=t] :: ForecastZero, "Debt return deducted from taxable income."
  vtProduct_p_u_o[p=product, u=use, o=origin, t=t; (p,u) in product_tax_p_u && (p,u,o) in purchaser_use_p_u_o], "Gross taxes on products by product, use, and origin (D.21)."
  vsProduct_p_u_o[p=product, u=use, o=origin, t=t; (p,u) in product_tax_p_u && (p,u,o) in purchaser_use_p_u_o], "Product subsidies by product, use, and origin (D.31)."
  vntProduct_p_u_o[p=product, u=use, o=origin, t=t; (p,u) in product_tax_p_u && (p,u,o) in purchaser_use_p_u_o], "Net product taxes by product, use, and origin."
  vtProduct_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Gross taxes on products by product and use (D.21)."
  vsProduct_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Product subsidies by product and use (D.31)."
  vntProduct_p_u[p=product, u=use, t=t; (p,u) in product_tax_p_u], "Net product taxes by product and use."
  vntProduct_u[u=use, t=t], "Net taxes on products by use (D.21 less D.31)."
  vtProduct[t], "Gross taxes on products (D.21)."
  vsProduct[t], "Subsidies on products (D.31)."
  vsProduction[t], "Subsidies on production implied by gross taxes and net factor-tax payments (D.39)."
  vtRoWProduct[t], "Taxes on products received by the rest of the world."
  vsRoWProduct[t], "Subsidies on products paid by the rest of the world."
  vsRoWProduction[t], "Subsidies on production paid by the rest of the world."
  vtIndirect[t], "Government taxes on production and imports (D.2)."

  vsProduction_c[c=production_subsidy_class, t=t], "Production subsidy by class."
  vtProduction[t=t], "Production taxes paid by resident producers."
  vntK_k_i[(k,i,t)=ntK_k_i], "Production tax less subsidy on capital stock."
  vntL_l_i[(l,i,t)=ntL_l_i], "Production tax less subsidy on labor."
  vntM_m_i[(m,i,t)=ntM_m_i], "Production tax less subsidy on intermediate inputs."
  vntProduction_i[i=industry, t=t], "Other production taxes less subsidies by industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, vtProduct_p_u_o, vtProduct_p_u_o_data)
  fill_cells!(db, vsProduct_p_u_o, vsProduct_p_u_o_data)
  fill_cells!(db, vntProduct_p_u_o, vntProduct_p_u_o_data)
  fill_cells!(db, vtProduct_p_u, vtProduct_p_u_data)
  fill_cells!(db, vsProduct_p_u, vsProduct_p_u_data)
  fill_cells!(db, vntProduct_p_u, vntProduct_p_u_data)
  fill_cells!(db, vntProduct_u, vntProduct_u_data)
  fill_cells!(db, vtProduct, vtProduct_data)
  fill_cells!(db, vsProduct, vsProduct_data)
  fill_cells!(db, vtProduction_c_i, vtProduction_c_i_data)
  fill_cells!(db, vsProduction_c_i, vsProduction_c_i_data)
  fill_cells!(db, vsProduction_c, vsProduction_c_data)
  fill_cells!(db, vtProduction, vtProduction_data)
  fill_cells!(db, vntK_k_i, vntK_k_i_data)
  fill_cells!(db, vntL_l_i, vntL_l_i_data)
  fill_cells!(db, vntM_m_i, vntM_m_i_data)
  fill_cells!(db, vntProductionOther_i, vntProductionOther_i_data)
  fill_cells!(db, vntProduction_i, vntProduction_i_data)
  fill_cells!(db, vtRoWProduct, vtRoWProduct_data)
  fill_cells!(db, vsRoWProduct, vsRoWProduct_data)
  fill_cells!(db, vsRoWProduction, vsRoWProduction_data)
  return nothing
end

function set_residual_tolerances!(tolerances)
  # Sector accounts report whole EUR millions. Tax classes and industries use decimals.
  tolerances[vtProduction] = 1.2
  tolerances[vsProduction_c] = 1.2
  tolerances[vntProduct_u] = 0.15
  # Government, sector-account, and production sources use different precision.
  tolerances[vtProduct] = 1.2
  tolerances[vsProduct] = 1.2
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

    vCorpIncomeBeforeTax_s[s=corporation_sector, t=t1:T],
    vCorpIncomeBeforeTax_s[s,t] == vGrossOpSurplusMixedIncome[s,t]
      - vCorpCapitalTaxDeduction_s[s,t]
      - vCorpDebtTaxDeduction_s[s,t]

    vtCorp_s[s=corporation_sector, t=t1:T], vtCorp_s[s,t] == tCorp_s[s,t] * vCorpIncomeBeforeTax_s[s,t]

    vtCorp[t=t1:T], vtCorp[t] == ∑(vtCorp_s[s,t] for s in corporation_sector)
    @test_constraint("Corporation taxes sum over payer sectors"; atol=1e-6, rtol=1e-8)
    vtCorp[t=t1:T],
    vtCorp[t] == ∑(tCorp_s[s,t] * vCorpIncomeBeforeTax_s[s,t] for s in corporation_sector)
    vtRoWIncome[t=t1:T], vtRoWIncome[t] == tRoWIncome[t] * vRoWNetWages[t]
    vtDirect[t=t1:T], vtDirect[t] == vtHhIncome[t] + vtCorp[t] + vtRoWIncome[t]

    # Capital-transfer taxes. Household financial assets provide the simple base.
    vtCap[t=t1:T],
    vtCap[t] == tCap[t] * ∑(vFinPosition_s_f[:Hh,f,:Assets,t] for f in fin_instrument)

    # Product taxes and subsidies. Only origin leaves enter flow accounts.
    vtProduct_p_u_o[p=product, u=use, o=origin, t=t1:T],
    vtProduct_p_u_o[p,u,o,t] == tProduct_p_u_o[p,u,o,t] * qPurchaserUse_p_u_o[p,u,o,t]
    vsProduct_p_u_o[p=product, u=use, o=origin, t=t1:T],
    vsProduct_p_u_o[p,u,o,t] == tsProduct_p_u_o[p,u,o,t] * qPurchaserUse_p_u_o[p,u,o,t]
    vntProduct_p_u_o[p=product, u=use, o=origin, t=t1:T],
    vntProduct_p_u_o[p,u,o,t] == vtProduct_p_u_o[p,u,o,t] - vsProduct_p_u_o[p,u,o,t]
    ntProduct[p=product, u=ordinary_uses, o=origin, t=t1:T],
    ntProduct[p,u,o,t] * qPurchaserUse_p_u_o[p,u,o,t] == vntProduct_p_u_o[p,u,o,t]

    vtProduct_p_u[p=product, u=use, t=t1:T],
    vtProduct_p_u[p,u,t] == ∑(vtProduct_p_u_o[p,u,o,t] for o in origin)
    vsProduct_p_u[p=product, u=use, t=t1:T],
    vsProduct_p_u[p,u,t] == ∑(vsProduct_p_u_o[p,u,o,t] for o in origin)
    vntProduct_p_u[p=product, u=use, t=t1:T],
    vntProduct_p_u[p,u,t] == ∑(vntProduct_p_u_o[p,u,o,t] for o in origin)

    vntProduct_u[u=use, t=t1:T],
    vntProduct_u[u,t] == ∑(vntProduct_p_u[p,u,t] for p in product)
    vtProduct[t=t1:T], vtProduct[t] == ∑(vtProduct_p_u[p,u,t] for (p,u) in product_tax_p_u)
    vsProduct[t=t1:T],
    vsProduct[t] == ∑(vsProduct_p_u[p,u,t] for (p,u) in product_tax_p_u)
    vtRoWProduct[t=t1:T], vtRoWProduct[t] == uRoWProductTaxRecipient[t] * vtProduct[t]
    vsRoWProduct[t=t1:T],
    vsRoWProduct[t] == uRoWProductSubsidyPayer[t] * vsProduct[t]

    # Production taxes and subsidies.
    vsProduction[t=t1:T],
    vsProduction[t] == vtProduction[t] - ∑(vntProduction_i[i,t] for i in industry)
    vsRoWProduction[t=t1:T],
    vsRoWProduction[t] == uRoWProductionSubsidyPayer[t] * vsProduction[t]
    # Government indirect tax revenue is the government share of D.21 plus resident D.29.
    vtIndirect[t=t1:T], vtIndirect[t] == vtProduct[t] - vtRoWProduct[t] + vtProduction[t]

    # Production tax and subsidy inputs.
    vsProduction_c[c=production_subsidy_class, t=t1:T],
    vsProduction_c[c,t] == ∑(vsProduction_c_i[c,i,t] for i in industry)

    @test_constraint("Production subsidies sum over classes"; atol=1.2, rtol=1e-8)
    vsProduction[t=[t1]],
    vsProduction[t] == ∑(vsProduction_c[c,t] for c in production_subsidy_class)

    vtProduction[t=t1:T],
    vtProduction[t] == ∑(vtProduction_c_i[c,i,t] for c in production_tax_class, i in industry)

    vntK_k_i[k=capital_type, i=industry, t=t1:T],
    vntK_k_i[k,i,t] == ntK_k_i[k,i,t] * qK_k_i[k,i,t-1]/fq

    vntL_l_i[l=labor_type, i=industry, t=t1:T], vntL_l_i[l,i,t] == ntL_l_i[l,i,t] * qL_l_i[l,i,t]

    vntM_m_i[m=intermediate_type, i=industry, t=t1:T], vntM_m_i[m,i,t] == ntM_m_i[m,i,t] * qM_m_i[m,i,t]

    vntProduction_i[i=industry, t=t1:T],
    vntProduction_i[i,t] == vntProductionOther_i[i,t]
      + ∑(vntK_k_i[k,i,t] for k in capital_type)
      + ∑(vntL_l_i[l,i,t] for l in labor_type)
      + ∑(vntM_m_i[m,i,t] for m in intermediate_type)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    tHhIncome[t1], vtHhIncome[t1]
    tCorp_s[:,t1], vtCorp_s[:,t1]
    tRoWIncome[t1], vtRoWIncome[t1]
    tCap[t1], vtCap[t1]
    tProduct_p_u_o[:,:,:,t1], vtProduct_p_u_o[:,:,:,t1]
    tsProduct_p_u_o[:,:,:,t1], vsProduct_p_u_o[:,:,:,t1]
    uRoWProductTaxRecipient[t1], vtRoWProduct[t1]
    uRoWProductSubsidyPayer[t1], vsRoWProduct[t1]
    uRoWProductionSubsidyPayer[t1], vsRoWProduction[t1]

    ntK_k_i[:,:,t1], vntK_k_i[:,:,t1]
    ntL_l_i[:,:,t1], vntL_l_i[:,:,t1]
    ntM_m_i[:,:,t1], vntM_m_i[:,:,t1]
  end

  return block
end
end # module
