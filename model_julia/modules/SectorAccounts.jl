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
import ..SectorAccountsSettings: sector_accounts_data_dir, cell_tolerance
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero
import ..InputOutput: vW, vC, vX, vM
import ..Settings: calibration_year
# ==========================================================================
# Indices
# ==========================================================================
const sector         = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_sectors.csv"))
const fin_instrument = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_fin_instruments.csv"))  # Financial instrument categories (ESA F.*). Loop variable: f.
const ass_liab       = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_ass_liab.csv"))          # Asset / liability side (ESA finpos). Loop variable: al.

# ============================================================================
# Checked-in benchmark data
# ============================================================================

const sector_accounts_file = joinpath(sector_accounts_data_dir, "sector_accounts.csv")
const gov_file = joinpath(@__DIR__, "..", "data", "government", "government_variables.csv")

"""Read one variable from a checked-in file into a dictionary keyed by index tuple."""
function read_cells(file, variable)
  data = read_sparse_array(file; variable)
  cells = Dict(key => data[key...] for key in eachindex(data))
  @assert all(isfinite, values(cells)) "$variable in $file must be finite"
  return cells
end

"""Calibration-year value of one cell. Cells the source does not report are zero."""
calibration_year_value(cells, index...) = get(cells, (index..., calibration_year), 0.0)

"""JuMP dense keys are `DenseAxisArrayKey`; sparse keys are already tuples."""
cell_key(key::Tuple) = key
cell_key(key) = key.I

"""Copy checked-in cells into a model variable. Years the file omits stay `nothing`."""
fill_cells!(db, var, cells) = db[var] .= [get(cells, cell_key(key), nothing) for key in keys(var)]

"""Read one time series for a one-dimensional variable view."""
function read_series(file, variable)
  cells = read_cells(file, variable)
  return [get(cells, (tt,), nothing) for tt in t]
end

const vFinIncome_data                           = read_cells(sector_accounts_file, "vFinIncome")
const vFinAL_data                               = read_cells(sector_accounts_file, "vFinAL")
const vFinTransactions_data                     = read_cells(sector_accounts_file, "vFinTransactions")
const vFinAssets_al_data                        = read_cells(sector_accounts_file, "vFinAssets")
const vNetFinTransactions_data                  = read_cells(sector_accounts_file, "vNetFinTransactions")
const vGrossCapitalFormation_data               = read_cells(sector_accounts_file, "vGrossCapitalFormation")
const vExports_data                             = read_cells(sector_accounts_file, "vExports")
const vImports_data                             = read_cells(sector_accounts_file, "vImports")
const vRoWPrimaryIncomeCurrentBalanceOther_data = read_cells(sector_accounts_file, "vRoWPrimaryIncomeCurrentBalanceOther")
const vRoWNetWages_data                         = read_cells(sector_accounts_file, "vRoWNetWages")
const vNonFinancialNonProducedAssets_data       = read_cells(sector_accounts_file, "vNonFinancialNonProducedAssets")
const vCorrectionNonFinCorp2Hh_data             = read_cells(sector_accounts_file, "vCorrectionNonFinCorp2Hh")
const vNetTransfers2sector_data                 = read_cells(sector_accounts_file, "vNetTransfers2sector")
const vGrossOpSurplusMixedIncome_data           = read_cells(sector_accounts_file, "vGrossOpSurplusMixedIncome")
const vFinReval_data                            = read_cells(sector_accounts_file, "vFinReval")
const vOtherChangesInVolume_data                = read_cells(sector_accounts_file, "vOtherChangesInVolume")
const vGovBalance_data                          = read_cells(gov_file, "vGovBalance")

# ============================================================================
# Cell masks
# ============================================================================
# Each mask is named after the indices it holds. Cells outside a mask have no
# variable and no equation, so a mask change needs a model rebuild.

"""Indices with a non-negligible calibration-year value. The last index is the year."""
calibration_year_indices(cells) = Set(
  key[1:(end - 1)]
  for (key, value) in cells
  if key[end] == calibration_year && abs(value) > cell_tolerance
)

const fin_income_s_f_al                    = calibration_year_indices(vFinIncome_data)
const fin_al_s_f_al                        = calibration_year_indices(vFinAL_data)
const fin_transactions_s_f_al              = calibration_year_indices(vFinTransactions_data)
const fin_reval_s_f_al                     = calibration_year_indices(vFinReval_data)
const other_changes_in_volume_s_f_al       = calibration_year_indices(vOtherChangesInVolume_data)
const fin_assets_s_al                      = calibration_year_indices(vFinAssets_al_data)
const net_fin_transactions_s               = calibration_year_indices(vNetFinTransactions_data)
const gross_capital_formation_s            = calibration_year_indices(vGrossCapitalFormation_data)
const non_financial_non_produced_assets_s  = calibration_year_indices(vNonFinancialNonProducedAssets_data)
const net_transfers_2sector_s              = calibration_year_indices(vNetTransfers2sector_data)
const gross_op_surplus_mixed_income_s      = calibration_year_indices(vGrossOpSurplusMixedIncome_data)

