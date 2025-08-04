import gamspy as gp
import blocks, groups

container = gp.Container()
container.domain_conditions = {}
container.domain_dummies = {}
container.debug = False

Set = container.addSet
Parameter = container.addParameter
Alias = container.addAlias

def toggle_debug():
  container.debug = not container.debug

def Variable(*args, condition=1, tags=None, **kwargs):
  """Return a gamsPy variable with additional domain_conditition and sub_domain attributes.""" 
  var = container.addVariable(*args, **kwargs)
  container.domain_conditions[var.name] = condition
  container.domain_dummies[var.name] = Set(
    name=f"domain_dummy_{var.name}",
    description=f"Domain dummy for {var.name}",
    domain=var.domain
  ) if var.domain else None
  if tags:
    for tag in tags:
      tag.add(var.name)
  return var

def Block(*args, **kwargs):
  return blocks.Block(container, *args, **kwargs)

def Group(*args, **kwargs):
  return groups.Group(container, *args, **kwargs)

class Tag:
  """
  A set of gamsPy symbols.
  Used to add tags to specific variables or equations.
  Unlike groups, tags do not have domain conditions.
  """
  def __init__(self):
    self.content = set()
  
  def add(self, var_name):
    self.content.add(var_name)

  def remove(self, var_name):
    self.content.remove(var_name)

  def __iter__(self):
    return iter(container[var_name] for var_name in self.content)
