# ==============================================================================
# Sector Accounts (Layer 1: pure accounting)
# ==============================================================================
# Mirrors the ESA 2010 institutional sector accounts: the non-financial side
# (primary income, distributive transactions, transfers, consumption, capital
# formation -> B.9) together with the financial side (balance sheets,
# financial transactions, revaluations -> B.9F).
#
# This module is intentionally behaviour-free. All "rates" (interest rate,
# dividend rate, revaluation rate, portfolio shares, capital structure) live in
# a separate behavioural layer on top of this one. Layer 1 only declares
# accounting variables and identities, plus interface variables that the
# sector-specific modules (Households, Government, NonFinCorp, FinCorp,
# RestOfWorld) fill in.
#
# Property income and revaluations follow the mechanical structure of
# financial_accounts.gms (vNetInterests / vNetDividends / vNetRevaluations and
# their zero-sum across sectors), mapped to instruments f=Debt and f=Equity.
# There are no rate-on-stock equations here; those belong in the behavioural layer.
#
# Monetary gold (F.1) is excluded from the instrument set since gold bullion
# has no liability counterparty and cannot fit a closed sector accounting
# system.
#
# Naming: sector-total variables have the simplest names. By-instrument
# disaggregations carry a "_f" suffix (index [s,f,t]). The asset/liability
# distinction is carried by the "al" index at the finest level [s,f,al,t].
#
# Other changes in volume (ESA K.1-K.6) are NOT modelled here; they are
# absorbed by the residual variables that @block creates automatically on
# each equation. The discrepancy between the non-financial accounts
# (B.9) and the financial accounts (B.9F), which is significant in data,
# is explicitly carried by jvNetTrans on the budget identity.

module SectorAccounts

import JuMP
using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ==========================================================================
# Indices
# ==========================================================================
const sector = [:FinCorp, :NonFinCorp, :Gov, :Hh, :RoW]
const F = [:Equity, :Debt] # Financial instrument categories (ESA F.*, aggregated). Loop variable: f.
const AL = [:Assets, :Liab] # Asset/liability side (ESA finpos). Loop variable: al.
const SectorAccountsTag = Tag(:SectorAccounts)

# ==========================================================================
# Variables
# ==========================================================================
@variables db.model :: (SectorAccountsTag, GrowthAdjusted, InflationAdjusted) begin
  # ----- Financial side ---------------------------------------------------

  # -- Sector totals: stocks, flows, and net positions --
  vNetFinAssets[sector,t], "Net financial assets by sector (assets minus liabilities)."
  vNetFinTrans[sector,t], "Net financial transactions by sector (B.9F): assets acquired minus liabilities incurred."
  vNetFinReval[sector,t], "Net revaluations of financial assets / liabilities by sector."

  # -- By instrument; _f disaggregation of vNetFin* --
  vNetFinAssets_f[sector,F,t], "Net financial assets by sector and instrument."
  vNetFinTrans_f[sector,F,t], "Net financial transactions by sector and instrument."
  vNetFinReval_f[sector,F,t], "Net revaluation of financial assets / liabilities by sector and instrument."
  vNetFinIncome_f[sector,F,t], "Net property income by sector and instrument."

  # -- By instrument and asset/liability side --
  vFinAL[sector,F,AL,t], "Financial assets (al=Assets) or liabilities (al=Liab) by sector and instrument."
  vFinTrans[sector,F,AL,t], "Financial transactions by sector, instrument, and side."
  vFinReval[sector,F,AL,t], "Revaluation of financial assets or liabilities by sector, instrument, and side."

  # ----- Non-financial side -----------------------------------------------

  # -- Property income (ESA D.4: D.41 interest + D.42+D.43 distributed income) --
  # f=Debt: interest (D.41); f=Equity: distributed income of corporations (D.42–D.43).
  vNetFinIncome[sector,t], "Net property income by sector (received minus paid)."
  # al=Assets: received (resource); al=Liab: paid (use).
  vFinIncome[sector,F,AL,t], "Property income received (al=Assets) or paid (al=Liab) by sector and instrument (ESA D.4)."

  # -- Sector budget components (interface variables, defined by sector modules) --
  vPrimaryIncome[sector,t], "Primary income excl. property income. For RoW: imports minus exports (net trade flow to RoW)."
  vNetTransfers[sector,t], "Net transfers received: current (D.5+D.6+D.7) plus capital (D.9), all received minus paid."
  vFinalConsumption[sector,t], "Final consumption expenditure (ESA P.3). Nonzero only for households and government."
  vGrossCapitalFormation[sector,t], "Gross capital formation and acquisitions less disposals of non-produced assets (ESA P.5 + NP). Zero for RoW."
end

@variables db.model :: (SectorAccountsTag) begin
  rFinIncome[sector,F,AL,t], "Property income rate by sector, instrument, and side."
  rFinReval[sector,F,AL,t], "Revaluation rate by sector, instrument, and side."
  rNetFinIncome_f[F,t], "Net property income rate by instrument (interest rate for Debt, dividend rate for Equity)."
  rNetFinReval_f[F,t], "Net revaluation rate by instrument."

end

# Residual on the sector budget identity. Forecast as zero, but in data
# it absorbs the discrepancy between national accounts incomes (B.9) and
# financial accounts net transactions (B.9F), which is significant.
@variables db.model :: (SectorAccountsTag, GrowthAdjusted, InflationAdjusted, ForecastConstant) begin
  jvNetTrans[sector,t], "Residual closing the non-financial / financial accounts gap (B.9 vs B.9F)."
  jrFinIncome[sector,F,AL,t], "Deviation from mean property income rate by sector, instrument, and side."
  jrFinReval[sector,F,AL,t], "Deviation from mean revaluation rate by sector, instrument, and side."
