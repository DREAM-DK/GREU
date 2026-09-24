# Solve one shock scenario against the calibrated baseline and write its report.
# To create another experiment, copy this file and change the marked settings
# and shock definition below.
using SquareModels
import GREU: Settings, Time, loaded_module_by_name, base_model, Exports, Labor
import GREU.Labor: labor_l_i, nL_l_i
import GREU.Time: T
import GREU.Log: @log_time

include("ShockReport.jl")

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
scenario[Labor.qL2nL[t1:T]] .*= 1.01 # replace this line to shock another exogenous variable
@log_time solve!(block, scenario; run_test_constraints=false)

# Report settings
report_file = "shock_report.html"
shock_title = "Labour productivity shock"
extra_figures=[(_, _, options) -> "Employment" => @plot(sum(nL_l_i[l,i,:] for (l, i) in labor_l_i); options...)]

# ==============================================================================
# Write one HTML report for the solved scenario.
# ==============================================================================
shock_report = ShockReport.write_report(
  joinpath(@__DIR__, "..", "Output", report_file), baseline, scenario;
  extra_figures,
  shock_title,
  periods=(t1-1):T,
)
