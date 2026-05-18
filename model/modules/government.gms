# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vG[t] "Government consumption expenditure."
  rG_g[g,t] "Share of total government consumption expenditure by purpose."
  vG2vGDP[t] "Government consumption expenditure to GDP ratio."

  vGovBalance[t] "Primary balance of government."
  vGovRevenue[t] "Revenue of government."
  vGovExpenditure[t] "Expenditure of government."
  vGovPrimaryBalance[t] "Primary balance of government."

  vtIndirect[t] "Revenue from indirect taxes."
  vtIndirect_other[i,t] "Indirect taxes not directly linked to the input-output module"
  sIndirect_other[t]  "Other indirect taxes relative to GVA"

  vtDirect[t] "Revenue from direct taxes."
  vtHhIncome[t] "Revenue from households income taxes."
  vtHhReturn[t] "Taxation of households return on wealth"
  vtHhWages[t] "Taxation of households wages"
  trHh[t] "Marginal tax rate on households return on wealth"
  tW[t] "Marginal tax rate on households wages"
  vtCorp[t] "Taxation of corporations"
  tCorp[t] "Tax rate on corporations"
  vtDirect_other[t] "Residual direct taxes."
  sDirect_other[t] "Residual direct taxes relative household and corporate taxes."

  vGovRevOther[t] "Other revenue of government."
  vGovSalesRev[t] "Revenue from sales."
  vGovOthSubRev[t] "Revenue from other subsidies."
  vGovPropertyIncome[t] "Revenue from property income."
  vGovSocialContRev[t] "Revenue from social contributions."
  vGovOthCurrentTransRev[t] "Revenue from other current transfers."
  vtCap[t] "Revenue from capital taxes."
  tCap[t] "Capital tax rate."
  vGovCapRev[t] "Revenue from capital transfers."
  sGovCapRev[t] "Share of capital transfers relative to GVA."
  vGovIntermediateCons[t] "Intermediate consumption of government."
  vGovCapInv[t] "Capital investment of government."
  vGovDepr[t] "Depreciation of government capital."
  vGovEmplComp[t] "Employment compensation of government."
  vGovOthProdTax[t] "Other production taxes of government."
  vGovSub[t] "Subsidies of government."
  sGovSub_Residual[t] "Residual government subsidies to corporations"
  vGovInterestPayments[t] "Interest payments of government."
  vGovSocBenefitExp[t] "Social benefit expenditure of government."
  vSocTransKind[t] "Social transfer kind."
  vGovOthCurrentTransExp[t] "Other current transfers expenditure of government."
  sGovOthCurrentTransRev[t] "Share of other current transfers relative to GVA."
  vGovAdjExp[t] "Adjustments of government."
  vGovCapTransExp[t] "Capital transfers expenditure of government."
  sGovCapTransExp[t] "Share of capital transfers expenditure relative to GVA."
  vGovNetAcquisitions[t] "Net acquisitions of non-produced non-financial assets of government."
  vLumpsum[t] "Lumpsum transfers from government to households"

  # J-terms for energy and emissions tax variables (endogenized by energy_and_emissions_taxes module when active)
  jvtCO2_ETS_tot[t] "Total revenue from ETS1 and ETS2 (endogenized by energy_and_emissions_taxes module when active)."
  jvtCO2_xE[i,t] "Tax revenue from national carbon tax, non-energy related emissions (endogenized by energy_and_emissions_taxes module when active)."

  # Missing
  vNetGov2Corp_xIO[i,t] "Net transfers from goverment to corporations not covered in the input-output module"
  vNetHh2Gov[t] "Net transfers from households to government"  
  vNetGov2Foreign[t] "Net transfers from government to foreign countries"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK government_equations government_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
 
 # Government balance
  .. vGovBalance[t] =E= vGovRevenue[t] - vGovExpenditure[t];
  .. vGovPrimaryBalance[t] =E= vGovBalance[t] - vGovInterestPayments[t];

# Government revenues
  .. vGovRevenue[t] =E=     + vtIndirect[t]
                            + vtDirect[t]
                            + vGovRevOther[t]
                            ;

  .. vtIndirect[t] =E=      + vtY[t] + vtM[t] # Net duties, paid through R, E, I, C, G, and X
                            + vtY_Tax[t]  - jvtCO2_ETS_tot[t] #Production taxes minus ETS-revenue
                            + sum(i, jvtCO2_xE[i,t])
                            + sum(i, vtIndirect_other[i,t])
                            ;
  .. vtIndirect_other[i,t] =E= sIndirect_other[t] * vGVA_i[i,t];

  .. vtDirect[t] =E=        + vtHhIncome[t]
                            + vtCorp[t]
                            + vtDirect_other[t]
                            ;
  .. vtHhIncome[t] =E=      + vtHhReturn[t]
                            + vtHhWages[t]
                            ; 
  .. vtHhReturn[t] =E= trHh[t] * rHh[t] * vNetFinAssets['Hh',t-1]/fv; 
  .. vtHhWages[t] =E= tW[t] * vWages[t];

  .. vtCorp[t] =E= tCorp[t] * sum(i, vEBITDA_i[i,t]-vDepr_i[i,t]);

  .. vtDirect_other[t] =E= sDirect_other[t] * vtHhIncome[t];

  .. vGovRevOther[t] =E=    + vGovSalesRev[t] 
                            + vGovOthSubRev[t] 
                            + vGovPropertyIncome[t] 
                            + vGovSocialContRev[t] 
                            + vGovOthCurrentTransRev[t] 
                            + vtCap[t]
                            + vGovCapRev[t]
                            ;
  .. vGovOthCurrentTransRev[t] =E= sGovOthCurrentTransRev[t] * sum(i, vGVA_i[i,t]);
  .. vtCap[t] =E= tCap[t] * vNetFinAssets['Hh',t];
  .. vGovCapRev[t] =E= sGovCapRev[t] * sum(i, vGVA_i[i,t]);

