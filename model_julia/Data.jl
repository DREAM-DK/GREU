# ==============================================================================
# Data Module
# ==============================================================================
# Loads the GDX file once and provides access to raw data.
# Modules extract their own sets and parameters from this.

module Data
	using GAMS

	const gdx_path = joinpath(@__DIR__, "..", "data", "data.gdx")
	const gdx = read_gdx(gdx_path)

	# Helper to extract set elements as vector of symbols
	function load_set(name::Symbol)
		df = gdx[name]
		col = first(names(df))
		return Symbol.(df[!, col])
	end

	# Helper to extract integer set (for time periods)
	function load_int_set(name::Symbol)
		df = gdx[name]
		col = first(names(df))
		return parse.(Int, df[!, col])
	end

	# Helper to load parameter/variable-level data as Dict{Tuple, Float64}
	function load_parameter(name::Symbol)
		df = gdx[name]
		cols = names(df)
		val_col = "level" in cols ? "level" : last(cols)
		idx_cols = [c for c in cols if !(c in [val_col, "marginal", "lower", "upper", "scale"])]
		return Dict(
			Tuple(string(row[c]) for c in idx_cols) => Float64(row[val_col])
			for row in eachrow(df) if Float64(row[val_col]) != 0.0
		)
	end

	export gdx, load_set, load_int_set, load_parameter
end

using .Data
