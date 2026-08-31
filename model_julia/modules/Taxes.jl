# Set direct, capital, product, and production tax rules.
# Map production tax and subsidy classes to factor inputs.
# Keep classes with no factor link at the top of the production tree.
include("TaxesSettings.jl")

module Taxes

using SquareModels
import ..Capital:
  capital_k_i,
  qK_k_i,
  qK_k_i_data,
  tK_k_i
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fq
import ..InputOutput: industry, use, vNetProductTax_u, vY
import ..Intermediates:
  intermediate_m_i,
  qM_m_i,
  qM_m_i_data,
  tM_m_i
import ..Labor:
  labor_l_i,
  qL_l_i,
  qL_l_i_data,
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
  NetNonFinancialTransactions_data,
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

const vProductionTax_c_i_data = read_cells(production_taxes_file, "vProductionTax_c_i")
const vProductionSubsidy_c_i_data = read_cells(production_taxes_file, "vProductionSubsidy_c_i")
const vProductionSubsidy_c_data = read_cells(production_taxes_file, "vProductionSubsidy_c")
const vProductionTax_data = read_cells(production_taxes_file, "vProductionTax")
const vtProduction_i_data = read_cells(production_gva_file, "vProductionTax_i")
const vtRoWProduct_data = Dict(
  (year,) => value
  for ((s, d, year), value) in NetNonFinancialTransactions_data
  if (s, d) == (:RoW, :D2)
)
const vRoWProductionSubsidy_data = Dict(
  (year,) => -value
  for ((s, d, year), value) in NetNonFinancialTransactions_data
  if (s, d) == (:RoW, :D3)
)

# ============================================================================
# Indices
# ============================================================================
const production_tax_class = sort(collect(keys(production_tax_input_map)))
const production_subsidy_class = sort(collect(keys(production_subsidy_input_map)))
const corporation_sector = [:FinCorp, :NonFinCorp]
const matrix_year = sort(unique(year for (_, _, year) in keys(vProductionTax_c_i_data)))

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
@assert all(>=(0), values(vRoWProductionSubsidy_data)) "RoW production subsidy payments must be nonnegative"
@assert all(
  count(!isempty(intersect(targets, inputs)) for inputs in (capital_type, labor_type, intermediate_type)) <= 1
  for targets in Iterators.flatten((values(production_tax_input_map), values(production_subsidy_input_map)))
) "A tax or subsidy class cannot span factor modules with different units"

function mapped_targets(mapping, class, factor_cells, factor_data, i, year)
  return [
    n
    for n in mapping[class]
    if (n, i) in factor_cells && get(factor_data, (n, i, year), 0.0) > 0
  ]
end

function mapped_value(cells, mapping, factor_cells, factor_data, n, i, year)
  return sum(
    get(cells, (class, i, year), 0.0) *
      factor_data[(n, i, year)] /
      sum(
        factor_data[(target, i, year)]
        for target in mapped_targets(mapping, class, factor_cells, factor_data, i, year)
      )
    for class in keys(mapping)
    if n in mapped_targets(mapping, class, factor_cells, factor_data, i, year)
    ; init=0.0
  )
end

function has_mapped_target(mapping, class, i, year)
  return !isempty(mapped_targets(mapping, class, capital_k_i, qK_k_i_data, i, year)) ||
    !isempty(mapped_targets(mapping, class, labor_l_i, qL_l_i_data, i, year)) ||
    !isempty(mapped_targets(mapping, class, intermediate_m_i, qM_m_i_data, i, year))
end

function unmapped_value(cells, mapping, i, year)
  return sum(
    get(cells, (class, i, year), 0.0)
    for class in keys(mapping)
    if !has_mapped_target(mapping, class, i, year)
    ; init=0.0
  )
end

const vtK_k_i_data = Dict(
  (k, i, year) =>
    mapped_value(vProductionTax_c_i_data, production_tax_input_map, capital_k_i, qK_k_i_data, k, i, year) -
    mapped_value(vProductionSubsidy_c_i_data, production_subsidy_input_map, capital_k_i, qK_k_i_data, k, i, year)
  for (k, i) in capital_k_i, year in matrix_year
)
const vtL_l_i_data = Dict(
  (l, i, year) =>
    mapped_value(vProductionTax_c_i_data, production_tax_input_map, labor_l_i, qL_l_i_data, l, i, year) -
    mapped_value(vProductionSubsidy_c_i_data, production_subsidy_input_map, labor_l_i, qL_l_i_data, l, i, year)
  for (l, i) in labor_l_i, year in matrix_year
)
const vtM_m_i_data = Dict(
  (m, i, year) =>
    mapped_value(vProductionTax_c_i_data, production_tax_input_map, intermediate_m_i, qM_m_i_data, m, i, year) -
    mapped_value(vProductionSubsidy_c_i_data, production_subsidy_input_map, intermediate_m_i, qM_m_i_data, m, i, year)
  for (m, i) in intermediate_m_i, year in matrix_year
)
const vtProductionOther_i_data = Dict(
  (i, year) =>
    unmapped_value(vProductionTax_c_i_data, production_tax_input_map, i, year) -
    unmapped_value(vProductionSubsidy_c_i_data, production_subsidy_input_map, i, year)
  for i in industry, year in matrix_year
)

