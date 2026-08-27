# Solve one shock scenario against the calibrated baseline and write its report.
# To create another experiment, copy this file and change the marked settings
# and shock definition below.
include("Model.jl")
include("ShockReport.jl")

# Use the same equation modules as Calibrate.jl. If that list changes, update
# this list as well before running new shocks.
modules = [
  ModuleTemplate,

  InputOutput,
    ImportSubstitution,
    FixedBasePriceAggregates,

  Production,
    Labor,
    Intermediates,
    Capital,

    Pricing,

  SectorAccounts,
    Households,
      ConsumptionSavingsDecision,
      # ConsumptionGroups,
    Government,
    Corporations,
      FinancialIncome,
      FirmValue,
    RestOfWorld,
      Exports,

  CapitalAdjustmentCosts,
  PhillipsCurve,
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
report_kind = :export
report_file = "export_demand_shock_report.html"

baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), model)
block = base_model(modules)

# ==============================================================================
# Shock definition - replace this line to shock another exogenous variable
# ==============================================================================
# This example permanently increases foreign demand for direct exports by 1%.
scenario = copy(baseline)
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
