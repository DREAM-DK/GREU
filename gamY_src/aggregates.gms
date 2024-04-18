# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$GROUP price_variables price_variables
  pC[t] "Aggregate private consumption deflator."
  pG[t] "Aggregate government consumption deflator."
  pX[t] "Aggregate exports deflator."
  pI[t] "Aggregate investments deflator."

  pY[t] "Aggregate output deflator."
  pM[t] "Aggregate imports deflator."

  pGDP[t] "GDP deflator."
;
$GROUP quantity_variables quantity_variables
  qC[t] "Real aggregate private consumption."
  qG[t] "Real aggregate government consumption."
  qX[t] "Real aggregate exports."
  qI[t] "Real aggregate investments."

  qY[t] "Real aggregate output."
  qM[t] "Real aggregate imports."

  qGDP[t] "Real GDP."
;

$BLOCK aggregates
  # Aggregate demand deflators
  pC[t]$(t1_[t]).. pC[t] * qC[t] =E= sum(c, pC_c[c,t] * qC_c[c,t]);
  pX[t]$(t1_[t]).. pX[t] * qX[t] =E= sum(x, pX_x[x,t] * qX_x[x,t]);
  pI[t]$(t1_[t]).. pI[t] * qI[t] =E= sum(i, pI_i[i,t] * qI_i[i,t]);

  pGDP[t]$(t1_[t]).. pGDP[t] * qGDP[t] =E= pC[t] * qC[t]
                                         + pG[t] * qG[t]
                                         + pI[t] * qI[t]
                                         + pX[t] * qX[t]
                                         - pM[t] * qM[t];
                                             
  # Aggregate demand quantities
  qC[t]$(t1_[t]).. pC[t-1]/fp * qC[t] =E= sum(c, pC_c[c,t-1]/fp * qC_c[c,t]);
  qI[t]$(t1_[t]).. pI[t-1]/fp * qI[t] =E= sum(i, pI_i[i,t-1]/fp * qI_i[i,t]);
  qX[t]$(t1_[t]).. pX[t-1]/fp * qX[t] =E= sum(x, pX_x[x,t-1]/fp * qX_x[x,t]);

  qGDP[t]$(t1_[t]).. pGDP[t-1]/fp * qGDP[t] =E= pC[t-1]/fp * qC[t]
                                              + pG[t-1]/fp * qG[t]
                                              + pI[t-1]/fp * qI[t]
                                              + pX[t-1]/fp * qX[t]
                                              - pM[t-1]/fp * qM[t];

  # Aggregate supply deflators
  pY[t]$(t1_[t]).. pY[t] * qY[t] =E= sum(s, pY_s[s,t] * qY_s[s,t]);
  pM[t]$(t1_[t]).. pM[t] * qM[t] =E= sum(s, pM_s[s,t] * qM_s[s,t]);

  # Aggregate supply
  qY[t]$(t1_[t]).. pY[t-1]/fp * qY[t] =E= sum(s, pY_s[s,t-1]/fp * qY_s[s,t]);
  qM[t]$(t1_[t]).. pM[t-1]/fp * qM[t] =E= sum(s, pM_s[s,t-1]/fp * qM_s[s,t]);
$ENDBLOCK


# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP aggregates_data_variables
  pC, qC
  pG, qG
  pX, qX
  pI, qI
  pY, qM
  pM, qY
  pGDP, qGDP
;
@load(aggregates_data_variables, "../data/data.gdx")

pC.l[tBase] = 1;
pX.l[tBase] = 1;
pI.l[tBase] = 1;
pGDP.l[tBase] = 1;
pY.l[tBase] = 1;
pM.l[tBase] = 1;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK aggregates_calibration
  empty_group_dummy[t]$(0).. 0 =E= 0;
$ENDBLOCK

$GROUP aggregates_calibration_endogenous
  aggregates_calibration_endogenous
  aggregates_endogenous

  -pC[tBase], pC[t0]
  -pX[tBase], pX[t0]
  -pI[tBase], pI[t0]
  -pGDP[tBase], pGDP[t0]
  -pY[tBase], pY[t0]
  -pM[tBase], pM[t0]
;

model aggregates_calibration_model /
  aggregates_equations
  aggregates_calibration_equations
/;