# ============================================================================
# Variables
# ============================================================================
const TaxesTag = Tag(:Taxes)

@variables model :: (TaxesTag, ForecastConstant) begin
  tHhIncome[t], "Average and marginal household income tax rate."
  tCorp_s[s=corporation_sector, t=t], "Average and marginal corporation tax rate by payer sector."
  tRoWIncome[t], "Average rest-of-world income tax rate on net wages."
  tCap[t], "Average and marginal capital tax rate on household financial assets."
  tProductSubsidy[t], "Average and marginal product subsidy rate on output."
  uRoWProductTaxRecipient[t], "Share of gross product taxes received by RoW."
  uRoWProductionSubsidyPayer[t], "Share of production subsidies paid by RoW."
end

@variables model :: (TaxesTag, GrowthAdjusted, InflationAdjusted, ForecastConstant) begin
  vProductionTax_c_i[c=production_tax_class, i=industry, t=t], "Production tax by class and industry."
  vProductionSubsidy_c_i[c=production_subsidy_class, i=industry, t=t], "Production subsidy by class and industry."
end

@variables model :: (TaxesTag, GrowthAdjusted, InflationAdjusted) begin
  vCorpIncomeBeforeTax_s[s=corporation_sector, t=t], "Corporation income before tax."
  vCorpCapitalTaxDeduction_s[s=corporation_sector, t=t] :: ForecastZero, "Capital tax depreciation deduction."
  vCorpDebtTaxDeduction_s[s=corporation_sector, t=t] :: ForecastZero, "Debt return deducted from taxable income."
  vProductSubsidy[t], "Subsidies on products (D.31)."
  vProductionSubsidy[t], "Subsidies on production implied by gross taxes and net factor-tax payments (D.39)."
  vtRoWProduct[t], "Taxes on products received by the rest of the world."
  vRoWProductionSubsidy[t], "Subsidies on production paid by the rest of the world."
  vGovProductTax[t], "Government taxes on products (D.21)."
  vGovSub[t], "Government subsidies on products and production (D.3)."
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
  fill_cells!(db, vRoWProductionSubsidy, vRoWProductionSubsidy_data)
  return nothing
end

function set_residual_tolerances!(tolerances)
  # Sector accounts report whole EUR millions. Tax classes and industries use decimals.
  tolerances[vProductionTax] = 1.2
  tolerances[vProductionSubsidy_c] = 1.2
  # Government, sector-account, and production sources use different precision.
  tolerances[vGovProductTax] = 1.2
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

    # Production taxes and subsidies.
    vProductionSubsidy[t=t1:T],
    vProductionSubsidy[t] == vProductionTax[t] - ∑(vtProduction_i[i,t] for i in industry)
    vRoWProductionSubsidy[t=t1:T],
    vRoWProductionSubsidy[t] == uRoWProductionSubsidyPayer[t] * vProductionSubsidy[t]
    # Product taxes and subsidies.
    vProductSubsidy[t=t1:T], vProductSubsidy[t] == tProductSubsidy[t] * vY[t]
    vtRoWProduct[t=t1:T],
    vtRoWProduct[t] ==
      uRoWProductTaxRecipient[t] * (∑(vNetProductTax_u[u,t] for u in use) + vProductSubsidy[t])

    # Government tax and subsidy totals.
    vGovSub[t=t1:T],
    vGovSub[t] == vProductSubsidy[t] + vProductionSubsidy[t] - vRoWProductionSubsidy[t]
    vGovProductTax[t=t1:T],
    vGovProductTax[t] ==
      ∑(vNetProductTax_u[u,t] for u in use) + vProductSubsidy[t] - vtRoWProduct[t]
    vtIndirect[t=t1:T], vtIndirect[t] == vGovProductTax[t] + vProductionTax[t]

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
    tCorp_s[:,t1], vtCorp_s[:,t1]
    tRoWIncome[t1], vtRoWIncome[t1]
    tCap[t1], vtCap[t1]
    tProductSubsidy[t1], vGovSub[t1]
    uRoWProductTaxRecipient[t1], vtRoWProduct[t1]
    uRoWProductionSubsidyPayer[t1], vRoWProductionSubsidy[t1]

    tK_k_i[:,:,t1], vtK_k_i[:,:,t1]
    tL_l_i[:,:,t1], vtL_l_i[:,:,t1]
    tM_m_i[:,:,t1], vtM_m_i[:,:,t1]
  end

  return block
end
end # module
