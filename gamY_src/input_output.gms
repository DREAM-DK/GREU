# ======================================================================================================================
# Input-output
# Demand for energy, other intermediate inputs, investments, private and public consumption, and exports
# is allocated to imports and output from domestic industries.
# ======================================================================================================================

# ----------------------------------------------------------------------------------------------------------------------
# Variable definitions
# ----------------------------------------------------------------------------------------------------------------------
set d1Y_i_d[i,d,t] "Dummy. Does the IO cell exist? (for domestic deliveries from industry i to demand d)" / /;
set d1M_i_d[i,d,t] "Dummy. Does the IO cell exist? (for imports from industry i to demand d)" / /;
set d1YM_i_d[i,d,t] "Dummy. Does the IO cell exist? (for demand d and industry i)" / /;

$Group+ price_variables
  pY_i[i,t] "Price of domestic output by industry."
  pM_i[i,t] "Price of imports by industry."

  pD_d[d,t] "Price of demand component."
  pR_di[di,t] "Price of intermediate inputs by industry demanding the inputs."
  pE_di[di,t] "Price of ergy inputs by industry demanding the ergy."
  pI_k[k,t] "Price of investment goods."
  pC_c[c,t] "Price of private consumption goods."
  SG_g[g,t] "Price of government consumption goods."
  pX_x[x,t] "Price of export goods."

  pY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Price of domestic output by industry and demand component."
  pM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Price of imports by industry and demand component."
;
$Group+ quantity_variables
  qY_i[i,t] "Real output by industry."
  qM_i[i,t]$(m[i]) "Real imports by industry."

  qD_d[d,t] "Real demand by demand component."
  qR_di[di,t] "Real intermediate inputs, by industry demanding the inputs."
  qE_di[di,t] "Real ergy inputs, by industry demanding the ergy."
  qI_k[k,t] "Real investments."
  qC_c[c,t] "Real private consumption."
  qG_g[g,t] "Real government consumption."
  qX_x[x,t] "Real exports."

  qY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Real output by industry and demand component."
  qM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Real imports by industry and demand component."
;
$Group+ value_variables
  vY_i[i,t] "Output by industry."
  vM_i[i,t]$(m[i]) "Imports by industry."

  vD_d[d,t] "Demand by demand component."
  vY_d[d,t] "Output by demand component."
  vM_d[d,t] "Imports by demand component."
  vR_di[di,t] "Intermediate inputs, by industry demanding the inputs."
  vE_di[di,t] "ergy inputs, by industry demanding the ergy."
  vI_k[k,t] "Investments."
  vC_c[c,t] "Private consumption."
  vG_g[g,t] "Government consumption."
  vX_x[x,t] "Exports."

  vY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Output by industry and demand component."
  vM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Imports by industry and demand component."

  vtY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Net duties on imports by industry and demand component."
  vtY_i[i,t] "Net duties on domestic production."
  vtM_i[i,t]$(m[i]) "Net duties on imports."
;
$Group+ other_variables
  tY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Duties on domestic output by industry and demand component."
  tM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Duties on imports by industry and demand component."
  jfpY_i_d[i,d,t] "Deviation from average industry price."
  jfpM_i_d[i,d,t] "Deviation from average industry price."

  rYM[i,d,t]$(d1YM_i_d[i,d,t]) "industry composition of demand."
  rM[i,d,t]$(d1YM_i_d[i,d,t]) "Import share."
  fYM[d,t] "Deviation from law of one price."
;

