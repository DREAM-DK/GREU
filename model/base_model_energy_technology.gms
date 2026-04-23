# First the base model is included and executed
$IMPORT base_model.gms

# Save baseline values from base_model.gms
qK_k_i_baseline.l[k,i,t] = qK_k_i.l[k,i,t];
pK_k_i_baseline.l[k,i,t] = pK_k_i.l[k,i,t];
pProd_baseline.l[pf,i,t] = pProd.l[pf,i,t];
qProd_baseline.l[pf,i,t] = qProd.l[pf,i,t];
vI_k_i_baseline.l[k,i,t] = vI_k_i.l[k,i,t];
qEtot_baseline.l[e,t]    = qEtot.l[e,t];

# Create partial models to get starting values for the energy technology model
$import pre_models_energy_technology.gms 

# Update energy dummies and run partial energy price model to get starting values for energy prices that do not exist in the CGE model
$import Dummies_new_energy_use.gms;
$FIX all_variables; $UNFIX energy_price_partial_endogenous;
Solve energy_price_partial using CNS;

# Calculate discrete prices of technologies for setting smoothing parameters
pTPotential.l[l,es,d,t] = 
  sum(e, uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t]) + uTKexp.l[l,es,d,t]*pTK.l[d,t];

# Set smoothing parameters
eP.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = 0.05*pTPotential.l[l,es,d,t]/uTKexp.l[l,es,d,t];

# ------------------------------------------------------------------------------
# Run the energy technology choice model integrated with the CGE-model
# ------------------------------------------------------------------------------
# We turn the energy technology model on to integrate it with the CGE-model
d1switch_energy_technology = 1;
d1switch_integrate_energy_technology = 1;

# Get starting values for the energy technology model
$import initial_values_energy_technology.gms;

# Solve partial energy technology model
$FIX all_variables; $UNFIX energy_technology_partial_endogenous;
Solve energy_technology_partial_equations using CNS;
# execute_unload 'Output/base_model_energy_technology_partial.gdx';

# Solve full model
$FIX all_variables; $UNFIX calibration_endogenous;
# execute_unload 'Output/pre_calibration_energy_technology.gdx';
solve calibration using CNS;

execute_unload 'Output/calibration_energy_technology.gdx';

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %test_energy_technology%:

@import_from_modules("tests")
# Data check  -  Abort if any data covered variables have been changed by the calibration
$GROUP G_test_data_covered_variables 
	G_test_data_covered_variables, 
  -qK_k_i[k,i,t]$(d1qI_k_i_energy_tech[k,i,t])
  -pEpj_base$(d1pEpj_base_energy_technology[es,e,d,t])
; 
@assert_no_difference(G_test_data_covered_variables, 1e-6, _data,.l, "data_covered_variables does not change more than previously done so by calibration."); #Ideally this check should be done rather than "diff-in-diff" above

# Test zero shock  -  Abort if a zero shock changes any variables significantly
@set(all_variables, _saved, .l)
$FIX all_variables; $UNFIX main_endogenous;
# execute_unload 'Output/main_pre.gdx';
Solve main using CNS;
@assert_no_difference(all_variables, 1e-6, .l, _saved, "Zero shock changed variables significantly.");
execute_unload 'Output/main_energy_technology.gdx';
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

$ENDIF # test_energy_technology