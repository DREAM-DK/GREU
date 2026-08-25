# Populate household entries of the SectorAccounts interface.
# Keep the household budget identity and simple portfolio rules.
# Exclude consumption functions from households.gms.

module Households

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..InputOutput: vC
import ..Labor: vHhWages
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
  vFinAssets_al
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================

const HouseholdsTag = Tag(:Households)

@variables model :: (HouseholdsTag, ForecastConstant) begin
  rHhDebtLiabilities2Consumption[t], "Target household debt liability ratio relative to consumption."
  rHhDebtAdjustment[t], "Annual household debt adjustment rate."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[rHhDebtAdjustment] .= 0.2
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
    # Equity assets have no transactions.
    vFinAL[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T], 
    vFinTransactions[s,f,al,t] == 0

    # Debt liabilities move part of the way to a fixed share of consumption.
    vFinAL[s=[:Hh], f=[:Debt], al=[:Liab], t=t1:T], 
    vFinAL[s,f,al,t] == (1 - rHhDebtAdjustment[t]) * vFinAL[s,f,al,t-1]/fv
                          + (rHhDebtAdjustment[t] * rHhDebtLiabilities2Consumption[t] * vC[t])

    # Hh debt assets are residual given net financial assets.
    vFinAL[s=[:Hh], f=[:Debt], al=[:Assets], t=t1:T], 
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    rHhDebtLiabilities2Consumption[t1], vFinAL[:Hh,:Debt,:Liab,t1]
  end

  return block
end

end # module
