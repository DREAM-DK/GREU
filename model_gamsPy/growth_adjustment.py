from global_container import Parameter, get_tagged_variables
from sets.time import t, tBase
from settings import gp, gq

fp = Parameter(name="fp", description="1 year adjustment factor for price inflation, =1+gp")
fq = Parameter(name="fq", description="1 year adjustment factor for growth in quantities, =1+gq")
fv = Parameter(name="fv", description="1 year composite growth and inflation factor to adjust for growth in nominal values, =(1+gq)(1+gp)")

fpt = Parameter(name="fpt", domain=t, description="Inflation adjustment factor, =fp^(t-tBase)")
fqt = Parameter(name="fqt", domain=t, description="Growth adjusment factor, =fq^(t-tBase)")
fvt = Parameter(name="fvt", domain=t, description="Geometric series for fv, =fv^(t-tBase)")

fp = 1 + gp
fq = 1 + gq
fv = fp * fq

fpt[t] = fp ** (t.val - tBase.val)
fqt[t] = fq ** (t.val - tBase.val)
fvt[t] = fv ** (t.val - tBase.val)

growth_adjusted = False
inflation_adjusted = False

def growth_adjust():
  assert not growth_adjusted, "Trying to adjust for growth, but model is already adjusted."
  growth_adjusted = True
  for var in get_tagged_variables("growth_adj"):
    var.l = var.l / fpt[t]

def inflation_adjust():
  assert not inflation_adjusted, "Trying to adjust for inflation, but model is already adjusted."
  inflation_adjusted = True
  for var in get_tagged_variables("inflation_adj"):
    var.l = var.l / fqt[t]

def remove_growth_adjust():
  assert growth_adjusted, "Trying to remove growth adjustment, but model is not adjusted."
  growth_adjusted = False
  for var in get_tagged_variables("growth_adj"):
    var.l = var.l * fpt[t]

def remove_inflation_adjust():
  assert inflation_adjusted, "Trying to remove inflation adjustment, but model is not adjusted"
  inflation_adjusted = False
  for var in get_tagged_variables("inflation_adj"):
    var.l = var.l * fqt[t]
