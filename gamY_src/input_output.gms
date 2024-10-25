# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
set d1Y_d_i[d,i,t] "Dummy. Does the IO cell exist? (for domestic deliveries from industry i to demand d)" / /;
set d1M_d_i[d,i,t] "Dummy. Does the IO cell exist? (for imports from industry i to demand d)" / /;
set d1YM_d_i[d,i,t] "Dummy. Does the IO cell exist? (for demand d and industry i)" / /;

$GROUP+ price_variables
  pY_i[i,t] "Price of domestic output by industry."
  pM_i[i,t] "Price of imports by industry."

  pR_di[di,t] "Price of intermediate inputs by industry demanding the inputs."
  pE_di[di,t] "Price of energy inputs by industry demanding the energy."
  pI_k[k,t] "Price of investment goods."
  pC_c[c,t] "Price of private consumption goods."
  pG_g[g,t] "Price of government consumption goods."
  pX_x[x,t] "Price of export goods."

  pY_d_i[d,i,t]$(d1Y_d_i[d,i,t]) "Price of domestic output by industry and demand component."
  pM_d_i[d,i,t]$(d1M_d_i[d,i,t]) "Price of imports by industry and demand component."
;
$GROUP+ quantity_variables
  qY_i[i,t] "Real output by industry."
  qM_i[i,t]$(m[i]) "Real imports by industry."

  qR_di[di,t] "Real intermediate inputs, by industry demanding the inputs."
  qE_di[di,t] "Real energy inputs, by industry demanding the energy."
  qI_k[k,t] "Real investments."
  qC_c[c,t] "Real private consumption."
  qG_g[g,t] "Real government consumption."
  qX_x[x,t] "Real exports."

  qY_d_i[d,i,t]$(d1Y_d_i[d,i,t]) "Real output by industry and demand component."
  qM_d_i[d,i,t]$(d1M_d_i[d,i,t]) "Real imports by industry and demand component."
;
$GROUP+ value_variables
  vY_i[i,t] "Output by industry."
  vM_i[i,t]$(m[i]) "Imports by industry."

  vR_di[di,t] "Intermediate inputs, by industry demanding the inputs."
  vE_di[di,t] "Energy inputs, by industry demanding the energy."
  vI_k[k,t] "Investments."
  vC_c[c,t] "Private consumption."
  vG_g[g,t] "Government consumption."
  vX_x[x,t] "Exports."

  vY_d_i[d,i,t]$(d1Y_d_i[d,i,t]) "Output by industry and demand component."
  vM_d_i[d,i,t]$(d1M_d_i[d,i,t]) "Imports by industry and demand component."

  vtY_d_i[d,i,t]$(d1Y_d_i[d,i,t]) "Net duties on domestic production by industry and demand component."
  vtM_d_i[d,i,t]$(d1M_d_i[d,i,t]) "Net duties on imports by industry and demand component."
  vtY_i[i,t] "Net duties on domestic production."
  vtM_i[i,t]$(m[i]) "Net duties on imports."
;
$GROUP+ other_variables
  tY_d_i[d,i,t]$(d1Y_d_i[d,i,t]) "Duties on domestic output by industry and demand component."
  tM_d_i[d,i,t]$(d1M_d_i[d,i,t]) "Duties on imports by industry and demand component."
  jfpY_d[d,t] "Deviation from average industry price."
  jfpM_d[d,t] "Deviation from average industry price."

  rYM[d,i,t]$(d1YM_d_i[d,i,t]) "industry composition of demand."
  rM[d,i,t]$(d1YM_d_i[d,i,t]) "Import share."
  fYM[d,t] "Deviation from law of one price."
