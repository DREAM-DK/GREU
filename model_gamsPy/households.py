from global_container import Variable, Block, Group, container
from sets.time import t, t1
from sets.sectors import sector, Hh, Corp

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
households_test_variable = Variable(
  name="households_test_variable",
  domain=t,
  description="Test variable from submodel households."
)

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
block = Block(condition=t.val >= t1.val)

def define_equations():
  from submodel_template import template_test_parameter

  block[...] = households_test_variable[t] == template_test_parameter[t]

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
data_variables = Group()

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
def define_calibration():
  global calibration
  calibration = block.copy()

  # households.calibration[...] = households_test_parameter[t] == 1

  calibration.endogenous = (
    calibration.endogenous
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
