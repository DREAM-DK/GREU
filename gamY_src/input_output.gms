# ======================================================================================================================
# Input-output
# Demand for energy, other intermediate inputs, investments, private and public consumption, and exports
# is allocated to imports and output from domestic industries.
# ======================================================================================================================

# ----------------------------------------------------------------------------------------------------------------------
# Variable definitions
# ----------------------------------------------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1Y_i_d[i,d,t] "Dummy. Does the IO cell exist? (for domestic deliveries from industry i to demand d)"
  d1M_i_d[i,d,t] "Dummy. Does the IO cell exist? (for imports from industry i to demand d)"
  d1YM_i_d[i,d,t] "Dummy. Does the IO cell exist? (for demand d and industry i)"
  d1Y_d[d,t] "Dummy. Does the IO cell exist? (any domestic deliveries to demand d)"
  d1M_d[d,t] "Dummy. Does the IO cell exist? (any imports to demand d)"
  d1YM_d[d,t] "Dummy. Does the IO cell exist?"
;

$Group+ all_variables
  pY_i[i,t] "Price of domestic output by industry."
  qY_i[i,t] "Real output by industry."
  vY_i[i,t] "Output by industry."

  pM_i[i,t] "Price of imports by industry."
  qM_i[i,t]$(m[i]) "Real imports by industry."
  vM_i[i,t]$(m[i]) "Imports by industry."

  vY_d[d,t]$(d1Y_d[d,t]) "Output by demand component."
  vM_d[d,t]$(d1M_d[d,t]) "Imports by demand component."

  pD_d[d,t]$(d1YM_d[d,t]) "Price of demand component."
  qD_d[d,t]$(d1YM_d[d,t]) "Real demand by demand component."
  vD_d[d,t]$(d1YM_d[d,t]) "Demand by demand component."

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
  vtY_i[i,t] "Net duties on domestic production."
  vtM_i[i,t]$(m[i]) "Net duties on imports."

  jfpY_i_d[i,d,t] "Deviation from average industry price."
  jfpM_i_d[i,d,t] "Deviation from average industry price."

  rYM[i,d,t]$(d1YM_i_d[i,d,t]) "industry composition of demand."
  rM[i,d,t]$(d1YM_i_d[i,d,t]) "Import share."
  fYM[d,t] "Deviation from law of one price."
;
$ENDIF # variables

# ----------------------------------------------------------------------------------------------------------------------
# Equations
# ----------------------------------------------------------------------------------------------------------------------
$IF %stage% == "equations":

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
$Group+ data_covered_variables input_output_data_variables$(t.val <= %calibration_year%);

@load(input_output_data_variables, "../data/data.gdx")

d1Y_i_d[i,d,t] = abs(vY_i_d.l[i,d,t]) > 1e-9;
d1M_i_d[i,d,t] = abs(vM_i_d.l[i,d,t]) > 1e-9;
d1YM_i_d[i,d,t] = d1Y_i_d[i,d,t] or d1M_i_d[i,d,t];
d1Y_d[d,t] = sum(i, d1Y_i_d[i,d,t]);
d1M_d[d,t] = sum(i, d1M_i_d[i,d,t]);
d1YM_d[d,t] = d1Y_d[d,t] or d1M_d[d,t];

rM.l[i,d,t]$(d1M_i_d[i,d,t] and not d1Y_i_d[i,d,t]) = 1;
rM.l[i,d,t]$(d1Y_i_d[i,d,t] and not d1M_i_d[i,d,t]) = 0;

pY_i.l[i,t] = 1;
pM_i.l[i,t] = 1;
pD_d.l[d,t] = 1;

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
$Group+ input_output_calibration_endogenous
  input_output_endogenous
  -vtY_i_d[i,d,t1], tY_i_d[i,d,t1]
  -vtM_i_d[i,d,t1], tM_i_d[i,d,t1]
  -vY_i_d[i,d,t1], -vM_i_d[i,d,t1], rYM[i,d,t1], rM[i,d,t]$(t1[t] and d1M_i_d[i,d,t] and d1Y_i_d[i,d,t]) 
  -pD_d[d,t1], qD_d[d,t1]
;
$Group+ calibration_endogenous input_output_calibration_endogenous;

$Group G_flat_after_last_data_year
  rYM, rM
;

$ENDIF # calibration