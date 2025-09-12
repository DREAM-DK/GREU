
import pandas as pd
from define_output_functions import extract_table_by_name, multiple_conditions_extract_table_by_name, newname

def table(series: pd.Series, target_values: dict, cols: str) -> pd.DataFrame:
    """
    From a MultiIndexed Series, extract entries matching multiple index level values and pivot one level into columns.

    Parameters:
    - series: pd.Series with MultiIndex
    - target_values: dict of {level_name: list of allowed values}
    - unstack_level: name of index level to pivot into columns

    Returns:
    - pd.DataFrame with one row per remaining levels, one column per value of unstacked level
    """

    indexer = pd.Series([True] * len(series), index=series.index)

    for level, allowed in target_values.items():
        level_vals = series.index.get_level_values(level)
        indexer &= level_vals.isin(allowed)

    # Filter and pivot
    filtered = series[indexer]
    df = filtered.unstack(cols)

    # Ensure all expected columns are present (fill with NaN if missing)
    expected_columns = target_values.get(cols, df.columns.tolist())
    return df.reindex(columns=expected_columns)



# Plotting
dt.YAXIS_TITLE_FROM_OPERATOR = {
  "pq": "Pct. changes relative to baseline",
	"m": "Difference from baseline",
}
dt.TIME_AXIS_TITLE = ""
