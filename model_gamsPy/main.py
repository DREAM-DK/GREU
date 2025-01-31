# --------------------------------------------------------------------------------------------------
# gamsPy implementation of GreenREFORM EU model
# --------------------------------------------------------------------------------------------------
# For interactive development - reload modules when they change
%reload_ext autoreload
%autoreload 2

import sys
from utils import differences
from growth_adjustment import growth_adjust, inflation_adjust

from global_container import toggle_debug
# toggle_debug() # Turn on debug mode - slower, but earlier tests for square errors etc.

# --------------------------------------------------------------------------------------------------
# Import submodels
# --------------------------------------------------------------------------------------------------
submodels = []
import submodel_template
import financial_accounts
import households
import factor_demand
import input_output

# Find all submodels from imported modules (by checking that they have a define_equations function)
submodels = [module for _, module in sys.modules.items() if hasattr(module, "define_equations")]

# --------------------------------------------------------------------------------------------------
# Define main model
# --------------------------------------------------------------------------------------------------
for submodel in submodels:
  submodel.define_equations()

# Merge sub-model blocks into main model block
main_block = sum(submodel.main_block for submodel in submodels)

# --------------------------------------------------------------------------------------------------
# Data and exogenous parameters
# --------------------------------------------------------------------------------------------------
for submodel in submodels:
  submodel.set_exogenous_values()

# Merge sub-model data groups, used to test that calibration does not change data
data_variables = sum(submodel.data_variables for submodel in submodels)

# Adjust for growth and inflation
growth_adjust()
inflation_adjust()

# Save data levels prior to calibration
data_levels = data_variables.get_level_records()

# --------------------------------------------------------------------------------------------------
# Calibration
# --------------------------------------------------------------------------------------------------
for submodel in submodels:
  submodel.define_calibration()

calibration_block = sum(submodel.calibration_block for submodel in submodels)

flat_after_last_data_year = sum(
  submodel.flat_after_last_data_year
  for submodel in submodels
  if hasattr(submodel, "flat_after_last_data_year")
)

calibration_block.solve()

assert not (changes := differences(data_levels, data_variables.get_level_records())), \
  f"Calibration changed variables covered by data:\n{'\n\n'.join(changes)}"

calibrated_levels = main_block.endogenous.get_level_records()

# --------------------------------------------------------------------------------------------------
# Zero shock 
# --------------------------------------------------------------------------------------------------
main_block.solve()
assert not (changes := differences(calibrated_levels, main_block.endogenous.get_level_records())), \
  f"Zero-shock changed endogenous variables:\n{'\n\n'.join(changes)}"

for submodel in submodels:
  submodel.tests()