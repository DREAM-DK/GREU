from global_container import Variable, Set, Block, Group
from growth_adjustment import inflation_adj, growth_adj, fp, fq, fv
from sets.time import t, t1, tEnd
from sets.input_output import k, i, y, re, i2re, invt
from gamspy import Sum as Σ
from gamspy.math import abs

# ------------------------------------------------------------------------------
# Variables with flat values after last data year
# ------------------------------------------------------------------------------
d1K_k_i = Set(name="d1K_k_i", domain=[k,i,t],
  description="Dummy. Does industry i have capital of type k?")
d1E_i = Set(name="d1E_i", domain=[i,t],
  description="Dummy. Does industry i use energy inputs?")

# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
qK_k_i = Variable(name="qK_k_i", domain=[k,i,t], tags=[growth_adj], condition=d1K_k_i[k,i,t],
  description="Real capital stock by capital type and industry.")
qL_i = Variable(name="qL_i", domain=[i,t], tags=[growth_adj],
  description="Labor in efficiency units by industry.")

qI_k_i = Variable(name="qI_k_i", domain=[k,i,t], tags=[growth_adj], condition=d1K_k_i[k,i,t],
  description="Real investments by capital type and industry.")
vI_k_i = Variable(name="vI_k_i", domain=[k,i,t], tags=[growth_adj, inflation_adj], condition=d1K_k_i[k,i,t],
  description="Investments by capital type and industry.")
rKDepr_k_i = Variable(name="rKDepr_k_i", domain=[k,i,t], condition=d1K_k_i[k,i,t],
  description="Capital depreciation rate by capital type and industry.")
qInvt_i = Variable(name="qInvt_i", domain=[i,t], tags=[growth_adj],
  description="Net real inventory investments by industry.")
vInvt_i = Variable(name="vInvt_i", domain=[i,t], tags=[growth_adj, inflation_adj],
  description="Net inventory investments by industry.")

pK_k_i = Variable(name="pK_k_i", domain=[k,i,t], tags=[inflation_adj], condition=d1K_k_i[k,i,t],
  description="User cost of capital by capital type and industry.")
rHurdleRate_i = Variable(name="rHurdleRate_i", domain=[i,t], condition=y[i],
  description="Corporations' hurdle rate of investments by industry.")
jpK_k_i = Variable(name="jpK_k_i", domain=[k,i,t], tags=[inflation_adj], condition=d1K_k_i[k,i,t],
  description="Additive residual in user cost of capital.")

# Ratio variables
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
def define_equations():
  global main_block
  main_block = Block(condition=(t.val >= t1.val) & (t.val <= tEnd.val))

  from input_output import qY_i, qD, pD, vD

  # Labor and capital ratios
  main_block[...] = qK_k_i[k,i,t] == qK2qY_k_i[k,i,t] * qY_i[i,t]
  main_block[...] = qL_i[i,t] == qL2qY_i[i,t] * qY_i[i,t]

  # Inventory investments
  main_block[...] = qInvt_i[i,t] == qInvt2qY_i[i,t] * qY_i[i,t]
  main_block[...] = qD[invt,t] == Σ(i, qInvt_i[i,t])
  main_block[...] = vInvt_i[i,t] == pD['invt',t] * qInvt_i[i,t]

  # Link demand for non-energy intermediate inputs to input-output model
  main_block[...] = qD[i,t] == qR2qY_i[i,t] * qY_i[i,t]

  # Link demand for energy intermediate inputs to input-output model
  main_block[...] = pE_i[i,t] == Σ(i2re[i,re], pD[re,t])
  main_block[...] = qE_i[i,t] == qE2qY_i[i,t] * qY_i[i,t]
  main_block[...] = qD[re,t] == Σ(i2re[i,re], qE_i[i,t])
  main_block[...] = vE_i[i,t] == Σ(i2re[i,re], vD[re,t])

  # Link demand for investments to input-output model
  main_block[...] = qD[k,t] == Σ(i, qI_k_i[k,i,t])
  main_block[...] = vI_k_i[k,i,t] == pD[k,t] * qI_k_i[k,i,t]

  # Capital accumulation
  main_block[...] = (
    qI_k_i[k,i,t] == qK_k_i[k,i,t] - (1-rKDepr_k_i[k,i,t]) * qK_k_i[k,i,t-1]/fq
  )

  # User cost of capital equations
  main_block[~tEnd[t]] = (
    pK_k_i[k,i,t] == pD[k,t] - (1-rKDepr_k_i[k,i,t]) / (1+rHurdleRate_i[i,t+1]) * pD[k,t+1]*fp + jpK_k_i[k,i,t]
  )
  main_block[tEnd[t]] = (
    pK_k_i[k,i,t] == pD[k,t] - (1-rKDepr_k_i[k,i,t]) / (1+rHurdleRate_i[i,t]) * pD[k,t]*fp + jpK_k_i[k,i,t]
  )

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
def set_exogenous_values():
  from input_output import qD

  global data_variables
  data_variables = (
    Group()
    + qK_k_i[k,i,t]
    + qI_k_i[k,i,t]
    + qD[i,t]
    + qD[re,t]
    + qInvt_i[i,t]
  )

  # *** Review: Handling of data loading from GDX file
  # @load(data_variables, "../data/data.gdx")

  # Set dummy variables based on data
  d1K_k_i[k,i,t] = abs(qK_k_i.l[k,i,t]) > 1e-9
  d1E_i[i,t] = abs(Σ(i2re[i,re], qD.l[re,t])) > 1e-9

  rHurdleRate_i.l[i,t] = 0.2

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
def define_calibration():
  global calibration_block
  calibration_block = main_block.copy()

  from input_output import qD

  calibration_block.endogenous = (
    calibration_block.endogenous
    - qK_k_i[k,i,t1] + qK2qY_k_i[k,i,t1]
    - qL_i[i,t1] + qL2qY_i[i,t1]
    - qD[i,t1] + qR2qY_i[i,t1]
    - qI_k_i[k,i,t1] + rKDepr_k_i[k,i,t1]
    - qInvt_i[i,t1] + qInvt2qY_i[i,t1]
    - qD[re,t1] + qE2qY_i[i,t1]
  )

  global flat_after_last_data_year
  flat_after_last_data_year = (
    Group()
    + qK2qY_k_i[k,i,t]
    + qL2qY_i[i,t]
    + qR2qY_i[i,t]
    + rKDepr_k_i[k,i,t]
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
def tests():
  pass