from global_container import Variable, Set, Block, Group
from growth_adjustment import inflation_adj, growth_adj
from sets.time import t, t1, t2
from sets.input_output import k, i

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
d1K_k_i = Set(name="d1K_k_i", domain=[k,i,t],
              description="Dummy. Does industry i have capital of type k?")
d1E_i = Set(name="d1E_i", domain=[i,t],
            description="Dummy. Does industry i use energy inputs?")

qK_k_i = Variable(name="qK_k_i", domain=[k,i,t], tags=[growth_adj], condition=d1K_k_i[k,i,t],
                  description="Real capital stock by capital type and industry.")
qL_i = Variable(name="qL_i", domain=[i,t], tags=[growth_adj],
                description="Labor in efficiency units by industry.")

qI_k_i = Variable(name="qI_k_i", domain=[k,i,t], tags=[growth_adj], condition=d1K_k_i[k,i,t],
                  description="Real investments by capital type and industry.")
vI_k_i = Variable(name="vI_k_i", domain=[k,i,t], tags=[growth_adj, inflation_adj], condition=d1K_k_i[k,i,t],
                  description="Investments by capital type and industry.")
rKDepr_k_i = Variable(name="rKDepr_k_i", domain=[k,i,t], tags=[inflation_adj],
                      description="Capital depreciation rate by capital type and industry.")
qInvt_i = Variable(name="qInvt_i", domain=[i,t], tags=[growth_adj],
                    description="Net real inventory investments by industry.")
vInvt_i = Variable(name="vInvt_i", domain=[i,t], tags=[growth_adj, inflation_adj],
                    description="Net inventory investments by industry.")

pK_k_i = Variable(name="pK_k_i", domain=[k,i,t], tags=[inflation_adj], condition=d1K_k_i[k,i,t],
                  description="User cost of capital by capital type and industry.")
rHurdleRate_i = Variable(name="rHurdleRate_i", domain=[i,t],
                        description="Corporations' hurdle rate of investments by industry.")
jpK_k_i = Variable(name="jpK_k_i", domain=[k,i,t], condition=d1K_k_i[k,i,t],
                  description="Additive residual in user cost of capital.")

qK2qY_k_i = Variable(name="qK2qY_k_i", domain=[k,i,t], condition=d1K_k_i[k,i,t],
                      description="Capital to output ratio by capital type and industry.")
qL2qY_i = Variable(name="qL2qY_i", domain=[i,t],
                  description="Labor to output ratio by industry.")
qR2qY_i = Variable(name="qR2qY_i", domain=[i,t],
                  description="Intermediate input to output ratio by industry.")
qInvt2qY_i = Variable(name="qInvt2qY_i", domain=[i,t],
                      description="Inventory investment to output ratio by industry.")
qE2qY_i = Variable(name="qE2qY_i", domain=[i,t], condition=d1E_i[i,t],
                  description="Demand for intermediate energy inputs to output ratio by industry.")
pE_i = Variable(name="pE_i", domain=[i,t], tags=[inflation_adj], condition=d1E_i[i,t],
                description="Price index of energy inputs, by industry.")
qE_i = Variable(name="qE_i", domain=[i,t], tags=[growth_adj], condition=d1E_i[i,t],
                description="Real energy inputs by industry.")
vE_i = Variable(name="vE_i", domain=[i,t], tags=[growth_adj, inflation_adj], condition=d1E_i[i,t],
                description="Energy inputs by industry.")

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
block = Block(condition=t.val >= t1.val)

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
  global calibration
  calibration = block.copy()

  calibration.endogenous = (
    calibration.endogenous
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
