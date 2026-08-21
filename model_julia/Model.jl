# Green Reform EU Model - Julia/JuMP/SquareModels Implementation
#
# A modular dynamic general equilibrium model for
# - fiscal sustainability
# - climate policy
# This is a minimal implementation to establish the architecture.
#
# Shared model container: settings, submodules, and the base equation system.
# Included by both Calibrate.jl (produces the baseline) and Shock.jl (runs scenarios on it).
import SquareModels: ModelDictionary, solve, solve!, load, unload, assert_no_diff, assert_residuals_small

include("Settings.jl")
include("Time.jl")
include("GrowthInflationAdjustment.jl")
include("Tags.jl")
include("DataUtils.jl")

include("Logging.jl")
import .Log: @log_time, @log_errors

# ==============================================================================
# Global model container
# ==============================================================================
db = ModelDictionary(Settings.square_model())

# ==============================================================================
# Include submodules
# ==============================================================================
const submodels = [@log_time("include modules/$name.jl", include(joinpath("modules", "$name.jl"))) for name in Settings.enabled_modules]

for m in submodels
	@log_time("set_data!($m)", m.set_data!(db))
end

base_model() = @log_time sum(m.define_equations() for m in submodels)
