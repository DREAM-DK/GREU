# ESA 2010 institutional sector and financial accounts.
# This layer has account identities and inputs for sector modules.
# It has no rates for income, asset choice, revaluation, or capital structure.
# Financial data splits debt and equity and omits monetary gold (F.11).
# Names that end in `_f` split by financial instrument. The `al` index selects
# the asset or liability side.
# See model/modules/financial_accounts.gms and SectorAccountsData.jl for maps.

include(joinpath(@__DIR__, "SectorAccountsSettings.jl"))

module SectorAccounts

using SquareModels
import ..DataUtils: fill_cells!, read_cells, read_series
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..SectorAccountsSettings: sector_accounts_data_dir, cell_tolerance
import ..Settings: calibration_year
import ..model
import ..Time: t, t1, T

# ============================================================================
# Read data
# ============================================================================

const sector = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_sectors.csv"))
const fin_instrument = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_fin_instruments.csv"))
const ass_liab = read_indices(joinpath(sector_accounts_data_dir, "sector_accounts_ass_liab.csv"))

const sector_accounts_file = joinpath(sector_accounts_data_dir, "sector_accounts.csv")

const vFinIncome_f_data = read_cells(sector_accounts_file, "vFinIncome_f")
const vFinPosition_f_data = read_cells(sector_accounts_file, "vFinPosition_f")
const vFinTransactions_f_data = read_cells(sector_accounts_file, "vFinTransactions_f")
const vNetFinTransactions_data = read_cells(sector_accounts_file, "vNetFinTransactions")
const vGrossCapitalFormation_data = read_cells(sector_accounts_file, "vGrossCapitalFormation")
const vNonFinancialNonProducedAssets_data = read_cells(sector_accounts_file, "vNonFinancialNonProducedAssets")
const vNetTransfers_data = read_cells(sector_accounts_file, "vNetTransfers")
const vGrossOpSurplusMixedIncome_data = read_cells(sector_accounts_file, "vGrossOpSurplusMixedIncome")
const vFinReval_f_data = read_cells(sector_accounts_file, "vFinReval_f")
const vOtherChangesInVolume_f_data = read_cells(sector_accounts_file, "vOtherChangesInVolume_f")
const vGovBalance_data = read_cells(sector_accounts_file, "vGovBalance")
const vNetFinAssets_data = read_cells(sector_accounts_file, "vNetFinAssets")

# ============================================================================
# Indices
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

@variables model :: (SectorAccountsTag, GrowthAdjusted, InflationAdjusted) begin
  # Sector totals.
  vNetFinAssets[s=sector, t=t], "Net financial assets by sector: assets less liabilities."
  vNetFinTransactions[s=sector, t=t], "Net financial transactions by sector: assets acquired less liabilities incurred (B.9F)."
  vNetFinReval[s=sector, t=t], "Net revaluations by sector: assets less liabilities."
  vNetFinIncome[s=sector, t=t], "Net property income by sector: income received less income paid (D.4)."
  vNetOtherChangesInVolume[s=sector, t=t], "Net other changes in volume by sector: assets less liabilities (K.1-K.6)."

  # Values by instrument and asset or liability. Each flow uses the stock mask
  # so each stock cell has one complete change identity.
  vFinPosition_f[s=sector, f=fin_instrument, al=ass_liab, t=t; (s,f,al) in calibration_year_indices(vFinPosition_f_data)], "Financial position by sector, instrument, and asset or liability side (F)."
  vFinTransactions_f[(s,f,al,t)=vFinPosition_f], "Financial transactions by sector, instrument, and asset or liability side."
  vFinReval_f[(s,f,al,t)=vFinPosition_f], "Financial revaluations by sector, instrument, and asset or liability side."
  vOtherChangesInVolume_f[(s,f,al,t)=vFinPosition_f], "Other changes in volume by sector, instrument, and asset or liability side (K.1-K.6)."
  vFinIncome_f[(s,f,al,t)=vFinPosition_f], "Property income received on assets or paid on liabilities by sector and instrument (D.4)."

  # Inputs for sector balances.
  vGrossCapitalFormation[s=sector, t=t; s in calibration_year_axis(vGrossCapitalFormation_data)], "Gross capital formation by sector (P.5)."
  vNonFinancialNonProducedAssets[s=sector, t=t; s in calibration_year_axis(vNonFinancialNonProducedAssets_data)], "Net purchases of non-produced non-financial assets by sector (NP)."
  vNetTransfers[s=sector, t=t; s in calibration_year_axis(vNetTransfers_data)], "Net current and capital transfers received by sector (D.5+D.6+D.7+D.8+D.9)."

  vGovBalance[t], "Government net lending or borrowing (B.9)."
  vGrossOpSurplusMixedIncome[s=sector, t=t; s in calibration_year_axis(vGrossOpSurplusMixedIncome_data)], "Gross operating surplus and mixed income by sector (B.2g+B.3g)."

  # Rest-of-world accounts.
  vRoWPrimaryIncomeCurrentBalanceOther[t], "Rest-of-world nonwage income balance other than property income (D.2+D.3+D.5+D.6+D.7+D.8+D.9)."

