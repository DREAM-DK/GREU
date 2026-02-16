# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1K_k_i[k,i,t] "Dummy. Does industry i have capital of type k?"
  d1E_re_i[re,i,t] "Dummy. Does industry i use energy inputs for purpose re?"
  d1E_i[i,t] "Dummy. Does industry i use energy inputs?"
;

$Group+ all_variables
  qK_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Real capital stock by capital type and industry."
  qL_i[i,t] "Labor in efficiency units by industry."

  qI_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Real investments by capital type and industry."
  vI_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Investments by capital type and industry."
  rKDepr_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Capital depreciation rate by capital type and industry."
  qInvt_i[i,t] "Net real inventory investments by industry."
  vInvt_i[i,t] "Net inventory investments by industry."

  fInstCost_k_i[k,i] "Multiplicative factor of installation cost function"
  qInstCost_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Real installation costs by capital type and industry"
  dInstCost2dKLag_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Derivative of installation costs wrt. lagged capital"
  dInstCost2dK_k_i[k,i,t]$(d1K_k_i[k,i,t])  "Derivative of installation costs wrt. current capital"

  qInvt_ene_i[i,t] "Net real inventory investments in energy by industry."
  vInvt_ene_i[i,t] "Net inventory investments in energy by industry."

  pK_k_i[k,i,t]$(d1K_k_i[k,i,t]) "User cost of capital by capital type and industry."
  rHurdleRate_i[i,t]$(d1Y_i[i,t]) "Corporations' hurdle rate of investments by industry."
  jpK_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Additive residual in user cost of capital."
  jDelta_qESK[k,i,t]$(d1K_k_i[k,i,t] and sameas[k,'iM']) "Additional investments from abatement model (endogenized by abatement module)."

  qK2qY_k_i[k,i,t]$(d1K_k_i[k,i,t]) "Capital to output ratio by capital type and industry."
  qL2qY_i[i,t] "Labor to output ratio by industry."
  qR2qY_i[i,t] "Intermediate input to output ratio by industry."
  qInvt2qY_i[i,t] "Inventory investment to output ratio by industry."
  qInvt_ene2qY_i[i,t] "Inventory investment in energy to output ration by industry"
  qE2qY_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Demand for intermediate energy inputs to output ratio by industry."
  pE_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Price index of energy inputs, by industry."
  qE_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Real energy inputs by industry."
  vE_re_i[re,i,t]$(d1E_re_i[re,i,t]) "Energy inputs by industry and final purpose."
  vE_i[i,t]$(d1E_i[i,t]) "Energy inputs by industry"

  vDepr_i[i,t] "Depreciation by industry."  
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK factor_demand_equations factor_demand_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Labor and capital ratios
  .. qK_k_i[k,i,t] =E= qK2qY_k_i[k,i,t] * qY_i[i,t];
  .. qL_i[i,t] =E= qL2qY_i[i,t] * qY_i[i,t];

  # Link demand for non-energy intermediate inputs to input-output model
  # We use a one-to-one mapping between types of intermediate inputs and industries
  .. qD[i,t] =E= qR2qY_i[i,t] * qY_i[i,t];

  # Link demand for energy intermediate inputs to input-output model
  .. pE_re_i[re,i,t] =E=  pD[re,t];
  .. qE_re_i[re,i,t] =E= qE2qY_re_i[re,i,t] * qY_i[i,t];
  .. qD[re,t] =E= sum(i, qE_re_i[re,i,t]);
  .. vE_re_i[re,i,t] =E= pE_re_i[re,i,t] * qE_re_i[re,i,t] ;

  .. vE_i[i,t] =E= sum(re, vE_re_i[re,i,t]);

  # Link energy inputs to financial_accounts module (aggregate approximation)
  # This endogenizes the J-term defined in financial_accounts.gms
  jvE_i[i,t]$(d1E_i[i,t])..
    jvE_i[i,t] =E= vE_i[i,t];

  # Inventory investments
  .. qInvt_i[i,t] =E= qInvt2qY_i[i,t] * qY_i[i,t];
  .. qD[invt,t] =E= sum(i, qInvt_i[i,t]);
  .. vInvt_i[i,t] =E= pD['invt',t] * qInvt_i[i,t];

  # Energy inventory investments
  .. qInvt_ene_i[i,t] =E= qInvt_ene2qY_i[i,t] * qY_i[i,t];
  .. qD[Invt_ene,t] =E= sum(i, qInvt_ene_i[i,t]);
  .. vInvt_ene_i[i,t] =E= pD['Invt_ene',t] * qInvt_ene_i[i,t];

  # Link energy inventory investments to financial_accounts module (aggregate approximation)
  # This endogenizes the J-term defined in financial_accounts.gms
  jvInvt_ene_i[i,t]$(d1E_i[i,t])..
    jvInvt_ene_i[i,t] =E= vInvt_ene_i[i,t];

  # Capital accumulation (firms demand capital directly, investments are residual from capital accumulation)
  .. qI_k_i[k,i,t] =E= qK_k_i[k,i,t] - (1-rKDepr_k_i[k,i,t]) * qK_k_i[k,i,t-1]/fq
                      + jDelta_qESK[k,i,t]; # Additional investments from the abatement model (endogenized by abatement module) 

  # Link demand for investments to input-output model
  .. qD[k,t] =E= sum(i, qI_k_i[k,i,t]);
  .. vI_k_i[k,i,t] =E= pD[k,t] * qI_k_i[k,i,t];

  # Installation costs for capital adjustments
  .. qInstCost_k_i[k,i,t] =E= fInstCost_k_i[k,i] * sqr((qI_k_i[k,i,t] / qK_k_i[k,i,t-1])) * qK_k_i[k,i,t-1];
 
  .. dInstCost2dKLag_k_i[k,i,t] =E= -fInstCost_k_i[k,i] * (2*(1 - rKDepr_k_i[k,i,t]) + ((qI_k_i[k,i,t+1]*fq) / (qK_k_i[k,i,t]))) * ((qI_k_i[k,i,t+1]*fq) / (qK_k_i[k,i,t]));
  
  .. dInstCost2dK_k_i[k,i,t] =E= fInstCost_k_i[k,i] * 2 * (qI_k_i[k,i,t] / (qK_k_i[k,i,t-1]/fq));

  $(not tEnd[t])..
    pK_k_i[k,i,t] =E= pD[k,t] - (1-rKDepr_k_i[k,i,t]) / (1+rHurdleRate_i[i,t+1]) * pD[k,t+1]*fp + pY_i[i,t] * dInstCost2dK_k_i[k,i,t]
                      + dInstCost2dKLag_k_i[k,i,t] / (1 + rHurdleRate_i[i, t+1]) * pY_i[i,t+1]*fp + jpK_k_i[k,i,t];
  pK_k_i&_tEnd[k,i,t]$(tEnd[t])..
    pK_k_i[k,i,t] =E= pD[k,t] - (1-rKDepr_k_i[k,i,t]) / (1+rHurdleRate_i[i,t]) * pD[k,t]*fp + pY_i[i,t] * dInstCost2dK_k_i[k,i,t]
                      + dInstCost2dKLag_k_i[k,i,t - 1] / (1 + rHurdleRate_i[i, t]) * pY_i[i,t]*fp + jpK_k_i[k,i,t];

  # Depreciation on industry level
  .. vDepr_i[i,t] =E= sum(k, pK_k_i[k,i,t] * rKDepr_k_i[k,i,t] * qK_k_i[k,i,t-1]/fq);
   
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
  qD[re,t]
  qD[k,t]
  qD[invt_ene,t]
  qD[invt,t]
  
  qInvt_i[i,t]
  qInvt_ene_i[i,t]
  qE_re_i[re,i,t] 
