# ==============================================================================
# Input-Output Module
# ==============================================================================
# Handles the flow of goods and services between industries and final demand.
# Simplified version to establish working architecture.

module InputOutput
	import JuMP
	using SquareModels
	using ..GrowthInflationAdjustment
	using ..Data: gdx, load_set, load_int_set
	import ..db, ..t, ..t1, ..T

	# ==========================================================================
	# Indices (owned by this module)
	# ==========================================================================
	# Industries - use the full  index from GDX
	const industries = load_set(:i)

	# Demand subsets
	const private_consumption_types = load_set(:c)
	const government_consumption_types = load_set(:g)
	const export_types = load_set(:x)
	const investment_types = load_set(:k)

	# ==========================================================================
	# Variables
	# ==========================================================================
	i = industries

	# Aggregate values (adjusted for both growth and inflation)
	@variables db.model :: (GrowthAdjusted, InflationAdjusted) begin
		vGDP[t], "Gross Domestic Product"
		vY[t], "Total output"
		vC[t], "Private consumption"
		vG[t], "Public consumption"
		vI[t], "Investments"
		vX[t], "Exports"
		vM[t], "Imports"
		vY_i[i,t], "Output by industry"
	end

	# Prices (adjusted for inflation only)
	@variables db.model :: InflationAdjusted begin
		pGDP[t], "GDP deflator"
		pY[t], "Output price deflator"
		pC[t], "Consumer price index"
		pG[t], "Government consumption deflator"
		pI[t], "Investment deflator"
		pX[t], "Export deflator"
		pM[t], "Import deflator"
		pY_i[i,t], "Price by industry"
	end

	# Real quantities (adjusted for growth only)
	@variables db.model :: GrowthAdjusted begin
		qGDP[t], "Real GDP"
		qY[t], "Real total output"
		qC[t], "Real consumption"
		qG[t], "Real government"
		qI[t], "Real investments"
		qX[t], "Real exports"
		qM[t], "Real imports"
		qY_i[i,t], "Real output by industry"
	end

	# Rates and shares (no adjustment)
	@variables db.model begin
		rY_i[i], "Industry share of total output (calibrated)"
	end

	# ==========================================================================
	# Data
	# ==========================================================================
	function set_data!(db)
		# Initialize prices to 1
		db[pY_i] .= 1.0
		db[pY] .= 1.0
		db[pGDP] .= 1.0
		db[pC] .= 1.0
		db[pG] .= 1.0
		db[pI] .= 1.0
		db[pX] .= 1.0
		db[pM] .= 1.0

		# Sample values for demand components
		db[vC] .= 1000.0
		db[vG] .= 500.0
		db[vI] .= 400.0
		db[vX] .= 600.0
		db[vM] .= 500.0
		db[vGDP] .= 2000.0

		# Real quantities (= values when prices = 1)
		db[qC] .= 1000.0
		db[qG] .= 500.0
		db[qI] .= 400.0
		db[qX] .= 600.0
		db[qM] .= 500.0
		db[qGDP] .= 2000.0

		# Total output (example)
		db[vY] .= 2500.0
		db[qY] .= 2500.0

		# Equal industry shares initially
		n_industries = length(i)
		for i_elem in i
			db[rY_i[i_elem]] = 1.0 / n_industries
			for t_elem in t
				db[vY_i[i_elem, t_elem]] = 2500.0 / n_industries
				db[qY_i[i_elem, t_elem]] = 2500.0 / n_industries
			end
		end

		return nothing
	end

	# ==========================================================================
	# Equations
	# ==========================================================================
	function define_equations()
		return @block db begin
			# GDP identity
			vGDP[t = t1:T],
			vGDP[t] == vC[t] + vI[t] + vG[t] + vX[t] - vM[t]

			pGDP[t = t1:T],
			pGDP[t] * qGDP[t] == vGDP[t]

			# Total output = sum of industry outputs
			vY[t = t1:T],
			vY[t] == sum(vY_i[i_elem, t] for i_elem in i)

			pY[t = t1:T],
			pY[t] * qY[t] == vY[t]

			# Industry output (simple fixed share)
			vY_i[i = industries, t = t1:T],
			vY_i[i,t] == rY_i[i] * vY[t]

			# Price-quantity identities
			pC[t = t1:T], pC[t] * qC[t] == vC[t]
			pG[t = t1:T], pG[t] * qG[t] == vG[t]
			pI[t = t1:T], pI[t] * qI[t] == vI[t]
			pX[t = t1:T], pX[t] * qX[t] == vX[t]
			pM[t = t1:T], pM[t] * qM[t] == vM[t]
		end
	end

	# ==========================================================================
	# Calibration
	# ==========================================================================
	function define_calibration()
		block = define_equations()
		@endo_exo! block begin
			rY_i[:], vY_i[:,t1]  # Calibrate industry shares to match observed outputs
		end
		return block
	end

	# ==========================================================================
	# Tests
	# ==========================================================================
	function run_tests(db)
		# Industry shares should sum to 1
		share_sum = sum(db[rY_i[i_elem]] for i_elem in i)
		abs(share_sum - 1.0) <= 1e-6 || error("Industry shares sum to $share_sum, expected 1.0")
		return nothing
	end
end
