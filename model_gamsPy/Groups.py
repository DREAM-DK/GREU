import gamspy as gp
import numpy as np
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
    self._counter = self.container.addParameter()

  def _add_variable(self, var, condition=One, allow_duplicate=False):
    condition = condition_from_subdomain(var, condition)
    if not allow_duplicate:
      assert not self._contains(var, condition), f"Variable {var.name} already in group for condition {condition.gamsRepr()}."
    if var.name not in self.content:
      self.content[var.name] = condition
    else:
      previous_condition = self.content[var.name]
      self.content[var.name] = merge_conditions(previous_condition, condition)

  def _contains(self, var, condition):
    """Check if a variable is in the group for a limited domain."""
    if var.name not in self.content:
      return False
    var = self.container[var.name] # If implicit variable, get the parent variable instead
    group_condition = self.content[var.name]
    var.m.where[group_condition] = 1 # We abuse the marginals attribute of the variable for our calculation
    var.m.where[condition] += 1
    isin = var.records.marginal.max() > 1
    var.m = 0
    return isin

  def _subtract_variable(self, var, condition=One, allow_non_removal=False):
    """Remove a variable from the group for a limited domain."""
    condition = condition_from_subdomain(var, condition)
    if not allow_non_removal:
      assert self._contains(var, condition), f'Variable "{var.name}" cannot be removed as it is not in the group for condition "{condition.gamsRepr()}".'
    if var.name not in self.content:
      pass
    elif condition is None:
      del self.content[var.name]
    else:
      self.content[var.name] = self.content[var.name] & ~condition

  def copy(self):
    """Return a copy of the group."""
    return Group(self.container, self.content.copy())

  def _add_group(self, other):
    """Combine two groups into a single group."""
    g = self.copy()
    for var_name, condition in other.content.items():
      if var_name in g.content:
        g.content[var_name] = merge_conditions(g.content[var_name], condition)
      else:
        g.content[var_name] = condition
    return g

  def _subtract_group(self, other):
    """Subtract the domain limits of another group from this group."""
    g = self.copy()
    for var_name, condition in other.content.items():
      if var_name in g.content:
        g.content[var_name] = g.content[var_name] & ~condition
    return g

  def __contains__(self, other):
    """Check if a variable is in the group using <var> in <group> syntax."""
    if isinstance(other, Group):
      return all(self._contains(var, condition) for var, condition in other.content.items())   
    elif isinstance(other, Condition):
      return self._contains(other.conditioning_on, other.condition)
    else:
      return self._contains(other, One)

  def __add__(self, other):
    """Allow adding variables and groups to a group using <group> + <var> syntax."""
    if isinstance(other, Group):
      return self._add_group(other)

    g = self.copy()
    if isinstance(other, Condition):
      g._add_variable(other.conditioning_on, other.condition)
    else:
      g._add_variable(other)
    return g

  def __sub__(self, other):
    """Allow removing variables and groups from a group using <group> - <var> syntax."""
    if isinstance(other, Group):
      return self._subtract_group(other)
    
    g = self.copy()
    if isinstance(other, Condition):
      g._subtract_variable(other.conditioning_on, other.condition)
    else:
      g._subtract_variable(other)
    return g
  
  def __radd__(self, other):
    """Summing groups is equivalent to adding them together."""
    if other == 0:
      return self
    return self.__add__(other)
  
  def __iter__(self):
    return iter(self.content)
  
  def n_elements(self):
    """Calculate the number of elements in the group."""
    return sum(
      self._calculate_var_elements(var_name, condition)
      for var_name, condition in self.content.items()
    )
    
  def _calculate_var_elements(self, var_name, condition):
    """Calculate the number of elements in a variable for a given domain condition"""
    n = self._counter
    var = self.container[var_name]
    domain_condition = self.container.domain_conditions[var_name]
    if len(var.domain) == 0:
      n[...].where[domain_condition & condition] = 1
    elif len(var.domain) == 1:
      n[...] = gp.Sum(var.domain[0].where[domain_condition & condition], 1)
    else:
      n[...] = gp.Sum(gp.Domain(*var.domain).where[domain_condition & condition], 1)
    return int(n.records.sum().iloc[0])
    
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

  def get_level_records(self):
      """Return a dictionary of records of the levels of the variables in the group"""
      return {
        var_name: level_to_parameter(self.container[var_name], constraint).records
        for var_name, constraint in self.content.items()
      }

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
  d = gp.Domain(sub_domain_pairs) if len(sub_domain_pairs) > 1 else sub_domain_pairs[0][0]
  ident = np.bitwise_and.reduce([s.sameAs(s_parent) for s, s_parent in sub_domain_pairs])
  return gp.Sum(d.where[ident], condition)


def merge_conditions(*conditions):
  """
  Merge multiple logical conditions into a single condition (with and operator),
  simplifying away conditions that are always true.
  """
  conditions = [c for c in conditions if not (isinstance(c, int) and c)]
  if len(conditions) == 0:
    return One
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
