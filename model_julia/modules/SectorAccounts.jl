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
# Naming: sector-total variables have the simplest names. By-asset/liability
# disaggregations carry a "_al" suffix (index [sector,ass_liab,t]). 
#
# Other changes in volume (ESA K.1-K.6) are NOT modelled here; they are
# absorbed by the residual variables that @block creates automatically on
# each equation. The discrepancy between the non-financial accounts
# (B.9) and the financial accounts (B.9F), which is significant in data,
# is explicitly carried by jvNetTrans on the budget identity.
#
# ESA item → variable mapping: see SectorAccountsData.jl.

include(joinpath(@__DIR__, "SectorAccountsSettings.jl"))

module SectorAccounts

import JuMP
using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..SectorAccountsSettings: sector_accounts_data_dir
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero
# ==========================================================================
# Indices
# ==========================================================================
const sector         = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_sectors.csv"))
const fin_instrument = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_fin_instruments.csv"))  # Financial instrument categories (ESA F.*). Loop variable: f.
const ass_liab       = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_ass_liab.csv"))          # Asset / liability side (ESA finpos). Loop variable: al.
const SectorAccountsTag = Tag(:SectorAccounts)

# ==========================================================================
# Variables
# ==========================================================================
@variables db.model :: (SectorAccountsTag, GrowthAdjusted, InflationAdjusted) begin
  # ----- Financial side ---------------------------------------------------

  # -- Sector totals: net positions of stocks flows --
  vNetFinAssets[sector,t], "Net financial assets by sector (assets minus liabilities)."
  vNetFinTransactions[sector,t], "Net financial transactions by sector (B.9F): assets acquired minus liabilities incurred."
  vNetFinReval[sector,t], "Net revaluations of financial assets / liabilities by sector."
  vNetFinIncome[sector,t], "Net property income by sector (D.4 received minus paid)."
  vNetOtherChangesInVolume[sector,t], "Net other changes in volume of financial assets / liabilities by sector (ESA K.1–K.6, assets minus liabilities)."

  # -- By instrument and asset/liability side --
  vFinAL[sector,fin_instrument,ass_liab,t], "Financial assets (al=Assets) or liabilities (al=Liab) by sector and instrument."
  vFinReval[sector,fin_instrument,ass_liab,t], "Revaluation of financial assets or liabilities by sector, instrument, and side."
  vOtherChangesInVolume[sector,fin_instrument,ass_liab,t], "Other changes in volume of financial assets or liabilities by sector, instrument, and side (ESA K.1–K.6)."
  vFinIncome[sector,fin_instrument,ass_liab,t], "Property income received (ass_liab=Assets) or paid (ass_liab=Liab) by sector and instrument."

  # -- By asset/liability side, summed over instruments --
  vFinReval_al[sector,ass_liab,t], "Revaluation by sector and asset/liability, summed over instruments."
  vOtherChangesInVolume_al[sector,ass_liab,t], "Other changes in volume by sector and asset/liability, summed over instruments."
  vFinIncome_al[sector,ass_liab,t], "Property income by sector and asset/liability, summed over instruments."
  vFinAssets_al[sector,ass_liab,t], "Financial assets or liabilities by sector and asset/liability, summed over instruments."

  # ----- Interface variables filled by sector-specific modules ------------
  vGrossCapitalFormation[sector,t], "Gross capital formation (ESA P.5)."
  vNonFinancialNonProducedAssets[sector,t], "Net acquisitions of non-produced non-financial assets (ESA NP)."
  vNetTransfers2sector[sector,t], "Net current and capital transfers received by sector (D.5+D.6+D.7+D.8+D.9 net)."

  # Gov
  vGovBalance[t], "Government net lending / borrowing (B.9 from the government accounts module)."
  vGovPrimaryBalance[t], "Government primary balance (government balance minus property income)."
  # Hh
  vHhWages[t], "Compensation of employees received by households (ESA D.1). TODO: replace with vWages from IO-system."
  vHhConsumption[t], "Household final consumption (ESA P.3). TODO: replace with vC from IO-system."
  vCorrectionNonFinCorp2Hh[t], "Adjustment redistributing retained earnings of NonFinCorp to Hh (ESA D.422/D.72)."
  # Corp
  vGrossOpSurplusMixedIncome[sector,t], "Gross operating surplus and mixed income (ESA B.2g+B.3g). TODO: replace with B2A3G from vIO_a."
  # RoW
  vExports[t], "Total exports of goods and services (ESA P.6). TODO: replace with vX from IO-system."
  vImports[t], "Total imports of goods and services (ESA P.7). TODO: replace with vM from IO-system."
  vRoWPrimaryIncomeCurrentBalanceOther[t], "RoW primary and current income balance excluding D.4 net (D.1+D.2+D.3+D.5+D.6+D.7 net from RoW perspective)."

  # -- Other computed variables --
  vGoodsServicesBalance[t], "Goods and services balance: exports minus imports (ESA B.11 trade component)."
  vRoWPrimaryIncomeCurrentBalance[t], "RoW primary and current income balance (D.4 net plus other)."
