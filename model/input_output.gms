# ======================================================================================================================
# Input-output
# Demand for energy, other intermediate inputs, investments, private and public consumption, and exports
# is allocated to imports and output from domestic industries.
# ======================================================================================================================

# ----------------------------------------------------------------------------------------------------------------------
# Variable and dummy definitions
# ----------------------------------------------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1Y_i_d[i,d,t] "Dummy. Does the IO cell exist? (for domestic deliveries from industry i to demand d)"
  d1M_i_d[i,d,t] "Dummy. Does the IO cell exist? (for imports from industry i to demand d)"
  d1YM_i_d[i,d,t] "Dummy. Does the IO cell exist? (for demand d and industry i)"
  d1Y_d[d,t] "Dummy. Does the IO cell exist? (any domestic deliveries to demand d)"
  d1M_d[d,t] "Dummy. Does the IO cell exist? (any imports to demand d)"
  d1YM_d[d,t] "Dummy. Does the IO cell exist?"
  d1Y_i[i,t] "Dummy. Does the IO cell exist? (any domestic production from industry i)"
  d1M_i[i,t] "Dummy. Does the IO cell exist? (any imports from industry i)"
;

$Group+ all_variables
  pGDP[t] "GDP deflator."
  qGDP[t] "Real Gross Domestic product."
  vGDP[t] "Gross Domestic product."
 
  pGVA[t] "GVA deflator."
  qGVA[t] "Real Gross value added."
  vGVA[t] "Gross value added."

  vR[t] "Non-energy intermediate inputs."
  vE[t] "Energy intermediate inputs."
  vI[t] "Investments."
  vC[t] "Private consumption."
  vG[t] "Public consumption."
  vX[t] "Exports."

  pR[t] "Deflator for non-energy intermediate inputs."
  pE[t] "Deflator for energy intermediate inputs."
  pI[t] "Deflator for investments."
  pC[t] "Deflator for private consumption."
  pG[t] "Deflator for public consumption."
  pX[t] "Deflator for exports."
  
  qR[t] "Real non-energy intermediate inputs."
  qE[t] "Real energy intermediate inputs."
  qI[t] "Real investments."
  qC[t] "Real private consumption."
  qG[t] "Real public consumption."
  qX[t] "Real exports."

  pY_i[i,t] "Price of domestic output by industry."
  qY_i[i,t] "Real output by industry."
  vY_i[i,t] "Output by industry."

  pY[t] "Deflator for total output."
  qY[t] "Real total output."
  vY[t] "Total output."

  pM_i[i,t] "Price of imports by industry."
  qM_i[i,t]$(m[i]) "Real imports by industry."
  vM_i[i,t]$(m[i]) "Imports by industry."

  pM[t] "Deflator for total imports."
  qM[t] "Real imports."
  vM[t] "Total imports."

  pD[d,t]$(d1YM_d[d,t]) "Deflator of demand component."
  qD[d,t]$(d1YM_d[d,t]) "Real demand by demand component."
  vD[d,t]$(d1YM_d[d,t]) "Demand by demand component."

  pY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Price of domestic output by industry and demand component."
  qY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Real output by industry and demand component."
  vY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Output by industry and demand component."

  pM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Price of imports by industry and demand component."
  qM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Real imports by industry and demand component."
  vM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Imports by industry and demand component."

  tY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Duties on domestic output by industry and demand component."
  tM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Duties on imports by industry and demand component."
  vtY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Net duties on imports by industry and demand component."
  vtY_i[i,t] "Net duties on domestic production by industry."
  vtM_i[i,t]$(m[i]) "Net duties on imports by industry."
  vtY[t] "Net duties on domestic production."
  vtM[t] "Net duties on imports."

  jfpY_i_d[i,d,t] "Deviation from average industry price."
  jfpM_i_d[i,d,t] "Deviation from average industry price."

  rYM[i,d,t]$(d1YM_i_d[i,d,t]) "industry composition of demand."
  rYM_energy[i,t]$(sum(re, d1Y_i_d[i,re,t])) "Used in linking between energy-markets and input-output."

  rM[i,d,t]$(d1YM_i_d[i,d,t]) "Import share."
  rM_energy[i,t]$(sum(re, d1M_i_d[i,re,t])) "Used in linking between energy-markets and input-output."
  fYM[d,t] "Deviation from law of one price."
;
$ENDIF # variables