end

# ==========================================================================
# Equations
# ==========================================================================
function define_equations()
  return @block db begin
    # End-of-year stock = previous stock + transactions + revaluations.
    # Other changes in volume (K.1-K.6) are not modelled and fall into the residual in data years.
    vNetFinAssets[s=sector, t=t1:T],
    vNetFinAssets[s,t] == vNetFinAssets[s,t-1]/fv + vNetFinTrans[s,t] + vNetFinReval[s,t]

    # ----- Non-financial / financial closure (B.9 = B.9F) ---------------
    # vNetFinTrans (B.9F, financial-accounts net lending) is here equated to
    # the budget identity (B.9). jvNetTrans absorbs the data discrepancy between the two sides;
    # it is forecast as zero, but nonzero in historical data.
    vNetFinTrans[s=sector, t=t1:T],
    vNetFinTrans[s,t] == vPrimaryIncome[s,t]
                       + vNetFinIncome[s,t]
                       + vNetTransfers[s,t]
                       - vFinalConsumption[s,t]
                       - vGrossCapitalFormation[s,t]
                       + jvNetTrans[s,t]

    vNetFinIncome[s=sector, t=t1:T],
    vNetFinIncome[s,t] == ∑(vNetFinIncome_f[s,f,t] for f in F)

    vNetFinReval[s=sector, t=t1:T],
    vNetFinReval[s,t] == ∑(vNetFinReval_f[s,f,t] for f in F)

    # -- By instrument --
    vNetFinAssets_f[s=sector, f=F, t=t1:T],
    vNetFinAssets_f[s,f,t] == vNetFinAssets_f[s,f,t-1]/fv + vNetFinTrans_f[s,f,t] + vNetFinReval_f[s,f,t]

    # -- Financial income and revaluations --
    vNetFinIncome[s=sector, f=F, t=t1:T],
    vNetFinIncome[s,f,t] == rNetFinIncome_f[f,t] * vNetFinAL[s,f,t-1]/fv

    vNetFinReval[s=sector, f=F, t=t1:T],
    vNetFinReval[s,f,t] == rNetFinReval_f[f,t] * vNetFinAL[s,f,t-1]/fv

    # -- Sector portfolios --
    # We assume that the government neither sells nor buys equity
    # vNetFinTrans_f[:Gov,:Equity,t] == 0

    #

    # # -- Gross assets and liabilities --
    # vNetFinTrans_f[s=sector, f=F, t=t1:T],
    # vNetFinTrans_f[s,f,t] == vFinTrans[s,f,:Assets,t] - vFinTrans[s,f,:Liab,t]

    # vNetFinReval_f[s=sector, f=F, t=t1:T],
    # vNetFinReval_f[s,f,t] == vFinReval[s,f,:Assets,t] - vFinReval[s,f,:Liab,t]

    # vNetFinIncome_f[s=sector, f=F, t=t1:T],
    # vNetFinIncome_f[s,f,t] == vFinIncome[s,f,:Assets,t] - vFinIncome[s,f,:Liab,t]

    # vFinAL[s=sector, f=F, al=AL, t=t1:T],
    # vFinAL[s,f,al,t] == vFinAL[s,f,al,t-1]/fv + vFinTrans[s,f,al,t] + vFinReval[s,f,al,t]

    # vFinIncome[s=sector, f=F, al=AL, t=t1:T],
    # vFinIncome[s,f,al,t] == rFinIncome[s,f,al,t] * vFinAL[s,f,al,t-1]/fv

    # vFinReval[s=sector, f=F, al=AL, t=t1:T],
    # vFinReval[s,f,al,t] == rFinReval[s,f,al,t] * vFinAL[s,f,al,t-1]/fv

    # rFinIncome[s=sector, f=F, al=AL, t=t1:T],
    # rFinIncome[s,f,al,t] == rNetFinIncome_f[f,t] + jrFinIncome[s,f,al,t]

    # rFinReval[s=sector, f=F, al=AL, t=t1:T],
    # rFinReval[s,f,al,t] == rNetFinReval_f[f,t] + jrFinReval[s,f,al,t]
  end
end

# ==========================================================================
# Tests
# ==========================================================================
function run_tests(db)
  atol = 1e-6
  errors = String[]

  for v in (vNetFinAssets, vNetFinTrans, vNetFinReval, vNetFinIncome)
    totals = sum.(db[v[:, τ]] for τ in t1:T)
    all(abs.(totals) .< atol) || push!(errors, "SectorAccounts: $v does not sum to zero across sectors: $totals")
  end

  for v in (vFinAL, vFinTrans, vFinReval, vFinIncome)
    diff = sum.(db[v[:, f, :Assets, τ]] for f in F, τ in t1:T) .- sum.(db[v[:, f, :Liab, τ]] for f in F, τ in t1:T)
    all(abs.(diff) .< atol) || push!(errors, "SectorAccounts: $v assets ≠ liabilities: $diff")
  end

  for v in (vNetFinAssets_f, vNetFinTrans_f, vNetFinReval_f, vNetFinIncome_f)
    totals = sum.(db[v[:, f, τ]] for f in F, τ in t1:T)
    all(abs.(totals) .< atol) || push!(errors, "SectorAccounts: $v does not sum to zero across sectors: $totals")
  end

  isempty(errors) || error(join(errors, "\n"))
  return nothing
end

end # module
