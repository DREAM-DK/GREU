from global_container import Variable, Block, Group, Set
from growth_adjustment import inflation_adj, growth_adj, fp, fq, fv
from sets.time import t, t1

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
template_test_variable = Variable(name="template_test_variable", domain=t,
  description="Test variable from submodel template."
)
template_test_parameter = Variable(name="template_test_parameter", domain=t,
  description="Test parameter from submodel template."
)

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
def define_equations():
  global main_block
  main_block = Block(condition=t.val >= t1.val)

  main_block[...] = template_test_variable[t] == template_test_parameter[t]

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
def set_exogenous_values():
  global data_variables
  data_variables = (
    Group()
    + template_test_variable[t1]
  )

  template_test_variable.l[t] = 1

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
def define_calibration():
  global calibration_block
  calibration_block = main_block.copy()

  # template.calibration_block[...] = template_test_parameter[t] == 1

  calibration_block.endogenous = (
    calibration_block.endogenous
    - template_test_variable[t1] + template_test_parameter[t1]
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
def tests():
  pass