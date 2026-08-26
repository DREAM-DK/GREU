# Government budget identities, tax and transfer accounts, and portfolio rules.
# Load budget items from Eurostat gov_10a_main.

include(joinpath(@__DIR__, "GovernmentSettings.jl"))

module Government

using SquareModels
import ..DataUtils: read_series
import ..GovernmentSettings: government_data_dir
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..InputOutput: industry, use, vY_i, vNetProductTax_u
import ..model
import ..Production: vProductionTax_i
import ..SectorAccounts:
  vNetFinTransactions,
  vNetFinIncome,
  vGovBalance,
  vGovPrimaryBalance,
  vFinAL,
  vFinReval,
  vFinIncome,
  vFinIncome_al,
  vNetFinAssets,
  vFinAssets_al,
  vHhWages,
  vGrossOpSurplusMixedIncome,
  vNetTransfers2sector
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero

# ============================================================================
# Read data
# ============================================================================
const government_file = joinpath(government_data_dir, "government_variables.csv")

# ============================================================================
# Variables
# ============================================================================
const GovernmentTag = Tag(:Government)

@variables model :: (GovernmentTag, GrowthAdjusted, InflationAdjusted) begin
  vGovPrimaryRevenue[t], "Primary revenue of government (TR less property income)."
  vGovPrimaryExpenditure[t], "Primary expenditure of government (TE less interest)."

  vGovRevenue[t], "Revenue of government (TR)."
  vGovExpenditure[t], "Expenditure of government (TE)."

  vtIndirect[t], "Revenue from indirect taxes (D.2)."
  vtIndirect_other[i=industry, t=t], "Indirect taxes not linked to the input-output module."
  vtDirect[t], "Revenue from direct taxes (D.5)."
  vtHhIncome[t], "Revenue from household income taxes (D.51A+D.51C1)."
  vtHhReturn[t], "Tax on household return on wealth."
  vtHhWages[t], "Tax on household wages."
  vtCorp[t], "Tax on corporations (D.51B+D.51C2)."
  vtDirect_other[t], "Residual direct taxes."

  vGovPrimaryRevOther[t], "Other revenue of government."
  vGovSalesRev[t], "Revenue from sales (P.11+P.12+P.131)."
  vGovOthSubRev[t], "Revenue from other subsidies (D.39)."
  vGovPropertyIncome[t], "Revenue from property income (D.4)."
  vGovSocialContRev[t], "Revenue from social contributions (D.61)."
  vGovOthCurrentTransRev[t], "Revenue from other current transfers (D.7)."
  vtCap[t], "Revenue from capital taxes (D.91)."
  vGovCapRev[t], "Revenue from capital transfers (D.92+D.99)."

  vGovIntermediateCons[t], "Intermediate consumption of government (P.2)."
  vGovCapInv[t], "Capital investment of government (P.5)."
  vGovDepr[t], "Depreciation of government capital (P.51C)."
  vGovEmplComp[t], "Employment compensation of government (D.1)."
  vGovOthProdTax[t], "Other production taxes of government (D.29)."
  vGovSub[t], "Subsidies of government (D.3)."
  vGovInterestPayments[t], "Interest payments of government (D.4)."
  vGovSocBenefitExp[t], "Social benefit expenditure of government (D.62+D.632)."
  vSocTransKind[t], "Social transfers in kind (D.632)."
  vGovOthCurrentTransExp[t], "Other current transfers expenditure of government (D.7)."
  vGovAdjExp[t], "Adjustments of government (D.8)."
  vGovCapTransExp[t], "Capital transfers expenditure of government (D.9)."
  vGovNetAcquisitions[t], "Net acquisitions of non-produced non-financial assets of government (NP)."
  vLumpsum[t] :: ForecastZero, "Lump-sum transfers from government to households."

  jvtCO2_ETS_tot[t] :: ForecastZero, "Total revenue from ETS. Zero while energy modules are off."
  jvtCO2_xE[i=industry, t=t] :: ForecastZero, "National carbon tax on non-energy emissions. Zero while energy modules are off."
end

