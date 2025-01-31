from global_container import Variable, Set, Block, Group
from growth_adjustment import inflation_adj, growth_adj, fp, fq, fv
from sets.time import t, t1, t2
from sets.input_output import i, m, d, re
from gamspy import Sum as Σ

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
# Dummy sets
d1Y_i_d = Set(name="d1Y_i_d", domain=[i,d,t],
              description="Dummy. Does the IO cell exist? (for domestic deliveries from industry i to demand d)")
d1M_i_d = Set(name="d1M_i_d", domain=[i,d,t],
              description="Dummy. Does the IO cell exist? (for imports from industry i to demand d)")
d1YM_i_d = Set(name="d1YM_i_d", domain=[i,d,t],
               description="Dummy. Does the IO cell exist? (for demand d and industry i)")
d1Y_d = Set(name="d1Y_d", domain=[d,t],
            description="Dummy. Does the IO cell exist? (any domestic deliveries to demand d)")
d1M_d = Set(name="d1M_d", domain=[d,t],
            description="Dummy. Does the IO cell exist? (any imports to demand d)")
d1YM_d = Set(name="d1YM_d", domain=[d,t],
             description="Dummy. Does the IO cell exist?")
d1Y_i = Set(name="d1Y_i", domain=[i,t],
            description="Dummy. Does the IO cell exist? (any domestic production from industry i)")
d1M_i = Set(name="d1M_i", domain=[i,t],
            description="Dummy. Does the IO cell exist? (any imports from industry i)")

# GDP and GVA variables
pGDP = Variable(name="pGDP", domain=[t], tags=[inflation_adj],
                description="GDP deflator.")
qGDP = Variable(name="qGDP", domain=[t], tags=[growth_adj],
                description="Real Gross Domestic product.")
vGDP = Variable(name="vGDP", domain=[t], tags=[growth_adj, inflation_adj],
                description="Gross Domestic product.")

pGVA = Variable(name="pGVA", domain=[t], tags=[inflation_adj],
                description="GVA deflator.")
qGVA = Variable(name="qGVA", domain=[t], tags=[growth_adj],
                description="Real Gross value added.")
vGVA = Variable(name="vGVA", domain=[t], tags=[growth_adj, inflation_adj],
                description="Gross value added.")

# Aggregate variables
vR = Variable(name="vR", domain=[t], tags=[growth_adj, inflation_adj],
              description="Non-energy intermediate inputs.")
vE = Variable(name="vE", domain=[t], tags=[growth_adj, inflation_adj],
              description="Energy intermediate inputs.")
vI = Variable(name="vI", domain=[t], tags=[growth_adj, inflation_adj],
              description="Investments.")
vC = Variable(name="vC", domain=[t], tags=[growth_adj, inflation_adj],
              description="Private consumption.")
vG = Variable(name="vG", domain=[t], tags=[growth_adj, inflation_adj],
              description="Public consumption.")
vX = Variable(name="vX", domain=[t], tags=[growth_adj, inflation_adj],
              description="Exports.")

# Price deflators
pR = Variable(name="pR", domain=[t], tags=[inflation_adj],
              description="Deflator for non-energy intermediate inputs.")
pE = Variable(name="pE", domain=[t], tags=[inflation_adj],
              description="Deflator for energy intermediate inputs.")
pI = Variable(name="pI", domain=[t], tags=[inflation_adj],
              description="Deflator for investments.")
pC = Variable(name="pC", domain=[t], tags=[inflation_adj],
              description="Deflator for private consumption.")
pG = Variable(name="pG", domain=[t], tags=[inflation_adj],
              description="Deflator for public consumption.")
pX = Variable(name="pX", domain=[t], tags=[inflation_adj],
              description="Deflator for exports.")

# Real quantities
qR = Variable(name="qR", domain=[t], tags=[growth_adj],
              description="Real non-energy intermediate inputs.")
qE = Variable(name="qE", domain=[t], tags=[growth_adj],
              description="Real energy intermediate inputs.")
qI = Variable(name="qI", domain=[t], tags=[growth_adj],
              description="Real investments.")
qC = Variable(name="qC", domain=[t], tags=[growth_adj],
              description="Real private consumption.")
qG = Variable(name="qG", domain=[t], tags=[growth_adj],
              description="Real public consumption.")
qX = Variable(name="qX", domain=[t], tags=[growth_adj],
              description="Real exports.")

# Industry-specific variables
pY_i = Variable(name="pY_i", domain=[i,t], tags=[inflation_adj],
                description="Price of domestic output by industry.")
qY_i = Variable(name="qY_i", domain=[i,t], tags=[growth_adj],
                description="Real output by industry.")
vY_i = Variable(name="vY_i", domain=[i,t], tags=[growth_adj, inflation_adj],
                description="Output by industry.")

# Total output variables
pY = Variable(name="pY", domain=[t], tags=[inflation_adj],
              description="Deflator for total output.")
qY = Variable(name="qY", domain=[t], tags=[growth_adj],
              description="Real total output.")
vY = Variable(name="vY", domain=[t], tags=[growth_adj, inflation_adj],
              description="Total output.")

