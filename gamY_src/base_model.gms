$onMulti # Allows adding to an already defined set or model with multiple "model" or "set" statements

$IMPORT functions.gms;
$IMPORT settings.gms

$IMPORT sets/time.sets.gms
$IMPORT sets/abatement.sets.gms

set_time_periods(%first_data_year%, %terminal_year%);

# ------------------------------------------------------------------------------
# Select modules
# ------------------------------------------------------------------------------
$FUNCTION import_from_modules(stage_key):
  $SETGLOBAL stage stage_key;
  $IMPORT abatement.gms
$ENDFUNCTION

# ------------------------------------------------------------------------------
# Define variables and dummies
# ------------------------------------------------------------------------------
# Group of all variables, identical to ALL group, except containing only elements that exist (not dummied out)
$Group all_variables ; # All variables in the model
$Group main_endogenous ;
$Group data_covered_variables ; # Variables that are covered by data
$Group G_flat_after_last_data_year ; # Variables that are extended with "flat forecast" after last data year
$SetGroup SG_flat_after_last_data_year ; # Dummies that are extended with "flat forecast" after last data year
@import_from_modules("variables")
$IMPORT variable_groups.gms
$IMPORT growth_adjustments.gms

# ------------------------------------------------------------------------------
# Define equations
# ------------------------------------------------------------------------------
model main;
model calibration;
@import_from_modules("equations")
@add_exist_dummies_to_model(main) # Limit the main model to only include elements that are not dummied out
main.optfile=1;

# ------------------------------------------------------------------------------
# Import data and set parameters
# ------------------------------------------------------------------------------
@import_from_modules("exogenous_values")
# @inf_growth_adjust()
@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration
@update_exist_dummies()

# ------------------------------------------------------------------------------
# Depicting discrete and smooth supply curves
# ------------------------------------------------------------------------------
$import premodel_abatement.gms
$import Supply_curves_abatement.gms

# ------------------------------------------------------------------------------
# Calibrate model
# ------------------------------------------------------------------------------
$Group calibration_endogenous ;
@import_from_modules("calibration")
calibration.optfile=1;
$IMPORT calibration.gms
$IMPORT report_abatement.gms
execute_unloaddi "calibration.gdx";

# ------------------------------------------------------------------------------
# Increasing capital costs for one technology
# ------------------------------------------------------------------------------

uTKexp.l['t1','heating','10030',t]$(d1sTPotential['t1','heating','10030',t]) 
  = uTKexp.l['t1','heating','10030',t] * 100;

$import Supply_curves_abatement.gms

$FIX all_variables;
$UNFIX main_endogenous;
@Setbounds_abatement();
Solve main using CNS;
$IMPORT report_abatement.gms
execute_unload 'shock_capital_cost.gdx';

# ------------------------------------------------------------------------------
# Calibration of electrification in the baseline
# ------------------------------------------------------------------------------

# uTKexp.l['t_Electricity_calib','heating','10030','2020'] = 2.2;
# uTKexp.l['t_Electricity_calib','heating','10030','2021'] = 2;
# uTKexp.l['t_Electricity_calib','heating','10030','2022'] = 1.5;
# uTKexp.l['t_Electricity_calib','heating','10030','2023'] = 1.2;
# uTKexp.l['t_Electricity_calib','heating','10030','2024'] = 1.2;
# uTKexp.l['t_Electricity_calib','heating','10030',t]$(t.val>2024) = 1.2;

# uTKexp.l['t_Electricity_calib_2','heating','10030','2020'] = 2.8;
# uTKexp.l['t_Electricity_calib_2','heating','10030','2021'] = 2.5;
# uTKexp.l['t_Electricity_calib_2','heating','10030','2022'] = 2.2;
# uTKexp.l['t_Electricity_calib_2','heating','10030','2023'] = 2;
# uTKexp.l['t_Electricity_calib_2','heating','10030',t]$(t.val>2023) = 2;

 $FIX all_variables;
 $UNFIX main_endogenous;
 @Setbounds_abatement();
 Solve main using CNS;
 $IMPORT report_abatement.gms
 execute_unload 'Abatement_partial_elec.gdx';

# ------------------------------------------------------------------------------
# Increasing carbon tax
# ------------------------------------------------------------------------------

#eP.l[l,es,i,t] = 0.01;

# Carbon tax
# tCO2_Emarg.l[em,es,e,i,t] = 5 * tCO2_Emarg.l[em,es,e,i,t]; #Increase in CO2-tax of 10%

# #uTKexp.l['t1','heating','10030',t]$(d1sTPotential['t1','heating','10030',t]) = 10;
#  uTE.l['t4','heating','Coal and coke','10030',t]$(d1sTPotential['t4','heating','10030',t]) = 20000;

# #Residual calculation of the marginal costs of capital for given value of pESmarg_trace. Equivilant to equation governing uTK in abatement.gms
# uTKmarg_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = max (0.000001, ( pESmarg_trace[es,d,t,trace] - sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	) / pTK.l[d,t] ); 

# # Smoothed supply curve for technology l
# sqT2qES_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_trace[l,es,d,t,trace],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);

# # Smoothed supply curve for technology for all technologies
# sqT2qES_trace_suml[es,d,t,trace] = sum(l$(sTPotential.l[l,es,d,t]), sqT2qES_trace[l,es,d,t,trace] );

# uTKmarg_trace_eq[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sum(trace, uTKmarg_trace[l,es,d,t,trace]$(sqT2qES_trace_suml[es,d,t,trace]  >= 1 and sqT2qES_trace_suml[es,d,t,trace-1]  < 1) );

# pESmarg_trace_eq[es,d,t] =   smax(l, sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	+ uTKmarg_trace_eq[l,es,d,t]*pTK.l[d,t] )  ;

# #Initial values for pESmarg and sTold (helps the solver getting a good starting point)
# uTKmarg.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg_trace_eq[l,es,d,t] ;
# uTKmargNobound.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t] ;
# sqT2qES.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_trace_eq[l,es,d,t],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);
# pESmarg.l[es,d,t] = pESmarg_trace_eq[es,d,t] ;

 $FIX all_variables;
 $UNFIX main_endogenous;
 @Setbounds_abatement();
 Solve main using CNS;
 $IMPORT report_abatement.gms
 execute_unload 'Abatement_partial_carbon_tax.gdx';

# ------------------------------------------------------------------------------
# Module for generating supply curves and setting initial values
# ------------------------------------------------------------------------------

#Resetting uTE 
 uTE.l['t4','heating','Coal and coke','10030',t]$(d1sTPotential['t4','heating','10030',t]) = 1.1;

