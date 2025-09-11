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
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2020, %terminal_year%);



parameter
  tCO2_abatement[em,es,e,i,t]
  ;

tCO2_abatement[em,es,e,i,t]$(sum(l, d1uTE[l,es,e,i,t]) and d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];

execute_unload 'pre_shock_carbon_tax.gdx';

## SHOCK TO EXOGENOUS VARIABLES

# Reset capital costs to original values
vTI.l['t1','heating','10030',t]$(d1sqTPotential['t1','heating','10030',t]) 
  = vTI_saved['t1','heating','10030',t];

# Apply carbon tax to specific energy types
# tCO2_Emarg.l[em,es,e,i,t]$(d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t] + 100;
tCO2_Emarg.l[em,es,e,i,t]$(d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t] + 1000;

## RUN CGE MODEL WITHOUT ABATEMENT MODEL
# We turn the abatement model on to integrate it with the CGE-model
d1switch_abatement[t] = 0;
d1switch_integrate_abatement[t] = 0;

$GROUP main_endogenous
  main_endogenous
  -uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
;

$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;

tCO2_abatement[em,es,e,i,t]$(sum(l, d1uTE[l,es,e,i,t]) and d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];

## RUN CGE MODEL WITH ABATEMENT MODEL
d1switch_abatement[t] = 1;
d1switch_integrate_abatement[t] = 1;

$GROUP main_endogenous
  main_endogenous
  uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), -jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
;

# Set starting values for the abatement model
$import Supply_curves_abatement.gms

$FIX all_variables;
$UNFIX main_endogenous;
@Setbounds_abatement();
Solve main using CNS;
$IMPORT report_abatement.gms
@import_from_modules("report")

execute_unload 'Output\shock_carbon_tax.gdx';
@import_from_modules("tests")

