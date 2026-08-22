# Template for a new model module. Copy this file and add it to enabled_modules.
# Read data, then build indices, then declare variables, then assign values.

module ModuleTemplate

using SquareModels
import ..db
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
@variables db.model begin
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
  return @block db begin
    test_variable[t = t1:T],
    test_variable[t] == 1
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations() + @block db begin
    test_forecast[t = t1:t1],
    test_forecast[t] == 42.0
  end
  return block
end

# ============================================================================
# Tests
# ============================================================================
function run_tests(db)
  errors = String[]
  all(db[test_forecast] .≈ db[test_forecast[t1]]) || push!(errors, "test_forecast should be constant")
  return errors
end

end # module
