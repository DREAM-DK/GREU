$IF %include_abatement% = 0:
  $SETGLOBAL test_CGE "1"
  $SETGLOBAL test_abatement "0"
  $IMPORT base_model.gms
$ENDIF # include_abatement

$IF %include_abatement% = 1:
  $SETGLOBAL test_CGE "0"
  $SETGLOBAL test_abatement "1"
  $IMPORT base_model_abatement.gms
$ENDIF # include_abatement


$IMPORT sets/report.sets.gms # Has to be manually fittet to country specifik data
$Group Report_variables ;
@import_from_modules("report_def")
@import_from_modules("report_baseline")

@import_from_modules("report")

execute_unload 'Output\baseline.gdx';

# ------------------------------------------------------------------------------
# Calibrate electrification technologies and CCS
# ------------------------------------------------------------------------------
$IF %include_abatement% = 1:
  $import Abatement_exercise.gms;
$ENDIF # include_abatement

# ------------------------------------------------------------------------------
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2021, %terminal_year%);



parameter
  tCO2_abatement[em,es,e,i,t]
  ;

tCO2_abatement[em,es,e,i,t]$(sum(l, d1uTE[l,es,e,i,t]) and d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];


## SHOCK TO EXOGENOUS VARIABLES

# Apply carbon tax to specific energy types inkluding household use of energy
tCO2_Emarg.l[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t]) = tCO2_Emarg.l[em,es,e,d,t] + 750;
# Apply carbon tax to non-energy emissions
tCO2_xEmarg.l[i,t]$(d1tCO2_xE[i,t]) = tCO2_xEmarg.l[i,t] + 750;



## RUN CGE MODEL WITHOUT ABATEMENT MODEL
# We turn the abatement model on to integrate it with the CGE-model
d1switch_abatement[t] = 0;
d1switch_integrate_abatement[t] = 0;

$GROUP main_endogenous
  main_endogenous
  -uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
  vG2vGDP, -qG, 
  # vLumpsum, -vGovPrimaryBalance  
;

$FIX all_variables; $UNFIX main_endogenous;
# execute_unload 'Output\pre_CO2_shock.gdx';
solve main using CNS;

tCO2_abatement[em,es,e,i,t]$(sum(l, d1uTE[l,es,e,i,t]) and d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];


$IF %include_abatement% = 1:
  ## RUN CGE MODEL WITH ABATEMENT MODEL
  d1switch_abatement[t] = 1;
  d1switch_integrate_abatement[t] = 1;

  $GROUP main_endogenous
    main_endogenous
    uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), -jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
    vG2vGDP, -qG, 
    # vLumpsum, -vGovPrimaryBalance    
  ;

  # Set starting values for the abatement model
  $import Supply_curves_abatement.gms

  # Solve partial abatement model
  $FIX all_variables;
  $UNFIX abatement_partial_endogenous;
  Solve abatement_partial_equations using CNS;
  execute_unload 'Output\shock_carbon_tax_abatement_partial.gdx';

  $FIX all_variables;
  $UNFIX main_endogenous;
  # @Setbounds_abatement();
  Solve main using CNS;

$ENDIF


# Report results
@import_from_modules("report")

$IF %include_abatement% = 1:
execute_unload 'Output\shock_carbon_tax_abatement.gdx';
$ENDIF

$IF %include_abatement% = 0:
execute_unload 'Output\shock_carbon_tax.gdx';
$ENDIF

jvY_i.l[i,t]$(t.val LE t1.val) = 0;
@import_from_modules("tests")

