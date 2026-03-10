# ==============================================================================
# Input-Output Module
# ==============================================================================
# Demand for energy, other intermediate inputs, investments, private and public
# consumption, and exports is allocated to imports and output from domestic
# industries. Mirrors model/modules/input_output.gms.

module InputOutput
	import JuMP
	using SquareModels
	using ..GrowthInflationAdjustment
	using ..Data: gdx, load_set, load_parameter
	import ..db, ..t, ..t1, ..T, ..tBase, ..ForecastConstant

	# ==========================================================================
	# GDX data conversion helpers
	# ==========================================================================
	_to_idt(raw) = Dict(
		(Symbol(k[1]), Symbol(k[2]), parse(Int, k[3])) => v for (k, v) in raw
	)
	_to_it(raw) = Dict(
		(Symbol(k[1]), parse(Int, k[2])) => v for (k, v) in raw
	)

	# ==========================================================================
	# Indices
	# ==========================================================================
	const i = load_set(:i)
	const d = load_set(:d)
	const m = load_set(:m)
	const rx = i                       # non-energy intermediates share industry elements
	const re = load_set(:re)
	const k = load_set(:k)
	const c = load_set(:c)
	const g = load_set(:g)
	const x = load_set(:x)
	const d_ene = load_set(:d_ene)
	const d_non_ene = load_set(:d_non_ene)
	const invt = first(load_set(:invt))
	const invt_ene = first(load_set(:invt_ene))

	# ==========================================================================
	# Load raw GDX data and compute sparse IO cell keys
	# ==========================================================================
	const _raw = (
		vY_i_d      = _to_idt(load_parameter(:vY_i_d)),
		vY_i_d_base = _to_idt(load_parameter(:vY_i_d_base)),
		vtY_i_d     = _to_idt(load_parameter(:vtY_i_d)),
		vM_i_d      = _to_idt(load_parameter(:vM_i_d)),
		vM_i_d_base = _to_idt(load_parameter(:vM_i_d_base)),
		vtM_i_d     = _to_idt(load_parameter(:vtM_i_d)),
		vtY_i_Sub   = _to_it(load_parameter(:vtY_i_Sub)),
		vtY_i_Tax   = _to_it(load_parameter(:vtY_i_Tax)),
	)

	# Data cleaning (matches GAMS exogenous_values section)
	const _energy_ind = Set([Symbol("19000"), Symbol("35002"), Symbol("38393")])
	const _d_ene_set = Set(d_ene)

	for (key, _) in collect(_raw.vM_i_d)
		key[1] != Symbol("19000") && key[2] in _d_ene_set && (_raw.vM_i_d[key] = 0.0)
	end
	for i_v in _energy_ind, d_v in d_non_ene, t_v in t
		delete!(_raw.vY_i_d, (i_v, d_v, t_v))
	end

	# Compute valid (i,d) pairs from data (abs value > 1e-6 threshold)
	function _id_keys(data)
		pairs = Set{Tuple{Symbol,Symbol}}()
		for ((i_v, d_v, _), val) in data
			abs(val) > 1e-6 && push!(pairs, (i_v, d_v))
		end
		sort!(collect(pairs))
	end

	const keys_Y  = _id_keys(_raw.vY_i_d)
	const keys_M  = _id_keys(_raw.vM_i_d)
	const keys_YM = sort!(collect(Set(keys_Y) ∪ Set(keys_M)))
	const keys_Y_set = Set(keys_Y)
	const keys_M_set = Set(keys_M)
	const both_keys = [id for id in keys_YM if id in keys_Y_set && id in keys_M_set]
	const import_only_keys = [id for id in keys_M if !(id in keys_Y_set)]

	# ==========================================================================
	# Variables
	# ==========================================================================

	# Values (growth + inflation adjusted)
	@variables db.model :: (GrowthAdjusted, InflationAdjusted) begin
		vGDP[t], "Gross Domestic Product"
		vGVA[t], "Gross value added"
		vR[t], "Non-energy intermediate inputs"
		vE[t], "Energy intermediate inputs"
		vI[t], "Investments"
		vC[t], "Private consumption"
		vG[t], "Public consumption"
		vX[t], "Exports"
		vY[t], "Total output"
		vM[t], "Total imports"
		vY_i[i, t], "Output by industry"
		vM_i[m, t], "Imports by industry"
		vD[d, t], "Demand by demand component"
		vY_i_d[keys_Y, t], "Domestic output by industry and demand"
		vY_i_d_base[keys_Y, t], "Domestic output in base prices"
		vM_i_d[keys_M, t], "Imports by industry and demand"
		vM_i_d_base[keys_M, t], "Imports in base prices"
		vtY_i_d[keys_Y, t], "Net duties on domestic production by (i,d)"
		vtM_i_d[keys_M, t], "Net duties on imports by (i,d)"
		vtY_i[i, t], "Net duties on domestic production by industry"
		vtM_i[m, t], "Net duties on imports by industry"
		vtY[t], "Total net duties on domestic production"
		vtM[t], "Total net duties on imports"
		vtY_i_Sub[i, t], "Production subsidies by industry"
		vtY_i_Tax[i, t], "Production taxes by industry"
		vtY_i_NetTaxSub[i, t], "Net production taxes and subsidies"
		vtY_Tax[t], "Total production taxes"
		vtY_Sub[t], "Total production subsidies"
		vC_WalrasLaw[t], "Walras law residual (stub, from households)"
	end

	# Prices (inflation adjusted)
	@variables db.model :: InflationAdjusted begin
		pGDP[t], "GDP deflator"
		pGVA[t], "GVA deflator"
		pR[t], "Non-energy intermediates deflator"
		pE[t], "Energy intermediates deflator"
		pI[t], "Investment deflator"
		pC[t], "Consumer price index"
		pG[t], "Government consumption deflator"
		pX[t], "Export deflator"
		pY[t], "Output deflator"
		pM[t], "Import deflator"
		pY_i[i, t], "Price of domestic output by industry"
		pM_i[i, t], "Price of imports by industry"
		pD[d, t], "Deflator of demand component"
		pY_i_d[keys_Y, t], "Price of domestic output by (i,d)"
		pY_i_d_base[keys_Y, t], "Base price of domestic output"
		pM_i_d[keys_M, t], "Price of imports by (i,d)"
		pM_i_d_base[keys_M, t], "Base price of imports"
	end

	# Quantities (growth adjusted)
	@variables db.model :: GrowthAdjusted begin
		qGDP[t], "Real GDP"
		qGVA[t], "Real GVA"
		qR[t], "Real non-energy intermediates"
		qE[t], "Real energy intermediates"
		qI[t], "Real investments"
		qC[t], "Real consumption"
		qG[t], "Real government consumption"
		qX[t], "Real exports"
		qY[t], "Real total output"
		qM[t], "Real imports"
		qY_i[i, t], "Real output by industry"
		qM_i[m, t], "Real imports by industry"
		qD[d, t], "Real demand by demand component"
		qY_i_d[keys_Y, t], "Real domestic output by (i,d)"
		qM_i_d[keys_M, t], "Real imports by (i,d)"
	end

	# Rates and shares (no adjustment)
	@variables db.model begin
		tY_i_d[keys_Y, t], "Tax rate on domestic output by (i,d)"
		tM_i_d[keys_M, t], "Tax rate on imports by (i,d)"
		tY_i_sub[i, t], "Average subsidy rate"
		tY_i_tax[i, t], "Average production tax rate"
		jfpY_i_d[keys_Y, t], "Price deviation, domestic"
		jfpM_i_d[keys_M, t], "Price deviation, imports"
		rYM[keys_YM, t] :: ForecastConstant, "Industry composition of demand"
		rM[keys_YM, t] :: ForecastConstant, "Import share"
	end

	# ==========================================================================
	# Data
	# ==========================================================================
	function set_data!(db)
		# IO data from GDX (3D variables)
		for ((i_v, d_v, t_v), val) in _raw.vY_i_d
			(i_v, d_v) in keys_Y_set && t_v in t && (db[vY_i_d[(i_v, d_v), t_v]] = val)
		end
		for ((i_v, d_v, t_v), val) in _raw.vY_i_d_base
			(i_v, d_v) in keys_Y_set && t_v in t && (db[vY_i_d_base[(i_v, d_v), t_v]] = val)
		end
		for ((i_v, d_v, t_v), val) in _raw.vtY_i_d
			(i_v, d_v) in keys_Y_set && t_v in t && (db[vtY_i_d[(i_v, d_v), t_v]] = val)
		end
		for ((i_v, d_v, t_v), val) in _raw.vM_i_d
			(i_v, d_v) in keys_M_set && t_v in t && (db[vM_i_d[(i_v, d_v), t_v]] = val)
		end
		for ((i_v, d_v, t_v), val) in _raw.vM_i_d_base
			(i_v, d_v) in keys_M_set && t_v in t && (db[vM_i_d_base[(i_v, d_v), t_v]] = val)
		end
		for ((i_v, d_v, t_v), val) in _raw.vtM_i_d
			(i_v, d_v) in keys_M_set && t_v in t && (db[vtM_i_d[(i_v, d_v), t_v]] = val)
		end

		# IO data from GDX (2D variables)
		i_set = Set(i)
		for ((i_v, t_v), val) in _raw.vtY_i_Sub
			i_v in i_set && t_v in t && (db[vtY_i_Sub[i_v, t_v]] = val)
		end
		for ((i_v, t_v), val) in _raw.vtY_i_Tax
			i_v in i_set && t_v in t && (db[vtY_i_Tax[i_v, t_v]] = val)
		end

		# Import shares: 1 for import-only cells, 0 for domestic-only
		for id in keys_YM, t_v in t
			if id in keys_M_set && !(id in keys_Y_set)
				db[rM[id, t_v]] = 1.0
			elseif id in keys_Y_set && !(id in keys_M_set)
				db[rM[id, t_v]] = 0.0
			end
		end

		# IO cell prices initialized to 1
		for id in keys_Y, t_v in t
			db[pY_i_d[id, t_v]] = 1.0
		end
		for id in keys_M, t_v in t
			db[pM_i_d[id, t_v]] = 1.0
		end

		# Real quantities at IO level: q = v - vt
		for id in keys_Y, t_v in t
			v = db[vY_i_d[id, t_v]]
			if !isnothing(v) && v > 1e-6
				db[qY_i_d[id, t_v]] = v - something(db[vtY_i_d[id, t_v]], 0.0)
			end
		end
		for id in keys_M, t_v in t
			v = db[vM_i_d[id, t_v]]
			if !isnothing(v) && v > 1e-6
				db[qM_i_d[id, t_v]] = v - something(db[vtM_i_d[id, t_v]], 0.0)
			end
		end

		# Aggregate prices = 1 (inflation adjustment via tags ≡ GAMS fpt[t])
		for p in [pY_i, pM_i, pD, pR, pE, pI, pC, pG, pX, pM, pY, pGDP, pGVA]
			db[p] .= 1.0
		end

		db[vGDP] .= 2321.0
		db[vC_WalrasLaw] .= 0.0

		return nothing
	end

	# ==========================================================================
	# Equations
	# ==========================================================================
	function define_equations()
		return @block db begin
			# -- GDP identity and chain price index --
			vGDP[t = t1:T],
			vGDP[t] == vC[t] + vI[t] + vG[t] + vX[t] - vM[t]

			pGDP[t = t1:T],
			pGDP[t] * qGDP[t] == vGDP[t]

			qGDP[t = t1:T],
			qGDP[t] * pGDP[t-1] == pC[t-1]*qC[t] + pI[t-1]*qI[t] + pG[t-1]*qG[t] + pX[t-1]*qX[t] - pM[t-1]*qM[t]

			# -- GVA identity and chain price index --
			vGVA[t = t1:T],
			vGVA[t] == vY[t] - vR[t] - vE[t]

			pGVA[t = t1:T],
			pGVA[t] * qGVA[t] == vGVA[t]

			qGVA[t = t1:T],
			qGVA[t] * pGVA[t-1] == pY[t-1]*qY[t] - pR[t-1]*qR[t] - pE[t-1]*qE[t]

			# -- Demand aggregates --
			vR[t = t1:T], vR[t] == sum(vD[s, t] for s in rx)
			vE[t = t1:T], vE[t] == sum(vD[s, t] for s in re)
			vI[t = t1:T], vI[t] == sum(vD[s, t] for s in k) + vD[invt, t]
			vC[t = t1:T], vC[t] == sum(vD[s, t] for s in c) + vC_WalrasLaw[t]
			vG[t = t1:T], vG[t] == sum(vD[s, t] for s in g)
			vX[t = t1:T], vX[t] == sum(vD[s, t] for s in x)

			# -- Deflator identities --
			pR[t = t1:T], pR[t] * qR[t] == vR[t]
			pE[t = t1:T], pE[t] * qE[t] == vE[t]
			pI[t = t1:T], pI[t] * qI[t] == vI[t]
			pC[t = t1:T], pC[t] * qC[t] == vC[t]
			pG[t = t1:T], pG[t] * qG[t] == vG[t]
			pX[t = t1:T], pX[t] * qX[t] == vX[t]

			# -- Chain price indices for demand aggregates --
			qR[t = t1:T],
			qR[t] * pR[t-1] == sum(pD[s, t-1] * qD[s, t] for s in rx)

			qE[t = t1:T],
			qE[t] * pE[t-1] == sum(pD[s, t-1] * qD[s, t] for s in re)

			qI[t = t1:T],
			qI[t] * pI[t-1] == sum(pD[s, t-1] * qD[s, t] for s in k) + pD[invt, t-1]*qD[invt, t] + pD[invt_ene, t-1]*qD[invt_ene, t]

			qC[t = t1:T],
			qC[t] * pC[t-1] == sum(pD[s, t-1] * qD[s, t] for s in c)

			qG[t = t1:T],
			qG[t] * pG[t-1] == sum(pD[s, t-1] * qD[s, t] for s in g)

			qX[t = t1:T],
			qX[t] * pX[t-1] == sum(pD[s, t-1] * qD[s, t] for s in x)

			# -- Supply equilibrium --
			vY_i[i_e = i, t = t1:T],
			vY_i[i_e, t] + vtY_i[i_e, t] == sum(vY_i_d[(i_e, d_e), t] for d_e in d if (i_e, d_e) in keys_Y_set; init=0.0)

			vY[t = t1:T], vY[t] == sum(vY_i[s, t] for s in i)
			pY[t = t1:T], pY[t] * qY[t] == vY[t]

			qY[t = t1:T],
			qY[t] * pY[t-1] == sum(pY_i[s, t-1] * qY_i[s, t] for s in i)

			# -- Industry quantity aggregation (base-year tax correction) --
			qY_i[i_e = i, t = t1:T],
			qY_i[i_e, t] == sum(
				qY_i_d[(i_e, d_e), t] / (1 + tY_i_d[(i_e, d_e), tBase])
				for d_e in d if (i_e, d_e) in keys_Y_set; init=0.0
			)

			qM_i[m_e = m, t = t1:T],
			qM_i[m_e, t] == sum(
				qM_i_d[(m_e, d_e), t] / (1 + tM_i_d[(m_e, d_e), tBase])
				for d_e in d if (m_e, d_e) in keys_M_set; init=0.0
			)

			# -- Import aggregation --
			vM_i[m_e = m, t = t1:T],
			vM_i[m_e, t] + vtM_i[m_e, t] == sum(vM_i_d[(m_e, d_e), t] for d_e in d if (m_e, d_e) in keys_M_set; init=0.0)

			vM[t = t1:T], vM[t] == sum(vM_i[s, t] for s in m)
			pM[t = t1:T], pM[t] * qM[t] == vM[t]

			qM[t = t1:T],
			qM[t] * pM[t-1] == sum(pM_i[s, t-1] * qM_i[s, t] for s in m)

			# -- Net duties --
			vtY_i_d[id = keys_Y, t = t1:T],
			vtY_i_d[id, t] == tY_i_d[id, t] * vY_i_d_base[id, t]

			vtM_i_d[id = keys_M, t = t1:T],
			vtM_i_d[id, t] == tM_i_d[id, t] * vM_i_d_base[id, t]

			vtY_i[i_e = i, t = t1:T],
			vtY_i[i_e, t] == sum(vtY_i_d[(i_e, d_e), t] for d_e in d if (i_e, d_e) in keys_Y_set; init=0.0)

			vtM_i[m_e = m, t = t1:T],
			vtM_i[m_e, t] == sum(vtM_i_d[(m_e, d_e), t] for d_e in d if (m_e, d_e) in keys_M_set; init=0.0)

			vtY[t = t1:T], vtY[t] == sum(vtY_i[s, t] for s in i)
			vtM[t = t1:T], vtM[t] == sum(vtM_i[s, t] for s in m)

			# -- Production taxes and subsidies --
			vtY_i_Sub[i_e = i, t = t1:T],
			vtY_i_Sub[i_e, t] == tY_i_sub[i_e, t] * qY_i[i_e, t]

			vtY_i_Tax[i_e = i, t = t1:T],
			vtY_i_Tax[i_e, t] == tY_i_tax[i_e, t] * qY_i[i_e, t]

			vtY_i_NetTaxSub[i_e = i, t = t1:T],
			vtY_i_NetTaxSub[i_e, t] == vtY_i_Tax[i_e, t] - vtY_i_Sub[i_e, t]

			vtY_Tax[t = t1:T], vtY_Tax[t] == sum(vtY_i_Tax[s, t] for s in i)
			vtY_Sub[t = t1:T], vtY_Sub[t] == sum(vtY_i_Sub[s, t] for s in i)

			# -- Demand composition and deflator --
			vD[d_e = d, t = t1:T],
			vD[d_e, t] == sum(vY_i_d[(i_e, d_e), t] for i_e in i if (i_e, d_e) in keys_Y_set; init=0.0) +
			              sum(vM_i_d[(i_e, d_e), t] for i_e in i if (i_e, d_e) in keys_M_set; init=0.0)

			pD[d_e = d, t = t1:T],
			pD[d_e, t] * qD[d_e, t] == vD[d_e, t]

			# -- IO price equations --
			pY_i_d[id = keys_Y, t = t1:T],
			pY_i_d[id, t] == (1 + tY_i_d[id, t]) * pY_i_d_base[id, t]

			pM_i_d[id = keys_M, t = t1:T],
			pM_i_d[id, t] == (1 + tM_i_d[id, t]) * pM_i_d_base[id, t]

			pY_i_d_base[id = keys_Y, t = t1:T],
			pY_i_d_base[id, t] == (1 + jfpY_i_d[id, t]) / (1 + tY_i_d[id, tBase]) * pY_i[id[1], t]

			pM_i_d_base[id = keys_M, t = t1:T],
			pM_i_d_base[id, t] == (1 + jfpM_i_d[id, t]) / (1 + tM_i_d[id, tBase]) * pM_i[id[1], t]

			# -- Quantity allocation --
			qY_i_d[id = keys_Y, t = t1:T],
			qY_i_d[id, t] == (1 - rM[id, t]) * rYM[id, t] * qD[id[2], t]

			qM_i_d[id = keys_M, t = t1:T],
			qM_i_d[id, t] == rM[id, t] * rYM[id, t] * qD[id[2], t]

			# -- Value identities at IO-cell level --
			vY_i_d[id = keys_Y, t = t1:T],
			vY_i_d[id, t] == pY_i_d[id, t] * qY_i_d[id, t]

			vM_i_d[id = keys_M, t = t1:T],
			vM_i_d[id, t] == pM_i_d[id, t] * qM_i_d[id, t]

			vY_i_d_base[id = keys_Y, t = t1:T],
			vY_i_d_base[id, t] == pY_i_d_base[id, t] * qY_i_d[id, t]

			vM_i_d_base[id = keys_M, t = t1:T],
			vM_i_d_base[id, t] == pM_i_d_base[id, t] * qM_i_d[id, t]
		end
	end

	# ==========================================================================
	# Calibration
	# ==========================================================================
	function define_calibration()
		block = define_equations()

		# Tax rates from observed duties at t1
		@endo_exo! block begin
			tY_i_d[:, t1], vtY_i_d[:, t1]
			tM_i_d[:, t1], vtM_i_d[:, t1]
			tY_i_sub[:, t1], vtY_i_Sub[:, t1]
			tY_i_tax[:, t1], vtY_i_Tax[:, t1]
		end

		# Composition shares from observed base-price values at t1
		# rYM calibrated for domestic keys from vY_i_d_base,
		# and for import-only keys from vM_i_d_base
		for id in keys_Y
			@endo_exo!(block, rYM[id, t1], vY_i_d_base[id, t1])
		end
		for id in import_only_keys
			@endo_exo!(block, rYM[id, t1], vM_i_d_base[id, t1])
		end
		# rM only calibrated where both domestic and import cells exist
		for id in both_keys
			@endo_exo!(block, rM[id, t1], vM_i_d_base[id, t1])
		end

		# Base-price continuity: p_base at t0 (= t1-1) equals p_base at t1
		block = block + @block db begin
			pY_i_d_base[id = keys_Y, t = (t1-1):(t1-1)],
			pY_i_d_base[id, t] == pY_i_d_base[id, t1]

			pM_i_d_base[id = keys_M, t = (t1-1):(t1-1)],
			pM_i_d_base[id, t] == pM_i_d_base[id, t1]
		end

		return block
	end

	# ==========================================================================
	# Tests
	# ==========================================================================
	function run_tests(db)
		for t_v in t1:T
			gdp_err = abs(db[vGDP[t_v]] - (db[vC[t_v]] + db[vI[t_v]] + db[vG[t_v]] + db[vX[t_v]] - db[vM[t_v]]))
			gdp_err <= 1e-6 || error("GDP identity violated at t=$t_v: residual=$gdp_err")

			gva_err = abs(db[vGVA[t_v]] - (db[vY[t_v]] - db[vR[t_v]] - db[vE[t_v]]))
			gva_err <= 1e-6 || error("GVA identity violated at t=$t_v: residual=$gva_err")
		end
		return nothing
	end
end