# ==========================================================================
# Variables
# ==========================================================================

const SectorAccountsTag = Tag(:SectorAccounts)

@variables db.model :: (SectorAccountsTag, GrowthAdjusted, InflationAdjusted) begin
  # ----- Financial side ---------------------------------------------------

  # -- Sector totals: net positions of stocks flows --
  vNetFinAssets[s=sector,t=t], "Net financial assets by sector (assets minus liabilities)."
  vNetFinTransactions[s = sector, t = t], "Net financial transactions by sector (B.9F): assets acquired minus liabilities incurred."
  vNetFinReval[s=sector,t=t], "Net revaluations of financial assets / liabilities by sector."
  vNetFinIncome[s=sector,t=t], "Net property income by sector (D.4 received minus paid)."
  vNetOtherChangesInVolume[s=sector,t=t], "Net other changes in volume of financial assets / liabilities by sector (ESA K.1–K.6, assets minus liabilities)."

  # -- By instrument and asset/liability side --
  vFinAL[s = sector, f = fin_instrument, al = ass_liab, t = t; (s, f, al) in fin_al_s_f_al], "Financial assets (al=Assets) or liabilities (al=Liab) by sector and instrument."
  vFinTransactions[(s, f, al, t) = vFinAL], "Financial transactions by sector, instrument, and asset/liability side."
  vFinReval[(s, f, al, t) = vFinAL], "Revaluation of financial assets or liabilities by sector, instrument, and side."
  vOtherChangesInVolume[(s, f, al, t) = vFinAL], "Other changes in volume of financial assets or liabilities by sector, instrument, and side (ESA K.1–K.6)."
  vFinIncome[(s, f, al, t) = vFinAL], "Property income received (ass_liab=Assets) or paid (ass_liab=Liab) by sector and instrument."

  # -- By asset/liability side, summed over instruments --
  vFinTransactions_al[sector,ass_liab,t], "Financial transactions by sector and asset/liability, summed over instruments."
  vFinReval_al[sector,ass_liab,t], "Revaluation by sector and asset/liability, summed over instruments."
  vOtherChangesInVolume_al[sector,ass_liab,t], "Other changes in volume by sector and asset/liability, summed over instruments."
  vFinIncome_al[sector,ass_liab,t], "Property income by sector and asset/liability, summed over instruments."
  vFinAssets_al[s = sector, al = ass_liab, t = t], "Financial assets or liabilities by sector and asset/liability, summed over instruments."

  # ----- Interface variables filled by sector-specific modules ------------
  vGrossCapitalFormation[s = sector, t = t], "Gross capital formation (ESA P.5)."
  vNonFinancialNonProducedAssets[s = sector, t = t], "Net acquisitions of non-produced non-financial assets (ESA NP)."
  vNetTransfers2sector[s = sector, t = t], "Net current and capital transfers received by sector (D.5+D.6+D.7+D.8+D.9 net)."

  # Gov
  vGovBalance[t], "Government net lending / borrowing (B.9 from the government accounts module)."
  vGovPrimaryBalance[t], "Government primary balance (government balance minus property income)."
  # Hh
  vCorrectionNonFinCorp2Hh[t], "Adjustment redistributing retained earnings of NonFinCorp to Hh (ESA D.422/D.72)."
  # Corp
  vGrossOpSurplusMixedIncome[s = sector, t = t], "Gross operating surplus and mixed income (ESA B.2g+B.3g). TODO: replace with B2A3G from vIO_a."
  # RoW
  vExports[t], "Total exports of goods and services (ESA P.6). TODO: replace with vX from IO-system."
  vImports[t], "Total imports of goods and services (ESA P.7). TODO: replace with vM from IO-system."
  vRoWPrimaryIncomeCurrentBalanceOther[t], "RoW primary and current income balance excluding D.4 net (D.1+D.2+D.3+D.5+D.6+D.7 net from RoW perspective)."

  # -- Other computed variables --
  vGoodsServicesBalance[t], "Goods and services balance: exports minus imports (ESA B.11 trade component)."
  vRoWPrimaryIncomeCurrentBalance[t], "RoW primary and current income balance (D.4 net plus other)."

  # --Move to LaborMarket.jl --
  vRoWNetWages[t], "RoW net wages (D.1 net from RoW perspective)."
  vHhWages[t], "Household net wages (D.1 net from Hh perspective)."
end