;
@load(factor_demand_data_variables, "../data/data.gdx")
$Group+ data_covered_variables factor_demand_data_variables$(t.val <= %calibration_year%);

d1K_k_i[k,i,t]    = abs(qK_k_i.l[k,i,t]) > 1e-9;
d1E_re_i[re,i,t] = abs(qE_re_i.l[re,i,t]) > 1e-9;
d1E_i[i,t]       = yes$(sum(re, d1E_re_i[re,i,t]));

rHurdleRate_i.l[i,t] = 0.2;

# Initialize J-term for abatement investments to zero (allows partial equilibrium when abatement module is off)
jDelta_qESK.l[k,i,t] = 0;

fInstCost_k_i.fx[k,i] = 0.5;
qInstCost_k_i.l[k,i,t]$(d1K_k_i[k,i,t] and not t1[t]) = fInstCost_k_i.l[k,i] * sqr((qI_k_i.l[k,i,t] / (qK_k_i.l[k,i,t-1]/fq))) * (qK_k_i.l[k,i,t-1]/fq);
dInstCost2dKLag_k_i.l[k,i,t]$(d1K_k_i[k,i,t] and not tEnd[t]) = -fInstCost_k_i.l[k,i] * (2*(1 - rKDepr_k_i.l[k,i,t]) + ((qI_k_i.l[k,i,t+1]*fq) / (qK_k_i.l[k,i,t]))) * ((qI_k_i.l[k,i,t+1]*fq) / (qK_k_i.l[k,i,t]));
dInstCost2dK_k_i.l[k,i,t]$(d1K_k_i[k,i,t] and not t1[t]) = fInstCost_k_i.l[k,i] * 2 * (qI_k_i.l[k,i,t] / (qK_k_i.l[k,i,t-1]/fq));

