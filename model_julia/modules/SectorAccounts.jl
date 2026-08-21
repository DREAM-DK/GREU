# ESA 2010 institutional sector and financial accounts.
# This layer has account identities and inputs for sector modules.
# It has no rates for income, asset choice, revaluation, or capital structure.
# Financial data splits debt and equity and omits monetary gold (F.11).
# Names that end in `_al` split assets and liabilities.
# See model/modules/financial_accounts.gms and SectorAccountsData.jl for maps.

include(joinpath(@__DIR__, "SectorAccountsSettings.jl"))

module SectorAccounts

using SquareModels
import ..DataUtils: fill_cells!, read_cells, read_series
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..InputOutput: vC, vM, vX
import ..SectorAccountsSettings: sector_accounts_data_dir, cell_tolerance
import ..Settings: calibration_year
import ..db
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================

const sector = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_sectors.csv"))
const fin_instrument = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_fin_instruments.csv"))
const ass_liab = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_ass_liab.csv"))

# ============================================================================
# Checked-in data
# ============================================================================

const sector_accounts_file = joinpath(sector_accounts_data_dir, "sector_accounts.csv")

const vFinIncome_data = read_cells(sector_accounts_file, "vFinIncome")
const vFinAL_data = read_cells(sector_accounts_file, "vFinAL")
const vFinTransactions_data = read_cells(sector_accounts_file, "vFinTransactions")
const vFinAssets_al_data = read_cells(sector_accounts_file, "vFinAssets")
const vNetFinTransactions_data = read_cells(sector_accounts_file, "vNetFinTransactions")
const vGrossCapitalFormation_data = read_cells(sector_accounts_file, "vGrossCapitalFormation")
const vNonFinancialNonProducedAssets_data = read_cells(sector_accounts_file, "vNonFinancialNonProducedAssets")
const vNetTransfers2sector_data = read_cells(sector_accounts_file, "vNetTransfers2sector")
const vGrossOpSurplusMixedIncome_data = read_cells(sector_accounts_file, "vGrossOpSurplusMixedIncome")
const vFinReval_data = read_cells(sector_accounts_file, "vFinReval")
const vOtherChangesInVolume_data = read_cells(sector_accounts_file, "vOtherChangesInVolume")

# ============================================================================
# Cell masks
# ============================================================================
# Each mask is named after the indices it holds. Cells outside a mask have no
# variable and no equation, so a mask change needs a model rebuild.

"""Indices with a non-negligible calibration-year value. The last index is the year."""
calibration_year_indices(cells) = Set(
  key[1:(end-1)]
  for (key,value) in cells
  if key[end] == calibration_year && abs(value) > cell_tolerance
)
calibration_year_axis(cells) = Set(only(index) for index in calibration_year_indices(cells))

# ============================================================================
# Variables
# ============================================================================

const SectorAccountsTag = Tag(:SectorAccounts)

