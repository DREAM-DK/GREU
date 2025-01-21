import gamspy as gp
from groups import Group, fix_all
from gamspy._algebra.condition import Condition
from gamspy._algebra.expression import Expression

One = gp.Number(1)

class Block:
  """A collection of equations and associated endogenous variables."""

  def __init__(self, container, condition=One):
    self.container = container
    self.equations = []
    self._endogenous = Group(container)
    self.domain_dummies = []
    self.condition = condition
    self._counter = container.addParameter()

  @property
  def endogenous(self):
    return self._endogenous
  
  @endogenous.setter
  def endogenous(self, new_group):
    assert new_group.n_elements() == self.n_elements(),\
      "Endogenous group must have the same number of elements as the block."
    self._endogenous = new_group

  def __setitem__(self, key, expression):
    if key is ...:
      endogenous = None
      condition = One
    elif isinstance(key, Condition):
      endogenous = key.conditioning_on
      condition = key.condition
    elif isinstance(key, Expression):
      endogenous = None
      condition = key
    else:
      endogenous = key
      condition = One
    self.Equation(expression, endogenous=endogenous, condition=condition)

  def Equation(self, expression, endogenous=None, domain=None, condition=One, **kwargs):
    """
    Add an equation to the block, with an associated endogenous variable.
    endogenous variable and domain will be inferred from first left-hand side variable if not provided.
    """
    if endogenous is None:
      endogenous = expression.left
    if domain is None:
      domain = endogenous.domain

    eq = self.container.addEquation(domain=domain, **kwargs)

    domain_dummy = evaluate_domain_dummy(self.container, endogenous.name)

    eq[domain].where[domain_dummy[domain] & self.condition & condition] = expression

    self.equations.append(eq)
    self.domain_dummies.append(domain_dummy)
    self.endogenous += endogenous.where[self.condition & condition]

    return eq
  
  def n_elements(self):
    """Calculate the number of elements in a block."""
    return sum(
      self._calculate_eq_elements(eq)
      for eq in self.equations
    )
  
  def _calculate_eq_elements(self, eq):
    """Calculate the number of elements in an equation for a given domain condition"""
    n = self._counter
    condition = eq._definition.left.condition # Relies on gamsPy internals!
    if len(eq.domain) == 0:
      n[...].where[condition] = 1
    elif len(eq.domain) == 1:
      n[...] = gp.Sum(eq.domain[0].where[condition], 1)
    else:
      n[...] = gp.Sum(gp.Domain(*eq.domain).where[condition], 1)
    return int(n.records.sum().iloc[0])

  def Model(self, problem="CNS", **kwargs):
    return self.container.addModel(
      equations=self.equations,
      problem=problem,
      limited_variables=limit_variable_domains(self.container),
      **kwargs
    )

  def solve(self, solver="CONOPT4", **kwargs):
    fix_all(self.container)
    self.endogenous.unfix()
    return self.Model().solve(solver=solver, **kwargs)

  def __add__(self, other):
    """Combine two blocks into a single block."""
    b = Block(self.container)
    b.equations = self.equations + other.equations
    b.endogenous = self.endogenous + other.endogenous
    return b
  
  def __radd__(self, other):
    if other == 0:
      return self
    return self.__add__(other)

  def copy(self):
    """Return a copy of the block."""
    b = Block(self.container)
    b.equations = self.equations.copy()
    b.endogenous = self.endogenous.copy()
    return b

def limit_variable_domains(container):
  """
  Return a list of limited variables, to limit the domain of variables in a model
  based on the domain_condition attribute of the variables.
  """
  return [container[var_name][sub_domain] for var_name in container.domain_conditions
          if (sub_domain := evaluate_domain_dummy(container, var_name)) is not None]

def evaluate_domain_dummy(container, var_name):
  """
  Set the sub_domain of a variable (subset limiting the domain of the variable)
  by evaluating the domain_condition of the variable (a logical expression).
  Return variable[sub_domain] (to limit the domain of the variable in a model).
  """
  domain_dummy = container.domain_dummies[var_name]
  if domain_dummy is None:
    return None
  domain_dummy[...] = container.domain_conditions[var_name]
  return domain_dummy