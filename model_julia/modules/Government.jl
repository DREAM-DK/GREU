# Populate government entries of the SectorAccounts interface.
# Keep the government budget identity and simple portfolio rules.

module Government

using SquareModels
import ..model
import ..SectorAccounts:
  ass_liab,
  vNetFinTransactions,
  vNetFinIncome,
  vGovBalance,
  vGovPrimaryBalance,
  vFinAL,
  vFinTransactions,
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
    # Gov neither buys nor sells equity; existing equity stocks follow non-transaction changes.
    vFinAL[s=[:Gov], f=[:Equity], al=ass_liab, t=t1:T],
    vFinTransactions[s,f,al,t] == 0

    # Gov does not buy or sell debt assets; the stock follows non-transaction changes.
    vFinAL[s=[:Gov], f=[:Debt], al=[:Assets], t=t1:T],
    vFinTransactions[s,f,al,t] == 0

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