;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK input_output $(t1.val <= t.val and t.val <= tEnd.val)
  # Equilibrium condition: supply + net duties = demand in each industry.
  vY_i[i,t].. vY_i[i,t] + vtY_i[i,t] =E= sum(d, vY_d_i[d,i,t]);

  # Aggregate imports from each import industry
  vM_i[i,t].. vM_i[i,t] + vtM_i[i,t] =E= sum(d, vM_d_i[d,i,t]);

  # Net duties on domestic production and imports
  vtY_d_i[d,i,t]..
    vtY_d_i[d,i,t] =E= tY_d_i[d,i,t] * vY_d_i[d,i,t] / (1+tY_d_i[d,i,t]);
  vtM_d_i[d,i,t]..
    vtM_d_i[d,i,t] =E= tM_d_i[d,i,t] * vM_d_i[d,i,t] / (1+tM_d_i[d,i,t]);

  vtY_i[i,t].. vtY_i[i,t] =E= sum(d, vtY_d_i[d,i,t]);
  vtM_i[i,t].. vtM_i[i,t] =E= sum(d, vtM_d_i[d,i,t]);

  # # Input-output prices reflect industry-prices or import prices, plus any taxes
  # # The fp[YM]_d can be endogenized by submodels to reflect pricing-to-market et..
  # pY_d_i[d,i,t].. pY_d_i[d,i,t] =E= (1+tY_d_i[d,i,t]) / (1+tY_d_i[d,i,tBase]) * (1+jfpY_d[d,t]) * pY_i[i,t];
  # pM_d_i[d,i,t].. pM_d_i[d,i,t] =E= (1+tM_d_i[d,i,t]) / (1+tM_d_i[d,i,tBase]) * (1+jfpM_d[d,t]) * pM_i[i,t];

  # rYM is the industry-composition for each demand - rYM is exogenous here, but can be endogenized in submodels
  # rM is the import-share for each demand - rM is exogenous here, but can be endogenized in submodels
  vY_d_i[di,r,t].. vY_d_i[di,r,t] =E= (1-rM[di,r,t]) * rYM[di,r,t] * vR_di[di,t];
  vY_d_i[di,e,t].. vY_d_i[di,e,t] =E= (1-rM[di,e,t]) * rYM[di,e,t] * vE_di[di,t];
  vY_d_i[k,i,t].. vY_d_i[k,i,t] =E= (1-rM[k,i,t]) * rYM[k,i,t] * vI_k[k,t];
  vY_d_i[c,i,t].. vY_d_i[c,i,t] =E= (1-rM[c,i,t]) * rYM[c,i,t] * vC_c[c,t];
  vY_d_i[g,i,t].. vY_d_i[g,i,t] =E= (1-rM[g,i,t]) * rYM[g,i,t] * vG_g[g,t];
  vY_d_i[x,i,t].. vY_d_i[x,i,t] =E= (1-rM[x,i,t]) * rYM[x,i,t] * vX_x[x,t];

  vM_d_i[di,r,t].. vM_d_i[di,r,t] =E= rM[di,r,t] * vR_di[di,t];
  vM_d_i[di,e,t].. vM_d_i[di,e,t] =E= rM[di,e,t] * vE_di[di,t];
  vM_d_i[k,i,t].. vM_d_i[k,i,t] =E= rM[k,i,t] * vI_k[k,t];
  vM_d_i[c,i,t].. vM_d_i[c,i,t] =E= rM[c,i,t] * vC_c[c,t];
  vM_d_i[g,i,t].. vM_d_i[g,i,t] =E= rM[g,i,t] * vG_g[g,t];
  vM_d_i[x,i,t].. vM_d_i[x,i,t] =E= rM[x,i,t] * vX_x[x,t];

  # Demand price indices
  pR_di[di,t].. pR_di[di,t] * qR_di[di,t] =E= vR_di[di,t];
  pE_di[di,t].. pE_di[di,t] * qE_di[di,t] =E= vE_di[di,t];
  pI_k[k,t].. pI_k[k,t] * qI_k[k,t] =E= vI_k[k,t];
  pC_c[c,t].. pC_c[c,t] * qC_c[c,t] =E= vC_c[c,t];
  pG_g[g,t].. pG_g[g,t] * qG_g[g,t] =E= vG_g[g,t];
  pX_x[x,t].. pX_x[x,t] * qX_x[x,t] =E= vX_x[x,t];

  vR_di[di,t].. vR_di[di,t] =E= sum(r, vY_d_i[di,r,t] + vM_d_i[di,r,t]);
  vE_di[di,t].. vE_di[di,t] =E= sum(e, vY_d_i[di,e,t] + vM_d_i[di,e,t]);
  vI_k[k,t].. vI_k[k,t] =E= sum(i, vY_d_i[k,i,t] + vM_d_i[k,i,t]);
  vC_c[c,t].. vC_c[c,t] =E= sum(i, vY_d_i[c,i,t] + vM_d_i[c,i,t]);
  vG_g[g,t].. vG_g[g,t] =E= sum(i, vY_d_i[g,i,t] + vM_d_i[g,i,t]);
  vX_x[x,t].. vX_x[x,t] =E= sum(i, vY_d_i[x,i,t] + vM_d_i[x,i,t]);
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / input_output_equations /;
$GROUP+ main_endogenous input_output_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP input_output_data_variables
  vY_d_i, vtY_d_i, tY_d_i
  vM_d_i, vtM_d_i, tM_d_i

  pY_i, qY_i, vY_i
  pM_i, qM_i, vM_i

  pC_c, qC_c, vC_c
  pX_x, qX_x, vX_x
  pG_g, qG_g, vG_g
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
# @load(input_output_data_variables, "../data/data.gdx")
$FIX(1) input_output_data_variables;
$GROUP+ data_covered_variables input_output_data_variables;

d1Y_d_i[d,i,t] = vY_d_i.l[d,i,t] <> 0;
d1M_d_i[d,i,t] = vM_d_i.l[d,i,t] <> 0;
d1YM_d_i[d,i,t] = d1Y_d_i[d,i,t] or d1M_d_i[d,i,t];

rM.l[d,i,t]$(d1M_d_i[d,i,t] and not d1Y_d_i[d,i,t]) = 1;
rM.l[d,i,t]$(d1Y_d_i[d,i,t] and not d1M_d_i[d,i,t]) = 0;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK input_output_calibration $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  input_output_equations
  # input_output_calibration_equations
/;
# Add endogenous variables to calibration model
$GROUP+ input_output_calibration_endogenous
  input_output_endogenous
  -vtY_d_i, tY_d_i$(d1Y_d_i[d,i,t])
  -vtM_d_i, tM_d_i$(d1M_d_i[d,i,t])
  -vY_d_i, -vM_d_i, rYM, rM$(d1M_d_i[d,i,t] and d1Y_d_i[d,i,t]) 
;
$GROUP+ calibration_endogenous input_output_calibration_endogenous;
