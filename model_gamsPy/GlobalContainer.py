import gamspy as gp
import Blocks
import Groups

container = gp.Container()

container.domain_conditions = {}
container.domain_dummy = {}

Set = container.addSet
Parameter = container.addParameter

def Variable(*args, condition=1, **kwargs):
  """Return a gamsPy variable with additional domain_conditition and sub_domain attributes."""
  var = container.addVariable(*args, **kwargs)
  container.domain_conditions[var.name] = condition
  container.domain_dummy[var.name] = Set(domain=var.domain)
  return var

def Block():
  return Blocks.Block(container)

def Group():
  return Groups.Group(container)