# ----------------------------------------------------------------------------------------------------------------------
# Equations
# ----------------------------------------------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK input_output_equations input_output_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. vGDP[t] =E= vC[t] + vI[t] + vG[t] + vX[t] - vM[t];
  .. pGDP[t] * qGDP[t] =E= vGDP[t];
  .. qGDP[t] * pGDP[t-1] =E= pC[t-1] * qC[t]
                           + pI[t-1] * qI[t]
                           + pG[t-1] * qG[t]
                           + pX[t-1] * qX[t]
                           - pM[t-1] * qM[t]; # /fp cancels out

  .. vGVA[t] =E= vY[t] - vR[t] - vE[t];
  .. pGVA[t] * qGVA[t] =E= vGVA[t];
  .. qGVA[t] * pGVA[t-1] =E= pY[t-1] * qY[t]
                           - pR[t-1] * qR[t]
                           - pE[t-1] * qE[t]; # /fp cancels out

  # Demand aggregates
  .. vR[t] =E= sum(rx, vD[rx,t]);
  .. vE[t] =E= sum(re, vD[re,t]); #Only firms aggregate of energy-input, households energy is in vC and exports in vX.
  .. vI[t] =E= sum(k, vD[k,t]) + vD['invt',t];
  .. vC[t] =E= sum(c, vD[c,t]);
  .. vG[t] =E= sum(g, vD[g,t]);
  .. vX[t] =E= sum(x, vD[x,t]);

  .. pR[t] * qR[t] =E= vR[t];
  .. pE[t] * qE[t] =E= vE[t];
  .. pI[t] * qI[t] =E= vI[t];
  .. pC[t] * qC[t] =E= vC[t];
  .. pG[t] * qG[t] =E= vG[t];
  .. pX[t] * qX[t] =E= vX[t];

  .. qR[t] * pR[t-1] =E= sum(rx, pD[rx,t-1] * qD[rx,t]);
  .. qE[t] * pE[t-1] =E= sum(re, pD[re,t-1] * qD[re,t]);
  .. qI[t] * pI[t-1] =E= sum(k, pD[k,t-1] * qD[k,t]) + pD['invt',t-1] * qD['invt',t] + pD['invt_ene',t-1]*qD['invt_ene',t];
  .. qC[t] * pC[t-1] =E= sum(c, pD[c,t-1] * qD[c,t]);
  .. qG[t] * pG[t-1] =E= sum(g, pD[g,t-1] * qD[g,t]);
  .. qX[t] * pX[t-1] =E= sum(x, pD[x,t-1] * qD[x,t]);

  # Equilibrium condition: supply + net duties = demand in each industry.
  .. vY_i[i,t] + vtY_i[i,t] =E= sum(d, vY_i_d[i,d,t]);
  .. vY[t] =E= sum(i, vY_i[i,t]);
  .. pY[t] * qY[t] =E= vY[t];
  .. qY[t] * pY[t-1] =E= sum(i, pY_i[i,t-1] * qY_i[i,t]);

  .. qY_i[i,t] =E= sum(d, qY_i_d[i,d,t] / (1+tY_i_d[i,d,tBase]));
  .. qM_i[i,t] =E= sum(d, qM_i_d[i,d,t] / (1+tM_i_d[i,d,tBase]));

  # Aggregate imports from each import industry
  .. vM_i[i,t] + vtM_i[i,t] =E= sum(d, vM_i_d[i,d,t]);
  .. vM[t] =E= sum(i, vM_i[i,t]);
  .. pM[t] * qM[t] =E= vM[t];
  .. qM[t] * pM[t-1] =E= sum(i, pM_i[i,t-1] * qM_i[i,t]);

  # Net duties on domestic production and imports
  .. vtY_i_d[i,d,t] =E= tY_i_d[i,d,t] * (vY_i_d[i,d,t] - vtY_i_d[i,d,t]);
  .. vtM_i_d[i,d,t] =E= tM_i_d[i,d,t] * (vM_i_d[i,d,t] - vtM_i_d[i,d,t]);

  .. vtY_i[i,t] =E= sum(d, vtY_i_d[i,d,t]);
  .. vtM_i[i,t] =E= sum(d, vtM_i_d[i,d,t]);

  .. vtY[t] =E= sum(i, vtY_i[i,t]);
  .. vtM[t] =E= sum(i, vtM_i[i,t]);

  # Real demand, qD, is determined in other modules. E.g. consumption chosen by households, factor inputs by firms.
  .. vD[d,t] =E= sum(i, vY_i_d[i,d,t] + vM_i_d[i,d,t]);
  .. pD[d,t] * qD[d,t] =E= vD[d,t];

  # Input-output prices reflect industry-prices or import prices, plus any taxes
  # jfp[YM]_d can be endogenized by submodels to reflect pricing-to-market etc.
  .. pY_i_d[i,d,t] =E= (1+tY_i_d[i,d,t]) / (1+tY_i_d[i,d,tBase]) * (1+jfpY_i_d[i,d,t]) * pY_i[i,t];
  .. pM_i_d[i,d,t] =E= (1+tM_i_d[i,d,t]) / (1+tM_i_d[i,d,tBase]) * (1+jfpM_i_d[i,d,t]) * pM_i[i,t];

  # rYM is the real industry-composition for each demand - rYM is exogenous here, but can be endogenized in submodels
  # rM is the real import-share for each demand - rM is exogenous here, but can be endogenized in submodels
  .. qY_i_d[i,d,t] =E= (1-rM[i,d,t]) * rYM[i,d,t] * qD[d,t];
  .. qM_i_d[i,d,t] =E= rM[i,d,t]     * rYM[i,d,t] * qD[d,t];

  .. vY_i_d[i,d,t] =E= pY_i_d[i,d,t] * qY_i_d[i,d,t];
  .. vM_i_d[i,d,t] =E= pM_i_d[i,d,t] * qM_i_d[i,d,t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / input_output_equations /;
$Group+ main_endogenous input_output_endogenous;

$ENDIF # equations

# ----------------------------------------------------------------------------------------------------------------------
# Data and exogenous parameters
# ----------------------------------------------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group input_output_data_variables
  vY_i_d, vtY_i_d
  vM_i_d, vtM_i_d
;
# $Group+ data_covered_variables input_output_data_variables$(t.val <= %calibration_year%),-vY_i_d[i,'energy',t];
$Group+ data_covered_variables input_output_data_variables$(t.val <= %calibration_year%);

@load(input_output_data_variables, "../data/data.gdx")

d1Y_i_d[i,d,t] = abs(vY_i_d.l[i,d,t]) > 1e-9;
d1M_i_d[i,d,t] = abs(vM_i_d.l[i,d,t]) > 1e-9;
d1YM_i_d[i,d,t] = d1Y_i_d[i,d,t] or d1M_i_d[i,d,t];
d1Y_d[d,t] = sum(i, d1Y_i_d[i,d,t]);
d1M_d[d,t] = sum(i, d1M_i_d[i,d,t]);
d1Y_i[i,t] = sum(d, d1Y_i_d[i,d,t]);
d1M_i[i,t] = sum(d, d1M_i_d[i,d,t]);
d1YM_d[d,t] = d1Y_d[d,t] or d1M_d[d,t];

rM.l[i,d,t]$(d1M_i_d[i,d,t] and not d1Y_i_d[i,d,t]) = 1;
rM.l[i,d,t]$(d1Y_i_d[i,d,t] and not d1M_i_d[i,d,t]) = 0;

pY_i.l[i,t] = fpt[t];
pM_i.l[i,t] = fpt[t];
pD.l[d,t]   = fpt[t];

# Lagged values used in chain price indices - should be added to data unless we switch to fixed price indices
pR.l[t] = fpt[t];
pE.l[t] = fpt[t];
pI.l[t] = fpt[t];
pC.l[t] = fpt[t];
pG.l[t] = fpt[t];
pX.l[t] = fpt[t];

pM.l[t] = fpt[t];
pY.l[t] = fpt[t];

pGDP.l[t] = fpt[t];
pGVA.l[t] = fpt[t];

$ENDIF # exogenous_values

# ----------------------------------------------------------------------------------------------------------------------
# Calibration
# ----------------------------------------------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK input_output_calibration_equations input_output_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  input_output_equations
  # input_output_calibration_equations
/;
# Add endogenous variables to calibration model
$Group+ calibration_endogenous
  input_output_endogenous
  input_output_calibration_endogenous
  -vtY_i_d[i,d,t1], tY_i_d[i,d,t1]
  -vtM_i_d[i,d,t1], tM_i_d[i,d,t1]
  -vY_i_d[i,d,t1], -vM_i_d[i,d,t1], rYM[i,d,t1], rM[i,d,t]$(t1[t] and d1M_i_d[i,d,t] and d1Y_i_d[i,d,t]) 

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  rYM, rM
;

$ENDIF # calibration