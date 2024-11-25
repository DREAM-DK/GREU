# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$Group+ price_variables
  pC[t] "Aggregate private consumption deflator."
  pG[t] "Aggregate government consumption deflator."
  pX[t] "Aggregate exports deflator."
  pI[t] "Aggregate investments deflator."

  pY[t] "Aggregate output deflator."
  pM[t] "Aggregate imports deflator."

  pGDP[t] "GDP deflator."
;
$Group+ quantity_variables
  qC[t] "Real aggregate private consumption."
  qG[t] "Real aggregate government consumption."
  qX[t] "Real aggregate exports."
  qI[t] "Real aggregate investments."

  qY[t] "Real aggregate output."
  qM[t] "Real aggregate imports."

  qGDP[t] "Real GDP."
;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK aggregates $(t1.val <= t.val and t.val <= tEnd.val)
  # Aggregate demand deflators
  pC[t].. pC[t] * qC[t] =E= sum(c, pC_c[c,t] * qC_c[c,t]);
  pX[t].. pX[t] * qX[t] =E= sum(x, pX_x[x,t] * qX_x[x,t]);
  pI[t].. pI[t] * qI[t] =E= sum(k, pI_k[k,t] * qI_k[k,t]);

  pGDP[t].. pGDP[t] * qGDP[t] =E= pC[t] * qC[t]
                                         + pG[t] * qG[t]
                                         + pI[t] * qI[t]
                                         + pX[t] * qX[t]
                                         - pM[t] * qM[t];
                                             
  # Aggregate demand quantities
  qC[t].. pC[t-1]/fp * qC[t] =E= sum(c, pC_c[c,t-1]/fp * qC_c[c,t]);
  qI[t].. pI[t-1]/fp * qI[t] =E= sum(k, pI_k[k,t-1]/fp * qI_k[k,t]);
  qX[t].. pX[t-1]/fp * qX[t] =E= sum(x, pX_x[x,t-1]/fp * qX_x[x,t]);

  qGDP[t].. pGDP[t-1]/fp * qGDP[t] =E= pC[t-1]/fp * qC[t]
                                              + pG[t-1]/fp * qG[t]
                                              + pI[t-1]/fp * qI[t]
                                              + pX[t-1]/fp * qX[t]
                                              - pM[t-1]/fp * qM[t];

  # Aggregate supply deflators
  pY[t].. pY[t] * qY[t] =E= sum(i, pY_i[i,t] * qY_i[i,t]);
  pM[t].. pM[t] * qM[t] =E= sum(i, pM_i[i,t] * qM_i[i,t]);

  # Aggregate supply
  qY[t].. pY[t-1]/fp * qY[t] =E= sum(i, pY_i[i,t-1]/fp * qY_i[i,t]);
  qM[t].. pM[t-1]/fp * qM[t] =E= sum(i, pM_i[i,t-1]/fp * qM_i[i,t]);
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / aggregates_equations /;
$Group+ main_endogenous aggregates_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$Group aggregates_data_variables
  pC, qC
  pG, qG
  pX, qX
  pI, qI
  pY, qM
  pM, qY
  pGDP, qGDP
;
@load(aggregates_data_variables, "../data/data.gdx")
# $Group data_covered_variables data_covered_variables aggregates_data_variables;

pC.l[tBase] = 1;
pX.l[tBase] = 1;
pI.l[tBase] = 1;
pGDP.l[tBase] = 1;
pY.l[tBase] = 1;
pM.l[tBase] = 1;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK aggregates_calibration $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  aggregates_equations
  # aggregates_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  aggregates_calibration_endogenous
  aggregates_endogenous
  -pC[tBase], pC[t0]
  -pX[tBase], pX[t0]
  -pI[tBase], pI[t0]
  -pGDP[tBase], pGDP[t0]
  -pY[tBase], pY[t0]
  -pM[tBase], pM[t0]

  calibration_endogenous
;