@variables db.model :: (SectorAccountsTag, GrowthAdjusted, InflationAdjusted) begin
  # Sector totals.
  vNetFinAssets[s=sector,t=t], "Net financial assets by sector: assets less liabilities."
  vNetFinTransactions[s=sector,t=t], "Net financial transactions by sector: assets acquired less liabilities incurred (B.9F)."
  vNetFinReval[s=sector,t=t], "Net revaluations by sector: assets less liabilities."
  vNetFinIncome[s=sector,t=t], "Net property income by sector: income received less income paid (D.4)."
  vNetOtherChangesInVolume[s=sector,t=t], "Net other changes in volume by sector: assets less liabilities (K.1-K.6)."

  # Values by instrument and asset or liability. Each flow uses the stock mask
  # so each stock cell has one complete change identity.
  vFinAL[s=sector,f=fin_instrument,al=ass_liab,t=t; (s,f,al) in calibration_year_indices(vFinAL_data)], "Financial assets or liabilities by sector, instrument, and asset or liability side (F)."
  vFinTransactions[(s,f,al,t)=vFinAL], "Financial transactions by sector, instrument, and asset or liability side."
  vFinReval[(s,f,al,t)=vFinAL], "Financial revaluations by sector, instrument, and asset or liability side."
  vOtherChangesInVolume[(s,f,al,t)=vFinAL], "Other changes in volume by sector, instrument, and asset or liability side (K.1-K.6)."
  vFinIncome[(s,f,al,t)=vFinAL], "Property income received on assets or paid on liabilities by sector and instrument (D.4)."

  # Values by asset or liability. Each sector has both sides.
  vFinTransactions_al[s=sector,al=ass_liab,t=t], "Financial transactions by sector and asset or liability."
  vFinReval_al[s=sector,al=ass_liab,t=t], "Financial revaluations by sector and asset or liability."
  vOtherChangesInVolume_al[s=sector,al=ass_liab,t=t], "Other changes in financial volume by sector and asset or liability."
  vFinIncome_al[s=sector,al=ass_liab,t=t], "Property income by sector and asset or liability."
  vFinAssets_al[s=sector,al=ass_liab,t=t], "Financial assets or liabilities by sector and asset or liability."

  # Inputs for sector balances.
  vGrossCapitalFormation[s=sector,t=t; s in calibration_year_axis(vGrossCapitalFormation_data)], "Gross capital formation by sector (P.5)."
  vNonFinancialNonProducedAssets[s=sector,t=t; s in calibration_year_axis(vNonFinancialNonProducedAssets_data)], "Net purchases of non-produced non-financial assets by sector (NP)."
  vNetTransfers2sector[s=sector,t=t; s in calibration_year_axis(vNetTransfers2sector_data)], "Net current and capital transfers received by sector (D.5+D.6+D.7+D.8+D.9)."

  vGovBalance[t], "Government net lending or borrowing (B.9)."
  vGovPrimaryBalance[t], "Government balance less net property income."
  vCorrectionNonFinCorp2Hh[t], "Retained earnings moved from non-financial firms to households (D.422/D.72)."
  # Replace this source value with the input-output B2A3G total when available.
  vGrossOpSurplusMixedIncome[s=sector,t=t; s in calibration_year_axis(vGrossOpSurplusMixedIncome_data)], "Gross operating surplus and mixed income by sector (B.2g+B.3g)."

  # Rest-of-world accounts.
  # Keep the P.6 and P.7 source totals for later data checks. The equations use
  # the input-output totals vX and vM.
  vExports[t], "Source total for exports of goods and services (P.6)."
  vImports[t], "Source total for imports of goods and services (P.7)."
  vRoWPrimaryIncomeCurrentBalanceOther[t], "Rest-of-world income balance other than property income (D.1+D.2+D.3+D.5+D.6+D.7+D.8+D.9)."
  vGoodsServicesBalance[t], "Goods and services balance (B.11 trade part)."
  vRoWPrimaryIncomeCurrentBalance[t], "Rest-of-world income balance: net D.4 plus other income."

  # Move wage accounts to LaborMarket.jl when that module is ready.
  vRoWNetWages[t], "Rest-of-world net wages (D.1)."
  vHhWages[t], "Household net wages (D.1)."
end # @variables

# ============================================================================
# Data
# ============================================================================

