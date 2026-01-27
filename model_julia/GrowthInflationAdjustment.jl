# ==============================================================================
# Growth and inflation adjustment
# ==============================================================================
# To make the model roughly stationary we adjust variables for growth or inflation.
# E.g. we change the coordinate system such that a constant price level really means
# that prices are growing at a constant rate. Prices, quantities, and values are adjusted as:
# p[t] ≡ p̂[t] / (1+π)^(t-base_year)
# q[t] ≡ q̂[t] / (1+g)^(t-base_year)
# v[t] ≡ v̂[t] / [(1+π)(1+g)]^(t-base_year)
# Where p̂, q̂, and v̂ are the unadjusted versions of the variables p, q, and v.

module GrowthInflationAdjustment
	using JuMP

	export gq, gp, fq, fp, fv
	export growth_adjusted, inflation_adjusted
	export @growth_adjusted, @inflation_adjusted

	const gq = 0.02 # Long-run real growth rate
	const gp = 0.02 # Long-run inflation rate
	const fq = 1 + gq # Quantity growth factor
	const fp = 1 + gp # Price growth factor
	const fv = fq * fp # Value growth factor

	# Sets to track which variables need growth/inflation adjustment
	const growth_adjusted = Set{VariableRef}()
	const inflation_adjusted = Set{VariableRef}()

	# Macros to tag variables for adjustment
	macro growth_adjusted(expr)
		esc(quote
			new_variables = $expr
			union!(growth_adjusted, collect(Iterators.flatten(new_variables)))
			new_variables
		end)
	end

	macro inflation_adjusted(expr)
		esc(quote
			new_variables = $expr
			union!(inflation_adjusted, collect(Iterators.flatten(new_variables)))
			new_variables
		end)
	end
end

using .GrowthInflationAdjustment
