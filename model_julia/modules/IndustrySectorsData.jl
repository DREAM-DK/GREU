# Build stylized industry-to-sector shares from current model inputs.
# Target government and household costs and sector operating surplus.
# Write each assumption beside its share so better data can replace it.

include(joinpath(@__DIR__, "..", "Settings.jl"))
include("GovernmentSettings.jl")
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("SectorAccountsSettings.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module IndustrySectorsData

using CSV
using DataFrames
import Ipopt
import JuMP
import ..DataUtils: read_cells
import ..GovernmentSettings: government_data_dir
import ..InputOutputSettings: cell_tolerance, input_output_data_dir
import ..ProductionSettings: production_data_dir
import ..SectorAccountsSettings: sector_accounts_data_dir
import ..Settings: calibration_year

const mapped_sector = [:FinCorp, :NonFinCorp, :Gov, :Hh]
const source_component = [:intermediate, :wages, :production_taxes]
const sector_target_component = [:operating_cost, :operating_surplus]
const financial_industry = :iK
const government_core_industry = Set([:iO, :iP, :iQ])
const household_housing_industry = :iL

const supply_file = joinpath(input_output_data_dir, "input_output_supply.csv")
const purchaser_use_file = joinpath(input_output_data_dir, "input_output_purchaser_use.csv")
const margin_file = joinpath(input_output_data_dir, "input_output_margins.csv")
const product_tax_file = joinpath(input_output_data_dir, "input_output_net_product_tax.csv")
const labor_file = joinpath(production_data_dir, "production_labor.csv")
const production_file = joinpath(production_data_dir, "production_gva.csv")
const government_file = joinpath(government_data_dir, "government_variables.csv")
const non_financial_transactions_file = joinpath(sector_accounts_data_dir, "non_financial_transactions.csv")
const sector_accounts_file = joinpath(sector_accounts_data_dir, "sector_accounts.csv")
const share_file = joinpath(sector_accounts_data_dir, "industry_sector_shares.csv")

"""Sum cells whose second index is the selected industry and whose last index is the year."""
sum_industry_cells(cells, industry, year) = sum(
  value
  for (key, value) in cells
  if key[2] == industry && key[end] == year;
  init = 0.0,
)

"""Industries that have output in the calibration year."""
model_industries(output) = sort(unique(
  i
  for ((_,i,year), value) in output
  if year == calibration_year && abs(value) > cell_tolerance
))

"""Industry accounts from the same source cells that the model uses."""
function industry_accounts(industries, year, source)
  return Dict(
    i => begin
      output = sum_industry_cells(source.output, i, year)
      intermediate = sum_industry_cells(source.purchaser_use, i, year) +
                     sum_industry_cells(source.margins, i, year) +
                     sum_industry_cells(source.product_taxes, i, year)
      average_wage = sum(value for ((_,source_year), value) in source.payroll if source_year == year) /
                     sum(value for ((_,_,source_year), value) in source.labor if source_year == year)
      wages = average_wage * sum_industry_cells(source.labor, i, year)
      production_taxes = get(source.production_taxes, (i, year), 0.0)
      (
        output = output,
        intermediate = intermediate,
        wages = wages,
        production_taxes = production_taxes,
        operating_cost = intermediate + wages + production_taxes,
        operating_surplus = output - intermediate - wages - production_taxes,
      )
    end
    for i in industries
  )
end

"""Operating-surplus targets for each mapped sector."""
function operating_surplus_targets(source, year)
  return Dict(s => source[s,year] for s in mapped_sector)
end

"""Use core government industries first. Use other industries for an operating-surplus gap."""
function government_rates(target, core_total, other_total)
  target <= core_total && return (core = target / core_total, other = 0.0)
  return (core = 1.0, other = (target - core_total) / other_total)
end

"""Return a clear prior before the government component targets adjust the shares."""
function government_prior(industries, accounts, target)
  core_total = sum(accounts[i].operating_surplus for i in government_core_industry)
  other_industries = setdiff(industries, [financial_industry; collect(government_core_industry)])
  other_total = sum(accounts[i].operating_surplus for i in other_industries)
  rate = government_rates(target, core_total, other_total)
  return Dict(
    i => i in government_core_industry ? rate.core :
         i == financial_industry ? 0.0 : rate.other
    for i in industries
  )
end

"""Use household operating surplus for housing first and spread mixed income across other industries."""
function household_prior(industries, accounts, source, year)
  other_industries = setdiff(industries, [financial_industry, household_housing_industry])
  housing_target = source[:Hh,:B2G,:RECV,year]
  mixed_income_target = source[:Hh,:B3G,:RECV,year]
  return Dict(
    i => i == household_housing_industry ? housing_target / accounts[i].operating_surplus :
         i == financial_industry ? 0.0 :
         mixed_income_target / sum(accounts[j].operating_surplus for j in other_industries)
    for i in industries
  )
end

"""Project a sector prior onto its targets and keep every share in its valid range."""
function target_shares(industries, accounts, targets, prior, capacity)
  share_model = JuMP.Model(Ipopt.Optimizer)
  JuMP.set_silent(share_model)
  JuMP.set_optimizer_attribute(share_model, "bound_relax_factor", 0.0)
  JuMP.@variable(share_model, 0.0 <= share[i in industries] <= capacity[i])
  JuMP.@constraint(
    share_model,
    [component in sector_target_component],
    sum(share[i] * getproperty(accounts[i], component) for i in industries) / targets[component] == 1.0,
  )
  JuMP.@objective(
    share_model,
    Min,
    sum(
      (
        (sum(share[i] * getproperty(accounts[i], component) for i in industries) - targets[component]) /
        targets[component]
      )^2
      for component in source_component
    ) + 1e-8 * sum((share[i] - prior[i])^2 for i in industries),
  )
  JuMP.set_start_value.(share, [prior[i] for i in industries])
  JuMP.optimize!(share_model)
  @assert JuMP.is_solved_and_feasible(share_model) "Sector share solve status: $(JuMP.termination_status(share_model))"

  share_value = JuMP.value.(share)
  @assert all(
    0.0 <= share_value[i] <= capacity[i]
    for i in industries
  ) "The share solve must respect each sector capacity"
  return Dict(i => share_value[i] for i in industries)
end

"""Explain each temporary share assumption in the output file."""
function share_assumption(sector, industry)
  sector == :FinCorp && industry == financial_industry &&
    return "Target FinCorp operating surplus within iK."
  sector == :FinCorp && return "Assign no other industry to FinCorp."
  sector == :Gov && industry in government_core_industry &&
    return "Start with iO, iP, and iQ; adjust shares to match Gov operating costs and operating surplus."
  sector == :Gov && industry == financial_industry && return "Assign no iK activity to Gov."
  sector == :Gov && return "Adjust the prior to match Gov P2+D1+D29 and operating surplus."
  sector == :Hh && industry == household_housing_industry &&
    return "Start from household operating surplus in iL, then match household costs and operating surplus."
  sector == :Hh && industry == financial_industry && return "Assign no iK activity to Hh."
  sector == :Hh && return "Spread household mixed income across other industries, then match household targets."
  industry == financial_industry && return "Assign the iK remainder to NonFinCorp."
  return "Assign the remainder after FinCorp, Gov, and Hh to NonFinCorp."
end

"""Build one year of shares and check all sector targets."""
function stylized_shares(industries, year, accounts, targets, government_targets, household_targets, source)
  @assert financial_industry in industries "The share build needs iK"
  @assert government_core_industry ⊆ Set(industries) "The share build needs iO, iP, and iQ"
  @assert household_housing_industry in industries "The share build needs iL"

  fin_rate = targets[:FinCorp] / accounts[financial_industry].operating_surplus
  government_share = target_shares(
    industries,
    accounts,
    government_targets,
    government_prior(industries, accounts, targets[:Gov]),
    Dict(i => i == financial_industry ? 0.0 : 1.0 for i in industries),
  )

  fin_share(i) = i == financial_industry ? fin_rate : 0.0
  household_share = target_shares(
    industries,
    accounts,
    household_targets,
    household_prior(industries, accounts, source, year),
    Dict(
      i => i == financial_industry ? 0.0 : 1.0 - fin_share(i) - government_share[i]
      for i in industries
    ),
  )

  non_fin_share(i) = 1.0 - fin_share(i) - government_share[i] - household_share[i]
  share(s, i) = s == :FinCorp ? fin_share(i) :
                s == :Gov ? government_share[i] : s == :Hh ? household_share[i] : non_fin_share(i)

  shares = DataFrame([
    (
      sector = s,
      industry = i,
      year = year,
      value = share(s, i),
      assumption = share_assumption(s, i),
    )
    for i in industries, s in mapped_sector
  ][:])

  @assert all((0.0 .<= shares.value) .& (shares.value .<= 1.0))
    "Each industry-sector share must be between zero and one"
  @assert all(
    isapprox(sum(shares.value[shares.industry .== i]), 1.0; atol = 1e-12, rtol = 0)
    for i in industries
  ) "Sector shares must sum to one for each industry"

  allocated(s) = sum(
    share(s, i) * accounts[i].operating_surplus
    for i in industries
  )
  @assert all(
    isapprox(allocated(s), targets[s]; atol = 2.0, rtol = 0)
    for s in mapped_sector
  ) "Stylized shares must reproduce sector operating surplus within source rounding"
  @assert all(
    isapprox(
      sum(share(:Gov, i) * getproperty(accounts[i], component) for i in industries),
      government_targets[component];
      atol = 2.0,
      rtol = 0,
    )
    for component in sector_target_component
  ) "Stylized shares must reproduce government components within source rounding"
  @assert all(
    isapprox(
      sum(share(:Hh, i) * getproperty(accounts[i], component) for i in industries),
      household_targets[component];
      atol = 2.0,
      rtol = 0,
    )
    for component in sector_target_component
  ) "Stylized shares must reproduce household components within source rounding"
  return shares
end

"""Build shares for each year that has all four sector targets."""
function build_industry_sector_shares()
  source = (
    output = read_cells(supply_file, "qY_p_i"),
    purchaser_use = read_cells(purchaser_use_file, "qPurchaserUse_p_u"),
    margins = read_cells(margin_file, "qMarginBundle_p_u"),
    product_taxes = read_cells(product_tax_file, "vNetProductTax_p_u"),
    labor = read_cells(labor_file, "qL_l_i"),
    payroll = read_cells(labor_file, "vWages_i"),
    production_taxes = read_cells(production_file, "vProductionTax_i"),
  )
  target_source = read_cells(sector_accounts_file, "vGrossOpSurplusMixedIncome")
  non_financial_source = read_cells(non_financial_transactions_file, "NonFinancialTransactions")
  government_source = Dict(
    :intermediate => read_cells(government_file, "vGovIntermediateCons"),
    :wages => read_cells(government_file, "vGovEmplComp"),
    :production_taxes => read_cells(government_file, "vGovOthProdTax"),
  )
  years = sort(unique(
    year
    for ((_,year), _) in target_source
    if year in (calibration_year-1):calibration_year
       && all(haskey(target_source, (s, year)) for s in mapped_sector)
       && all(haskey(government_source[component], (year,)) for component in keys(government_source))
       && all(
         haskey(non_financial_source, (:Hh, item, direct, year))
         for (item,direct) in [(:P2,:PAID), (:D1,:PAID), (:D29,:PAID), (:D39,:RECV),
                               (:B2G,:RECV), (:B3G,:RECV)]
       )
  ))
  @assert !isempty(years) "The share build needs a common sector operating-surplus year"

  industries = model_industries(source.output)
  return vcat([
    stylized_shares(
      industries,
      year,
      industry_accounts(industries, year, source),
      operating_surplus_targets(target_source, year),
      Dict(
        :operating_cost => sum(
          government_source[component][(year,)] for component in source_component
        ),
        :operating_surplus => target_source[:Gov,year],
        (component => government_source[component][(year,)] for component in source_component)...,
      ),
      Dict(
        :operating_cost => non_financial_source[:Hh,:P2,:PAID,year] +
                           non_financial_source[:Hh,:D1,:PAID,year] +
                           non_financial_source[:Hh,:D29,:PAID,year] -
                           non_financial_source[:Hh,:D39,:RECV,year],
        :operating_surplus => target_source[:Hh,year],
        :intermediate => non_financial_source[:Hh,:P2,:PAID,year],
        :wages => non_financial_source[:Hh,:D1,:PAID,year],
        :production_taxes => non_financial_source[:Hh,:D29,:PAID,year] -
                             non_financial_source[:Hh,:D39,:RECV,year],
      ),
      non_financial_source,
    )
    for year in years
  ]...)
end

function refresh_industry_sector_shares!(dir = sector_accounts_data_dir)
  shares = build_industry_sector_shares()
  mkpath(dir)
  CSV.write(
    joinpath(dir, basename(share_file)),
    DataFrame(
      variable = fill("rIndustrySector_s_i", nrow(shares)),
      indices = ["$(row.sector),$(row.industry),$(row.year)" for row in eachrow(shares)],
      value = shares.value,
      assumption = shares.assumption,
    ),
  )
  return shares
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  IndustrySectorsData.refresh_industry_sector_shares!()
end
