# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
set d1Y_d_s[d,s,t] "Dummy. Does the IO cell exist? (for domestic deliveries from sector s to demand d)" / /;
set d1M_d_s[d,s,t] "Dummy. Does the IO cell exist? (for imports from sector s to demand d)" / /;
set d1YM_d_s[d,s,t] "Dummy. Does the IO cell exist? (for demand d and sector s)" / /;

$GROUP price_variables price_variables
  pC_c[c,t] "Price of private consumption goods."
  pG_g[g,t] "Price of government consumption goods."
  pX_x[x,t] "Price of export goods."
  pI_i[i,t] "Price of investment goods."

  pR_s[ds,t] "Price of intermediate inputs by sector demanding the inputs."
  pE_s[ds,t] "Price of energy inputs by sector demanding the energy."

  pY_s[s,t] "Price of domestic output by sector."
  pM_s[s,t] "Price of imports by sector."

  pY_d_s[d,s,t]$(d1Y_d_s[d,s,t]) "Price of domestic output by sector and demand component."
  pM_d_s[d,s,t]$(d1M_d_s[d,s,t]) "Price of imports by sector and demand component."
;
$GROUP quantity_variables quantity_variables
  qC_c[c,t] "Real private consumption."
  qG_g[g,t] "Real government consumption."
  qX_x[x,t] "Real exports."
  qI_i[i,t] "Real investments."

  qR_s[ds,t] "Real intermediate inputs, by sector demanding the inputs."
  qE_s[ds,t] "Real energy inputs, by sector demanding the energy."

  qY_s[s,t] "Real output by sector."
  qM_s[s,t]$(m[s]) "Real imports by sector."

  qY_d_s[d,s,t]$(d1Y_d_s[d,s,t]) "Real output by sector and demand component."
  qM_d_s[d,s,t]$(d1M_d_s[d,s,t]) "Real imports by sector and demand component."
;
$GROUP other_variables other_variables
  tY_d_s[d,s,t]$(d1Y_d_s[d,s,t]) "Duties on domestic output by sector and demand component."
  tM_d_s[d,s,t]$(d1M_d_s[d,s,t]) "Duties on imports by sector and demand component."
  jfpY_d[d,t] "Deviation from average sector price."
  jfpM_d[d,t] "Deviation from average sector price."

  rYM[d,s,t]$(d1YM_d_s[d,s,t]) "Sector composition of demand."
  rM[d,s,t]$(d1YM_d_s[d,s,t]) "Import share."
  fYM[d,t] "Deviation from law of one price."
;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP input_output_data_variables
  pY_d_s, qY_d_s, tY_d_s
  pM_d_s, qM_d_s, tM_d_s

  pY_s#, qY_s
  pM_s#, qM_s

  pC_c, qC_c
  pX_x, qX_x
  pG_g, qG_g
  pI_i, qI_i
  pR_s, qR_s
  pE_s, qE_s

  # pC, qC
  # pG, qG
  # pX, qX
  # pI, qI
  # pY, qM
  # pM, qY
  # pGDP, qGDP
;
@load(input_output_data_variables, "../data/data.gdx")
$GROUP data_covered_variables data_covered_variables, input_output_data_variables;

