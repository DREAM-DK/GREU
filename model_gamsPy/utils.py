import numpy as np
import pandas as pd

def dataframe_differences(a, b, value_col='value', atol=1e-12):
  # Return None if both inputs are None
  if a is None and b is None:
    return None

  if a is None:
    a = pd.DataFrame(columns=b.columns)
  if b is None:
    b = pd.DataFrame(columns=a.columns)

  index_cols = [col for col in a.columns if col != value_col]

  # Set multi-index
  a_indexed = a.set_index(index_cols)
  b_indexed = b.set_index(index_cols)

  # Reindex both DataFrames to include all indices from both
  combined_index = a_indexed.index.union(b_indexed.index)
  a_full = a_indexed.reindex(combined_index)
  b_full = b_indexed.reindex(combined_index)

  # Find elements that differ beyond tolerance
  differences = ~np.isclose(a_full[value_col].fillna(0), b_full[value_col].fillna(0), atol=atol)

  if not differences.any():
    return None

  # Reset index to include the index columns in the string representation
  diff_df = pd.DataFrame({
    'a': a_full[value_col][differences],
    'b': b_full[value_col][differences]
  }).reset_index() 
  
  return diff_df.to_string()

def differences(a, b):
  """Find differences between two dictionaries of parameters (e.g. variable levels of a group)."""
  return [
      f"{var_name}\n:\n{diffs}"
      for var_name in set(a.keys()) | set(b.keys())
      if (diffs := dataframe_differences(a.get(var_name), b.get(var_name))) is not None
  ]