function set_data!(db)
  @assert all(haskey(vNetFinTransactions_data, (s,calibration_year)) for s in sector) "Each sector needs net financial transactions"
  @assert all(haskey(vFinAssets_al_data, (s,al,calibration_year)) for s in sector for al in ass_liab) "Each sector needs financial assets and liabilities"

  fill_cells!(db, vFinIncome, vFinIncome_data)
  fill_cells!(db, vFinAL, vFinAL_data)
  fill_cells!(db, vFinTransactions, vFinTransactions_data)
  fill_cells!(db, vFinAssets_al, vFinAssets_al_data)
  fill_cells!(db, vNetFinTransactions, vNetFinTransactions_data)
  fill_cells!(db, vGrossCapitalFormation, vGrossCapitalFormation_data)
  fill_cells!(db, vNonFinancialNonProducedAssets, vNonFinancialNonProducedAssets_data)
  fill_cells!(db, vNetTransfers2sector, vNetTransfers2sector_data)
  fill_cells!(db, vGrossOpSurplusMixedIncome, vGrossOpSurplusMixedIncome_data)
  fill_cells!(db, vFinReval, vFinReval_data)
  fill_cells!(db, vOtherChangesInVolume, vOtherChangesInVolume_data)

  db[vExports] .= read_series(sector_accounts_file, "vExports", t)
  db[vImports] .= read_series(sector_accounts_file, "vImports", t)
  db[vRoWPrimaryIncomeCurrentBalanceOther] .= read_series(sector_accounts_file, "vRoWPrimaryIncomeCurrentBalanceOther", t)
  db[vRoWNetWages] .= read_series(sector_accounts_file, "vRoWNetWages", t)
  db[vHhWages] .= read_series(sector_accounts_file, "vHhWages", t)
  db[vCorrectionNonFinCorp2Hh] .= read_series(sector_accounts_file, "vCorrectionNonFinCorp2Hh", t)

  # Until the government module supplies B.9, use the same source total as
  # government net financial transactions.
  db[vGovBalance] .= [
    get(vNetFinTransactions_data, (:Gov,tt), nothing)
    for tt in t
  ]

  # Net financial assets: assets minus liabilities by sector.
  db[vNetFinAssets] .= [
    let
      asset = db[vFinAssets_al][s,:Assets,tt]
      liability = db[vFinAssets_al][s,:Liab,tt]
      asset === nothing || liability === nothing ? nothing : asset-liability
    end
    for s in sector, tt in t
  ]

  return nothing
end # set_data!

