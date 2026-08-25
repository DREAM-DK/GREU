# Apply an example scenario shock to the calibrated baseline (produced by Calibrate.jl)
# and plot the results.
include("Model.jl")
import .Time: T

baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), model)

scenario = copy(baseline)
scenario[ModuleTemplate.test_forecast[T-5:T]] .+= π
@log_time solve!(base_model(model_modules), scenario)

using CairoMakie, SquareModels, DREAMMakieTheme

set_default_source!(baseline => scenario)
set_default_periods!(T-5:T)
@prt :m test_forecast

@plot :m test_forecast