# ==========================================================================
# Data
# ==========================================================================
function set_data!(db)
  fill_cells!(db, vFinIncome, vFinIncome_data)
  fill_cells!(db, vFinAL, vFinAL_data)
  fill_cells!(db, vFinTransactions, vFinTransactions_data)
  fill_cells!(db, vFinAssets_al, vFinAssets_al_data)
  fill_cells!(db, vNetFinTransactions, vNetFinTransactions_data)
  fill_cells!(db, vGrossCapitalFormation, vGrossCapitalFormation_data)
  fill_cells!(db, vExports, vExports_data)
  fill_cells!(db, vImports, vImports_data)
  fill_cells!(db, vRoWPrimaryIncomeCurrentBalanceOther, vRoWPrimaryIncomeCurrentBalanceOther_data)
  fill_cells!(db, vRoWNetWages, vRoWNetWages_data)
  fill_cells!(db, vNonFinancialNonProducedAssets, vNonFinancialNonProducedAssets_data)
  fill_cells!(db, vCorrectionNonFinCorp2Hh, vCorrectionNonFinCorp2Hh_data)
  fill_cells!(db, vNetTransfers2sector, vNetTransfers2sector_data)
  fill_cells!(db, vGrossOpSurplusMixedIncome, vGrossOpSurplusMixedIncome_data)
  fill_cells!(db, vFinReval, vFinReval_data)
  fill_cells!(db, vOtherChangesInVolume, vOtherChangesInVolume_data)
  # Government balance is exogenous data for now, will be modelled later in the Government module.
  fill_cells!(db, vGovBalance, vGovBalance_data)

  # Net financial assets: assets minus liabilities by sector.
  for s in sector, τ in t
    a = db[vFinAssets_al][s,:Assets,τ]
    l = db[vFinAssets_al][s,:Liab,τ]
    (a === nothing || l === nothing) && continue
    db[vNetFinAssets][s,τ] = a - l
  end

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
  tolerances[vNetFinAssets] = 250000.0 # Discrepancy in data on sector-level between change in vNetFinAssets and the sum of net financial transactions, revaluations, and other changes in volume.
  tolerances[vNetFinTransactions] = 250000.0 # Small discrepancies between data sources and rounding errors.
  tolerances[vFinAL] = 1000000.0 
  tolerances[vFinTransactions] = 1000000.0
end

