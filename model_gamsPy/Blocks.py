from groups import Group, merge_conditions, fix_all
from gamspy._algebra.condition import Condition
from gamspy._algebra.expression import Expression

class Block:
  """A collection of equations and associated endogenous variables."""

  def __init__(self, container, condition=1):
    self.container = container
    self.equations = []
    self.endogenous = Group(container)
    self.condition = condition

  def __setitem__(self, key, expression):
    if key is ...:
      endogenous = None
      condition = 1
    elif isinstance(key, Condition):
      endogenous = key.conditioning_on
      condition = key.condition
    elif isinstance(key, Expression):
      endogenous = None
      condition = key
    else:
      endogenous = key
      condition = 1
    self.Equation(expression, endogenous=endogenous, condition=condition)

  def Equation(self, expression, endogenous=None, domain=None, condition=1, **kwargs):
    """
    Add an equation to the block, with an associated endogenous variable.
    endogenous variable and domain will be inferred from first left-hand side variable if not provided.
    """
    if endogenous is None:
      endogenous = expression.left
    if domain is None:
      domain = endogenous.domain

    eq = self.container.addEquation(domain=domain, **kwargs)

    if domain:
      domain_dummy = self.container.domain_dummy[endogenous.name]
      eq[domain].where[domain_dummy[domain] & self.condition & condition] = expression
    else:
      eq[...].where[self.condition & condition] = expression

    self.equations.append(eq)
    self.endogenous.add_variable(endogenous, self.condition & condition)

    return eq

  def Model(self, problem="CNS", **kwargs):
    return self.container.addModel(
      equations=self.equations,
      problem=problem,
      limited_variables=limit_variable_domains(self.container),
      **kwargs
    )

  def solve(self, **kwargs):
    fix_all(self.container)
    self.endogenous.unfix()
    return self.Model().solve(**kwargs)

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

def evaluate_domain_condition(container, var_name):
  """
  Set the sub_domain of a variable (subset limiting the domain of the variable)
  by evaluating the domain_condition of the variable (a logical expression).
  Return variable[sub_domain] (to limit the domain of the variable in a model).
  """
  sub_domain = container.domain_dummy[var_name]
  if sub_domain is None:
    return None
  domain_condition = container.domain_conditions[var_name]
  sub_domain[...] = domain_condition
  variable = container[var_name]
  return variable[sub_domain]

def limit_variable_domains(container):
  """
  Return a list of limited variables, to limit the domain of variables in a model
  based on the domain_condition attribute of the variables.
  """
  return [var_lim for var_name in container.domain_conditions
          if (var_lim := evaluate_domain_condition(container, var_name)) is not None]