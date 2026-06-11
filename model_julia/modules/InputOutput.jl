# ==============================================================================
# Input-Output Module
# ==============================================================================
# Demand for energy, other intermediate inputs, investments, private and public
# consumption, and exports is allocated to imports and output from domestic
# industries. Mirrors model/modules/input_output.gms.
include(joinpath(@__DIR__, "InputOutputSettings.jl"))

module InputOutput

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutputSettings:
  all_demand_components,
  capital_types,
  energy_types,
  export_types,
  government_consumption_types,
  input_output_data_dir,
  private_consumption_types
import ..Settings: calibration_year
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ==========================================================================
# Indices
# ==========================================================================

const industries_with_domestic = read_indices(joinpath(input_output_data_dir, "industries.csv"))
const industries_with_imports = read_indices(joinpath(input_output_data_dir, "industries_with_imports.csv"))
const industries = sort(union(industries_with_domestic, industries_with_imports))

const I = industries
const M = industries_with_imports
const demand_components = all_demand_components(industries)
const D_all = demand_components

const vY_i_d_data = read_sparse_array(joinpath(input_output_data_dir, "input_output_cells.csv"); variable="vY_i_d")
const vM_i_d_data = read_sparse_array(joinpath(input_output_data_dir, "input_output_cells.csv"); variable="vM_i_d")

# Calibration-year cells define the sparse (industry, demand) variable masks.
const D1Y = Set(eachindex(vY_i_d_data[:, :, calibration_year]))
const D1M = Set(eachindex(vM_i_d_data[:, :, calibration_year]))
const D1YM = D1Y ∪ D1M
const D = [d for d in D_all if any((i, d) in D1YM for i in I)]

const RX = industries
const RE = energy_types
const K = capital_types
const C = private_consumption_types
const G = government_consumption_types
const X = export_types

# ==========================================================================
# Variables
# ==========================================================================
const InputOutputTag = Tag(:InputOutput)

# Values (growth + inflation adjusted)
@variables db.model :: (InputOutputTag, GrowthAdjusted, InflationAdjusted) begin
  vGDP[t], "Gross Domestic Product"
  vGVA[t], "Gross Value Added"
  vR[t], "Non-energy intermediate inputs"
  vE[t], "Energy intermediate inputs"
  vI[t], "Investments"
  vC[t], "Private consumption"
  vG[t], "Public consumption"
  vX[t], "Exports"
  vY[t], "Total output"
  vM[t], "Total imports"
  vY_i[I, t], "Output by industry"
  vGVA_i[I, t], "Gross value added at basic prices by industry"
  vM_i[M, t], "Imports by industry"
  vD[D, t], "Demand by demand component at purchaser prices"
  vY_d[D, t], "Domestic output by demand component before net product taxes and subsidies"
  vM_d[D, t], "Imports by demand component before net product taxes and subsidies"
  vY_i_d[i=I, d=D, t=t; (i, d) in D1Y], "Domestic output by industry and demand before net product taxes and subsidies"
  vM_i_d[i=I, d=D, t=t; (i, d) in D1M], "Imports by industry and demand before net product taxes and subsidies"
  vtY_i_d[i=I, d=D, t=t; (i, d) in D1Y], "Net taxes less subsidies on domestic produced products by (i,d)"
  vtM_i_d[i=I, d=D, t=t; (i, d) in D1M], "Net taxes less subsidies on imported products by (i,d)"
  vtD[D, t], "Net taxes less subsidies on products by demand component"
  vtY_d[D, t], "Net taxes less subsidies on products on domestic production by demand component"
  vtM_d[D, t], "Net taxes less subsidies on products on imports by demand component"
  vtY_i[I, t], "Net taxes less subsidies on products on domestic production by industry"
  vtM_i[M, t], "Net taxes less subsidies on products on imports by industry"
  vtY[t], "Net taxes less subsidies on products (domestic)"
  vtM[t], "Net taxes less subsidies on products (imports)"
  # Per-industry primary inputs (ESA value-added block of the use table)
  vW_i[I, t], "Compensation of employees by industry (ESA D.1)"
  vtYOther_i[I, t], "Other taxes less subsidies on production by industry (ESA D.29 − D.39)"
  vDepr_i[I, t], "Consumption of fixed capital by industry (ESA P.51c / K.1)"
  vOpSurplus_i[I, t], "Net operating surplus and mixed income by industry (ESA B.2n + B.3n)"
  # Economy-wide aggregates of the value-added block
  vW[t], "Total compensation of employees"
  vtYOther[t], "Total other taxes less subsidies on production"
  vDepr[t], "Total consumption of fixed capital"
  vOpSurplus[t], "Total net operating surplus and mixed income"