end

# Residuals and deviations (forecast as zero / constant after calibration)
@variables db.model :: (SectorAccountsTag, GrowthAdjusted, InflationAdjusted, ForecastZero) begin
end

# ==========================================================================
# Data
# ==========================================================================
function set_data!(db; dir = sector_accounts_data_dir)
  vars_file = joinpath(dir, "sector_accounts_variables.csv")

  db[vFinIncome]                             .= read_variable(vars_file, vFinIncome, default = 0.0)
  db[vFinAL]                                 .= read_variable(vars_file, vFinAL; default = 0.0)

  # Financial assets and liabilities by side, summed over instruments.
  for s in sector, al in ass_liab, τ in t
    db[vFinAssets_al][s,al,τ] = sum(db[vFinAL][s,f,al,τ] for f in fin_instrument)
  end
  # Net financial assets: assets minus liabilities by sector.
  for s in sector, τ in t
    db[vNetFinAssets][s,τ] = db[vFinAssets_al][s,:Assets,τ] - db[vFinAssets_al][s,:Liab,τ]
  end

  db[vNetFinTransactions]                    .= read_variable(vars_file, vNetFinTransactions)
  db[vGrossCapitalFormation]                 .= read_variable(vars_file, vGrossCapitalFormation; default = 0.0)

  db[vExports]                               .= read_variable(vars_file, vExports)
  db[vImports]                               .= read_variable(vars_file, vImports)
  db[vRoWPrimaryIncomeCurrentBalanceOther]   .= read_variable(vars_file, vRoWPrimaryIncomeCurrentBalanceOther)
  db[vNonFinancialNonProducedAssets]         .= read_variable(vars_file, vNonFinancialNonProducedAssets)
  db[vHhConsumption]                         .= read_variable(vars_file, vHhConsumption)
  db[vHhWages]                               .= read_variable(vars_file, vHhWages)
  db[vCorrectionNonFinCorp2Hh]               .= read_variable(vars_file, vCorrectionNonFinCorp2Hh)
  db[vNetTransfers2sector]                   .= read_variable(vars_file, vNetTransfers2sector)
  db[vGrossOpSurplusMixedIncome]             .= read_variable(vars_file, vGrossOpSurplusMixedIncome)

  db[vFinReval]                              .= read_variable(vars_file, vFinReval; default = 0.0)
  db[vOtherChangesInVolume]                  .= read_variable(vars_file, vOtherChangesInVolume; default = 0.0)

  # Government balance is exogenous data for now, will be modelled later in the Government module.
  gov_vars_file = joinpath(@__DIR__, "..", "data", "government", "government_variables.csv")
  db[vGovBalance]                            .= read_variable(gov_vars_file, vGovBalance)


  return nothing
end

# ==========================================================================
# Starting values (solver hints, not exogenous data)
# ==========================================================================
function set_starting_values!(db)
end

# ==========================================================================
# Residuals allowed to exceed the global tolerance
# ==========================================================================
function set_residual_tolerances!(tolerances)
  tolerances[vNetFinAssets] = 20000.0
  tolerances[vNetFinTransactions] = 3.0
end

