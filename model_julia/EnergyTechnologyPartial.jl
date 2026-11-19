# Calibrate the partial energy technology model and link it one way to the CGE model.
# CGE prices and energy demand drive the partial model. Nothing goes back to the CGE model.
# The mappings to the CGE model are in modules/EnergyTechnologySettings.jl.
# Needs Output/baseline.parquet from Calibrate.jl and Output/scenario.parquet from Shock.jl.
# Needs :EnergyTechnology in Settings.loaded_modules. Keep it out of Settings.model_modules.
using Revise
using SquareModels
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
import GREU.InputOutput: pPurchaserUse_p_u
import GREU.Intermediates: qM_m_i
import GREU.Capital: pK_k_i
import GREU.EnergyTechnologySettings: linked_capital, linked_industry, linked_product

include("Helper.jl") # Helper functions
Time.t1 = Settings.calibration_year # An earlier run in this session may have moved t1.

const output_dir = joinpath(@__DIR__, "..", "Output")

# ==============================================================================
# Shock settings
# ==============================================================================
# First shocked year. Use the same year as in Shock.jl.
const shock_year = 2026

# ==============================================================================
# Calibration of the partial model on its own data
# ==============================================================================
data = assign_data!(ModelDictionary(model))
@log_time adjust_growth_inflation!(data)

# Only this module adds equations. Helper.jl reads this name.
model_modules = [EnergyTechnology]

Time.T = Time.max_terminal_year
base_blocks = [m.define_equations() for m in model_modules]
base_block = sum(base_blocks)

static_solution, static_calibrated_parameters = static_calibration(data, base_block)
calibrated = @log_time "dynamic calibration" dynamic_calibration(
  data, static_solution, static_calibrated_parameters; base_blocks)

assert_residuals_small(calibrated; rtol=1e-4, residual_tolerances(calibrated, model_modules)...,
  msg="Large residuals after dynamic calibration")

Time.t1 = shock_year
zero_shock = solve(base_model(model_modules), calibrated; run_test_constraints=false)
assert_no_diff(calibrated, zero_shock; atol=1e-5, msg="Zero shock test failed")

# ==============================================================================
# CGE results
# ==============================================================================
# Build the CGE model first, so that its residual variables exist when the results load.
cge_block = base_model([loaded_module_by_name[name] for name in Settings.model_modules])
cge_baseline = load(joinpath(output_dir, "baseline.parquet"), cge_block.model)
cge_scenario = load(joinpath(output_dir, "scenario.parquet"), cge_block.model)

"""Growth of a CGE series from the calibration year to `year`. `var(t)` gives the series in year t."""
function cge_growth(cge, var, year)
  start, now = cge[var(Settings.calibration_year)], cge[var(year)]
  @assert !isnothing(start) && !isnothing(now) "No CGE value for $(var(year)). Check the link settings."
  return now / start
end

"""
Set the partial model's demand, energy prices and capital cost from the CGE model.
Each keeps its calibration-year level from the data and grows as its CGE series.
"""
function link!(db, cge, years)
  t0 = Settings.calibration_year
  E = EnergyTechnology
  for year in years, (es, d) in E.service_es_d
    i = linked_industry[d]
    db[E.qES_es_d[es,d,year]] = db[E.qES_es_d[es,d,t0]] * cge_growth(cge, t -> qM_m_i[:energy,i,t], year)
    db[E.pTK_d[d,year]] = db[E.pTK_d[d,t0]] * cge_growth(cge, t -> pK_k_i[linked_capital,i,t], year)
    for e in E.energy
      (es,e,d) in E.energy_es_e_d && haskey(linked_product, e) || continue
      db[E.pEBase_es_e_d[es,e,d,year]] =
        db[E.pEBase_es_e_d[es,e,d,t0]] * cge_growth(cge, t -> pPurchaserUse_p_u[linked_product[e],i,t], year)
    end
  end
  return db
end

# ==============================================================================
# Linked baseline and scenario
# ==============================================================================
# Linked baseline: the partial model under the CGE baseline from the year after calibration.
Time.t1 = Settings.calibration_year + 1
baseline = link!(copy(calibrated), cge_baseline, Time.t1:Time.T)
@log_time "linked baseline" solve!(base_model(model_modules), baseline)

# Linked scenario: the partial model under the CGE scenario from the shock year.
Time.t1 = shock_year
scenario = link!(copy(baseline), cge_scenario, Time.t1:Time.T)
@log_time "linked scenario" solve!(base_model(model_modules), scenario)

# ==============================================================================
# Results
# ==============================================================================
shown_year = 2030
change(var) = round(100 * (scenario[var] / baseline[var] - 1); digits=2)
user, service = :i10030, :heating
i = linked_industry[user]

println("CGE in $i, $shown_year: % change from baseline")
for p in sort(unique(values(linked_product)))
  price = pPurchaserUse_p_u[p,i,shown_year]
  println("  price of $p: ", round(100 * (cge_scenario[price] / cge_baseline[price] - 1); digits=2))
end
energy_input = qM_m_i[:energy,i,shown_year]
println("  energy input: ", round(100 * (cge_scenario[energy_input] / cge_baseline[energy_input] - 1); digits=2))

println("$service in $user, $shown_year: linked baseline -> linked scenario")
for l in EnergyTechnology.technologies(service, user)
  share = EnergyTechnology.rT_l_es_d[l,service,user,shown_year]
  println("  share of $l: ", round(baseline[share]; digits=4), " -> ", round(scenario[share]; digits=4))
end
for e in EnergyTechnology.energy
  (service, e, user) in EnergyTechnology.energy_es_e_d || continue
  use = EnergyTechnology.qESE_es_e_d[service,e,user,shown_year]
  println("  PJ of $e: ", round(baseline[use]; digits=4), " -> ", round(scenario[use]; digits=4))
end
for (name, price) in (("marginal price", EnergyTechnology.pESMarg_es_d), ("average price", EnergyTechnology.pES_es_d))
  println("  $name: ", round(baseline[price[service,user,shown_year]]; digits=4),
    " -> ", round(scenario[price[service,user,shown_year]]; digits=4), " (", change(price[service,user,shown_year]), "%)")
end