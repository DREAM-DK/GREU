from global_container import container
from growth_adjustment import growth_adjust, inflation_adjust

sub_models = []

import submodel_template
sub_models.append(submodel_template)
import households
sub_models.append(households)
  
# Define submodel blocks
for m in sub_models:
  m.define_equations()
  m.define_calibration()

# Merge sub-models blocks
main = sum(m.block for m in sub_models)
calibration = sum(m.calibration for m in sub_models)

# Merge sub-model data groups, used to test that calibration does not change data
data_variables = sum(m.data_variables for m in sub_models)

# Adjust for growth and inflation
growth_adjust()
inflation_adjust()

# Save data levels prior to calibration
data_levels = data_variables.get_level_records()

calibration.solve()

assert all(
  x.equals(y) for x, y in zip(data_levels, data_variables.get_level_records())
),"Calibration changed variables covered by data."

calibrated_levels = main.endogenous.get_level_records()

main.solve()

assert all(
  x.equals(y) for x, y in zip(calibrated_levels, main.endogenous.get_level_records())
),"Zero-shock changed endogenous variables."

[x.records for x in container.getVariables()]
