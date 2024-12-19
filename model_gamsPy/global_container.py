import gamspy as gp
import blocks
import groups

container = gp.Container()

container.domain_conditions = {}
container.domain_dummy = {}

container.tags = {}

container.submodels = []

Set = container.addSet
Parameter = container.addParameter
Alias = container.addAlias

def Tag(name):
  """Create a new tag that can be added to variables."""
  if name not in container.tags:
    container.tags[name] = set()
  return container.tags[name]

def add_tag_to_variable(tag, var_name):
  """Add a tag to a variable."""
  container.tags[tag].add(var_name)

def remove_tag_from_variable(tag, var_name):
  """Remove a tag from a variable."""
  container.tags[tag].remove(var_name)

def get_tagged_variables(tag):
  """Return a list of variables with a given tag."""
  return [container[name] for name in container.tags[tag]]

def Variable(*args, condition=1, **kwargs):
  """Return a gamsPy variable with additional domain_conditition and sub_domain attributes.""" 
  tags = {tag: kwargs.pop(tag) for tag in container.tags if tag in kwargs}
  var = container.addVariable(*args, **kwargs)
  container.domain_conditions[var.name] = condition
  container.domain_dummy[var.name] = Set(domain=var.domain) if var.domain else None
  for tag, value in tags.items():
    if value:
      add_tag_to_variable(tag, var.name)
  return var

def Block(**kwargs):
  return blocks.Block(container, **kwargs)

def Group(**kwargs):
  return groups.Group(container, **kwargs)
