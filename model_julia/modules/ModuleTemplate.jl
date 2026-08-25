# Template for a new model module. Copy this file and add it to Settings.module_names.
# Read data, then build indices, then declare variables, then assign values.

module ModuleTemplate

using SquareModels
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================

# ============================================================================
# Indices
# ============================================================================
const test_index = [:a, :b, :c]

# ============================================================================
# Variables
# ============================================================================
@variables model begin
  test_variable[t], "Test variable from the module template."
  test_scalar, "Test variable with no indices."
  test_constant[test_index], "Test variable with no time index."
  test_forecast[t] :: ForecastConstant, "Variable forecast as constant from t1."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[test_variable] .= 1.0
  db[test_scalar] = 1.0
  db[test_constant] .= 1.0
  db[test_forecast] .= 42.0
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    test_variable[t = t1:T],
    test_variable[t] == 1

    @test_constraint("test_forecast must be constant")
    test_forecast[t = t1:T], test_forecast[t] == test_forecast[t1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations() + @block model begin
    test_forecast[t = t1:t1],
    test_forecast[t] == 42.0
  end
  return block
end

end # module
