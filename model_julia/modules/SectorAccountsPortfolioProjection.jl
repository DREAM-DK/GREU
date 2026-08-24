# ==============================================================================
# Sector Portfolio Projection (Layer 2: balance-sheet dynamics)
# ==============================================================================
# Determines how each sector's financial assets and liabilities are projected,
# building on the pure accounting stock-flow identity in SectorAccounts.jl.
#
# For each sector the block has:
#   - behavioural equations for all but one vFinAL[s,f,al,t] component, and
#   - one closing equation that pins the residual component through the net
#     financial assets identity (vNetFinAssets == vNetDebt + vNetEquity).
#
# Portfolio ratios (r-variables) are dimensionless and tagged ForecastConstant:
# calibration solves for their t1 values; the forecast holds them fixed.
#
# NonFinCorp debt equations reference vNonFinCorpExpenses and vNonFinCorpCapital,
# declared as interface variables here and filled by zero until the IO module is
# connected (TO DO).
#
# Note: vFinAL[:Hh,:Equity,:Liab,t] has no portfolio equation and remains
# exogenous — household equity liabilities are negligible in practice.

include(joinpath(@__DIR__, "SectorAccountsSettings.jl"))

module SectorAccountsPortfolioProjection

import JuMP
using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..SectorAccountsSettings: sector_accounts_data_dir
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant
import ..SectorAccounts: sector, fin_instrument, ass_liab,
  vFinAL, vNetFinAssets, vFinAssets_al, vFinTransactions

# ==========================================================================
# Indices
# ==========================================================================
const SectorAccountsPortfolioProjectionTag = Tag(:SectorAccountsPortfolioProjection)

# ==========================================================================
# Variables
# ==========================================================================
@variables model :: (SectorAccountsPortfolioProjectionTag, GrowthAdjusted, InflationAdjusted) begin
  # -- By-instrument net positions --
  vNetDebtInstruments[sector,t], "Net debt instruments by sector (debt assets minus debt liabilities)."
  vNetEquity[sector,t], "Net equity by sector (equity assets minus equity liabilities)."

  # -- Interface variables for NonFinCorp IO-module linkage --
  vNonFinCorpExpenses[t], "NonFinCorp total expenses (wages + depreciation + user cost of capital). Filled by IO module."
  vNonFinCorpCapital[t], "NonFinCorp total capital stock. Filled by IO module."
end

# Portfolio ratios (dimensionless; no growth or inflation adjustment; constant in forecast)
@variables model :: (SectorAccountsPortfolioProjectionTag, ForecastConstant) begin
  rFinCorpDebtAssets2DomesticDebtLiabilities[t], "FinCorp debt asset ratio: debt assets relative to domestic debt liabilities of Hh, NonFinCorp, and Gov."
  rFinCorpDebtLiabilities2EquityLiabilities[t], "FinCorp capital structure: debt liabilities relative to own equity liabilities."
  rNonFinCorpEquityAssets2EquityLiabilities[t], "NonFinCorp equity asset ratio: equity assets relative to own equity liabilities."
  rNonFinCorpDebtAssets2Expenses[t], "NonFinCorp debt asset ratio: debt assets relative to total expenses."
  rNonFinCorpDebtLiabilities2Capital[t], "NonFinCorp debt liability ratio: debt liabilities relative to total capital stock."
  rRoWDebtAssets2TotalDebtLiabilities[t], "RoW debt asset ratio: RoW debt assets relative to total domestic debt liabilities."
  rRoWEquityAssets2DomesticEquityLiabilities[t], "RoW equity asset ratio: RoW equity assets relative to domestic equity liabilities of Hh and NonFinCorp."
end