# Import variables
pM_i = Variable(name="pM_i", domain=[i,t], tags=[inflation_adj],
                description="Price of imports by industry.")
qM_i = Variable(name="qM_i", domain=[i,t], tags=[growth_adj], condition=m[i],
                description="Real imports by industry.")
vM_i = Variable(name="vM_i", domain=[i,t], tags=[growth_adj, inflation_adj], condition=m[i],
                description="Imports by industry.")

pM = Variable(name="pM", domain=[t], tags=[inflation_adj],
              description="Deflator for total imports.")
qM = Variable(name="qM", domain=[t], tags=[growth_adj],
              description="Real imports.")
vM = Variable(name="vM", domain=[t], tags=[growth_adj, inflation_adj],
              description="Total imports.")

# Demand component variables
pD = Variable(name="pD", domain=[d,t], tags=[inflation_adj], condition=d1YM_d[d,t],
              description="Deflator of demand component.")
qD = Variable(name="qD", domain=[d,t], tags=[growth_adj], condition=d1YM_d[d,t],
              description="Real demand by demand component.")
vD = Variable(name="vD", domain=[d,t], tags=[growth_adj, inflation_adj], condition=d1YM_d[d,t],
              description="Demand by demand component.")

# Industry and demand component variables
pY_i_d = Variable(name="pY_i_d", domain=[i,d,t], tags=[inflation_adj], condition=d1Y_i_d[i,d,t],
                  description="Price of domestic output by industry and demand component.")
qY_i_d = Variable(name="qY_i_d", domain=[i,d,t], tags=[growth_adj], condition=d1Y_i_d[i,d,t],
                  description="Real output by industry and demand component.")
vY_i_d = Variable(name="vY_i_d", domain=[i,d,t], tags=[growth_adj, inflation_adj], condition=d1Y_i_d[i,d,t],
                  description="Output by industry and demand component.")

pM_i_d = Variable(name="pM_i_d", domain=[i,d,t], tags=[inflation_adj], condition=d1M_i_d[i,d,t],
                  description="Price of imports by industry and demand component.")
qM_i_d = Variable(name="qM_i_d", domain=[i,d,t], tags=[growth_adj], condition=d1M_i_d[i,d,t],
                  description="Real imports by industry and demand component.")
vM_i_d = Variable(name="vM_i_d", domain=[i,d,t], tags=[growth_adj, inflation_adj], condition=d1M_i_d[i,d,t],
                  description="Imports by industry and demand component.")

# Duties variables
tY_i_d = Variable(name="tY_i_d", domain=[i,d,t], condition=d1Y_i_d[i,d,t],
                  description="Duties on domestic output by industry and demand component.")
tM_i_d = Variable(name="tM_i_d", domain=[i,d,t], condition=d1M_i_d[i,d,t],
                  description="Duties on imports by industry and demand component.")
vtY_i_d = Variable(name="vtY_i_d", domain=[i,d,t], tags=[growth_adj, inflation_adj], condition=d1Y_i_d[i,d,t],
                   description="Net duties on domestic production by industry and demand component.")
vtM_i_d = Variable(name="vtM_i_d", domain=[i,d,t], tags=[growth_adj, inflation_adj], condition=d1M_i_d[i,d,t],
                   description="Net duties on imports by industry and demand component.")
vtY_i = Variable(name="vtY_i", domain=[i,t], tags=[growth_adj, inflation_adj],
                 description="Net duties on domestic production by industry.")
vtM_i = Variable(name="vtM_i", domain=[i,t], tags=[growth_adj, inflation_adj], condition=m[i],
                 description="Net duties on imports by industry.")
vtY = Variable(name="vtY", domain=[t], tags=[growth_adj, inflation_adj],
               description="Net duties on domestic production.")
vtM = Variable(name="vtM", domain=[t], tags=[growth_adj, inflation_adj],
               description="Net duties on imports.")

# Price deviation and composition variables
jfpY_i_d = Variable(name="jfpY_i_d", domain=[i,d,t],
                    description="Deviation from average industry price.")
jfpM_i_d = Variable(name="jfpM_i_d", domain=[i,d,t],
                    description="Deviation from average industry price.")

rYM = Variable(name="rYM", domain=[i,d,t], condition=d1YM_i_d[i,d,t],
               description="industry composition of demand.")
rYM_energy = Variable(name="rYM_energy", domain=[i,t], 
                     condition=Σ(re, d1Y_i_d[i,re,t]),
                     description="Used in linking between energy-markets and input-output.")

rM = Variable(name="rM", domain=[i,d,t], condition=d1YM_i_d[i,d,t],
              description="Import share.")
rM_energy = Variable(name="rM_energy", domain=[i,t],
                    condition=Σ(re, d1M_i_d[i,re,t]),
                    description="Used in linking between energy-markets and input-output.")
fYM = Variable(name="fYM", domain=[d,t],
               description="Deviation from law of one price.")

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
main_block = Block(condition=t.val >= t1.val)

def define_equations():
  pass

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
def set_exogenous_values():
  global data_variables
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
