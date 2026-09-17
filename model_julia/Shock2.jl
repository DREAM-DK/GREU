# Solve one shock scenario against the calibrated baseline and write its report.
# To create another experiment, copy this file and change the marked settings
# and shock definition below.
using SquareModels
import GREU: Settings, Time, model, loaded_module_by_name, base_model, Production, Exports
import GREU.ProductionSettings: labor_type
import GREU.Time: t1, T
import GREU.Taxes: tHhIncome
import GREU.SectorAccounts: vNetFinAssets
import GREU.Log: @log_time

include("ShockReport.jl")


# Drop the wage Phillips curve to get a competitive labor market. Household
# employment then stays at its baseline level and pW clears the market each year.
model_modules = [
  loaded_module_by_name[name] for name in Settings.model_modules if name != :PhillipsCurve
]

# ==============================================================================
# Shock settings
# ==============================================================================
# Choose the first shocked year. A calendar year can also be entered directly.
shock_year = Time.t1 + 5

# Enter percentage shocks as decimal changes: 0.01 is +1% and -0.01 is -1%.
shock_size = 0.01

# Ending at Time.T makes the shock permanent. For a one-year shock, use
# `shock_period = shock_year:shock_year` instead.
shock_period = shock_year:Time.T

# Start the report one year earlier to display anticipatory responses.
report_period = (shock_year - 1):Time.T

# Change the report type and file name when defining another shock. The report
# has tailored overview figures for :export and :labor_supply; other symbols use
# the standard overview figures.
report_kind = :labor_productivity
report_file = "labor_productivity_shock_report.html"

# Create residual variables before loading their calibrated values.
block = base_model(model_modules)
baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), model)

# ==============================================================================
# Fiscal closure
# ==============================================================================
# The core has no tax rule, so a shock that moves the primary balance puts
# government debt on a permanent drift and no stock reaches a steady state.
# Hold net government assets on the baseline path and let the household income
# tax rate carry the adjustment.
@endo_exo_swap! block begin
  tHhIncome[t1:T], vNetFinAssets[:Gov,t1:T]
end
# ==============================================================================
# Shock definition - replace this line to shock another exogenous variable
# ==============================================================================
# This example permanently raises labor productivity in every industry by 1%.
# uProd is the CES share of labor in its nest, so one percent less labor per unit
# of the input bundle is one percent higher labor productivity. The share moves
# opposite to productivity, hence the minus sign.
scenario = copy(baseline)
E = 0.7
scenario[Production.uProd[labor_type,:,shock_period]] .*= (1 + shock_size)^(E-1)
scenario[Exports.qXMarket_p[:,shock_period]] .*= 1 + shock_size
@log_time solve!(block, scenario; run_test_constraints=false)

# Write one HTML report for the solved scenario.
shock_report = ShockReport.write_report(
  joinpath(@__DIR__, "..", "Output", report_file),
  baseline,
  scenario;
  periods=report_period,
  shock_year,
  kind=report_kind,
)

# ==============================================================================
# Diagnostics
# ==============================================================================
# Build every sum and ratio inside @prt. The macro replaces the last index with
# the default periods, so a container built outside it keeps every year. Do not
# splice with `@prt $result` either, which applies the operator a second time.
using SquareModels: @prt, set_default_source!, set_default_periods!, set_default_operator!
import GREU.Labor: pW, vHhWages, qL_l_i, labor_l_i
import GREU.InputOutput: qC, pC, qI, qX, qG
import GREU.FixedBasePriceAggregates: qGDP
import GREU.Capital: capital_k_i, qK_k_i
import GREU.ConsumptionSavingsDecision: qHhWealth
import GREU.SectorAccounts: vFinPosition_s_f, vFinTransactions_f, vFinReval_s_f, vNetFinTransactions, vNetFinReval
import GREU.FinancialRevaluations: rFinReval_f
import GREU.IndustrySectors: vK_s
import GREU.Corporations: vNonFinCorpExpenses

set_default_source!(baseline => scenario)
set_default_operator!(:q)
set_default_periods!((T-5):T)

# Consumption tracks household wealth one for one, and the wage magnifies the
# output shortfall by about three.
@prt (
  qGDP, qC, qI, qX, qG, qHhWealth, pW,
  sum(qL_l_i[l,i,:] for (l, i) in labor_l_i),
  sum(qK_k_i[k,i,:] for (k, i) in capital_k_i),
)

# Corporate equity value is the residual of the balance sheet, so a rise in
# corporate net financial assets shows up as a capital loss for the owners. Cross
# holdings divide that loss by one less the equity asset ratio.
@prt :m vNetFinAssets
@prt :m vFinPosition_s_f[:,:Equity,:Assets,:]
@prt :m vFinTransactions_f[:,:Equity,:Liab,:]

# Households and financial corporations now buy their share of new issues, so
# these no longer sit at zero. That is the change under test.
@prt :m vFinTransactions_f[:,:Equity,:Assets,:]

# The price of holding government net assets on the baseline path.
@prt :m tHhIncome

# Real household wealth is net financial assets over pC, and nothing else. It
# holds no capital and no future wages, and it enters utility as a level. Read
# every line as a percentage: a homogeneous model puts each one at 1.0.
@prt (qHhWealth, qC, pC, vNetFinAssets[:Hh,:], vHhWages)

# Saving against revaluation. Before the share rule, saving was positive while
# revaluation carried the whole wealth loss, because the adjusted equity stock had
# a unit root: its revaluation rate only offset fv, so nothing pulled it back.
@prt :m (vNetFinTransactions[:Hh,:], vNetFinReval[:Hh,:], vFinReval_s_f[:Hh,:Equity,:Assets,:])
@prt :m rFinReval_f[:Equity,:]

# Firm value against what it should track. Equity is the residual of the balance
# sheet, so it follows corporate debt and expenses, not the capital stock.
@prt (
  vFinPosition_s_f[:NonFinCorp,:Equity,:Liab,:],
  vFinPosition_s_f[:NonFinCorp,:Debt,:Liab,:],
  vFinPosition_s_f[:NonFinCorp,:Debt,:Assets,:],
  vK_s[:NonFinCorp,:],
  vNonFinCorpExpenses,
)