# ==========================================================================
# Equations
# ==========================================================================
function define_equations()
  return @block db begin

    # ----------------------------
    # -- Move to LaborMarket.jl --
    # ----------------------------

    vHhWages[t=t1:T],
    vW[t] == vRoWNetWages[t] + vHhWages[t]

    # ----------------------------
    # -- Financial transactions --
    # ----------------------------

    vFinTransactions[s=sector, f=fin_instrument, al=ass_liab, t=t1:T; (s, f, al) in keys(vFinTransactions)],
    vFinAL[s,f,al,t] == vFinAL[s,f,al,t-1]/fv + vFinTransactions[s,f,al,t] + vFinReval[s,f,al,t] + vOtherChangesInVolume[s,f,al,t]

    # -----------------------------------------------------------------------
    # -- Net positions of stocks flows: assets minus liabilities by sector --
    # -----------------------------------------------------------------------

    vNetFinAssets[s=sector, t=t1:T],
    vNetFinAssets[s,t] == vNetFinAssets[s,t-1]/fv + vNetFinTransactions[s,t] + vNetFinReval[s,t] + vNetOtherChangesInVolume[s,t]

    # @test_constraint "Aggregating financial instruments" vNetFinAssets[s=sector, t=t1:T],
    # vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]

    @test_constraint("Summing vNetFinAssets over sectors"; atol=1.0, rtol=1e-6)
    vNetFinAssets[s=[:Hh], t=t1:T],
    ∑(vNetFinAssets[s,t] for s in sector) == 0.0

    # -- Government --
    vGovPrimaryBalance[t=t1:T],
    vGovPrimaryBalance[t] == vGovBalance[t] - vNetFinIncome[:Gov,t]

    vNetFinTransactions[s=[:Gov], t=t1:T; (s,) in net_fin_transactions_s],
    vNetFinTransactions[s,t] == vGovPrimaryBalance[t]
                          + vNetFinIncome[s,t]

    # -- Households --
    vNetFinTransactions[s=[:Hh], t=t1:T; (s,) in net_fin_transactions_s],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                         + vNetTransfers2sector[s,t]
                         + vHhWages[t] 
                         - vC[t]
                         + vCorrectionNonFinCorp2Hh[t]
                         - vGrossCapitalFormation[s,t]
                         - vNonFinancialNonProducedAssets[s,t]

    # -- Financial corporations --
    vNetFinTransactions[s=[:FinCorp], t=t1:T; (s,) in net_fin_transactions_s],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                              + vNetTransfers2sector[s,t]
                              - vGrossCapitalFormation[s,t]
                              - vNonFinancialNonProducedAssets[s,t]
                              + vGrossOpSurplusMixedIncome[s,t]  # TO DO: replace with B2A3G from vIO_a

    # -- Non-financial corporations --
    vNetFinTransactions[s=[:NonFinCorp], t=t1:T; (s,) in net_fin_transactions_s],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]  # TO DO: replace with B2A3G from vIO_a
                                 - vCorrectionNonFinCorp2Hh[t]

    # -- Rest of World --
    vNetFinTransactions[s=[:RoW], t=t1:T; (s,) in net_fin_transactions_s],
    vNetFinTransactions[s,t] == vGoodsServicesBalance[t]
                            + vRoWPrimaryIncomeCurrentBalance[t]
                            - vNonFinancialNonProducedAssets[s,t]

    # Goods and services balance (B.11 current account trade component).
    vGoodsServicesBalance[t=t1:T],
    vGoodsServicesBalance[t] == vX[t] - vM[t] 

    # RoW primary and current income balance (D.4 net plus other current transfers).
    vRoWPrimaryIncomeCurrentBalance[t=t1:T],
    vRoWPrimaryIncomeCurrentBalance[t] == vNetFinIncome[:RoW,t]           # D.4 net
                                        + vRoWPrimaryIncomeCurrentBalanceOther[t]

    @test_constraint "Summing vNetFinTransactions over sectors" vNetFinTransactions[s=[:Hh], t=t1:T; (s,) in net_fin_transactions_s],
    ∑(vNetFinTransactions[s,t] for s in sector) == 0.0

    # ---------------------
    # -- Aggregating ... --
    # ---------------------

    vFinTransactions_al[s=sector, al=ass_liab, t=t1:T],
    vFinTransactions_al[s,al,t] == ∑(vFinTransactions[s,f,al,t]  for f in fin_instrument)

    vFinAssets_al[s=sector, al=ass_liab, t=t1:T],
    vFinAssets_al[s,al,t] == ∑(vFinAL[s,f,al,t]  for f in fin_instrument)

    @test_constraint "Summing vNetFinTransactions over sectors" vNetFinTransactions[s=[:Hh], t=t1:T; (s,) in net_fin_transactions_s],
    ∑(vNetFinTransactions[s,t] for s in sector) == 0.0

    # Net revaluation by sector and asset/liability side.
    vNetFinReval[s=sector, t=t1:T],
    vNetFinReval[s,t] == vFinReval_al[s,:Assets,t] - vFinReval_al[s,:Liab,t]

    vFinReval_al[s=sector, al=ass_liab, t=t1:T],
    vFinReval_al[s,al,t] == ∑(vFinReval[s,f,al,t]  for f in fin_instrument)

    @test_constraint("Summing vNetFinReval over sectors"; atol=1.0, rtol=1e-6)
    vNetFinReval[s=[:Hh], t=t1:T],
    ∑(vNetFinReval[s,t] for s in sector) == 0.0

    # Net other changes in volume by sector and asset/liability side.
    vNetOtherChangesInVolume[s=sector, t=t1:T],
    vNetOtherChangesInVolume[s,t] == vOtherChangesInVolume_al[s,:Assets,t] - vOtherChangesInVolume_al[s,:Liab,t]

    vOtherChangesInVolume_al[s=sector, al=ass_liab, t=t1:T; (s, al) in other_changes_in_volume_s_f_al],
    vOtherChangesInVolume_al[s,al,t] == ∑(vOtherChangesInVolume[s,f,al,t]  for f in fin_instrument)

    @test_constraint("Summing vNetOtherChangesInVolume over sectors"; atol=1.0, rtol=1e-6)
    vNetOtherChangesInVolume[s=[:Hh], t=t1:T],
    ∑(vNetOtherChangesInVolume[s,t] for s in sector) == 0.0

    # Net property income by sector. RoW is the residual given net property income of other sectors.
    vNetFinIncome[s=filter(≠(:RoW), sector), t=t1:T],
    vNetFinIncome[s,t] == vFinIncome_al[s,:Assets,t] - vFinIncome_al[s,:Liab,t]

    vNetFinIncome[s=[:RoW], t=t1:T],
    vNetFinIncome[s,t] == -∑(vNetFinIncome[s2,t] for s2 in sector if s2 != :RoW)

    vFinIncome_al[s=sector, al=ass_liab, t=t1:T],
    vFinIncome_al[s,al,t] == ∑(vFinIncome[s,f,al,t]  for f in fin_instrument)

    @test_constraint("Summing vNetFinIncome over sectors"; atol=1.0, rtol=1e-6)
    vNetFinIncome[s=[:Hh], t=t1:T],
    ∑(vNetFinIncome[s,t] for s in sector) == 0.0

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

end # module
