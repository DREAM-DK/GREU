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
# Calibrate model
# ------------------------------------------------------------------------------
$Group calibration_endogenous ;
@import_from_modules("calibration")
calibration.optfile=1;
$IMPORT calibration.gms
$IMPORT report_abatement.gms
execute_unloaddi "calibration.gdx";

# ------------------------------------------------------------------------------
# Calibrate model with lower variance on technology costs
# ------------------------------------------------------------------------------

 #eP.l[l,es,i,t] = 0.01;
 #uTKexp.l['t1','heating','10030',t]$(d1sTPotential['t1','heating','10030',t]) = 10;

#uTE.FX['t1','heating','Diesel for transport','10030',t]$(d1sTPotential['t1','heating','10030',t]) = 100;

 #$IMPORT calibration.gms
 #$IMPORT report_abatement.gms

 #execute_unloaddi "Abatement_partial.gdx";


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
 uTE.l['t4','heating','Coal and coke','10030',t]$(d1sTPotential['t4','heating','10030',t]) = 20000;

#Residual calculation of the marginal costs of capital for given value of pESmarg_trace. Equivilant to equation governing uTK in abatement.gms
uTKmarg_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = max (0.000001, ( pESmarg_trace[es,d,t,trace] - sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	) / pTK.l[d,t] ); 

# Smoothed supply curve for technology l
sqT2qES_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_trace[l,es,d,t,trace],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);

# Smoothed supply curve for technology for all technologies
sqT2qES_trace_suml[es,d,t,trace] = sum(l$(sTPotential.l[l,es,d,t]), sqT2qES_trace[l,es,d,t,trace] );

uTKmarg_trace_eq[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sum(trace, uTKmarg_trace[l,es,d,t,trace]$(sqT2qES_trace_suml[es,d,t,trace]  >= 1 and sqT2qES_trace_suml[es,d,t,trace-1]  < 1) );

pESmarg_trace_eq[es,d,t] =   smax(l, sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	+ uTKmarg_trace_eq[l,es,d,t]*pTK.l[d,t] )  ;

#Initial values for pESmarg and sTold (helps the solver getting a good starting point)
uTKmarg.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg_trace_eq[l,es,d,t] ;
uTKmargNobound.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t] ;
sqT2qES.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_trace_eq[l,es,d,t],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);
pESmarg.l[es,d,t] = pESmarg_trace_eq[es,d,t] ;

 $FIX all_variables;
 $UNFIX main_endogenous;
 @Setbounds_abatement();
 Solve main using CNS;
 $IMPORT report_abatement.gms
 execute_unload 'Abatement_partial_carbon_tax.gdx';

# ------------------------------------------------------------------------------
# Module for generating supply curves and setting initial values
# ------------------------------------------------------------------------------
 set scen / 1*100 /;

#Resetting uTE 
 uTE.l['t4','heating','Coal and coke','10030',t]$(d1sTPotential['t4','heating','10030',t]) = 1.1;

## Create scenario specific versions of all endogenous variables
$GROUP G_scenarios
  $LOOP abatement_endogenous_core:
    {name}_scen{sets}{$}[+scen]${conditions} "Alternate version of {name} used in {scenario} scenario."
  $ENDLOOP
;
$LOOP G_scenarios:
  {name}_exists_dummy{sets} = {conditions};
$ENDLOOP

# Set starting value of scenario specific variables equal to their original counterparts
$LOOP abatement_endogenous_core:
  {name}_scen.l{sets}{$}[+scen]${conditions} = {name}.l{sets};
$ENDLOOP

# Create scenario specific versions of entire model, with all endogenous variables replaced by scenario specific counterparts
$BLOCK B_scenarios
  # Substitute each variable in g_replace_scen by adding '_scen' to the name and adding ',scen' to the sets.
  $REGEX(('(?<=[\s\+\*\(\-\/])('+'|'.join(self.groups['abatement_endogenous_core'].keys())+')\[(.+?)\]'), '\g<1>_scen[\g<2>,scen]')  
    $LOOP abatement_equations_core:
        {name}_scen{sets}{$}[+scen]${conditions}.. {LHS} =E= {RHS};
    $ENDLOOP
  $ENDREGEX
$ENDBLOCK

#Including the new scenario specific variables in the list of variables
$GROUP all_variables_scen
  all_variables
  G_scenarios
