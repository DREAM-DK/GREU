# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1E_re_i[re,i,t] "Dummy. Does industry i use energy inputs for purpose re?"
  d1E_i[i,t] "Dummy. Does industry i use energy inputs?"
;

$Group+ all_variables
  qInvt_ene_i[i,t] "Net real inventory investments in energy by industry."
  vInvt_ene_i[i,t] "Net inventory investments in energy by industry."

  jDelta_qESK[k,i,t]$(d1K_k_i[k,i,t] and sameas[k,'iM']) "Additional investments from abatement model (endogenized by abatement module)."

  qInvt_ene2qY_i[i,t] "Inventory investment in energy to output ration by industry"
  qE2qY_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Demand for intermediate energy inputs to output ratio by industry."
  pE_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Price index of energy inputs, by industry."
  qE_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Real energy inputs by industry."
  vE_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Energy inputs by industry and final purpose."
  vE_i[i,t]$(d1E_i[i,t]) "Energy inputs by industry"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK factor_demand_energy_equations factor_demand_energy_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Link demand for energy intermediate inputs to input-output model
  .. pE_re_i[re,i,t] =E=  pD[re,t];
  .. qE_re_i[re,i,t] =E= qE2qY_re_i[re,i,t] * qY_i[i,t];
  .. qD[re,t] =E= sum(i, qE_re_i[re,i,t]);
  .. vE_re_i[re,i,t] =E= pE_re_i[re,i,t] * qE_re_i[re,i,t] ;

  .. vE_i[i,t] =E= sum(re, vE_re_i[re,i,t]);

  # Link energy inputs to financial_accounts module
  # This endogenizes the J-term defined in financial_accounts.gms
  jvE_i[i,t]$(d1E_i[i,t]).. jvE_i[i,t] =E= vE_i[i,t];

  # Energy inventory investments
  .. qInvt_ene_i[i,t] =E= qInvt_ene2qY_i[i,t] * qY_i[i,t];
  .. qD[Invt_ene,t] =E= sum(i, qInvt_ene_i[i,t]);
  .. vInvt_ene_i[i,t] =E= pD['Invt_ene',t] * qInvt_ene_i[i,t];

  # Link energy inventory investments to financial_accounts module 
  # This endogenizes the J-term defined in financial_accounts.gms
  jvInvt_ene_i[i,t]$(d1E_i[i,t]).. jvInvt_ene_i[i,t] =E= vInvt_ene_i[i,t];
   
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / factor_demand_energy_equations /;
$Group+ main_endogenous factor_demand_energy_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group factor_demand_energy_data_variables
  qD[re,t]
  qD[invt_ene,t]
  qInvt_ene_i[i,t]
  qE_re_i[re,i,t]
;
@load(factor_demand_energy_data_variables, "../data/data.gdx")
$Group+ data_covered_variables factor_demand_energy_data_variables$(t.val <= %calibration_year%);

d1E_re_i[re,i,t] = abs(qE_re_i.l[re,i,t]) > 1e-9;
d1E_i[i,t]       = yes$(sum(re, d1E_re_i[re,i,t]));

pE_re_i.l[re,i,t]$d1E_re_i[re,i,t] = fpt[t];

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK factor_demand_energy_calibration_equations factor_demand_energy_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  factor_demand_energy_equations
  # factor_demand_energy_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  factor_demand_energy_endogenous
  factor_demand_energy_calibration_endogenous
  -qInvt_ene_i[i,t1], qInvt_ene2qY_i[i,t1]
  -qE_re_i[re,i,t1], qE2qY_re_i[re,i,t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  qE2qY_re_i[re,i,t]
  qInvt_ene2qY_i[i,t]
;

# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO factor_demand_energy_calibration_starting_values

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
$ENDIF # tests