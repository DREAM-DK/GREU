# Government budget identities, tax and transfer accounts, and portfolio rules.
# Load budget items from Eurostat gov_10a_main.

include(joinpath(@__DIR__, "GovernmentSettings.jl"))

module Government

using SquareModels
import ..DataUtils: read_series
import ..GovernmentSettings: government_data_dir
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..IndustrySectors: vM_s, vtProduction_s, vWages_s
import ..model
import ..SectorAccounts:
  ass_liab,
  fin_instrument,
  vFinIncome_s_f,
  vFinPosition_s_f,
  vFinTransactions_f,
  vGovBalance,
  vI_s,
  vNetFinTransactions,
  vNetFinAssets
import ..Time: t, t1, T
import ..Tags: ForecastZero

# ============================================================================
# Read data
# ============================================================================
const government_file = joinpath(government_data_dir, "government_variables.csv")

# ============================================================================
# Variables
# ============================================================================
const GovernmentTag = Tag(:Government)

@variables model :: (GovernmentTag, GrowthAdjusted, InflationAdjusted) begin
  vGovRevenue[t], "Revenue of government (TR)."
  vGovExpenditure[t], "Expenditure of government (TE)."
  vGovPrimaryRevenue[t], "Primary revenue of government (TR less interest income)."
  vGovPrimaryExpenditure[t], "Primary expenditure of government (TE less interest payments)."
  vGovPrimaryBalance[t], "Government net lending or borrowing before interest payments."

  vtIndirect[t], "Revenue from indirect taxes (D.2)."
  vtDirect[t], "Revenue from direct taxes (D.5)."
  vtHhIncome[t], "Revenue from household income taxes (D.51A+D.51C1)."
  vtCorp[t], "Tax on corporations (D.51B+D.51C2)."
  vGovProductTax[t], "Taxes on products (D.21)."
  vGovOthProductionTax[t], "Other taxes on production (D.29)."
  vtDirectOther[t], "Other direct taxes."

  vGovPrimaryRevOther[t], "Other primary revenue of government."
  vGovSalesRev[t], "Revenue from sales (P.11+P.12+P.131)."
  vGovOthSubRev[t], "Revenue from other subsidies (D.39)."
  vGovSocialContRev[t], "Revenue from social contributions (D.61)."
  vGovOthCurrentTransRev[t], "Revenue from other current transfers (D.7)."
  vtCap[t], "Revenue from capital taxes (D.91)."
  vGovCapRev[t], "Revenue from capital transfers (D.92+D.99)."

  vGovDepr[t], "Depreciation of government capital (P.51C)."
  vGovSub[t], "Subsidies of government (D.3)."
  vGovSocBenefitExp[t], "Social benefit expenditure of government (D.62+D.632)."
  vSocTransKind[t], "Social transfers in kind (D.632)."
  vGovOthCurrentTransExp[t], "Other current transfers expenditure of government (D.7)."
  vGovAdjExp[t], "Adjustments of government (D.8)."
  vGovCapTransExp[t], "Capital transfers expenditure of government (D.9)."
  vGovNetAcquisitions[t], "Net acquisitions of non-produced non-financial assets of government (NP)."
  vLumpsum[t] :: ForecastZero, "Lump-sum transfers from government to households."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[vGovBalance] .= read_series(government_file, "vGovBalance", t)
  db[vGovRevenue] .= read_series(government_file, "vGovRevenue", t)
  db[vGovExpenditure] .= read_series(government_file, "vGovExpenditure", t)

  db[vtIndirect] .= read_series(government_file, "vtIndirect", t)
  db[vtDirect] .= read_series(government_file, "vtDirect", t)
  db[vtHhIncome] .= read_series(government_file, "vtHhIncome", t)
  db[vtCorp] .= read_series(government_file, "vtCorp", t)
  db[vGovProductTax] .= read_series(government_file, "vGovProductTax", t)
  db[vGovOthProductionTax] .= read_series(government_file, "vGovOthProductionTax", t)
  db[vGovSalesRev] .= read_series(government_file, "vGovSalesRev", t)
  db[vGovOthSubRev] .= read_series(government_file, "vGovOthSubRev", t)
  db[vGovSocialContRev] .= read_series(government_file, "vGovSocialContRev", t)
  db[vGovOthCurrentTransRev] .= read_series(government_file, "vGovOthCurrentTransRev", t)
  db[vtCap] .= read_series(government_file, "vtCap", t)
  db[vGovCapRev] .= read_series(government_file, "vGovCapRev", t)

  db[vGovDepr] .= read_series(government_file, "vGovDepr", t)
  db[vGovSub] .= read_series(government_file, "vGovSub", t)
  db[vGovSocBenefitExp] .= read_series(government_file, "vGovSocBenefitExp", t)
  db[vSocTransKind] .= read_series(government_file, "vSocTransKind", t)
  db[vGovOthCurrentTransExp] .= read_series(government_file, "vGovOthCurrentTransExp", t)
  db[vGovAdjExp] .= read_series(government_file, "vGovAdjExp", t)
  db[vGovCapTransExp] .= read_series(government_file, "vGovCapTransExp", t)
  db[vGovNetAcquisitions] .= read_series(government_file, "vGovNetAcquisitions", t)

  db[vLumpsum] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Balances.
    vGovPrimaryBalance[t=t1:T],
    vGovPrimaryBalance[t] == vGovPrimaryRevenue[t] - vGovPrimaryExpenditure[t]

    vGovBalance[t=t1:T],
    vGovBalance[t] == vGovPrimaryBalance[t]
                       + vFinIncome_s_f[:Gov,:Debt,:Assets,t]
                       - vFinIncome_s_f[:Gov,:Debt,:Liab,t]

    vNetFinTransactions[s=[:Gov], t=t1:T], vNetFinTransactions[s,t] == vGovBalance[t]

    # Revenue.
    vGovPrimaryRevenue[t=t1:T],
    vGovPrimaryRevenue[t] == vtIndirect[t] + vtDirect[t] + vGovPrimaryRevOther[t]

    vtIndirect[t=t1:T], vtIndirect[t] == vGovProductTax[t] + vGovOthProductionTax[t]
    vtDirect[t=t1:T], vtDirect[t] == vtHhIncome[t] + vtCorp[t] + vtDirectOther[t]

    vGovPrimaryRevOther[t=t1:T],
    vGovPrimaryRevOther[t] == vGovSalesRev[t]
                              + vGovOthSubRev[t]
                              + vFinIncome_s_f[:Gov,:Equity,:Assets,t]
                              + vGovSocialContRev[t]
                              + vGovOthCurrentTransRev[t]
                              + vtCap[t]
                              + vGovCapRev[t]

    # Expenditure.
    vGovPrimaryExpenditure[t=t1:T],
    vGovPrimaryExpenditure[t] == vM_s[:Gov,t]
                                  + vI_s[:Gov,t]
                                  + vWages_s[:Gov,t]
                                  + vtProduction_s[:Gov,t]
                                  + vGovSub[t]
                                  + vGovSocBenefitExp[t]
                                  + vGovOthCurrentTransExp[t]
                                  + vGovAdjExp[t]
                                  + vGovCapTransExp[t]
                                  + vGovNetAcquisitions[t]
                                  + vLumpsum[t]

    # Portfolio.
    # Gov neither buys nor sells equity; existing equity stocks follow non-transaction changes.
    vFinPosition_s_f[s=[:Gov], f=[:Equity], al=ass_liab, t=t1:T], vFinTransactions_f[s,f,al,t] == 0

    # Gov does not buy or sell debt assets; the stock follows non-transaction changes.
    vFinPosition_s_f[s=[:Gov], f=[:Debt], al=[:Assets], t=t1:T], vFinTransactions_f[s,f,al,t] == 0

    # Gov debt liabilities are residual given net financial assets.
    vFinPosition_s_f[s=[:Gov], f=[:Debt], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == ∑(vFinPosition_s_f[s,f,:Assets,t] for f in fin_instrument)
                           - ∑(vFinPosition_s_f[s,f,:Liab,t] for f in fin_instrument)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    vtDirectOther[t1], vtDirect[t1]
  end

  return block
end

end # module