;

#Solving the model for exogenous marginal price
$MODEL M_supply_initialization_pre
      B_scenarios
      -E_pESmarg_es_d_scen
;

$GROUP G_supply_initialization
        G_scenarios 
        - pESmarg_scen
;

 $FIX all_variables_scen;
 $UNFIX G_supply_initialization;
 @Setbounds_abatement();
 Solve M_supply_initialization_pre using CNS;
 execute_unload 'Abatement_partial_initialization_pre.gdx';

#Solving the model for different values of pESmarg 
parameter
  d1Expensive_tech_smooth_scen[es,d,t] "Most expensive technology"
  uTKmarg_eq[l,es,d,t]  "The marginal cost of capital in equilibrium, ie. at the point where demand is satisified"
  pESmarg_eq[es,d,t]    "The marginal cost of energy service in equilibrium, ie. at the point where demand is satisified"
;

    #Må være en smartere måde at gøre dette på...
      $GROUP init_group
        $LOOP sqT2qES_sum:
          {name}_scen{sets}{$}[+scen]${conditions} "Alternate version of {name} used in {scenario} scenario."
        $ENDLOOP
      ;
      $LOOP init_group:
        {name}_exists_dummy{sets} = (((t1.val <= t.val and t.val <= tEnd.val)) and sqT2qES_sum_exists_dummy[es,d,t]);
      $ENDLOOP

      $LOOP sqT2qES_sum:
        {name}_scen.l{sets}{$}[+scen]${conditions} = {name}.l{sets};
      $ENDLOOP


$BLOCK abatement_equations_supply_curve abatement_endogenous_supply_curve $(t1.val <= t.val and t.val <= tEnd.val)  
  .. pTPotential[l,es,d,t]	=E= sum(e, uTE[l,es,e,d,t]*pTE[es,e,d,t]$(d1pTE[es,e,d,t] and d1uTE[l,es,e,d,t]))+ uTKexp[l,es,d,t]*pTK[d,t];
  .. pESmarg_scen[es,d,t,scen]$(sum(l, d1sTPotential[l,es,d,t])) =E= ord(scen)/100 * d1Expensive_tech_smooth_scen[es,d,t];
  .. sqT2qES_sum_scen[es,d,t,scen] =E= sum(l$(d1sTPotential[l,es,d,t]), sqT2qES_scen[l,es,d,t,scen] );
$ENDBLOCK

# Re-determining the most expensive technology
d1Expensive_tech_smooth_scen[es,d,t] = smax(l, pTPotential.l[l,es,d,t] * (1 + 4 * eP.l[l,es,d,t]));

#Model for creating supply curve
$MODEL M_supply_initialization_supply_curve
  M_supply_initialization_pre
  abatement_equations_supply_curve;

@add_exist_dummies_to_model(M_supply_initialization_supply_curve) # Limit the main model to only include elements that are not dummied out

$GROUP+ G_supply_initialization 
abatement_endogenous_supply_curve;

# $GROUP+ all_variables_scen
#   sqT2qES_scen$(d1sTPotential[l,es,d,t])
#   ;

 $FIX all_variables_scen;
 $UNFIX G_supply_initialization;
 @Setbounds_abatement();
 execute_unload 'Abatement_partial_supply_curve_pre.gdx';
 Solve M_supply_initialization_supply_curve using CNS;
 execute_unload 'Abatement_partial_supply_curve.gdx';

# Smoothed supply curve for technology for all technologies
uTKmarg_eq[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sum(scen, uTKmarg_scen.l[l,es,d,t,scen]$(sqT2qES_sum_scen.l[es,d,t,scen]  >= 1 and sqT2qES_sum_scen.l[es,d,t,scen-1]  < 1) );
pESmarg_eq[es,d,t] =   smax(l, sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	+ uTKmarg_eq[l,es,d,t]*pTK.l[d,t] )  ;

# Initial values for pESmarg and sTold (helps the solver getting a good starting point)
uTKmarg.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg_eq[l,es,d,t] ;
uTKmargNobound.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t] ;
sqT2qES.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_eq[l,es,d,t],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);
pESmarg.l[es,d,t] = pESmarg_eq[es,d,t] ;

 execute_unload 'Abatement_partial_initialization.gdx';