# ==========================================================================
# Data
# ==========================================================================
function set_data!(db; dir = sector_accounts_data_dir)
  # By-instrument net positions derived from balance-sheet data (vFinAL set by SectorAccounts).
  for s in sector, τ in t
    db[vNetDebtInstruments][s,τ] = db[vFinAL][s,:Debt,:Assets,τ] - db[vFinAL][s,:Debt,:Liab,τ]
    db[vNetEquity][s,τ]          = db[vFinAL][s,:Equity,:Assets,τ] - db[vFinAL][s,:Equity,:Liab,τ]
  end

  # IO-module interface: filled by IO module; zeros here until IO is connected.
  db[vNonFinCorpExpenses]  .= 10000.0
  db[vNonFinCorpCapital]   .= 5000.0

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
  return @block model begin
    # ------------------------------------------------------------------------------------------
    # -- Projections of financial transctions by sector, instrument, and asset/liability side --
    # ------------------------------------------------------------------------------------------

    # -- Government --
    # Gov neither buys nor sells equity; both equity positions follow revaluation only.
    vFinAL[s=[:Gov], f=[:Equity], al=ass_liab, t=t1:T], 
    vFinTransactions[s,f,al,t] == 0
    # Gov keeps a constant level of debt instruments; assets follow revaluation only.
    vFinAL[s=[:Gov], f=[:Debt], al=[:Assets], t=t1:T], 
    vFinTransactions[s,f,al,t] == 0

    # Gov debt liabilities are residual given net financial assets.
    vFinAL[s=[:Gov], f=[:Debt], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]
    
    # -- Households --
    # Equity assets and debt liabilities follow revaluation.
    vFinAL[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T], 
    vFinTransactions[s,f,al,t] == 0

    vFinAL[s=[:Hh], f=[:Debt], al=[:Liab], t=t1:T], 
    vFinTransactions[s,f,al,t] == 0

    # Hh debt assets are residual given net financial assets.
    vFinAL[s=[:Hh], f=[:Debt], al=[:Assets], t=t1:T], 
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]

    # -- Financial corporations --
    # Equity assets follow revaluation.
    vFinAL[s=[:FinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinTransactions[s,f,al,t] == 0

    # Debt assets are a fixed fraction of the aggregate debt liabilities of domestic sectors.
    vFinAL[s=[:FinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rFinCorpDebtAssets2DomesticDebtLiabilities[t] * ∑(vFinAL[s2,:Debt,:Liab,t] for s2 in sector if s2 in (:Hh, :NonFinCorp, :Gov))

    # Debt liabilities are a fixed fraction of equity liabilities (shareholder equity).
    vFinAL[s=[:FinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinAL[s,f,al,t] == rFinCorpDebtLiabilities2EquityLiabilities[t] * vFinAL[:FinCorp,:Equity,:Liab,t]

    # Equity liabilities are residual given net financial assets.
    vFinAL[s=[:FinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]

    # -- Non-financial corporations --
    # Equity assets are a fixed fraction of equity liabilities.
    vFinAL[s=[:NonFinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpEquityAssets2EquityLiabilities[t] * vFinAL[:NonFinCorp,:Equity,:Liab,t]

    # Debt assets are a fixed fraction of total expenses (wages + depreciation + user cost of capital).
    # TODO: replace vNonFinCorpExpenses with sum over IO industries once the IO module is connected.
    vFinAL[s=[:NonFinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpDebtAssets2Expenses[t] * vNonFinCorpExpenses[t]

    # Debt liabilities are a fixed fraction of total capital.
    # TODO: replace vNonFinCorpCapital with sum over IO capital types once the IO module is connected.
    vFinAL[s=[:NonFinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpDebtLiabilities2Capital[t] * vNonFinCorpCapital[t]

    # Equity liabilities are residual given net financial assets.
    vFinAL[s=[:NonFinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]

    # -- Rest of World -- 
    # Debt assets are a fixed fraction of total domestic debt liabilities.
    vFinAL[s=[:RoW], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rRoWDebtAssets2TotalDebtLiabilities[t] * ∑(vFinAL[s2,:Debt,:Liab,t] for s2 in sector if s2 != :RoW)

    # Debt liabilities: residual so that net debt instruments sum to zero across sectors.
    vFinAL[s=[:RoW], f=[:Debt], al=[:Liab], t=t1:T],
    ∑(vFinAL[s,:Debt,:Assets,t] for s in sector) == ∑(vFinAL[s,:Debt,:Liab,t] for s in sector)
    
    # Equity assets are a fixed fraction of domestic equity liabilities (Hh and NonFinCorp).
    vFinAL[s=[:RoW], f=[:Equity], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rRoWEquityAssets2DomesticEquityLiabilities[t] * ∑(vFinAL[s2,:Equity,:Liab,t] for s2 in sector if s2 in (:Hh, :NonFinCorp))

    # Debt liabilities: residual so that net debt instruments sum to zero across sectors.
    vFinAL[s=[:RoW], f=[:Equity], al=[:Liab], t=t1:T],
    ∑(vFinAL[s,:Equity,:Assets,t] for s in sector) == ∑(vFinAL[s,:Equity,:Liab,t] for s in sector)


  end
end

# ==========================================================================
# Calibration
# ==========================================================================
function define_calibration()
  block = define_equations()

  # At t1, swap each rate endogenous and the corresponding vFinAL cell exogenous,
  # so calibration solves for the ratio implied by observed balance-sheet data.
  @endo_exo_swap! block begin
    rFinCorpDebtAssets2DomesticDebtLiabilities[t1],    vFinAL[:FinCorp,:Debt,:Assets,t1]
    rFinCorpDebtLiabilities2EquityLiabilities[t1],     vFinAL[:FinCorp,:Debt,:Liab,t1]
    rNonFinCorpEquityAssets2EquityLiabilities[t1],     vFinAL[:NonFinCorp,:Equity,:Assets,t1]
    rNonFinCorpDebtAssets2Expenses[t1],                vFinAL[:NonFinCorp,:Debt,:Assets,t1]
    rNonFinCorpDebtLiabilities2Capital[t1],            vFinAL[:NonFinCorp,:Debt,:Liab,t1]
    rRoWDebtAssets2TotalDebtLiabilities[t1],           vFinAL[:RoW,:Debt,:Assets,t1]
    rRoWEquityAssets2DomesticEquityLiabilities[t1],    vFinAL[:RoW,:Equity,:Assets,t1]
  end

  return block
end

end # module
