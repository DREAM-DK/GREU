# ESA 2010 institutional sector and financial accounts.
# This layer has account identities and inputs for sector modules.
# It has no rates for income, asset choice, revaluation, or capital structure.
# Financial data splits debt and equity and omits monetary gold (F.11).
# Names that end in `_f` split by financial instrument. The `al` index selects
# the asset or liability side.
# Non-financial source rows map to transfer inputs in assign_data!.

include(joinpath(@__DIR__, "SectorAccountsSettings.jl"))

module SectorAccounts

using SquareModels
import ..DataUtils: fill_cells!, read_cells
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
const non_financial_transactions_file = joinpath(sector_accounts_data_dir, "non_financial_transactions.csv")

const vFinIncome_f_data = read_cells(sector_accounts_file, "vFinIncome_f")
const vFinPosition_f_data = read_cells(sector_accounts_file, "vFinPosition_f")
const vFinTransactions_f_data = read_cells(sector_accounts_file, "vFinTransactions_f")
const vNetFinTransactions_data = read_cells(sector_accounts_file, "vNetFinTransactions")
const vI_s_data = read_cells(sector_accounts_file, "vI_s")
const vGrossOpSurplusMixedIncome_data = read_cells(sector_accounts_file, "vGrossOpSurplusMixedIncome")
const vFinReval_f_data = read_cells(sector_accounts_file, "vFinReval_f")
const vOtherChangesInVolume_f_data = read_cells(sector_accounts_file, "vOtherChangesInVolume_f")
const vGovBalance_data = read_cells(sector_accounts_file, "vGovBalance")
const vNetFinAssets_data = read_cells(sector_accounts_file, "vNetFinAssets")

const NonFinancialTransactions_data = read_cells(non_financial_transactions_file, "NonFinancialTransactions")
const NetNonFinancialTransactions_data = read_cells(non_financial_transactions_file, "NetNonFinancialTransactions")

"""Net transactions summed over transaction codes, keyed by sector and year."""
function net_transaction_cells(codes...)
  cells = Dict{Tuple{Symbol,Int},Float64}()
  for ((s, d, year), value) in NetNonFinancialTransactions_data
    d in codes || continue
    cells[(s, year)] = get(cells, (s, year), 0.0) + value
  end
  return cells
end

"""Other transfers. The rest of the world also nets taxes on products and imports."""
function other_transfer_cells()
  cells = net_transaction_cells(:D7, :D92, :D99)
  for (key, value) in net_transaction_cells(:D2, :D3, :D7, :D92, :D99)
    first(key) == :RoW && (cells[key] = value)
  end
  return cells
end

"""Paid transactions for one code, keyed by sector and year."""
paid_transaction_cells(code) = Dict(
  (s, year) => value
  for ((s, d, al, year), value) in NonFinancialTransactions_data
  if d == code && al == :PAID
)

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
  vI_s[s=sector, t=t; s in calibration_year_axis(vI_s_data)], "Gross capital formation by sector (P.5). Households include NPISH."
  vNetTransfers[s=sector, t=t], "Transfer receipts less payments."
  vCurrentIncomeWealthTaxes[s=sector, t=t], "Current taxes on income, profits, capital gains, and wealth received less paid (D.5)."
  vInheritanceGiftWealthTaxes[s=sector, t=t], "Taxes on inheritances and gifts, and exceptional levies on assets or net wealth, received less paid (D.91)."
  vSocialContributions[s=sector, t=t], "Social insurance and pension contributions received less paid, after scheme service charges (D.61)."
  vSocialBenefits[s=sector, t=t], "Cash and other non-kind social benefits received less paid, including pension benefits (D.62)."
  vPensionSaving[s=sector, t=t], "Net pension saving received less paid: contributions and credited returns less fees and benefits (D.8)."
  vOtherTransfers[s=sector, t=t], "Other current and capital transfers received less paid (D.7, D.92, and D.99). RoW also includes D.2 and D.3."
  vNonProducedAssetAcquisitions[s=sector, t=t], "Purchases less sales of land, mineral and energy reserves, other natural resources, and transferable contracts, leases, and licences (NP)."

  vGovBalance[t], "Government net lending or borrowing (B.9)."
  vGrossOpSurplusMixedIncome[s=sector, t=t; s in calibration_year_axis(vGrossOpSurplusMixedIncome_data)], "Gross operating surplus and mixed income by sector (B.2g+B.3g)."

end # @variables

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  fill_cells!(db, vFinIncome_f, vFinIncome_f_data)
  fill_cells!(db, vFinPosition_f, vFinPosition_f_data)
  fill_cells!(db, vFinTransactions_f, vFinTransactions_f_data)
  fill_cells!(db, vNetFinTransactions, vNetFinTransactions_data)
  fill_cells!(db, vI_s, vI_s_data)

  db[vCurrentIncomeWealthTaxes] .= NetNonFinancialTransactions[:,:D5,:]
  db[vInheritanceGiftWealthTaxes] .= NetNonFinancialTransactions[:,:D91,:]
  db[vSocialContributions] .= NetNonFinancialTransactions[:,:D61,:]
  db[vSocialBenefits] .= NetNonFinancialTransactions[:,:D62,:]
  db[vPensionSaving] .= NetNonFinancialTransactions[:,:D8,:]
  db[vOtherTransfers] .= sum(NetNonFinancialTransactions[:,d,:] for d in [:D7, :D92, :D99])
  db[vOtherTransfers[:RoW,:]] .= sum(
    NetNonFinancialTransactions[:RoW,d,:]
    for d in [:D2, :D3, :D7, :D92, :D99]
  )
  db[vNonProducedAssetAcquisitions] .= NonFinancialTransactions[:,:NP,:PAID,:]

  fill_cells!(db, vGrossOpSurplusMixedIncome, vGrossOpSurplusMixedIncome_data)
  fill_cells!(db, vFinReval_f, vFinReval_f_data)
  fill_cells!(db, vOtherChangesInVolume_f, vOtherChangesInVolume_f_data)

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
    vNetTransfers[s=sector, t=t1:T],
    vNetTransfers[s,t] == vCurrentIncomeWealthTaxes[s,t] + vInheritanceGiftWealthTaxes[s,t]
                           + vSocialContributions[s,t] + vSocialBenefits[s,t] + vPensionSaving[s,t]
                           + vOtherTransfers[s,t]

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
