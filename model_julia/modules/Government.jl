# ==============================================================================
# Government
# ==============================================================================
# Port of model/modules/government.gms. Populates the government (:Gov) entries
# of the SectorAccounts interface variables.

module Government

import JuMP
using SquareModels
using ..GrowthInflationAdjustment
import ..db, ..t, ..t1, ..T, ..ForecastConstant
import ..SectorAccounts: vPrimaryIncome, vNetTransfers, vFinalConsumption, vGrossCapitalFormation

# ==========================================================================
# Indices
# ==========================================================================

# ==========================================================================
# Variables
# ==========================================================================

# ==========================================================================
# Data
# ==========================================================================
function set_data!(db)
  return nothing
end

# ==========================================================================
# Equations
# ==========================================================================
function define_equations()
  return @block db begin
  end
end

# ==========================================================================
# Calibration
# ==========================================================================
function define_calibration()
  return define_equations()
end

end # module