qInstCost_k_i.l[k,i,t]$(d1K_k_i[k,i,t] and t1[t]) = fInstCost_k_i.l[k,i] * sqr(qI_k_i.l[k,i,t] / (qK_k_i.l[k,i,t]/fq)) * qK_k_i.l[k,i,t]/fq;
dInstCost2dKLag_k_i.l[k,i,t]$(d1K_k_i[k,i,t] and tEnd[t]) = -fInstCost_k_i.l[k,i] * (2*(1 - rKDepr_k_i.l[k,i,t]) + ((qI_k_i.l[k,i,t]*fq) / (qK_k_i.l[k,i,t]))) * ((qI_k_i.l[k,i,t]*fq) / (qK_k_i.l[k,i,t]));
dInstCost2dK_k_i.l[k,i,t]$(d1K_k_i[k,i,t] and t1[t]) = fInstCost_k_i.l[k,i] * 2 * (qI_k_i.l[k,i,t] / (qK_k_i.l[k,i,t]/fq));

pK_k_i.l[k,i,t]$d1K_k_i[k,i,t] = rHurdleRate_i.l[i,t]; 
pE_re_i.l[re,i,t]$d1E_re_i[re,i,t] = fpt[t];
$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK factor_demand_calibration_equations factor_demand_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # jpK_k_i[k,i,t]$(t.val>t1.val and t.val <tEnd.val)..
  #   pK_k_i[k,i,t] =E= pK_k_i[k,i,t1];
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
  -qInvt_ene_i[i,t1], qInvt_ene2qY_i[i,t1]
  -qE_re_i[re,i,t1], qE2qY_re_i[re,i,t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  qK2qY_k_i[k,i,t]
  qL2qY_i[i,t]
  qR2qY_i[i,t]
  rKDepr_k_i[k,i,t]
;

# There may be a smarter solution for this, but for now we add a specific installation cost variable group
# to utilize during calibration. This allows us to catch when installation costs are turned off and set related
# variables equal to zero to avoid pivot errors during calibration in that case
$Group instcost_variables
  qInstCost_k_i[k,i,t]$(d1K_k_i[k,i,t])
  dInstCost2dKLag_k_i[k,i,t]$(d1K_k_i[k,i,t])
  dInstCost2dK_k_i[k,i,t]$(d1K_k_i[k,i,t])
;

# Variables that require custom starting values rather than the default 0.99 assignment
# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
  dInstCost2dKLag_k_i[k,i,t]
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO factor_demand_calibration_starting_values \
  dInstCost2dKLag_k_i.l[k,i,t]$(t1.val <= t.val and t.val <= tEnd.val and d1K_k_i[k,i,t]) = dInstCost2dKLag_k_i.l[k,i,t0];

$ENDIF # calibration