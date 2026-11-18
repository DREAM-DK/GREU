# Calibrate and shock the partial energy technology model on its own.
# Energy prices, capital cost and service demand stay at their data values. No other module solves.
# Needs :EnergyTechnology in Settings.loaded_modules. Keep it out of Settings.model_modules.
using Revise
using SquareModels
include("sqm_patch.jl")
import GREU:
  Settings,
  Time,
  model,
  loaded_modules,
  loaded_module_by_name,
  assign_data!,
  base_model
import GREU.Log: @log_time
import GREU.GrowthInflationAdjustment: adjust_growth_inflation!
import GREU.Calibration: residual_tolerances
import GREU.EnergyTechnology

include("Helper.jl") # Helper functions
Time.t1 = Settings.calibration_year # An earlier run in this session may have moved t1.

const output_dir = joinpath(@__DIR__, "..", "Output")

# ==============================================================================
# Data
# ==============================================================================
data = assign_data!(ModelDictionary(model))
@log_time adjust_growth_inflation!(data)

# Only this module adds equations. Helper.jl reads this name.
model_modules = [EnergyTechnology]

Time.T = Time.max_terminal_year
base_blocks = [m.define_equations() for m in model_modules]
base_block = sum(base_blocks)

# ==============================================================================
# Calibration
# ==============================================================================
static_solution, static_calibrated_parameters = static_calibration(data, base_block)
baseline = @log_time "dynamic calibration" dynamic_calibration(
  data, static_solution, static_calibrated_parameters; base_blocks)

assert_residuals_small(baseline; rtol=1e-4, residual_tolerances(baseline, model_modules)...,
  msg="Large residuals after dynamic calibration")

Time.t1 = 2026
zero_shock = solve(base_model(model_modules), baseline; run_test_constraints=false)
assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed")

mkpath(output_dir)
unload(joinpath(output_dir, "energy_technology_baseline.parquet"), baseline)

# ==============================================================================
# Shock
# ==============================================================================
# The price of all inputs except electricity and captured CO2 rises by 0.5 per PJ from t1.
t1, T = Time.t1, Time.T
user, service = :i10030, :heating
shocked = [e for e in EnergyTechnology.energy
  if (service, e, user) in EnergyTechnology.energy_es_e_d && !(e in (:electricity, :captured_co2))]
scenario = copy(baseline)
for e in shocked
  scenario[EnergyTechnology.pE_es_e_d[service,e,user,t1:T]] .+= 0.5
end
solve!(base_model(model_modules), scenario)

# ==============================================================================
# Results
# ==============================================================================
shown_year = 2030
println("$service in $user, $shown_year: baseline -> shock")
for l in EnergyTechnology.technologies(service, user)
  share = EnergyTechnology.rT_l_es_d[l,service,user,shown_year]
  println("  share of $l: ", round(baseline[share]; digits=3), " -> ", round(scenario[share]; digits=3))
end
for e in EnergyTechnology.energy
  (service, e, user) in EnergyTechnology.energy_es_e_d || continue
  use = EnergyTechnology.qESE_es_e_d[service,e,user,shown_year]
  println("  PJ of $e: ", round(baseline[use]; digits=3), " -> ", round(scenario[use]; digits=3))
end
for (name, price) in (("marginal price", EnergyTechnology.pESMarg_es_d), ("average price", EnergyTechnology.pES_es_d))
  println("  $name: ", round(baseline[price[service,user,shown_year]]; digits=4),
    " -> ", round(scenario[price[service,user,shown_year]]; digits=4))
end