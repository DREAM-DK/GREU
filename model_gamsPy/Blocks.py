from Groups import Group, merge_conditions, fix_all


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
    domain_dummy = self.container.domain_dummy[endogenous.name]
    eq = self.container.addEquation(domain=domain, **kwargs)
    eq[domain].where[domain_dummy[domain] & condition] = expression

    self.equations.append(eq)
    self.endogenous.add_variable(endogenous, condition)

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
  domain_condition = container.domain_conditions[var_name]
  sub_domain[...] = domain_condition
  variable = container[var_name]
  return variable[sub_domain]

def limit_variable_domains(container):
  """
  Return a list of limited variables, to limit the domain of variables in a model
  based on the domain_condition attribute of the variables.
  """
  return [evaluate_domain_condition(container, var_name) for var_name in container.domain_conditions]