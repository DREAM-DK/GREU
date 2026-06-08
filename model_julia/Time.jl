module Time

import JuMP
import SquareModels
import ..Settings: first_data_year, base_year, calibration_year, terminal_year

const tBase = base_year # Statistical index year where prices are set to 1
const max_terminal_year = terminal_year
const t = first_data_year:max_terminal_year

t1::Int = calibration_year # First endogenous year (configurable)
T::Int = max_terminal_year # Terminal year (configurable)

"""
Return the same variable at a chosen year by replacing the last index.

Examples:
- `x[2025] -> x[2030]`
- `x[i,2025] -> x[i,2030]`
"""
@inline at_year(var, year::Integer) = at_year(JuMP.owner_model(var), var, year)
function at_year(model, var, year::Integer)
	var_name = JuMP.name(var)
	open_bracket = findlast(==('['), var_name)
	isnothing(open_bracket) && return var
	last_comma = findlast(==(','), var_name)
	year_name = isnothing(last_comma) || last_comma < open_bracket ?
		string(SubString(var_name, 1, open_bracket), year, ']') :
		string(SubString(var_name, 1, last_comma), year, ']')
	return SquareModels.variable_by_name(model, year_name)
end

"""
Extract the year index from a JuMP/SquareModels variable name, returning the year as an integer.
Returns `nothing` if the variable does not have a year index.

Examples:
- `variable_year(x[2030])` returns `2030`
- `variable_year(x[i,2025])` returns `2025`
"""
function variable_year(var)
	var_name = JuMP.name(var)
	open_bracket = findlast(==('['), var_name)
	isnothing(open_bracket) && return nothing
	last_comma = findlast(==(','), var_name)
	year_txt = isnothing(last_comma) || last_comma < open_bracket ?
		SubString(var_name, open_bracket + 1, lastindex(var_name) - 1) :
		SubString(var_name, last_comma + 1, lastindex(var_name) - 1)
	return tryparse(Int, String(year_txt))
end

end
