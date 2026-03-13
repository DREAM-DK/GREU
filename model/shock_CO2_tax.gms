# $IF %include_energy_technology% = 0:
#   $SETGLOBAL test_CGE "1"
#   $SETGLOBAL test_energy_technology "0"
#   $IMPORT base_model.gms
# $ENDIF # include_energy_technology

# $IF %include_energy_technology% = 1:
#   $SETGLOBAL test_CGE "0"
#   $SETGLOBAL test_energy_technology "1"
#   $IMPORT base_model_energy_technology.gms 
# $ENDIF # include_energy_technology


$IMPORT sets/report.sets.gms # Has to be manually fittet to country specific data
$Group Report_variables ;
@import_from_modules("report_def")
@import_from_modules("report_baseline")
@import_from_modules("report")

$IF %include_energy_technology% = 1:
  execute_unload 'Output/baseline_energy_technology.gdx';
$ENDIF

$IF %include_energy_technology% = 0:
  execute_unload 'Output/baseline.gdx';
$ENDIF

# # ------------------------------------------------------------------------------
# # Calibrate electrification technologies
# # ------------------------------------------------------------------------------
# $IF %include_energy_technology% = 1:
#   $import calib_electrification.gms;
# $ENDIF # include_energy_technology

# # ------------------------------------------------------------------------------
# # Calibrate CCS technologies
# # ------------------------------------------------------------------------------
# $IF %include_energy_technology% = 1:
#   $import Calib_CCS.gms;
# $ENDIF # include_energy_technology

# ------------------------------------------------------------------------------
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2021, 2050);

parameter phaseInTax[t];
  phaseInTax(t)$(t.val > 2024 and t.val < 2030) = (t.val - 2024) / (2030 - 2024);
  phaseInTax(t) $(t.val ge 2030) = 1;
display phaseInTax;


parameter
  tCO2_energy_technology[em,es,e,i,t]
  ;

tCO2_energy_technology[em,es,e,i,t]$(sum(l, d1uTE[l,es,e,i,t]) and d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];


## SHOCK TO EXOGENOUS VARIABLES

# Apply carbon tax to specific energy types inkluding household use of energy
tCO2_Emarg.l[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t]) = tCO2_Emarg.l[em,es,e,d,t] + 750 * phaseInTax[t];
# tCO2_Emarg.l[em,es,e,i,t]$(d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t] + 750 * phaseInTax[t];

# Apply carbon tax to non-energy emissions
tCO2_xEmarg.l[i,t]$(d1tCO2_xE[i,t]) = tCO2_xEmarg.l[i,t] + 750 * phaseInTax[t];



## RUN CGE MODEL WITHOUT ENERGY TECHNOLOGY MODEL
# We turn the energy technology model off
d1switch_energy_technology[t] = 0;
d1switch_integrate_energy_technology[t] = 0;

$GROUP main_endogenous
  main_endogenous
  -uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
  vG2vGDP, -qG, 
  vLumpsum, -vGovPrimaryBalance  
;

$FIX all_variables; $UNFIX main_endogenous;
# execute_unload 'Output/pre_CO2_shock.gdx';
solve main using CNS;

tCO2_energy_technology[em,es,e,i,t]$(sum(l, d1uTE[l,es,e,i,t]) and d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];


$IF %include_energy_technology% = 1:
  ## RUN CGE MODEL WITH ENERGY TECHNOLOGY MODEL
  d1switch_energy_technology[t] = 1;
  d1switch_integrate_energy_technology[t] = 1;

$GROUP main_endogenous
  main_endogenous
  uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), -jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
  vG2vGDP, -qG, 
  vLumpsum, -vGovPrimaryBalance    
;

  # Set starting values for the energy technology model
  $import Supply_curve_energy_technology.gms

  # Solve partial energy technology model
  $FIX all_variables;
  $UNFIX energy_technology_partial_endogenous;
  Solve energy_technology_partial_equations using CNS;
  execute_unload 'Output/shock_carbon_tax_energy_technology_partial.gdx';

  $FIX all_variables;
  $UNFIX main_endogenous;
  # @Setbounds_energy_technology();
  Solve main using CNS;

$ENDIF


# Report results
@import_from_modules("report")

$IF %include_energy_technology% = 1:
execute_unload 'Output/shock_carbon_tax_energy_technology.gdx';
$ENDIF

$IF %include_energy_technology% = 0:
execute_unload 'Output/shock_carbon_tax.gdx';
$ENDIF

jvY_i.l[i,t]$(t.val LE t1.val) = 0;
@import_from_modules("tests")

