%load_ext autoreload
%autoreload 2

from global_container import Variable, Block
from sets.time import t, t1
from sets.sectors import sector, Hh, Corp

test_variable = Variable(name="test_variable", domain=t, description="Test variable from submodel template.")
test_scalar = Variable(name="test_scalar", description="Test variable with no indices.")
test_constant = Variable(name="test_constant", domain=sector, description="Test variable with no time index.")

eq = test_model = Block()

eq[test_variable.where[~t1[t]]] = test_variable[t] == 1
eq[test_variable.where[t1[t]]] = test_variable[t] == 2
eq[...] = test_scalar == 3
eq[...] = test_constant[Hh] == 4
eq[~(Hh[sector] | Corp[sector])] = test_constant[sector] == 5
eq[test_constant[Corp]] = test_constant[Corp] == 6

test_model.solve()

from print_and_plot import eval_expression
assert all(eval_expression(test_variable[t1]) == 2), "test_variable[t1] should be 2"
assert all(test_scalar.records.level == 3), "test_scalar should be 3"
assert all(test_constant.records.level == [6, 5, 4, 5]), "test_constant should be [6, 5, 4, 5]"
