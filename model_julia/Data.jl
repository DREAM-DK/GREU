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

	export gdx, load_set, load_int_set
end

using .Data