function set_residual_tolerances!(tolerances)
  # Sector stock changes can differ from the sum of transactions,
  # revaluations, and other changes in volume. Sources also have round-off gaps.
  tolerances[vNetFinAssets] = 250000.0
  tolerances[vNetFinTransactions] = 250000.0
  tolerances[vFinAL] = 1000000.0
  tolerances[vFinTransactions] = 1000000.0
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block db begin
    # Stock changes equal transactions, revaluations, and other volume changes.
    vFinTransactions[s = sector, f = fin_instrument, al = ass_liab, t = t1:T],
    vFinAL[s,f,al,t] == vFinAL[s,f,al,t-1]/fv
                       + vFinTransactions[s,f,al,t]
                       + vFinReval[s,f,al,t]
                       + vOtherChangesInVolume[s,f,al,t]

    vNetFinAssets[s=sector,t=t1:T],
    vNetFinAssets[s,t] == vNetFinAssets[s,t-1]/fv
                         + vNetFinTransactions[s,t]
                         + vNetFinReval[s,t]
                         + vNetOtherChangesInVolume[s,t]

    @test_constraint("Summing vNetFinAssets over sectors"; atol=1.0, rtol=1e-6)
    vNetFinAssets[s=[:Hh],t=t1:T],
      ∑(vNetFinAssets[s,t] for s in sector) == 0.0

    # Sector balances.
    # Government.
    vGovPrimaryBalance[t=t1:T], vGovPrimaryBalance[t] == vGovBalance[t]-vNetFinIncome[:Gov,t]

    vNetFinTransactions[s=[:Gov],t=t1:T],
    vNetFinTransactions[s,t] == vGovPrimaryBalance[t]+vNetFinIncome[s,t]

    # Households.
    vNetFinTransactions[s=[:Hh],t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 + vHhWages[t]
                                 - vC[t]
                                 + vCorrectionNonFinCorp2Hh[t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]

    # Financial firms.
    vNetFinTransactions[s=[:FinCorp],t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]

    # Non-financial firms.
    vNetFinTransactions[s=[:NonFinCorp],t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]
                                 - vCorrectionNonFinCorp2Hh[t]

    # Rest of the world.
    vNetFinTransactions[s=[:RoW],t=t1:T],
    vNetFinTransactions[s,t] == vGoodsServicesBalance[t]
                                 + vRoWPrimaryIncomeCurrentBalance[t]
                                 - vNonFinancialNonProducedAssets[s,t]

    # Goods and services balance (B.11 trade part).
    vGoodsServicesBalance[t=t1:T], vGoodsServicesBalance[t] == vX[t]-vM[t]

    # Add net property income (D.4) to the other income balance.
    vRoWPrimaryIncomeCurrentBalance[t=t1:T],
    vRoWPrimaryIncomeCurrentBalance[t] == vNetFinIncome[:RoW,t]
                                           + vRoWPrimaryIncomeCurrentBalanceOther[t]

    @test_constraint("Summing vNetFinTransactions over sectors"; atol=1.0, rtol=1e-6)
    vNetFinTransactions[s=[:Hh],t=t1:T],
      ∑(vNetFinTransactions[s2,t] for s2 in sector) == 0.0

    # Totals by asset or liability.
    vFinTransactions_al[s=sector,al=ass_liab,t=t1:T],
    vFinTransactions_al[s,al,t] == ∑(vFinTransactions[s,f,al,t] for f in fin_instrument)

    vFinAssets_al[s=sector,al=ass_liab,t=t1:T],
    vFinAssets_al[s,al,t] == ∑(vFinAL[s,f,al,t] for f in fin_instrument)

    # Net revaluation is the asset value less the liability value.
    vNetFinReval[s=sector,t=t1:T],
    vNetFinReval[s,t] == vFinReval_al[s,:Assets,t]-vFinReval_al[s,:Liab,t]

    vFinReval_al[s=sector,al=ass_liab,t=t1:T],
    vFinReval_al[s,al,t] == ∑(vFinReval[s,f,al,t] for f in fin_instrument)

    @test_constraint("Summing vNetFinReval over sectors"; atol=1.0, rtol=1e-6)
    vNetFinReval[s=[:Hh],t=t1:T],
      ∑(vNetFinReval[s,t] for s in sector) == 0.0

    # Net other volume change is the asset value less the liability value.
    vNetOtherChangesInVolume[s=sector,t=t1:T],
    vNetOtherChangesInVolume[s,t] == vOtherChangesInVolume_al[s,:Assets,t]
                                          - vOtherChangesInVolume_al[s,:Liab,t]

    vOtherChangesInVolume_al[s=sector,al=ass_liab,t=t1:T],
    vOtherChangesInVolume_al[s,al,t] == ∑(vOtherChangesInVolume[s,f,al,t] for f in fin_instrument)

    @test_constraint("Summing vNetOtherChangesInVolume over sectors"; atol=1.0, rtol=1e-6)
    vNetOtherChangesInVolume[s=[:Hh],t=t1:T],
      ∑(vNetOtherChangesInVolume[s,t] for s in sector) == 0.0

    # Rest-of-world property income closes the sector total.
    vNetFinIncome[s=filter(≠(:RoW), sector),t=t1:T],
    vNetFinIncome[s,t] == vFinIncome_al[s,:Assets,t]
                          - vFinIncome_al[s,:Liab,t]

    vNetFinIncome[s=[:RoW],t=t1:T],
    vNetFinIncome[s,t] == -∑(vNetFinIncome[s2,t] for s2 in sector if s2 != :RoW)

    vFinIncome_al[s=sector,al=ass_liab,t=t1:T],
    vFinIncome_al[s,al,t] == ∑(vFinIncome[s,f,al,t] for f in fin_instrument)

    @test_constraint("Summing vNetFinIncome over sectors"; atol=1.0, rtol=1e-6)
    vNetFinIncome[s=[:Hh],t=t1:T],
      ∑(vNetFinIncome[s,t] for s in sector) == 0.0
  end # @block
end # define_equations

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  return define_equations()
end

end # module
