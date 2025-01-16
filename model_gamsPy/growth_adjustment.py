from global_container import Parameter, Tag
from sets.time import t, tBase
from settings import gp, gq

# Create tags, indicating that a variable is adjusted for growth or inflation
growth_adj = Tag()
inflation_adj = Tag()

fp = Parameter(name="fp", description="1 year adjustment factor for price inflation, =1+gp")
fq = Parameter(name="fq", description="1 year adjustment factor for growth in quantities, =1+gq")
fv = Parameter(name="fv", description="1 year composite growth and inflation factor to adjust for growth in nominal values, =(1+gq)(1+gp)")

fpt = Parameter(name="fpt", domain=t, description="Inflation adjustment factor, =fp^(t-tBase)")
fqt = Parameter(name="fqt", domain=t, description="Growth adjusment factor, =fq^(t-tBase)")
fvt = Parameter(name="fvt", domain=t, description="Geometric series for fv, =fv^(t-tBase)")

fp[...] = 1 + gp
fq[...] = 1 + gq
fv[...] = fp * fq

fpt[t] = fp ** (t.val - tBase.val)
fqt[t] = fq ** (t.val - tBase.val)
fvt[t] = fv ** (t.val - tBase.val)

def growth_adjust():
  for var in growth_adj:
    var.l = var.l / fpt[t]

def inflation_adjust():
  for var in inflation_adj:
    var.l = var.l / fqt[t]

def remove_growth_adjust():
  for var in growth_adj:
    var.l = var.l * fpt[t]

def remove_inflation_adjust():
  for var in inflation_adj:
    var.l = var.l * fqt[t]
