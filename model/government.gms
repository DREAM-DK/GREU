# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vG[t] "Government consumption expenditure."
  rG_g[g,t] "Share of total government consumption expenditure by purpose."
  vG2vGDP[t] "Government consumption expenditure to GDP ratio."

  vGovPrimaryBalance[t] "Primary balance of government."
  vGovRevenue[t] "Revenue of government."
  vGovExpenditure[t] "Expenditure of government."

  vtIndirect[t] "Revenue from indirect taxes."
  vtIndirect_other[i,t] "Indirect taxes not directly linked to the input-output module"
  sIndirect_other[t]  "Other indirect taxes relative to GVA"

  vtDirect[t] "Total direct taxes"
  vtHhReturn[t] "Taxation of households return on wealth"
  vtHhWages[t] "Taxation of households wages"
  trHh[t] "Marginal tax rate on households return on wealth"
  tW[t] "Marginal tax rate on households wages"
  vtCorp[t] "Taxation of corporations"
  tCorp[t] "Tax rate on corporations"
  vtDirect_other[t] "Residual direct taxes"
  sDirect_other[t] "Residual direct taxes relative to GVA"

  vGovRevOther[t] "Other government revenues"
  vCont[t] "Contributions to social security"
  vContExo[t] "Exogenous contributions to social security"
  vGovRevGovCorp[t] "Revenue from public production"
  vGovDepr[t] "Depreciation of public capital"
  vGovRevGovCorpCorrection[t] "Correction to revenue from public production"
  vGovDeprCorrection[t] "Correction to depreciation of public capital"
  vGovRevQuasi[t] "Revenue from quasi-corporations"
  vGovRent[t] "Revenue from rent"
  vtGovDepr[t] "Depreciation of public capital"
  vGovReceiveCorp[t] "Capital transfers from corporations"
  vGovReceiveCorpNonCap[t] "Other transfers from corporations"
  sGovReceiveCorp[t] "Share of capital transfers from corporations relative to GVA"
  sGovReceiveCorpNonCap[t] "Share of other transfers from corporations relative to GVA"
  vGovReceiveF[t] "Transfers from foreign countries"
  vtCap[t] "Capital taxes"
  tCap[t] "Capital tax rate"

  vHhTransfers[t] "Transfers to households and non-profits from government."
  vGov2Corp[t] "Transfers to corporations"
  sGov2Corp[t] "Share of gross value added transferred to corporations"
  vGovSub[t] "Government subsidies to corporations"
  sGovSub_Residual[t] "Residual government subsidies to corporations"
  qPopTransfers[t] "Population receiving transfers"
  vGov2Foreign[t] "Transfers form government to foreign countries"
  vGovNetAcquisitions[t] "Net acquisitions of non-produced non-financial assets"
  vLumpsum[t] "Lumpsum transfers from government to households"

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
 
  .. vGovPrimaryBalance[t] =E= vGovRevenue[t] - vGovExpenditure[t];

# Government revenues
  .. vGovRevenue[t] =E=     + vtIndirect[t]
                            + vtDirect[t]
                            + vGovRevOther[t]
                            ;


  .. vtIndirect[t] =E=    vtY[t] + vtM[t] # Net duties, paid through R, E, I, C, G, and X
                        + vtY_Tax[t]  - vtCO2_ETS_tot[t] #Production taxes minus ETS-revenue
                        + sum(i, vtCO2_xE[i,t])
                        + sum(i, vtIndirect_other[i,t])
                        ;

  .. vtIndirect_other[i,t] =E= sIndirect_other[t] * vGVA_i[i,t];                      


  .. vtDirect[t] =E= vtHhReturn[t] + vtHhWages[t] + vtCorp[t] + vtDirect_other[t];
  .. vtHhReturn[t] =E= trHh[t] * rHh[t] * vNetFinAssets['Hh',t-1]/fv;
  .. vtHhWages[t] =E= tW[t] * vWages[t];
  .. vtCorp[t] =E= tCorp[t] * sum(i, vEBITDA_i[i,t]-vDepr_i[i,t]);
  .. vtDirect_other[t] =E= sDirect_other[t] * (vtHhReturn[t] + vtHhWages[t]);


  .. vGovRevOther[t] =E= 
                            + vGovRevGovCorp[t]
                            + vGovDepr[t]
                            + vCont[t]
                            + vGovReceiveCorp[t]
                            + vGovReceiveCorpNonCap[t]
                            + vGovReceiveF[t]
                            + vtCap[t]
                            ;

  .. vCont[t] =E= pW[t] * vContExo[t];

  ..vGovRevGovCorp[t] =E= sum(i$i_public[i], vEBITDA_i[i,t]-vDepr_i[i,t]) + vGovRevGovCorpCorrection[t];

  ..vGovDepr[t] =E= sum(i$i_public[i], vDepr_i[i,t]) + vGovDeprCorrection[t];

  ..vGovReceiveCorp[t] =E= sGovReceiveCorp[t] * sum(i, vGVA_i[i,t]);
  ..vGovReceiveCorpNonCap[t] =E= sGovReceiveCorpNonCap[t] * sum(i, vGVA_i[i,t]);

  ..vtCap[t] =E= tCap[t] * vNetFinAssets['Hh',t];


