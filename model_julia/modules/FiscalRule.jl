# Phase in a lump-sum transfer from government to households.
# Calibration sets its long-run level and the shape of the phase-in.
# Government net financial assets then meet a target share of GDP and stay flat in the terminal year.
# The base model holds the transfer on its calibrated share of GDP. It has no rule for a shock.

module FiscalRule

using SquareModels
import ..FixedBasePriceAggregates: vGDP
import ..Government: vGovLumpSum
import ..model
import ..SectorAccounts: vNetFinAssets
import ..Time: t, t1, T, max_terminal_year

# The transfer reaches its long-run share in this forecast year.
const phase_in_years = 20

# ============================================================================
# Variables
# ============================================================================
const FiscalRuleTag = Tag(:FiscalRule)

@variables model :: FiscalRuleTag begin
  rGovLumpSum2GDP[t], "Government lump-sum transfer to households relative to GDP."
  rGovLumpSum2GDPLongRun, "Lump-sum transfer relative to GDP after the phase-in."
  eGovLumpSumPhaseIn, "Elasticity of the lump-sum share to the elapsed share of the phase-in. One gives a linear path."
  rGovNetFinAssets2GDPTarget, "Target for government net financial assets relative to GDP in the terminal year."
end

# ============================================================================
# Assign data
# ============================================================================
# The transfer is zero until calibration sets the path. The two rule parameters have no data.
function assign_data!(db)
  db[rGovLumpSum2GDP] .= 0.0
  db[rGovNetFinAssets2GDPTarget] = 0.5
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[rGovLumpSum2GDPLongRun] = 0.06
  start_values[eGovLumpSumPhaseIn] = 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    vGovLumpSum[t=t1:T], vGovLumpSum[t] == rGovLumpSum2GDP[t] * vGDP[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  # The rule needs the full horizon. A shorter horizon keeps the transfer share at zero.
  T == max_terminal_year || return copy(base)

  return copy(base) + @block model begin
    # The share rises over the first forecast years and then stays flat.
    rGovLumpSum2GDP[t=(t1+1):(t1+phase_in_years-1)],
    rGovLumpSum2GDP[t] == rGovLumpSum2GDPLongRun * ((t - t1) / phase_in_years)^eGovLumpSumPhaseIn

    rGovLumpSum2GDP[t=(t1+phase_in_years):T], rGovLumpSum2GDP[t] == rGovLumpSum2GDPLongRun

    # The long-run share puts government net financial assets on target in the terminal year.
    rGovLumpSum2GDPLongRun, vNetFinAssets[:Gov,T] == rGovNetFinAssets2GDPTarget * vGDP[T]

    # The phase-in shape holds the net asset share flat in the terminal year.
    eGovLumpSumPhaseIn, vNetFinAssets[:Gov,T] / vGDP[T] == vNetFinAssets[:Gov,T-1] / vGDP[T-1]
  end
end

end # module