@variables model :: (GovernmentTag, ForecastConstant) begin
  sIndirect_other[t], "Other indirect taxes relative to industry output."
  tW[t], "Marginal tax rate on household wages."
  tCorp[t], "Tax rate on corporations."
  sDirect_other[t], "Residual direct taxes relative to household income taxes."
  tCap[t], "Capital tax rate."
  sGovCapRev[t], "Capital transfer revenue relative to industry output."
  sGovOthCurrentTransRev[t], "Other current transfer revenue relative to industry output."
  sGovSub_Residual[t], "Residual government subsidies relative to industry output."
  sGovCapTransExp[t], "Capital transfer expenditure relative to industry output."
end

@variables model :: GovernmentTag begin
  trHh[t], "Marginal tax rate on household return on wealth."
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
  db[vGovSalesRev] .= read_series(government_file, "vGovSalesRev", t)
  db[vGovOthSubRev] .= read_series(government_file, "vGovOthSubRev", t)
  db[vGovPropertyIncome] .= read_series(government_file, "vGovPropertyIncome", t)
  db[vGovSocialContRev] .= read_series(government_file, "vGovSocialContRev", t)
  db[vGovOthCurrentTransRev] .= read_series(government_file, "vGovOthCurrentTransRev", t)
  db[vtCap] .= read_series(government_file, "vtCap", t)
  db[vGovCapRev] .= read_series(government_file, "vGovCapRev", t)

  db[vGovIntermediateCons] .= read_series(government_file, "vGovIntermediateCons", t)
  db[vGovCapInv] .= read_series(government_file, "vGovCapInv", t)
  db[vGovDepr] .= read_series(government_file, "vGovDepr", t)
  db[vGovEmplComp] .= read_series(government_file, "vGovEmplComp", t)
  db[vGovOthProdTax] .= read_series(government_file, "vGovOthProdTax", t)
  db[vGovSub] .= read_series(government_file, "vGovSub", t)
  db[vGovInterestPayments] .= read_series(government_file, "vGovInterestPayments", t)
  db[vGovSocBenefitExp] .= read_series(government_file, "vGovSocBenefitExp", t)
  db[vSocTransKind] .= read_series(government_file, "vSocTransKind", t)
  db[vGovOthCurrentTransExp] .= read_series(government_file, "vGovOthCurrentTransExp", t)
  db[vGovAdjExp] .= read_series(government_file, "vGovAdjExp", t)
  db[vGovCapTransExp] .= read_series(government_file, "vGovCapTransExp", t)
  db[vGovNetAcquisitions] .= read_series(government_file, "vGovNetAcquisitions", t)

  db[tW] .= 0.4
  db[trHh] .= 0.25
  db[jvtCO2_ETS_tot] .= 0.0
  db[jvtCO2_xE] .= 0.0
  db[vLumpsum] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Government balance.
    vGovPrimaryBalance[t=t1:T],
    vGovPrimaryBalance[t] == vGovPrimaryRevenue[t] - vGovPrimaryExpenditure[t]

    vGovBalance[t=t1:T],
    vGovBalance[t] == vGovPrimaryBalance[t] + vNetFinIncome[:Gov,t]

    vNetFinTransactions[s=[:Gov], t=t1:T],
    vNetFinTransactions[s,t] == vGovBalance[t]

    # Government revenues.
    vGovPrimaryRevenue[t=t1:T],
    vGovPrimaryRevenue[t] == vtIndirect[t]
                      + vtDirect[t]
                      + vGovPrimaryRevOther[t]
    
    # vNetTransfers2sector[s=[:Gov], t=t1:T],
    # vNetTransfers2sector[s,t] == vtDirect[t] # D5
    #                   + vGovSocialContRev[t] # D61
    #                   + vGovOthCurrentTransRev[t] # D7
    #                   + vtCap[t] # D91
    #                   + vGovCapRev[t] # D92-D99
    #                   - vGovSocBenefitExp[t]
    #                   - vGovOthCurrentTransExp[t]
    #                   - vGovAdjExp[t]
    #                   - vGovCapTransExp[t]

    # vtIndirect[t=t1:T],
    # vtIndirect[t] == ∑(vNetProductTax_u[u,t] for u in use)
    #                  + ∑(vProductionTax_i[i,t] for i in industry)
    #                  - jvtCO2_ETS_tot[t]
    #                  + ∑(jvtCO2_xE[i,t] for i in industry)
    #                  + ∑(vtIndirect_other[i,t] for i in industry)

    # vtIndirect_other[i=industry, t=t1:T],
    # vtIndirect_other[i,t] == sIndirect_other[t] * vY_i[i,t]

    # vtDirect[t=t1:T],
    # vtDirect[t] == vtHhIncome[t]
    #                + vtCorp[t]
    #                + vtDirect_other[t]

    # vtHhIncome[t=t1:T],
    # vtHhIncome[t] == vtHhReturn[t] + vtHhWages[t]

    # vtHhReturn[t=t1:T],
    # vtHhReturn[t] == trHh[t] * vNetFinIncome[:Hh,t]

    # vtHhWages[t=t1:T],
    # vtHhWages[t] == tW[t] * vHhWages[t]

    # vtCorp[t=t1:T],
    # vtCorp[t] == tCorp[t] * ∑(vGrossOpSurplusMixedIncome[s,t] for s in (:NonFinCorp, :FinCorp))

    # vtDirect_other[t=t1:T],
    # vtDirect_other[t] == sDirect_other[t] * vtHhIncome[t]

    vGovPrimaryRevOther[t=t1:T],
    vGovPrimaryRevOther[t] == vGovSalesRev[t]
                       + vGovOthSubRev[t]
                       + vGovSocialContRev[t]
                       + vGovOthCurrentTransRev[t]
                       + vtCap[t]
                       + vGovCapRev[t]


    
    # vGovOthCurrentTransRev[t=t1:T],
    # vGovOthCurrentTransRev[t] == sGovOthCurrentTransRev[t] * ∑(vY_i[i,t] for i in industry)

    # vtCap[t=t1:T],
    # vtCap[t] == tCap[t] * vNetFinAssets[:Hh,t]

    # vGovCapRev[t=t1:T],
    # vGovCapRev[t] == sGovCapRev[t] * ∑(vY_i[i,t] for i in industry)

    # Government expenditure.
    vGovPrimaryExpenditure[t=t1:T],
    vGovPrimaryExpenditure[t] == vGovIntermediateCons[t]
                                 + vGovCapInv[t]
                                 + vGovEmplComp[t]
                                 + vGovOthProdTax[t]
                                 + vGovSub[t]
                                 + vGovSocBenefitExp[t] ###
                                 + vGovOthCurrentTransExp[t] ###
                                 + vGovAdjExp[t] ###
                                 + vGovCapTransExp[t] ###
                                 + vGovNetAcquisitions[t]
                                 + vLumpsum[t]

    

    # vGovSub[t=t1:T],
    # vGovSub[t] == sGovSub_Residual[t] * ∑(vY_i[i,t] for i in industry)

    # vGovCapTransExp[t=t1:T],
    # vGovCapTransExp[t] == sGovCapTransExp[t] * ∑(vY_i[i,t] for i in industry)

    # Portfolio.
    # Gov neither buys nor sells equity; equity assets follow revaluation.
    vFinAL[s=[:Gov], f=[:Equity], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == vFinAL[s,f,al,t-1]/fv + vFinReval[s,f,al,t]

    # Debt assets follow revaluation.
    vFinAL[s=[:Gov], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == vFinAL[s,f,al,t-1]/fv + vFinReval[s,f,al,t]

    # Gov debt liabilities are residual given net financial assets.
    vFinAL[s=[:Gov], f=[:Debt], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    # sIndirect_other[t1], vtIndirect[t1]
    # trHh[t1], vtHhIncome[t1]
    # sDirect_other[t1], vtDirect[t1]
    # sGovOthCurrentTransRev[t1], vGovOthCurrentTransRev[t1]
    # tCorp[t1], vtCorp[t1]
    # tCap[t1], vtCap[t1]
    # sGovCapRev[t1], vGovCapRev[t1]
    # sGovSub_Residual[t1], vGovSub[t1]
    # sGovCapTransExp[t1], vGovCapTransExp[t1]
  end

  return block
end

end # module