# Government expenditures

  .. vGovExpenditure[t] =E= vG[t] + vHhTransfers[t] + vI_public[t]
                          + vGovSub[t] + vGov2Corp[t] + vGov2Foreign[t] + vGovNetAcquisitions[t] + vLumpsum[t];


  rG_g[g,t]$(first(g)).. vG[t] =E= vG2vGDP[t] * vGDP[t];  # Government consumption expenditure to GDP ratio
  qD[g,t].. vD[g,t] =E= rG_g[g,t] * vG[t];


  .. vHhTransfers[t] =E= pW[t-3] * qPopTransfers[t]; 

  .. vGovSub[t] =E= vtY_Sub[t] + sGovSub_Residual[t] * sum(i,vGVA_i[i,t]);

  .. vGov2Corp[t] =E= sGov2Corp[t] * sum(i, vGVA_i[i,t]);



# Income flow to the other sectors

 .. vNetGov2Corp_xIO[i,t] =E= (sGov2Corp[t] + sGovSub_Residual[t] - sGovReceiveCorp[t] - sGovReceiveCorpNonCap[t]) 
                                * vGVA_i[i,t]
                              - vtCO2_xE[i,t] 
                              - vtIndirect_other[i,t] 
                              - tCorp[t] * (vEBITDA_i[i,t]-vDepr_i[i,t]);


  .. vNetHh2Gov[t] =E= vtHhWages[t] + vtHhReturn[t] + vtDirect_other[t] 
                       + vCont[t] + vGovRevGovCorpCorrection[t] + vGovDeprCorrection[t] + vtCap[t]  
                       - vHhTransfers[t] - vGovNetAcquisitions[t] - vLumpsum[t];


  .. vNetGov2Foreign[t] =E= vGov2Foreign[t] + vtCO2_ETS_tot[t] - vGovReceiveF[t];

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

  vtIndirect[t]
  vtDirect[t]
  vtCorp[t]
  vCont[t]
  vGovRevQuasi[t]
  vGovRent[t]
  vtGovDepr[t]
  vGovReceiveCorp[t]
  vGovReceiveCorpNonCap[t]
  vGovReceiveF[t]
  vtCap[t]

  vGov2Corp[t]
  vGovSub[t]
  vHhTransfers[t]
  vGov2Foreign[t]
  vGovNetAcquisitions[t]

;
@load(government_data_variables, "../data/data.gdx")
$Group+ data_covered_variables government_data_variables$(t.val <= %calibration_year%);

trHh.l[t] = 0.25;
tW.l[t] = 0.4;

vGovDepr.l[t] = vtGovDepr.l[t];
vGovRevGovCorp.l[t] = vGovRevQuasi.l[t] + vGovRent.l[t];

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
  government_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  government_endogenous
  government_calibration_endogenous
  -qD[g,t1], rG_g[g,t1], vG2vGDP[t1]
  -vtIndirect[t1], sIndirect_other[t1]
  -vtCorp[t1], tCorp[t1]
  -vtDirect[t1], sDirect_other[t1]
  -vCont[t1], vContExo[t1]
  -vGovRevGovCorp[t1], vGovRevGovCorpCorrection[t1]
  -vGovDepr[t1], vGovDeprCorrection[t1]
  -vGovReceiveCorp[t1], sGovReceiveCorp[t1]
  -vGovReceiveCorpNonCap[t1], sGovReceiveCorpNonCap[t1]
  -vtCap[t1], tCap[t1]
  -vGov2Corp[t1], sGov2Corp[t1]
  -vGovSub[t1], sGovSub_Residual[t1]
  -vHhTransfers[t1], qPopTransfers[t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  vG2vGDP[t]
  rG_g[c,t]
  sIndirect_other[t]
  tCorp[t]
  sDirect_other[t]  
  sGov2Corp[t]
  sGovSub_Residual[t]
  qPopTransfers[t]
  vGov2Foreign[t]
  vGovNetAcquisitions[t]
  vContExo[t]
  sGovReceiveCorp[t]
  sGovReceiveCorpNonCap[t]
  tCap[t]
;

$Group+ G_zero_after_last_data_year
  vGovRevGovCorpCorrection[t]
  vGovDeprCorrection[t]
;

$Group+ G_zero_t1_after_static_calibration
  vLumpsum[t]
;

$ENDIF # calibration