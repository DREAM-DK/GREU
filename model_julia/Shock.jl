# Solve one shock scenario against the calibrated baseline and write its report.
# To create another experiment, copy this file and change the marked settings
# and shock definition below.
using SquareModels
import GREU: Settings, Time, loaded_module_by_name, base_model, InputOutput
import GREU.Time: T
import GREU.Log: @log_time

model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]

# ==============================================================================
# Shock settings
# ==============================================================================
# Choose the first shocked year
t1 = Time.t1 = 2026

# Create residual variables before loading their calibrated values.
block = base_model(model_modules)
baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), block.model)

# ==============================================================================
# Shock definition
# ==============================================================================
scenario = copy(baseline)
# The import price of refined petroleum (C19) rises by 30% from t1.
scenario[InputOutput.pSupply_p_o[:C19,InputOutput.import_origin,t1:T]] .*= 1.3 # replace this line to shock another exogenous variable
@log_time solve!(block, scenario; start_values=baseline, run_test_constraints=false)

# Save the solved scenario. EnergyTechnologyLink.jl reads it.
unload(joinpath(@__DIR__, "..", "Output", "scenario.parquet"), scenario)

# Report settings
report_file = "shock_report.html"
tables_file = "c19_import_price_shock_tables.html"
shock_title = "C19 import price shock"
extra_figures = ()

# ==============================================================================
# Write one HTML report for the solved scenario.
# ==============================================================================
include("ShockReport.jl")
shock_report = ShockReport.write_report(
  joinpath(@__DIR__, "..", "Output", report_file), baseline, scenario;
  extra_figures,
  shock_title,
  periods=(t1-1):T,
)

# One styled HTML report with three tables: percentage deviation from baseline in 2050.
include("ShockTables.jl")
ShockTables.write_tables(
    joinpath(@__DIR__, "..", "Output", "ShockTables", tables_file),
    baseline, scenario;
    shock_title,
    year=2050
)



import GREU.EnergyTechnology as E
import GREU.InputOutput: pPurchaserUse_p_u
old = load(joinpath(@__DIR__, "..", "Output", "scenario_softlink.parquet"), block.model)
p = pPurchaserUse_p_u[:C19,:iC10_12,2030]
println("CGE C19 price, old vs new: ", old[p], "  ", scenario[p])
for l in E.technologies(:heating, :i10030)
  r = E.rT_l_es_d[l,:heating,:i10030,2030]
  println(l, ": ", round(baseline[r]; digits=4), " -> ", round(scenario[r]; digits=4))
end
for v in (E.pESMarg_es_d, E.pES_es_d)
  println(round(baseline[v[:heating,:i10030,2030]]; digits=2), " -> ", round(scenario[v[:heating,:i10030,2030]]; digits=2))
end