# # Plotting
# dt.YAXIS_TITLE_FROM_OPERATOR = {
#   "pq": "Pct. changes relative to baseline",
# 	"m": "Difference from baseline",
# }
# dt.TIME_AXIS_TITLE = ""


import pandas as pd
def extract_table_by_name(series: pd.Series, target_names: list, level: str = 'name') -> pd.DataFrame:
    """
    From a MultiIndexed Series, create a DataFrame with specified `name` level values as columns.

    Parameters:
    - series: pd.Series with MultiIndex
    - target_names: list of values from the `name` level to include
    - level: the name of the index level to pivot into columns (default: 'name')

    Returns:
    - pd.DataFrame with one row per remaining index levels, and one column per name
    """
    # Filter for the selected names
    series_filtered = series[series.index.get_level_values(level).isin(target_names)]
    # Unstack the `name` level
    df = series_filtered.unstack(level)

    # Keep only the desired columns (some may be missing, so reindex)
    return df.reindex(columns=target_names)


def multiple_conditions_extract_table_by_name(series: pd.Series, target_values: dict, cols: str) -> pd.DataFrame:
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



def newname(series: pd.Series, target_values: dict, cols: str) -> pd.DataFrame:
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
