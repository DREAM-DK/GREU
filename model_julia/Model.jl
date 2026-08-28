# Define the shared model and include all loaded modules.
# Provide explicit source-value construction for calibration.
# Do not create source values as an include side effect.
import SquareModels: ModelDictionary, solve, solve!, load, unload, assert_no_diff, assert_residuals_small

include("Settings.jl")
include("Time.jl")
include("GrowthInflationAdjustment.jl")
include("Tags.jl")
include("DataUtils.jl")

include("Logging.jl")
import .Log: @log_time, @log_errors

# ==============================================================================
# Model
# ==============================================================================
const model = Settings.square_model()

# ==============================================================================
# Modules
# ==============================================================================
const loaded_modules = [
  @log_time("include modules/$name.jl", include(joinpath("modules", "$name.jl")))
  for name in Settings.loaded_modules
]

# Revise methods without rerunning module data and variable declarations.
for m in loaded_modules
  Core.eval(m, :(const __revise_mode__ = :evalmeth))
end

const loaded_module_by_name = Dict(nameof(m) => m for m in loaded_modules)

function assign_data!(db)
  for m in loaded_modules
    @log_time("assign_data!($m)", m.assign_data!(db))
  end
  return db
end

base_model(modules) = @log_time sum(m.define_equations() for m in modules)
