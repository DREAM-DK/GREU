# Populate household entries of the SectorAccounts interface.
# Keep the household budget identity and simple portfolio rules.
# Exclude consumption functions from households.gms.

module Households

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: vC
import ..model
import ..SectorAccounts:
  vNetFinTransactions,
  vNetFinIncome,
  vNetTransfers2sector,
  vCorrectionNonFinCorp2Hh,
  vGrossCapitalFormation,
  vNonFinancialNonProducedAssets,
  vFinAL,
  vFinTransactions,
  vFinReval,
  vNetFinAssets,
  vFinAssets_al,
  vHhWages
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
    vNetFinTransactions[s=[:Hh], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 + vHhWages[t]
                                 - vC[t]
                                 + vCorrectionNonFinCorp2Hh[t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]

    # Portfolio.
    # Equity assets and debt liabilities follow revaluation.
    vFinAL[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T], 
    vFinTransactions[s,f,al,t] == 0

    vFinAL[s=[:Hh], f=[:Debt], al=[:Liab], t=t1:T], 
    vFinTransactions[s,f,al,t] == 0

    # Hh debt assets are residual given net financial assets.
    vFinAL[s=[:Hh], f=[:Debt], al=[:Assets], t=t1:T], 
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