# ----------------------------------------------------------------------------------------------------------------------
# Equations
# ----------------------------------------------------------------------------------------------------------------------
$BLOCK input_output_equations input_output_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Equilibrium condition: supply + net duties = demand in each industry.
  .. vY_i[i,t] + vtY_i[i,t] =E= sum(d, vY_i_d[i,d,t]);

  # Aggregate imports from each import industry
  .. vM_i[i,t] + vtM_i[i,t] =E= sum(d, vM_i_d[i,d,t]);

  # Net duties on domestic production and imports
  .. vtY_i_d[i,d,t] =E= tY_i_d[i,d,t] * (vY_i_d[i,d,t] - vtY_i_d[i,d,t]);
  .. vtM_i_d[i,d,t] =E= tM_i_d[i,d,t] * (vM_i_d[i,d,t] - vtM_i_d[i,d,t]);

  .. vtY_i[i,t] =E= sum(d, vtY_i_d[i,d,t]);
  .. vtM_i[i,t] =E= sum(d, vtM_i_d[i,d,t]);

  # Demand aggregates.
  # The quantities, qD_d, are determined in other modules. E.g. consumption chosen by households, factor inputs by firms.
  .. vD_d[d,t] =E= vY_d[d,t] + vM_d[d,t];
  .. pD_d[d,t] * qD_d[d,t] =E= vD_d[d,t];

  .. vY_d[d,t] =E= sum(i, vY_i_d[i,d,t]);
  .. vM_d[d,t] =E= sum(i, vM_i_d[i,d,t]);

  # Input-output prices reflect industry-prices or import prices, plus any taxes
  # jfp[YM]_d can be endogenized by submodels to reflect pricing-to-market etc.
  .. pY_i_d[i,d,t] =E= (1+tY_i_d[i,d,t]) / (1+tY_i_d[i,d,tBase]) * (1+jfpY_i_d[i,d,t]) * pY_i[i,t];
  .. pM_i_d[i,d,t] =E= (1+tM_i_d[i,d,t]) / (1+tM_i_d[i,d,tBase]) * (1+jfpM_i_d[i,d,t]) * pM_i[i,t];

  # rYM is the real industry-composition for each demand - rYM is exogenous here, but can be endogenized in submodels
  # rM is the real import-share for each demand - rM is exogenous here, but can be endogenized in submodels
  .. qY_i_d[i,d,t] =E= (1-rM[i,d,t]) * rYM[i,d,t] * qD_d[d,t];
  .. qM_i_d[i,d,t] =E= rM[i,d,t] * rYM[i,d,t] * qD_d[d,t];
  # Demand price indices
  pR_di[di,t].. pR_di[di,t] * qR_di[di,t] =E= vR_di[di,t];
  pE_di[di,t].. pE_di[di,t] * qE_di[di,t] =E= vE_di[di,t];
  pI_k[k,t].. pI_k[k,t] * qI_k[k,t] =E= vI_k[k,t];
  pC_c[c,t].. pC_c[c,t] * qC_c[c,t] =E= vC_c[c,t];
  SG_g[g,t].. SG_g[g,t] * qG_g[g,t] =E= vG_g[g,t];
  pX_x[x,t].. pX_x[x,t] * qX_x[x,t] =E= vX_x[x,t];

  .. vY_i_d[i,d,t] =E= pY_i_d[i,d,t] * qY_i_d[i,d,t];
  .. vM_i_d[i,d,t] =E= pM_i_d[i,d,t] * qM_i_d[i,d,t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / input_output_equations /;
$Group+ main_endogenous input_output_endogenous;

# ----------------------------------------------------------------------------------------------------------------------
# Data and exogenous parameters
# ----------------------------------------------------------------------------------------------------------------------
$Group input_output_data_variables
  vY_i_d, vtY_i_d
  vM_i_d, vtM_i_d
  vY_d_i, vtY_d_i, tY_d_i
  vM_d_i, vtM_d_i, tM_d_i

  pY_i, qY_i, vY_i
  pM_i, qM_i, vM_i

  pC_c, qC_c, vC_c
  pX_x, qX_x, vX_x
  SG_g, qG_g, vG_g
  pI_k, qI_k, vI_k
  pR_di, qR_di, vR_di
  pE_di, qE_di, vE_di

  # pC, qC
  # pG, qG
  # pX, qX
  # pI, qI
  # pY, qM
  # pM, qY
  # pGDP, qGDP
;
$Group+ data_covered_variables input_output_data_variables;

@load(input_output_data_variables, "../data/data.gdx")

d1Y_i_d[i,d,t] = vY_i_d.l[i,d,t] <> 0;
d1M_i_d[i,d,t] = vM_i_d.l[i,d,t] <> 0;
d1YM_i_d[i,d,t] = d1Y_i_d[i,d,t] or d1M_i_d[i,d,t];

rM.l[i,d,t]$(d1M_i_d[i,d,t] and not d1Y_i_d[i,d,t]) = 1;
rM.l[i,d,t]$(d1Y_i_d[i,d,t] and not d1M_i_d[i,d,t]) = 0;

# ----------------------------------------------------------------------------------------------------------------------
# Calibration
# ----------------------------------------------------------------------------------------------------------------------
$BLOCK input_output_calibration_equations input_output_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  input_output_equations
  # input_output_calibration_equations
/;
# Add endogenous variables to calibration model
$Group+ input_output_calibration_endogenous
  input_output_endogenous
  -vtY_i_d, tY_i_d$(d1Y_i_d[i,d,t])
  -vtM_i_d, tM_i_d$(d1M_i_d[i,d,t])
  -vY_i_d, -vM_i_d, rYM, rM$(d1M_i_d[i,d,t] and d1Y_i_d[i,d,t]) 
  -pD_d, qD_d
;
$Group+ calibration_endogenous input_output_calibration_endogenous;
