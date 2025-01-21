from global_container import Variable, Set, Block, Group
from growth_adjustment import inflation_adj, growth_adj, fp, fq, fv
from sets.time import t, t1, t2
from sets.input_output import k, i

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
nL = Variable(name="nL", domain=[t],
              description="Total employment.")

pL_i = Variable(name="pL_i", domain=[i,t], tags=[inflation_adj],
                description="Usercost of labor, by industry.")
qL = Variable(name="qL", domain=[t], tags=[growth_adj],
              description="Labor in efficiency units.")

pLWedge_i = Variable(name="pLWedge_i", domain=[i,t], tags=[inflation_adj],
                     description="Wedge between wage and usercost of labor (e.g. matching costs), by industry.")

pW = Variable(name="pW", domain=[t], tags=[inflation_adj],
              description="Wage pr. efficiency unit of labor.")
qProductivity = Variable(name="qProductivity", domain=[t], tags=[growth_adj],
                        description="Labor augmenting productivity.")
vWages_i = Variable(name="vWages_i", domain=[i,t], tags=[growth_adj, inflation_adj],
                    description="Compensation of employees by industry.")
vWages = Variable(name="vWages", domain=[t], tags=[growth_adj, inflation_adj],
                  description="Total compensation of employees.")
vW = Variable(name="vW", domain=[t], tags=[growth_adj, inflation_adj],
              description="Compensation pr. employee.")
rWageInflation = Variable(name="rWageInflation", domain=[t],
                         description="Wage inflation, based on vW.")

# Phillips curve variables
snL = Variable(name="snL", domain=[t],
               description="Structural employment.")
uPhillipsCurveEmpl = Variable(name="uPhillipsCurveEmpl", domain=[t],
                             description="Sensitivity of wages to deviations from structural employment.")
uPhillipsCurveExpWage = Variable(name="uPhillipsCurveExpWage", domain=[t],
                                description="Sensitivity of wages to expected future wages.")
jnL = Variable(name="jnL", domain=[t],
               description="Deviations from Phillips curve. Can be used to override the Phillips curve model.")

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
main_block = Block(condition=t.val >= t1.val)

def define_equations():
  pass

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
data_variables = (
  Group()
)

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
def define_calibration():
  global calibration_block
  calibration_block = main_block.copy()

  calibration_block.endogenous = (
    calibration_block.endogenous
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