d1Y_d_s[d,s,t] = qY_d_s.l[d,s,t] <> 0;
d1M_d_s[d,s,t] = qM_d_s.l[d,s,t] <> 0;
d1YM_d_s[d,s,t] = d1Y_d_s[d,s,t] or d1M_d_s[d,s,t];

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK input_output
  # Equilibrium condition: supply = demand in each sector.
  # The demand prices, pY_d_s and pM_d_s, include duties, unlike the sector prices.
  # As all prices are normalized to 1 in the base year, we have to account for duties in the base year.
  qY_s[s,t]$(t1_[t]).. qY_s[s,t] =E= sum(d, qY_d_s[d,s,t] / (1+tY_d_s[d,s,tBase]));

  # Aggregate imports from each import sector
  qM_s[s,t]$(t1_[t]).. qM_s[s,t] =E= sum(d, qM_d_s[d,s,t] / (1+tM_d_s[d,s,tBase]));

  # Demand price indices
  pC_c[c,t]$(t1_[t]).. pC_c[c,t] * qC_c[c,t] =E= sum(s, pY_d_s[c,s,t] * qY_d_s[c,s,t] + pM_d_s[c,s,t] * qM_d_s[c,s,t]);
  pG_g[g,t]$(t1_[t]).. pG_g[g,t] * qG_g[g,t] =E= sum(s, pY_d_s[g,s,t] * qY_d_s[g,s,t] + pM_d_s[g,s,t] * qM_d_s[g,s,t]);
  pI_i[i,t]$(t1_[t]).. pI_i[i,t] * qI_i[i,t] =E= sum(s, pY_d_s[i,s,t] * qY_d_s[i,s,t] + pM_d_s[i,s,t] * qM_d_s[i,s,t]);
  pX_x[x,t]$(t1_[t]).. pX_x[x,t] * qX_x[x,t] =E= sum(s, pY_d_s[x,s,t] * qY_d_s[x,s,t] + pM_d_s[x,s,t] * qM_d_s[x,s,t]);

  pR_s[ds,t]$(t1_[t]).. pR_s[ds,t] * qR_s[ds,t] =E= sum(r, pY_d_s[ds,r,t] * qY_d_s[ds,r,t] + pM_d_s[ds,r,t] * qM_d_s[ds,r,t]);
  pE_s[ds,t]$(t1_[t]).. pE_s[ds,t] * qE_s[ds,t] =E= sum(e, pY_d_s[ds,e,t] * qY_d_s[ds,e,t] + pM_d_s[ds,e,t] * qM_d_s[ds,e,t]);

  # Input-output prices reflect sector-prices or import prices, plus any taxes
  # The fp[YM]_d can be endogenized by submodels to reflect pricing-to-market et..
  pY_d_s[d,s,t]$(t1_[t] and d1Y_d_s[d,s,t]).. pY_d_s[d,s,t] =E= (1+tY_d_s[d,s,t]) / (1+tY_d_s[d,s,tBase]) * (1+jfpY_d[d,t]) * pY_s[s,t];
  pM_d_s[d,s,t]$(t1_[t] and d1M_d_s[d,s,t]).. pM_d_s[d,s,t] =E= (1+tM_d_s[d,s,t]) / (1+tM_d_s[d,s,tBase]) * (1+jfpM_d[d,t]) * pM_s[s,t];

  # rYM is the sector-composition for each demand - rYM is exogenous here, but can be endogenized in submodels
  # rM is the import-share for each demand - rM is exogenous here, but can be endogenized in submodels
  # fYM captures deviations from law of one price in data, ensuring that rYM sums to 1
  qY_d_s[c,s,t]$(t1_[t] and d1Y_d_s[c,s,t]).. qY_d_s[c,s,t] =E= fYM[c,t] * (1-rM[c,s,t]) * rYM[c,s,t] * qC_c[c,t];
  qY_d_s[g,s,t]$(t1_[t] and d1Y_d_s[g,s,t]).. qY_d_s[g,s,t] =E= fYM[g,t] * (1-rM[g,s,t]) * rYM[g,s,t] * qG_g[g,t];
  qY_d_s[x,s,t]$(t1_[t] and d1Y_d_s[x,s,t]).. qY_d_s[x,s,t] =E= fYM[x,t] * (1-rM[x,s,t]) * rYM[x,s,t] * qX_x[x,t];
  qY_d_s[i,s,t]$(t1_[t] and d1Y_d_s[i,s,t]).. qY_d_s[i,s,t] =E= fYM[i,t] * (1-rM[i,s,t]) * rYM[i,s,t] * qI_i[i,t];
  qY_d_s[ds,r,t]$(t1_[t] and d1Y_d_s[ds,r,t]).. qY_d_s[ds,r,t] =E= fYM[ds,t] * (1-rM[ds,r,t]) * rYM[ds,r,t] * qR_s[ds,t];
  qY_d_s[ds,e,t]$(t1_[t] and d1Y_d_s[ds,e,t]).. qY_d_s[ds,e,t] =E= fYM[ds,t] * (1-rM[ds,e,t]) * rYM[ds,e,t] * qE_s[ds,t];

  qM_d_s[c,s,t]$(t1_[t] and d1M_d_s[c,s,t]).. qM_d_s[c,s,t] =E= fYM[c,t] * rM[c,s,t] * rYM[c,s,t] * qC_c[c,t];
  qM_d_s[g,s,t]$(t1_[t] and d1M_d_s[g,s,t]).. qM_d_s[g,s,t] =E= fYM[g,t] * rM[g,s,t] * rYM[g,s,t] * qG_g[g,t];
  qM_d_s[x,s,t]$(t1_[t] and d1M_d_s[x,s,t]).. qM_d_s[x,s,t] =E= fYM[x,t] * rM[x,s,t] * rYM[x,s,t] * qX_x[x,t];
  qM_d_s[i,s,t]$(t1_[t] and d1M_d_s[i,s,t]).. qM_d_s[i,s,t] =E= fYM[i,t] * rM[i,s,t] * rYM[i,s,t] * qI_i[i,t];
  qM_d_s[ds,r,t]$(t1_[t] and d1M_d_s[ds,r,t]).. qM_d_s[ds,r,t] =E= fYM[ds,t] * rM[ds,r,t] * rYM[ds,r,t] * qR_s[ds,t];
  qM_d_s[ds,e,t]$(t1_[t] and d1M_d_s[ds,e,t]).. qM_d_s[ds,e,t] =E= fYM[ds,t] * rM[ds,e,t] * rYM[ds,e,t] * qE_s[ds,t];
$ENDBLOCK

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK input_output_calibration
  fYM[d,t]$(t1_[t]).. sum(s, rYM[d,s,t]) =E= 1;
$ENDBLOCK

$GROUP input_output_calibration_endogenous
  input_output_calibration_endogenous
  input_output_endogenous

  -qY_d_s, -qM_d_s, rYM, rM$(d1M_d_s[d,s,t] and d1Y_d_s[d,s,t])
;

rM.l[d,s,t]$(d1M_d_s[d,s,t] and not d1Y_d_s[d,s,t]) = 1;
rM.l[d,s,t]$(d1Y_d_s[d,s,t] and not d1M_d_s[d,s,t]) = 0;

model input_output_calibration_model /
  input_output_equations
  input_output_calibration_equations
/;