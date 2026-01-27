# ==============================================================================
# Input-Output Module
# ==============================================================================
# Handles the flow of goods and services between industries and final demand.
# Simplified version focusing on core IO relationships.

module InputOutput
	using JuMP, SquareModels
	using ..GrowthInflationAdjustment
	import ..db, ..t, ..t₁, ..T

	# ==========================================================================
	# Sets / Indices (defined in this module)
	# ==========================================================================
	# Industry/sector indices
	const i = [:agri, :manuf, :services, :energy]

	# Demand components
	const d = [:C, :G, :I, :X]  # Consumption, Government, Investment, Exports

	# Origin (for import/domestic distinction)
	const o = [:domestic, :import]

	# ==========================================================================
	# Variables
	# ==========================================================================
	# Values (adjusted for both growth and inflation)
	@growth_adjusted @inflation_adjusted @variables db.model begin
		vGDP[t]     # Gross Domestic Product
		vY[t]       # Total output
		vM[t]       # Total imports
		vC[t]       # Private consumption
		vG[t]       # Government consumption
		vI[t]       # Investment
		vX[t]       # Exports
		vY_i[i, t]  # Output by industry
		vIO[i, d, t] # IO flows (value of deliveries from industry i to demand d)
	end

	# Prices (adjusted for inflation only)
	@inflation_adjusted @variables db.model begin
		pY[t]       # Output price deflator
		pM[t]       # Import price deflator
		pC[t]       # Consumer price index
		pG[t]       # Government consumption deflator
		pI[t]       # Investment deflator
		pX[t]       # Export deflator
		pY_i[i, t]  # Price by industry
	end

	# Parameters (no adjustment)
	@variables db.model begin
		μIO[i, d]   # IO coefficients (share of industry i in demand d)
	end

	# ==========================================================================
	# Equations
	# ==========================================================================
	function define_equations()
		return @block db begin
			# GDP identity: Y - M = C + G + I + X
			vGDP[t = t₁:T],
			vGDP[t] == vC[t] + vG[t] + vI[t] + vX[t] - vM[t]

			# Total output = sum of industry outputs
			vY[t = t₁:T],
			vY[t] == sum(vY_i[i, t] for i in i)

			# Industry output = sum of deliveries to all demand components
			vY_i[i = i, t = t₁:T],
			vY_i[i, t] == sum(vIO[i, d, t] for d in d)

			# IO flows: simple Leontief (fixed coefficients)
			# Deliveries from industry i to consumption
			vIO[i = i, d = [:C], t = t₁:T],
			vIO[i, d, t] == μIO[i, d] * vC[t]

			# Deliveries from industry i to government
			vIO[i = i, d = [:G], t = t₁:T],
			vIO[i, d, t] == μIO[i, d] * vG[t]

			# Deliveries from industry i to investment
			vIO[i = i, d = [:I], t = t₁:T],
			vIO[i, d, t] == μIO[i, d] * vI[t]

			# Deliveries from industry i to exports
			vIO[i = i, d = [:X], t = t₁:T],
			vIO[i, d, t] == μIO[i, d] * vX[t]

			# Price indices (value-weighted)
			pC[t = t₁:T],
			pC[t] * vC[t] == sum(pY_i[i, t] * vIO[i, :C, t] for i in i)

			pG[t = t₁:T],
			pG[t] * vG[t] == sum(pY_i[i, t] * vIO[i, :G, t] for i in i)

			pI[t = t₁:T],
			pI[t] * vI[t] == sum(pY_i[i, t] * vIO[i, :I, t] for i in i)

			pX[t = t₁:T],
			pX[t] * vX[t] == sum(pY_i[i, t] * vIO[i, :X, t] for i in i)

			# Aggregate output price
			pY[t = t₁:T],
			pY[t] * vY[t] == sum(pY_i[i, t] * vY_i[i, t] for i in i)

			# Import price (exogenous for now)
			pM[t = t₁:T],
			pM[t] == 1.0
		end
	end

	# ==========================================================================
	# Data
	# ==========================================================================
	function set_data!(db)
		# Initial values for final demand (base year)
		db[vC] .= 1000.0
		db[vG] .= 500.0
		db[vI] .= 400.0
		db[vX] .= 600.0
		db[vM] .= 500.0

		# Prices normalized to 1
		db[pY_i] .= 1.0
		db[pY] .= 1.0
		db[pM] .= 1.0
		db[pC] .= 1.0
		db[pG] .= 1.0
		db[pI] .= 1.0
		db[pX] .= 1.0

		# GDP
		db[vGDP] .= 2000.0
		db[vY] .= 2500.0

		# Industry outputs (rough split)
		db[vY_i[:agri, :]] .= 200.0
		db[vY_i[:manuf, :]] .= 800.0
		db[vY_i[:services, :]] .= 1200.0
		db[vY_i[:energy, :]] .= 300.0

		# IO flows (will be calibrated)
		db[vIO] .= 100.0

		return nothing
	end

	# ==========================================================================
	# Calibration
	# ==========================================================================
	function define_calibration()
		block = define_equations()
		@endo_exo! block begin
			# Calibrate IO coefficients to match observed flows
			μIO, vIO[i, d, t₁]
		end
		return block
	end
end