end

# Prices (inflation adjusted)
@variables db.model :: (InputOutputTag, InflationAdjusted) begin
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
  pY_i[I, t], "Price of domestic output by industry"
  pM_i[I, t], "Price of imports by industry"
  pD[D, t], "Deflator of demand component"
  pY_i_d[i=I, d=D, t=t; (i, d) in D1Y], "Domestic output price before net product taxes and subsidies by (i,d)"
  pM_i_d[i=I, d=D, t=t; (i, d) in D1M], "Import price before net product taxes and subsidies by (i,d)"
end

# Quantities (growth adjusted)
@variables db.model :: (InputOutputTag, GrowthAdjusted) begin
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
  qY_i[I, t], "Real output by industry"
  qM_i[M, t], "Real imports by industry"
  qD[D, t], "Real demand by demand component"
  qY_i_d[i=I, d=D, t=t; (i, d) in D1Y], "Real domestic output by (i,d)"
  qM_i_d[i=I, d=D, t=t; (i, d) in D1M], "Real imports by (i,d)"
end

# Rates and shares (no adjustment)
@variables db.model :: InputOutputTag begin
  tY_i_d[i=I, d=D, t=t; (i, d) in D1Y] :: ForecastConstant, "Tax rate on domestic output by (i,d)"
  tM_i_d[i=I, d=D, t=t; (i, d) in D1M] :: ForecastConstant, "Tax rate on imports by (i,d)"
  jfpY_i_d[i=I, d=D, t=t; (i, d) in D1Y], "Price deviation, domestic"
  jfpM_i_d[i=I, d=D, t=t; (i, d) in D1M], "Price deviation, imports"
  rYM[i=I, d=D, t=t; (i, d) in D1YM] :: ForecastConstant, "Industry composition of demand"
  rM[i=I, d=D, t=t; (i, d) in D1YM] :: ForecastConstant, "Import share"
end

# ==========================================================================
# Data
# ==========================================================================
function set_data!(db; dir = input_output_data_dir)
  cells_file = joinpath(dir, "input_output_cells.csv")
  industries_file = joinpath(dir, "input_output_industries.csv")
  demands_file = joinpath(dir, "input_output_demands.csv")
  aggregates_file = joinpath(dir, "input_output_aggregates.csv")

  db[vY_i_d] .= read_variable(cells_file, vY_i_d)
  db[vM_i_d] .= read_variable(cells_file, vM_i_d)
  db[vtY_i_d] .= read_variable(cells_file, vtY_i_d; default=0.0)
  db[vtM_i_d] .= read_variable(cells_file, vtM_i_d; default=0.0)
  db[vW_i] .= read_variable(industries_file, vW_i; default=0.0)
  db[vtYOther_i] .= read_variable(industries_file, vtYOther_i; default=0.0)
  db[vDepr_i] .= 0.0
  db[vOpSurplus_i] .= read_variable(industries_file, vOpSurplus_i; default=0.0)

  db[jfpY_i_d] .= 0.0
  db[jfpM_i_d] .= 0.0
  db[rM] .= [(i, d) ∈ D1Y ? 0.0 : 1.0 for (i, d, _) in keys(rM)]

  db[qD] .= read_variable(demands_file, qD)
  db[vD] .= read_variable(demands_file, vD)
  db[vGDP] .= read_variable(aggregates_file, vGDP)
  db[vGVA] .= read_variable(aggregates_file, vGVA)

  # Set prices to 1.0 (inflation, but not growth-adjusted, variables)
  for name in tagged(InputOutputTag)
    has_tag(name, InflationAdjusted) && !has_tag(name, GrowthAdjusted) && (db[getfield(@__MODULE__, name)] .= 1.0)
  end

  return nothing
end

# ==========================================================================
# Starting values (solver hints, not exogenous data)
# ==========================================================================
function set_starting_values!(db)
end

