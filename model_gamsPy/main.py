import gamspy as gp
from gamspy import Sum as Σ
from gamspy import Domain
from gamspy._algebra.condition import Condition
import numpy as np
import pandas as pd
from math import inf

container = gp.Container()

Set = container.addSet
Parameter = container.addParameter
Equation = container.addEquation

container.domain_conditions = {}
container.domain_dummy = {}

def Variable(*args, condition=1, **kwargs):
  """Return a gamsPy variable with additional domain_conditition and sub_domain attributes."""
  var = container.addVariable(*args, **kwargs)
  container.domain_conditions[var.name] = condition
  container.domain_dummy[var.name] = Set(domain=var.domain)
  return var

def evaluate_domain_condition(var_name):
  """
  Set the sub_domain of a variable (subset limiting the domain of the variable)
  by evaluating the domain_condition of the variable (a logical expression).
  Return variable[sub_domain] (to limit the domain of the variable in a model).
  """
  sub_domain = container.domain_dummy[var_name]
  domain_condition = container.domain_conditions[var_name]
  sub_domain[...] = domain_condition
  variable = container[var_name]
  return variable[sub_domain]

def limit_variable_domains(container):
  """
  Return a list of limited variables, to limit the domain of variables in a model
  based on the domain_condition attribute of the variables.
  """
  return [evaluate_domain_condition(var_name) for var_name in container.domain_conditions]

def Model(*args, **kwargs):
  """Return a gamsPy model with sub_domain attribute of variables used to limit domains.""" 
  return container.addModel(*args, operations=limit_variable_domains(container), **kwargs)

def merge_conditions(*conditions):
  """
  Merge multiple logical conditions into a single condition (with and operator),
  simplifying away conditions that are always true.
  """
  conditions = [c for c in conditions if not (isinstance(c, int) and c)]
  if len(conditions) == 0:
    return 1
  else:
    return np.bitwise_and.reduce(conditions)

def condition_from_subdomain(var, condition):
  """
  Return a logical condition based on a variable and a condition,
  taking into account that the domain may have been subsetted.
  E.g. if foo is defined over ab
    condition_from_subdomain(foo[a], 1)
    ->
    Sum(a.where[a.sameAs(ab)], 1)
  """
  parent = var.container[var.name]
  if var.domain == parent.domain:
    return condition

  sub_domain_pairs = [(s, s_parent)
                      for s, s_parent in zip(var.domain, parent.domain)
                      if s != s_parent]
  d = Domain(sub_domain_pairs) if len(sub_domain_pairs) > 1 else sub_domain_pairs[0]
  ident = np.logical_and(s.sameAs(s_parent) for s, s_parent in sub_domain_pairs)
  return gp.Sum(d.where[ident], condition)

class Group:
  """
  A collection of variables and associated domain conditions.
  
  Attributes:
  container: the container of the variables in the group
  content: a dictionary of variable names and domain conditions
  """

  def __init__(self, container, content=None):
    self.container = container
    self.content = content if content is not None else {}

  def add_variable(self, var, condition=1):
    condition = condition_from_subdomain(var, condition)
    if var.name not in self.content:
      self.content[var.name] = condition
    else:
      self.content[var.name] = merge_conditions(self.content[var.name], condition)

  def subtract_variable(self, var, condition=None):
    """Remove a variable from the group for a limited domain."""   
    if var.name not in self.content:
      pass
    elif condition is None:
      del self.content[var.name]
    else:
      condition = condition_from_subdomain(var, condition)
      self.content[var.name] = self.content[var.name] & ~condition

  def copy(self):
    """Return a copy of the group."""
    return Group(self.container, self.content.copy())

  def add_group(self, other):
    """Combine two groups into a single group."""
    g = self.copy()
    for var_name, condition in other.content.items():
      if var_name in g.content:
        g.content[var_name] = merge_conditions(g.content[var_name], condition)
      else:
        g.content[var_name] = condition
    return g
  
  def subtract_group(self, other):
    """Subtract the domain limits of another group from this group."""
    g = self.copy()
    for var_name, condition in other.content.items():
      if var_name in g.content:
        g.content[var_name] = g.content[var_name] & ~condition
    return g
  
  def __add__(self, other):
    if isinstance(other, Group):
      return self.add_group(other)
    elif isinstance(other, Condition):
      return self.add_variable(other.conditioning_on, other.condition)
    else:
      self.add_variable(other)

  def __sub__(self, other):
    if isinstance(other, Group):
      return self.subtract_group(other)
    elif isinstance(other, Condition):
      return self.subtract_variable(other.conditioning_on, other.condition)
    else:
      self.subtract_variable(other)

  def fix(self):
    """Fix variables in the group to their levels."""
    for var_name, condition in self.content.items():
      var = self.container[var_name]
      domain_condition = self.container.domain_conditions[var_name]
      var.fx.where[domain_condition & condition] = var.l

  def unfix(self, lower=-inf, upper=inf):
    """Unfix variables in the group."""
    for var_name, condition in self.content.items():
      var = self.container[var_name]
      domain_condition = self.container.domain_conditions[var_name]
      var.lo.where[domain_condition & condition] = lower
      var.up.where[domain_condition & condition] = upper
  