end # @variables

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  fill_cells!(db, vFinIncome_f, vFinIncome_f_data)
  fill_cells!(db, vFinPosition_f, vFinPosition_f_data)
  fill_cells!(db, vFinTransactions_f, vFinTransactions_f_data)
  fill_cells!(db, vNetFinTransactions, vNetFinTransactions_data)
  fill_cells!(db, vGrossCapitalFormation, vGrossCapitalFormation_data)
  fill_cells!(db, vNonFinancialNonProducedAssets, vNonFinancialNonProducedAssets_data)
  fill_cells!(db, vNetTransfers, vNetTransfers_data)
  fill_cells!(db, vGrossOpSurplusMixedIncome, vGrossOpSurplusMixedIncome_data)
  fill_cells!(db, vFinReval_f, vFinReval_f_data)
  fill_cells!(db, vOtherChangesInVolume_f, vOtherChangesInVolume_f_data)

  db[vRoWPrimaryIncomeCurrentBalanceOther] .= read_series(sector_accounts_file, "vRoWPrimaryIncomeCurrentBalanceOther", t)
  # Until the government module supplies B.9, use the same source total as
  # government net financial transactions.
  fill_cells!(db, vGovBalance, vGovBalance_data)
  fill_cells!(db, vNetFinAssets, vNetFinAssets_data)

  return nothing
end # assign_data!

function set_residual_tolerances!(tolerances)
  # Sector stock changes can differ from the sum of transactions,
  # revaluations, and other changes in volume. Source income also has small gaps.
  tolerances[vNetFinAssets] = 20000.0
  tolerances[vNetFinTransactions] = 4.0
  tolerances[vFinPosition_f] = 40000.0
  tolerances[vFinTransactions_f] = 40000.0
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    # --- Stock changes equal transactions, revaluations, and other volume changes. ---
    vFinTransactions_f[s=sector, f=fin_instrument, al=ass_liab, t=t1:T],
    vFinPosition_f[s,f,al,t] == vFinPosition_f[s,f,al,t-1]/fv + vFinTransactions_f[s,f,al,t]
                              + vFinReval_f[s,f,al,t] + vOtherChangesInVolume_f[s,f,al,t]

    vNetFinAssets[s=sector, t=t1:T],
    vNetFinAssets[s,t] == vNetFinAssets[s,t-1]/fv + vNetFinTransactions[s,t]
                        + vNetFinReval[s,t] + vNetOtherChangesInVolume[s,t]

    # Net revaluation is the asset value less the liability value.
    vNetFinReval[s=sector, t=t1:T],
    vNetFinReval[s,t] == ∑(vFinReval_f[s,f,:Assets,t] for f in fin_instrument)
                       - ∑(vFinReval_f[s,f,:Liab,t] for f in fin_instrument)

    # Net other volume change is the asset value less the liability value.
    vNetOtherChangesInVolume[s=sector, t=t1:T],
    vNetOtherChangesInVolume[s,t] == ∑(vOtherChangesInVolume_f[s,f,:Assets,t] for f in fin_instrument)
                                   - ∑(vOtherChangesInVolume_f[s,f,:Liab,t] for f in fin_instrument)

    # Property income is receipts less payments for each sector.
    vNetFinIncome[s=sector, t=t1:T],
    vNetFinIncome[s,t] == ∑(vFinIncome_f[s,f,:Assets,t] for f in fin_instrument)
                        - ∑(vFinIncome_f[s,f,:Liab,t] for f in fin_instrument)

    # --- Tests. ---
    @test_constraint("Net financial transactions equals assets minus liabilities"; atol=1.0, rtol=1e-6)
    vNetFinTransactions[s=sector, t=t1:T],
    vNetFinTransactions[s,t] == ∑(vFinTransactions_f[s,f,:Assets,t] for f in fin_instrument)
                              - ∑(vFinTransactions_f[s,f,:Liab,t] for f in fin_instrument)

    @test_constraint("Summing vNetFinAssets over sectors"; atol=2.0, rtol=1e-6)
    vNetFinAssets[s=[:Hh], t=t1:T], ∑(vNetFinAssets[s,t] for s in sector) == 0.0

    @test_constraint("Summing vNetFinTransactions over sectors"; atol=1.0, rtol=1e-6)
    vNetFinTransactions[s=[:Hh], t=t1:T], ∑(vNetFinTransactions[s2,t] for s2 in sector) == 0.0

    @test_constraint("Summing vNetFinReval over sectors"; atol=1.0, rtol=1e-6)
    vNetFinReval[s=[:Hh], t=t1:T], ∑(vNetFinReval[s,t] for s in sector) == 0.0

    @test_constraint("Summing vNetOtherChangesInVolume over sectors"; atol=1.0, rtol=1e-6)
    vNetOtherChangesInVolume[s=[:Hh], t=t1:T], ∑(vNetOtherChangesInVolume[s,t] for s in sector) == 0.0

    @test_constraint("Summing vNetFinIncome over sectors"; atol=1.0, rtol=1e-6)
    vNetFinIncome[s=[:Hh], t=t1:T], ∑(vNetFinIncome[s,t] for s in sector) == 0.0
  end # @block
end # define_equations

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  return define_equations()
end

end # module
