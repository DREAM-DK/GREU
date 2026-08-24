# Populate government entries of the SectorAccounts interface.
# Keep the government budget identity and simple portfolio rules.

module Government

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..model
import ..SectorAccounts:
  vNetFinTransactions,
  vNetFinIncome,
  vGovBalance,
  vGovPrimaryBalance,
  vFinAL,
  vFinReval,
  vNetFinAssets,
  vFinAssets_al
import ..Time: t, t1, T

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Budget identity.
    vGovPrimaryBalance[t=t1:T],
    vGovPrimaryBalance[t] == vGovBalance[t] - vNetFinIncome[:Gov,t]

    vNetFinTransactions[s=[:Gov], t=t1:T],
    vNetFinTransactions[s,t] == vGovPrimaryBalance[t]
                                 + vNetFinIncome[s,t]

    # Portfolio.
    # Gov neither buys nor sells equity; equity assets follow revaluation.
    vFinAL[s=[:Gov], f=[:Equity], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == vFinAL[s,f,al,t-1]/fv + vFinReval[s,f,al,t]

    # Debt assets follow revaluation.
    vFinAL[s=[:Gov], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == vFinAL[s,f,al,t-1]/fv + vFinReval[s,f,al,t]

    # Gov debt liabilities are residual given net financial assets.
    vFinAL[s=[:Gov], f=[:Debt], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations()
end

end # module
