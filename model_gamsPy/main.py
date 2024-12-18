%load_ext autoreload
%autoreload 2

import gamspy as gp
from gamspy import Sum as Σ
from GlobalContainer import Set, Parameter, Variable, Block, Group

t = Set(name="t", description="Year")
s = Set(name="s", description="Sector")
t1 = Set(name="t1", domain=t, is_singleton=True, description="First main_endogenous year")
s.setRecords(["Corp", "Gov", "Hh", "RoW"])
Hh = Set(name="Hh", domain=s, description="Households", records=["Hh"])

foo = Variable(name="foo", domain=[s,t], description="foo", condition=~s.sameAs("Gov"))
bar = Variable(name="bar", domain=[s,t], description="bar")
endogenous=foo[s,t]
test_block = Block()

test_block.Equation(expression=foo[Hh,t] == bar[Hh,t], condition=~t1[t])
test_block.Equation(expression=foo[s,t] == 2, condition=~Hh[s])

calibration_block = test_block.copy()
# calibration_block.endogenous = test_block.endogenous - foo + bar

t.setRecords([1, 2, 3, 4])
t1.setRecords([2])

bar.l[s,t] = 5
test_block.solve(options=gp.Options(listing_file="gp.lst", hold_fixed_variables=True))

from print_and_plot import plot
plot(foo)