# ==========================================================================
# Equations
# ==========================================================================
function define_equations()
  return @block db begin
    vNetFinAssets[s=sector, t=t1:T],
    vNetFinAssets[s,t] == vNetFinAssets[s,t-1]/fv + vNetFinTransactions[s,t] + vNetFinReval[s,t] + vNetOtherChangesInVolume[s,t]

    # -- Government --
    vGovPrimaryBalance[t=t1:T],
    vGovPrimaryBalance[t] == vGovBalance[t] - vNetFinIncome[:Gov,t]

    vNetFinTransactions[s=[:Gov], t=t1:T],
    vNetFinTransactions[s,t] == vGovPrimaryBalance[t]
                          + vNetFinIncome[s,t]

    # -- Households --
    vNetFinTransactions[s=[:Hh], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                         + vNetTransfers2sector[s,t]
                         + vHhWages[t]                  # TO DO: replace with vWages from IO-system
                         - vHhConsumption[t]             # TO DO: replace with vC from IO-system
                         + vCorrectionNonFinCorp2Hh[t]
                         - vGrossCapitalFormation[s,t]
                         - vNonFinancialNonProducedAssets[s,t]

    # -- Financial corporations --
    vNetFinTransactions[s=[:FinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                              + vNetTransfers2sector[s,t]
                              - vGrossCapitalFormation[s,t]
                              - vNonFinancialNonProducedAssets[s,t]
                              + vGrossOpSurplusMixedIncome[s,t]  # TO DO: replace with B2A3G from vIO_a

    # -- Non-financial corporations --
    vNetFinTransactions[s=[:NonFinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]  # TO DO: replace with B2A3G from vIO_a
                                 - vCorrectionNonFinCorp2Hh[t]

    # -- Rest of World --
    vNetFinTransactions[s=[:RoW], t=t1:T],
    vNetFinTransactions[s,t] == - vGoodsServicesBalance[t]
                            + vRoWPrimaryIncomeCurrentBalance[t]
                            - vNonFinancialNonProducedAssets[s,t]

    # Goods and services balance (B.11 current account trade component).
    vGoodsServicesBalance[t=t1:T],
    vGoodsServicesBalance[t] == vExports[t] - vImports[t]  # TO DO: replace with vX[t] - vM[t] from IO-system

    # RoW primary and current income balance (D.4 net plus other current transfers).
    vRoWPrimaryIncomeCurrentBalance[t=t1:T],
    vRoWPrimaryIncomeCurrentBalance[t] == vNetFinIncome[:RoW,t]           # D.4 net
                                        + vRoWPrimaryIncomeCurrentBalanceOther[t]

    # Net property income by sector. RoW is the residual given net property income of other sectors.
    vNetFinIncome[s=filter(≠(:RoW), sector), t=t1:T],
    vNetFinIncome[s,t] == vFinIncome_al[s,:Assets,t] - vFinIncome_al[s,:Liab,t]

    vNetFinIncome[s=[:RoW], t=t1:T],
    vNetFinIncome[s,t] == -∑(vNetFinIncome[s2,t] for s2 in sector if s2 != :RoW)

    vFinIncome_al[s=sector, al=ass_liab, t=t1:T],
    vFinIncome_al[s,al,t] == ∑(vFinIncome[s,f,al,t]  for f in fin_instrument)

    # Net revaluation by sector and asset/liability side.
    vNetFinReval[s=sector, t=t1:T],
    vNetFinReval[s,t] == vFinReval_al[s,:Assets,t] - vFinReval_al[s,:Liab,t]

    vFinReval_al[s=sector, al=ass_liab, t=t1:T],
    vFinReval_al[s,al,t] == ∑(vFinReval[s,f,al,t]  for f in fin_instrument)

    # Net other changes in volume by sector and asset/liability side.
    vNetOtherChangesInVolume[s=sector, t=t1:T],
    vNetOtherChangesInVolume[s,t] == vOtherChangesInVolume_al[s,:Assets,t] - vOtherChangesInVolume_al[s,:Liab,t]

    vOtherChangesInVolume_al[s=sector, al=ass_liab, t=t1:T],
    vOtherChangesInVolume_al[s,al,t] == ∑(vOtherChangesInVolume[s,f,al,t]  for f in fin_instrument)

  end
end

# ==========================================================================
# Calibration
# ==========================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
  end

  return block
end

# ==========================================================================
# Tests
# ==========================================================================
# function run_tests(db)
#   atol = 1e-6
#   errors = String[]

#   # Sector-level totals must sum to zero: net lending, net income, and net revaluations
#   # are all zero-sum in a closed economy accounting system.
#   for v in (vNetFinAssets, vNetFinTransactions, vNetFinReval, vNetFinIncome)
#     totals = sum.(db[v[:, τ]] for τ in t1:T)
#     all(abs.(totals) .< atol) || push!(errors,
#       "SectorAccounts: $v does not sum to zero across sectors: $totals")
#   end

#   for v in (vNetFinAssets_f, vNetFinTransactions_f, vNetFinReval_f, vNetFinIncome_f)
#     for f in fin_instrument
#       totals = sum.(db[v[:, f, τ]] for τ in t1:T)
#       all(abs.(totals) .< atol) || push!(errors,
#         "SectorAccounts: $v[:,$f,:] does not sum to zero across sectors: $totals")
#     end
#   end

#   isempty(errors) || error(join(errors, "\n"))
#   return nothing
# end

end # module
