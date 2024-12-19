import gamspy as gp
import plotly.express as px

def variable_level_as_series(variable):
  """Return the level of a variable as a pandas Series, with preceding columns as index."""
  index_columns = variable.records.columns[:-5].tolist()
  if index_columns:
    series = variable.records.set_index(index_columns)["level"]
  else:
    series = variable.records["level"]
  series.name = variable.name
  return series

def parameter_values_as_series(parameter):
  """Return the values of a parameter as a pandas Series, with preceding columns as index."""
  index_columns = parameter.records.columns[:-1].tolist()
  if index_columns:
    series = parameter.records.set_index(index_columns)["value"]
  else:
    series = parameter.records["value"]
  series.name = parameter.name
  return series

def eval_expression(expr):
  """Evaluate a gamsPy expression recursively, returning a Pandas series and a Latex reprensation."""
  if isinstance(expr, gp.Variable):
    return variable_level_as_series(expr)
  if isinstance(expr, gp.Parameter):
    return parameter_values_as_series(expr)
  if isinstance(expr, gp.Expression):
    left = eval_expression(expr.left)
    right = eval_expression(expr.right)
    operator = eval_expression(expr.data)
    return eval(f"left {operator} right")
  if isinstance(expr, gp._symbols.implicits.implicit_variable.ImplicitVariable):
    return eval_implicit_variable(expr)
  if isinstance(expr, gp._symbols.implicits.implicit_parameter.ImplicitParameter):
    return eval_implicit_parameter(expr)
  return expr

def eval_implicit_variable(symbol):
  parent_series = variable_level_as_series(symbol.parent)
  return parent_series.loc[*[d.records.iloc[:,0] for d in symbol.domain]]

def eval_implicit_parameter(symbol):
  parent_series = parameter_values_as_series(symbol.parent)
  return parent_series.loc[*[d.records.iloc[:,0] for d in symbol.domain]]

def plot(expr):
  """Plot a gamsPy expression."""
  series = eval_expression(expr)
  df = series.reset_index().set_index("t")
  df["element"] = df[[c for c in df.columns if c != series.name]].apply("_".join, axis=1)
  return px.line(df, y=series.name, color="element")

def prt(expr):
  """Print a gamsPy expression."""
  series = eval_expression(expr)
  print(series)