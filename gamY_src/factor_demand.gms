# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1K_k_i[k,i,t] "Dummy. Does industry i have capital of type k?"
;

$Group+ all_variables
  qK_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Real capital stock by capital type and industry."
  qL_i[i,t] "Labor in efficiency units by industry."

  qI_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Real investments by capital type and industry."
  rKDepr_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Capital depreciation rate by capital type and industry."
  qInvt_i[i,t] "Inventory investments by industry."

  qK2qY_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Capital to output ratio by capital type and industry."
  qL2qY_i[i,t] "Labor to output ratio by industry."
  qR2qY_i[i,t] "Intermediate input to output ratio by industry."
  qInvt2qY_i[i,t] "Inventory investment to output ratio by industry."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK factor_demand_equations factor_demand_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Temporary price equation
  .. pY_i[i,t] =E= pW[t];

  # Labor and capital ratios
  .. qK_k_i[k,i,t] =E= qK2qY_k_i[k,i,t] * qY_i[i,t];
  .. qL_i[i,t] =E= qL2qY_i[i,t] * qY_i[i,t];

  # Inventory investments
  .. qInvt_i[i,t] =E= qInvt2qY_i[i,t] * qY_i[i,t];
  .. qD[invt,t] =E= sum(i, qInvt_i[i,t]);

  # Link demand for non-energy intermediate inputs to input-output model
  # We use a one-to-one mapping between types of intermediate inputs and industries
  .. qD[i,t] =E= qR2qY_i[i,t] * qY_i[i,t];

  # Link demand for investments to input-output model
  .. qD[k,t] =E= sum(i, qI_k_i[k,i,t]);

  # Capital accumulation (firms demand capital directly, investments are residual from capital accumulation)
  .. qI_k_i[k,i,t] =E= qK_k_i[k,i,t] - (1-rKDepr_k_i[k,i,t]) * qK_k_i[k,i,t-1]/fq;
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / factor_demand_equations /;
$Group+ main_endogenous factor_demand_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group factor_demand_data_variables
  qK_k_i[k,i,t]
  qI_k_i[k,i,t]
  qD[i,t]
  qInvt_i[i,t]
;
@load(factor_demand_data_variables, "../data/data.gdx")
$Group+ data_covered_variables factor_demand_data_variables$(t.val <= %calibration_year%);

d1K_k_i[k,i,t] = abs(qK_k_i.l[k,i,t]) > 1e-9;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK factor_demand_calibration_equations factor_demand_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  factor_demand_equations
  # factor_demand_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  factor_demand_endogenous
  factor_demand_calibration_endogenous
  -qK_k_i[k,i,t1], qK2qY_k_i[k,i,t1]
  -qL_i[i,t1], qL2qY_i[i,t1]
  -qD[i,t1], qR2qY_i[i,t1]
  -qI_k_i[k,i,t1], rKDepr_k_i[k,i,t1]
  -qInvt_i[i,t1], qInvt2qY_i[i,t1]

  calibration_endogenous
;

$Group G_flat_after_last_data_year
  qK2qY_k_i[k,i,t]
  qL2qY_i[i,t]
  qR2qY_i[i,t]
  rKDepr_k_i[k,i,t]
;

$ENDIF # calibration