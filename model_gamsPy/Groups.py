import gamspy as gp
import numpy as np
from gamspy import Domain
from gamspy._algebra.condition import Condition
from math import inf

One = gp.Number(1)

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

  def add_variable(self, var, condition=One):
    condition = condition_from_subdomain(var, condition)
    if var.name not in self.content:
      self.content[var.name] = condition
    else:
      self.content[var.name] = merge_conditions(self.content[var.name], condition)

  def subtract_variable(self, var, condition=One):
    """Remove a variable from the group for a limited domain."""
    condition = condition_from_subdomain(var, condition)
    if var.name not in self.content:
      pass
    elif condition is None:
      del self.content[var.name]
    else:
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
    """Allow adding variables and groups to a group using <group> + <var> syntax."""
    if isinstance(other, Group):
      return self.add_group(other)

    g = self.copy()
    if isinstance(other, Condition):
      g.add_variable(other.conditioning_on, other.condition)
    else:
      g.add_variable(other)
    return g

  def __sub__(self, other):
    """Allow removing variables and groups from a group using <group> - <var> syntax."""
    if isinstance(other, Group):
      return self.subtract_group(other)
    
    g = self.copy()
    if isinstance(other, Condition):
      g.subtract_variable(other.conditioning_on, other.condition)
    else:
      g.subtract_variable(other)
    return g
  
  def __radd__(self, other):
    """Summing groups is equivalent to adding them together."""
    if other == 0:
      return self
    return self.__add__(other)

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

  def levels_to_pameters(self):
    """
    Create a parameter for each variable in the group,
    with values set to the levels of the variables.
    Returns a list of parameters.
    """
    return [level_to_parameter(self.container[var_name], constraint)
            for var_name, constraint in self.content.items()]
  
  def get_level_records(self):
    """Return a list of records of the levels of the variables in the group"""
    return [x.records for x in self.levels_to_pameters()]


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
  d = Domain(sub_domain_pairs) if len(sub_domain_pairs) > 1 else sub_domain_pairs[0][0]
  ident = np.bitwise_and.reduce([s.sameAs(s_parent) for s, s_parent in sub_domain_pairs])
  return gp.Sum(d.where[ident], condition)


def merge_conditions(*conditions):
  """
  Merge multiple logical conditions into a single condition (with and operator),
  simplifying away conditions that are always true.
  """
  conditions = [c for c in conditions if not (isinstance(c, int) and c)]
  if len(conditions) == 0:
    return gp.Number(1)
  else:
    return np.bitwise_or.reduce(conditions)


def level_to_parameter(var, constraint):
  """Create a parameter with values set to the levels of a variable (for unconstrained elements)."""
  p = var.container.addParameter(domain=var.domain)
  p[...].where[constraint] = var.l
  return p

def fix_all(container):
  """Fix all variables in the container to their levels, for elements where the domain condition is true."""
  for var_name, domain_condition in container.domain_conditions.items():
    var = container[var_name]
    var.fx[...].where[domain_condition] = var.l[...]

