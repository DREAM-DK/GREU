from global_container import Variable, Block, Group, container
from growth_adjustment import inflation_adj, growth_adj
from sets.time import t, t1
from sets.sectors import sector, Hh, Corp
from sets.input_output import c

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
households_test_variable = Variable(name="households_test_variable", domain=t,
  description="Test variable from submodel households.")
vHhIncome = Variable(name="vHhIncome", domain=t, tags=[inflation_adj, growth_adj],
  description="Household income.",)
vC = Variable(name="vC", domain=t, tags=[inflation_adj, growth_adj],
  description="Household and non-profit (NPISH) consumption expenditure.")

rMPC = Variable(name="rMPC", domain=t, tags=[],
  description="Marginal propensity to consume out of income.")
rMPCW = Variable(name="rMPCW", domain=t, tags=[],
  description="Marginal propensity to consume out of wealth.")
rC_c = Variable(name="rC_c", domain=[c, t], tags=[],
  description="Share of total consumption expenditure by purpose.")

vNetInterests = Variable(name="vNetInterests", domain=[sector, t], tags=[inflation_adj, growth_adj],
  description="Interests by sector.")
vNetRevaluations = Variable(name="vNetRevaluations", domain=[sector, t], tags=[inflation_adj, growth_adj],
  description="Revaluations by sector.")

mrHhReturn = Variable(name="mrHhReturn", domain=t, tags=[],
  description="Expected marginal after-tax return on household wealth.")

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
block = Block(condition=t.val >= t1.val)

def define_equations():
  from submodel_template import template_test_parameter

  block[...] = households_test_variable[t] == template_test_parameter[t]

  # block[rC_c[c,t].where[c.ord == 1]] = vC[t] == rMPC[t] * vHhIncome[t] + rMPCW[t] * vNetFinAssets['Hh',t-1]/fv

  # block[...] = vD[c,t] == rC_c[c,t] * vC[t]

  # Link to input-output model - households choose private consumption by purpose
  # block[...] = vHhIncome[t] == vWages[t] + vHhTransfers[t] - vHhTaxes[t] + vNetInterests['Hh',t] + vNetRevaluations['Hh',t]

  # Marginal return is calculated ex-ante
  # and not in the first period, where information shocks can cause realized returns to differ from expectations
  # block[~t1[t]] = mrHhReturn[t] == (vNetDividends['Hh',t] + vNetInterests['Hh',t]) / (vNetFinAssets['Hh',t-1]/fv)

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
