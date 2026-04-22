import gamspy as gp
import numpy as np

One = gp.Number(1)

def condition_from_subdomain(var, condition):
  """
  Return a logical condition based on a variable and a condition,
  taking into account that the domain may have been subsetted.
  E.g. if foo is defined over ab and t
    condition_from_subdomain(foo[a,"1"], One)
    ->
    Sum(a.where[a.sameAs(ab)], One) and t.sameAs("1")
  """
  parent = var.container[var.name]

  if var.domain == parent.domain:
    return condition

  subdomains = var.domain.copy()
  for pos, element in var._scalar_domains:
    subdomains.insert(pos, element)

  sum_sets = []
  sum_conditions = []
  scalar_restrictions = []
  for s, s_parent in zip(subdomains, parent.domain):
    if s != s_parent:
      if isinstance(s, str):
        scalar_restrictions.append(s_parent.sameAs(s))
      else:
        sum_sets.append(s)
        sum_conditions.append(s.sameAs(s_parent))

  if sum_sets:
    d = gp.Domain(*sum_sets) if len(sum_sets) > 1 else sum_sets[0]
    condition = gp.Sum(d.where[np.bitwise_and.reduce(sum_conditions)], condition)
  if scalar_restrictions:
    condition = and_merge_conditions(condition, *scalar_restrictions)

  return condition

def and_merge_conditions(*conditions):
  """
  Merge multiple logical conditions into a single condition with and operator,
  simplifying away conditions that are always true.
  """
  conditions = [c for c in conditions if c is not One]
  if len(conditions) == 0:
    return One
  else:
    return np.bitwise_and.reduce(conditions)

def or_merge_conditions(*conditions):
  """
  Merge multiple logical conditions into a single condition with or operator,
  simplifying away conditions that are always true.
  """
  if any(c is One for c in conditions): # Using is operator instead of One in conditions to avoid comparing One with a gams condition
    return One
  else:
    return np.bitwise_or.reduce(conditions)