class Block:
  """A collection of equations and associated endogenous variables."""

  def __init__(self, container):
    self.container = container
    self.equations = []
    self.endogenous = Group(container)

  def Equation(self, expression, endogenous=None, domain=None, condition=1, **kwargs):
    """
    Add an equation to the block, with an associated endogenous variable.
    endogenous variable and domain will be inferred from first left-hand side variable if not provided.
    """
    if endogenous is None:
      endogenous = expression.left
    if domain is None:
      domain = endogenous.domain
    sub_domain = container.domain_dummy[endogenous.name]
    domain_condition = merge_conditions(condition, sub_domain[domain])
    # domain_condition.gamsRepr()
    eq = Equation(domain=domain, **kwargs)
    eq[domain].where[domain_condition] = expression

    self.equations.append(eq)
    self.endogenous.add_operation(endogenous, domain_condition)

    return eq
  
  def Model(self, problem="CNS", **kwargs):
    return Model(equations=self.equations, problem=problem, **kwargs)
  
  def solve(self, **kwargs):
    return self.Model().solve(**kwargs)
  
  def unfix(self):
    self.endogenous.evaluate_domain_conditions()
    self.endogenous.unfix()

  def __add__(self, other):
    """Combine two blocks into a single block."""
    b = Block(self.container)
    b.equations = self.equations + other.equations
    b.endogenous = self.endogenous + other.endogenous
    return b
  
  def copy(self):
    """Return a copy of the block."""
    b = Block(self.container)
    b.equations = self.equations.copy()
    b.endogenous = self.endogenous.copy()
    return b

t = Set(name="t", description="Year")
s = Set(name="s", description="Sector")
t1 = Set(name="t1", domain=t, is_singleton=True, description="First main_endogenous year")
s.setRecords(["Corp", "Gov", "Hh", "RoW"])
Hh = Set(name="Hh", domain=s, description="Households", records=["Hh"])

foo = Variable(name="foo", domain=[s,t], description="foo", condition=~s.sameAs("Gov"))
bar = Variable(name="bar", domain=[s,t], description="bar")
endogenous=foo[s,t]
test_block = Block(container)

test_block.Equation(expression=foo[Hh,t] == bar[Hh,t], condition=~t1[t])
test_block.Equation(expression=foo[s,t] == 2, condition=~Hh[s])

calibration_block = test_block.copy()
# calibration_block.endogenous = test_block.endogenous - foo + bar

t.setRecords([1, 2, 3, 4])
t1.setRecords([2])

def fix_all():
  for var_name, domain_condition in container.domain_conditions.items():
    var = container[var_name]
    var.fx[...].where[domain_condition] = var.l[...]

bar.l[s,t] = 5
limit_variable_domains(container)
fix_all()
test_block.unfix()

test_block.solve(options=gp.Options(listing_file="gp.lst", hold_fixed_variables=True))

from print_and_plot import plot
plot(foo)


