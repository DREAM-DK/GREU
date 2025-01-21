# --------------------------------------------------------------------------------------------------
# gamsPy implementation of GreenREFORM EU model
# --------------------------------------------------------------------------------------------------
# For interactive development - reload modules when they change
%reload_ext autoreload
%autoreload 2

import sys
from utils import differences
from growth_adjustment import growth_adjust, inflation_adjust

# --------------------------------------------------------------------------------------------------
# Import submodels
# --------------------------------------------------------------------------------------------------
import submodel_template
import financial_accounts
# import households
# import factor_demand
# import input_output

# Find all submodels from imported modules (by checking that they have a define_equations function)
submodels = [module for name, module in sys.modules.items() if hasattr(module, "define_equations")]
  
# --------------------------------------------------------------------------------------------------
# Define main model and calibration model
# --------------------------------------------------------------------------------------------------
for m in submodels:
  m.define_equations()
  m.define_calibration()

# Merge sub-models blocks
main = sum(m.block for m in submodels)
calibration = sum(m.calibration for m in submodels)

# --------------------------------------------------------------------------------------------------
# Data and exogenous parameters
# --------------------------------------------------------------------------------------------------
# Merge sub-model data groups, used to test that calibration does not change data
data_variables = sum(m.data_variables for m in submodels)

# Adjust for growth and inflation
growth_adjust()
inflation_adjust()

# Save data levels prior to calibration
data_levels = data_variables.get_level_records()

# --------------------------------------------------------------------------------------------------
# Calibration
# --------------------------------------------------------------------------------------------------
calibration.solve()

assert not (changes := differences(data_levels, data_variables.get_level_records())), \
  f"Calibration changed variables covered by data:\n{'\n\n'.join(changes)}"

calibrated_levels = main.endogenous.get_level_records()

# --------------------------------------------------------------------------------------------------
# Zero shock 
# --------------------------------------------------------------------------------------------------
main.solve()
assert not (changes := differences(calibrated_levels, main.endogenous.get_level_records())), \
  f"Zero-shock changed endogenous variables:\n{'\n\n'.join(changes)}"

for m in submodels:
  m.tests()