# ==========================================================================
# Equations
# ==========================================================================
function define_equations()
  return @block db begin
    # -- GDP identity and fixed price index --
    vGDP[t = t1:T], vGDP[t] == vC[t] + vI[t] + vG[t] + vX[t] - vM[t]
    pGDP[t = t1:T], pGDP[t] * qGDP[t] == vGDP[t]
    qGDP[t = t1:T], qGDP[t] == qC[t] + qI[t] + qG[t] + qX[t] - qM[t]

    # -- GVA identity and fixed price index --
    vGVA[t = t1:T], vGVA[t] == vY[t] - vR[t] - vE[t]
    pGVA[t = t1:T], pGVA[t] * qGVA[t] == vGVA[t]
    qGVA[t = t1:T], qGVA[t] == qY[t] - qR[t] - qE[t]

    # -- Per-industry GVA at basic prices (ESA D.1 + (D.29-D.39) + P.51c + B.2n+B.3n) --
    vGVA_i[i=I, t=t1:T],
    vGVA_i[i,t] == vW_i[i,t] + vtYOther_i[i,t] + vDepr_i[i,t] + vOpSurplus_i[i,t]

    # -- Economy-wide value-added aggregates --
    vW[t=t1:T], vW[t] == ∑(vW_i[i,t] for i in I)
    vtYOther[t=t1:T], vtYOther[t] == ∑(vtYOther_i[i,t] for i in I)
    vDepr[t=t1:T], vDepr[t] == ∑(vDepr_i[i,t] for i in I)
    vOpSurplus[t=t1:T], vOpSurplus[t] == ∑(vOpSurplus_i[i,t] for i in I)

    # -- Demand aggregates --
    vR[t = t1:T], vR[t] == ∑(vD[d,t] for d in RX)
    vE[t = t1:T], vE[t] == ∑(vD[d,t] for d in RE)
    vI[t = t1:T], vI[t] == ∑(vD[d,t] for d in K)
    vC[t = t1:T], vC[t] == ∑(vD[d,t] for d in C)
    vG[t = t1:T], vG[t] == ∑(vD[d,t] for d in G)
    vX[t = t1:T], vX[t] == ∑(vD[d,t] for d in X)

    # -- Deflator identities --
    pR[t = t1:T], pR[t] * qR[t] == vR[t]
    pE[t = t1:T], pE[t] * qE[t] == vE[t]
    pI[t = t1:T], pI[t] * qI[t] == vI[t]
    pC[t = t1:T], pC[t] * qC[t] == vC[t]
    pG[t = t1:T], pG[t] * qG[t] == vG[t]
    pX[t = t1:T], pX[t] * qX[t] == vX[t]

    # -- Fixed price indices for demand aggregates --
    qR[t = t1:T], qR[t] == ∑(qD[rx,t] for rx in RX)
    qE[t = t1:T], qE[t] == ∑(qD[re,t] for re in RE)
    qI[t = t1:T], qI[t] == ∑(qD[k,t] for k in K)
    qC[t = t1:T], qC[t] == ∑(qD[c,t] for c in C)
    qG[t = t1:T], qG[t] == ∑(qD[g,t] for g in G)
    qX[t = t1:T], qX[t] == ∑(qD[x,t] for x in X)

    # -- Supply equilibrium before net product taxes and subsidies --
    vY_i[i = I, t = t1:T],
    vY_i[i, t] == ∑(vY_i_d[i, d, t] for d in D if (i, d) in D1Y)

    vY[t = t1:T], vY[t] == ∑(vY_i[i, t] for i in I)
    pY[t = t1:T], pY[t] * qY[t] == vY[t]
    qY[t = t1:T], qY[t] == ∑(qY_i[i, t] for i in I)

    # -- Industry quantity aggregation --
    qY_i[i = I, t = t1:T],
    qY_i[i, t] == ∑(qY_i_d[i, d, t] for d in D if (i, d) in D1Y)

    qM_i[m = M, t = t1:T],
    qM_i[m, t] == ∑(qM_i_d[m, d, t] for d in D if (m, d) in D1M)

    # -- Import aggregation before net product taxes and subsidies --
    vM_i[m = M, t = t1:T],
    vM_i[m, t] == ∑(vM_i_d[m, d, t] for d in D if (m, d) in D1M)

    vM[t = t1:T], vM[t] == ∑(vM_i[m, t] for m in M)
    pM[t = t1:T], pM[t] * qM[t] == vM[t]

    qM[t = t1:T],
    qM[t] == ∑(qM_i[m, t] for m in M)

    # -- Net duties --
    vtY_i_d[i = I, d = D, t = t1:T; (i, d) in D1Y],
    vtY_i_d[i, d, t] == tY_i_d[i, d, t] * vY_i_d[i, d, t]

    vtM_i_d[i = I, d = D, t = t1:T; (i, d) in D1M],
    vtM_i_d[i, d, t] == tM_i_d[i, d, t] * vM_i_d[i, d, t]

    vtY_i[i = I, t = t1:T],
    vtY_i[i, t] == ∑(vtY_i_d[i, d, t] for d in D if (i, d) in D1Y)

    vtY_d[d = D, t = t1:T],
    vtY_d[d, t] == ∑(vtY_i_d[i, d, t] for i in I if (i, d) in D1Y)

    vtM_i[m = M, t = t1:T],
    vtM_i[m, t] == ∑(vtM_i_d[m, d, t] for d in D if (m, d) in D1M)

    vtM_d[d = D, t = t1:T],
    vtM_d[d, t] == ∑(vtM_i_d[i, d, t] for i in I if (i, d) in D1M)

    vtD[d = D, t = t1:T],
    vtD[d, t] == vtY_d[d, t] + vtM_d[d, t]

    vtY[t = t1:T], vtY[t] == ∑(vtY_i[i, t] for i in I)
    vtM[t = t1:T], vtM[t] == ∑(vtM_i[m, t] for m in M)

    # -- Demand composition and deflator at purchaser prices --
    vY_d[d = D, t = t1:T],
    vY_d[d, t] == ∑(vY_i_d[i, d, t] for i in I if (i, d) in D1Y)

    vM_d[d = D, t = t1:T],
    vM_d[d, t] == ∑(vM_i_d[i, d, t] for i in I if (i, d) in D1M)

    vD[d = D, t = t1:T],
    vD[d, t] == vY_d[d, t] + vM_d[d, t] + vtD[d, t]

    pD[d = D, t = t1:T],
    pD[d, t] * qD[d, t] == vD[d, t]

    # -- IO price equations --
    pY_i_d[i = I, d = D, t = t1:T; (i, d) in D1Y],
    pY_i_d[i, d, t] == (1 + jfpY_i_d[i, d, t]) * pY_i[i, t]

    pM_i_d[i = I, d = D, t = t1:T; (i, d) in D1M],
    pM_i_d[i, d, t] == (1 + jfpM_i_d[i, d, t]) * pM_i[i, t]

    # -- Quantity allocation --
    qY_i_d[i = I, d = D, t = t1:T; (i, d) in D1Y],
    qY_i_d[i, d, t] == (1 - rM[i, d, t]) * rYM[i, d, t] * qD[d, t]

    qM_i_d[i = I, d = D, t = t1:T; (i, d) in D1M],
    qM_i_d[i, d, t] == rM[i, d, t] * rYM[i, d, t] * qD[d, t]

    # -- Value identities at IO-cell level --
    vY_i_d[i = I, d = D, t = t1:T; (i, d) in D1Y],
    vY_i_d[i, d, t] == pY_i_d[i, d, t] * qY_i_d[i, d, t]

    vM_i_d[i = I, d = D, t = t1:T; (i, d) in D1M],
    vM_i_d[i, d, t] == pM_i_d[i, d, t] * qM_i_d[i, d, t]
  end
end

# ==========================================================================
# Calibration
# ==========================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    tY_i_d[:, :, t1], vtY_i_d[:, :, t1]
    tM_i_d[:, :, t1], vtM_i_d[:, :, t1]
    rYM[:, :, t1], [(i, d) in D1Y ? vY_i_d[i, d, t1] : vM_i_d[i, d, t1] for (i, d) in D1YM]
    [rM[i, d, t1] for (i, d) in D1Y ∩ D1M], [vM_i_d[i, d, t1] for (i, d) in D1Y ∩ D1M]
  end

  return block
end

# ==========================================================================
# Tests
# ==========================================================================
function run_tests(db)
  return nothing
end

end # module
