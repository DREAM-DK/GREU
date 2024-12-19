from global_container import Variable, Block, Group, container
from sets.time import t, t1, t2
from sets.sectors import sector, Hh, Corp

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
template_test_variable = Variable(
  name="template_test_variable",
  domain=t,
  description="Test variable from submodel template."
)
template_test_parameter = Variable(
  name="template_test_parameter",
  domain=t,
  description="Test parameter from submodel template."
)
# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
block = Block(condition=t.val >= t1.val)

def define_equations():
  block[...] = template_test_variable[t] == template_test_parameter[t]

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
template_test_variable.l[t] = 1

data_variables = (
  Group()
  + template_test_variable[t1]
)

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
def define_calibration():
  global calibration
  calibration = block.copy()

  # template.calibration[...] = template_test_parameter[t] == 1

  calibration.endogenous = (
    calibration.endogenous
    - template_test_variable[t1] + template_test_parameter[t1]
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
