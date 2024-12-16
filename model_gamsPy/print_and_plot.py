import gamspy as gp
import plotly.express as px

def variable_level_as_series(variable):
  """Return the level of a variable as a pandas Series, with preceding columns as index."""
  index_columns = variable.records.columns[:-5].tolist()
  series = variable.records.set_index(index_columns)["level"]
  series.name = variable.name
  return series

def parameter_values_as_series(parameter):
  """Return the values of a parameter as a pandas Series, with preceding columns as index."""
  index_columns = parameter.records.columns[:-1].tolist()
  series = parameter.records.set_index(index_columns)["value"]
  series.name = parameter.name
  return series

def eval_expression(expr, repr=None):
  """Evaluate a gamsPy expression recursively, returning a Pandas series and a Latex reprensation."""
  if isinstance(expr, gp.Variable):
    return variable_level_as_series(expr), repr
  if isinstance(expr, gp.Parameter):
    return parameter_values_as_series(expr), repr
  if isinstance(expr, gp.Expression):
    repr = expr.latexRepr()
    left = eval_expression(expr.left, repr)[0]
    right = eval_expression(expr.right, repr)[0]
    operator = eval_expression(expr.data, repr)[0]
    return eval(f"left {operator} right"), repr
  if isinstance(expr, gp._symbols.implicits.implicit_variable.ImplicitVariable):
    return eval_implicit_variable(expr), repr
  if isinstance(expr, gp._symbols.implicits.implicit_parameter.ImplicitParameter):
    return eval_implicit_parameter(expr), repr
  return expr, repr

def eval_implicit_variable(symbol):
  parent_series = variable_level_as_series(symbol.parent)
  return parent_series.loc[*[d.records.iloc[:,0] for d in symbol.domain]]

def eval_implicit_parameter(symbol):
  parent_series = parameter_values_as_series(symbol.parent)
  return parent_series.loc[*[d.records.iloc[:,0] for d in symbol.domain]]

def plot(expr):
  """Plot a gamsPy expression."""
  series, repr = eval_expression(expr)
  df = series.reset_index().set_index("t")
  df["element"] = df[[c for c in df.columns if c != series.name]].apply("_".join, axis=1)
  return px.line(df, y=series.name, color="element")
