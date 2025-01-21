from global_container import Variable, Block, Group, Set
from growth_adjustment import inflation_adj, growth_adj, fp, fq, fv
from sets.time import t, t1
from sets.sectors import sector, Hh, Corp
from sets.input_output import c
from gamspy import Sum as Σ

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
vHhIncome = Variable(name="vHhIncome", domain=[t], tags=[inflation_adj, growth_adj],
  description="Household income.")

vC = Variable(name="vC", domain=[t], tags=[inflation_adj, growth_adj],
  description="Household and non-profit (NPISH) consumption expenditure.")

rMPC = Variable(name="rMPC", domain=[t],
  description="Marginal propensity to consume out of income.")
rMPCW = Variable(name="rMPCW", domain=[t],
  description="Marginal propensity to consume out of wealth.")
rC_c = Variable(name="rC_c", domain=[c,t],
  description="Share of total consumption expenditure by purpose.")

vNetInterests = Variable(name="vNetInterests", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Interests by sector.")
vNetRevaluations = Variable(name="vNetRevaluations", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Revaluations by sector.")

mrHhReturn = Variable(name="mrHhReturn", domain=[t],
  description="Expected marginal after-tax return on household wealth.")

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
def define_equations():
  global main_block
  main_block = Block(condition=t.val >= t1.val)

  from submodel_template import template_test_parameter
  from financial_accounts import vNetFinAssets, vNetDividends, vHhTransfers, vHhTaxes, vNetInterests, vNetRevaluations
  from labor_market import vWages
  from input_output import vD, qD

  main_block[...] = households_test_variable[t] == template_test_parameter[t]

  main_block[rC_c[c,t].where[c.ord == 1]]\
    = vC[t] == rMPC[t] * vHhIncome[t] + rMPCW[t] * vNetFinAssets['Hh',t-1]/fv

  # Link to input-output model - households choose private consumption by purpose
  main_block[qD[c,t]] = vD[c,t] == rC_c[c,t] * vC[t]

  main_block[...] = (
    vHhIncome[t] == vWages[t]
                  + vHhTransfers[t]
                  - vHhTaxes[t]
                  + vNetInterests[Hh,t] + vNetRevaluations[Hh,t]
  )

  # Marginal return is calculated ex-ante
  # and not in the first period, where information shocks can cause realized returns to differ from expectations
  main_block[...].where[~t1[t]] = (
    mrHhReturn[t] == (vNetDividends[Hh,t] + vNetInterests[Hh,t]) / (vNetFinAssets[Hh,t-1]/fv)
  )

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
data_variables = (
  Group()
  # + qD[c,t]
)

rMPC.l[t] = 0.4

# *** Review: Handling of data loading from GDX file
# @load(data_variables, "../data/data.gdx")

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
def define_calibration():
  global calibration_block
  calibration_block = main_block.copy()

  calibration_block.endogenous = (
    calibration_block.endogenous
    - qD[c,t1] + rC_c[c,t1] + rMPCW[t1]
  )

  # Variables that are flat after last data year
  flat_after_last_data_year = (
    Group()
    + rMPCW[t]
    + rC_c[c,t]
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
def tests():
  pass  # No tests specified in original module