# Government expenditure
  .. vGovExpenditure[t] =E= + vGovIntermediateCons[t]
                            + vGovCapInv[t]
                            + vGovEmplComp[t]
                            + vGovOthProdTax[t] 
                            + vGovSub[t]
                            + vGovInterestPayments[t] 
                            + vGovSocBenefitExp[t]
                            + vGovOthCurrentTransExp[t]
                            + vGovAdjExp[t]
                            + vGovCapTransExp[t]
                            + vGovNetAcquisitions[t]
                            + vLumpsum[t]
                            ;
  
  .. vGovSub[t] =E= vtY_Sub[t] + sGovSub_Residual[t] * sum(i,vGVA_i[i,t]);

  .. vGovCapTransExp[t] =E= sGovCapTransExp[t] * sum(i, vGVA_i[i,t]);

  # .. vG[t] =E= vGovEmplComp[t] + vGovDepr[t] + vGovIntermediateCons[t] + vGovOthProdTax[t] + vSocTransKind[t]
  #              - vGovSalesRev[t] - vGovOthSubRev[t];
  
  rG_g[g,t]$(first(g)).. vG[t] =E= vG2vGDP[t] * vGDP[t];  # Government consumption expenditure to GDP ratio
  qD[g,t].. vD[g,t] =E= rG_g[g,t] * vG[t];

$ENDBLOCK

# Add equation and endogenous variables to main model
model main / government_equations /;
$Group+ main_endogenous government_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group government_data_variables
  qD[g,t]

  vGovBalance[t]
  vGovRevenue[t]
  vGovExpenditure[t]

  vtIndirect[t]
  vtDirect[t]
  vGovSalesRev[t]
  vGovOthSubRev[t]
  vGovPropertyIncome[t]
  vGovSocialContRev[t]
  vGovOthCurrentTransRev[t]
  vtCap[t]
  vGovCapRev[t]

  vtHhIncome[t]
  vtCorp[t]

  vGovIntermediateCons[t]
  vGovCapInv[t]
  vGovDepr[t]
  vGovEmplComp[t]
  vGovOthProdTax[t]
  vGovSub[t]
  vGovInterestPayments[t]
  vGovSocBenefitExp[t]
  vGovOthCurrentTransExp[t]
  vGovAdjExp[t]
  vGovCapTransExp[t]
  vGovNetAcquisitions[t]
  vSocTransKind[t]

;
@load(government_data_variables, "../data/data.gdx")
$Group+ data_covered_variables government_data_variables$(t.val <= %calibration_year%);

trHh.l[t] = 0.25;
tW.l[t] = 0.4;

# Initialize J-terms for energy and emissions tax variables to zero (allows partial equilibrium when energy modules are off)
jvtCO2_ETS_tot.l[t] = 0;
jvtCO2_xE.l[i,t] = 0;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

# $BLOCK government_calibration_equations government_calibration_endogenous
$BLOCK government_calibration_equations government_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

  vLumpsum&_t1[t]$(t.val = tEnd.val).. vNetFinAssets['Gov',t] =E= vNetFinAssets['Gov',t-1];
  vLumpsum[t]$(t1.val < t.val and t.val < tEnd.val).. vLumpsum[t] =E= vLumpsum[t+1]*0.9;

$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  government_equations
  # government_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  government_endogenous
  # government_calibration_endogenous
  -vtIndirect[t1], sIndirect_other[t1]
  -vtHhIncome[t1], trHh[t1]
  -vtDirect[t1], sDirect_other[t1]
  -vGovOthCurrentTransRev[t1], sGovOthCurrentTransRev[t1]
  -vtCorp[t1], tCorp[t1] 
  -vtCap[t1], tCap[t1]
  -vGovCapRev[t1], sGovCapRev[t1]

  -vGovSub[t1], sGovSub_Residual[t1]
  -vGovCapTransExp[t1], sGovCapTransExp[t1]
  -qD[g,t1], rG_g[g,t1], vG2vGDP[t1]
  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  sIndirect_other[t]
  sDirect_other[t]
  tCorp[t]
  tCap[t]
  sGovCapRev[t]
  sGovCapTransExp[t]
  sGovSub_Residual[t]

  vG2vGDP[t]
  rG_g[c,t]
;

$Group+ G_zero_after_last_data_year

;

$Group+ G_zero_t1_after_static_calibration
  vLumpsum[t]
;

# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO government_calibration_starting_values

$ENDIF # calibration