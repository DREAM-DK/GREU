$IMPORT functions.gms;
$IMPORT settings.gms

$IMPORT sets/time.sets.gms
$IMPORT sets/input_output.sets.gms
$IMPORT sets/output.sets.gms
$IMPORT sets/production.sets.gms
$IMPORT sets/emissions.sets.gms
$IMPORT sets/energy_taxes_and_emissions.sets.gms
$IMPORT sets/abatement.sets.gms

set_time_periods(%first_data_year%, %terminal_year%);

# ------------------------------------------------------------------------------
# Initialize models and groups used accross modules
# ------------------------------------------------------------------------------
$onMulti
model main;
model calibration;

$GROUP price_variables ; # Variables that are adjusted for steady state inflation
$GROUP quantity_variables ; # Variables that are adjusted for steady state productivity growth
$GROUP value_variables ; # Variables that are adjusted for both steady state inflation and productivity growth
$GROUP other_variables ; # Variables that are not adjusted for steady state inflation or productivity growth
$GROUP data_covered_variables ; # Variables that are covered by data
$GROUP G_flat_after_last_data_year ; # Variables that are extended with "flat forecast" after last data year
$PGROUP PG_flat_after_last_data_year ""; # Dummies that are extended with "flat forecast" after last data year

$GROUP main_endogenous "";
$GROUP calibration_endogenous "";

$IMPORT growth_adjustments.gms

# ------------------------------------------------------------------------------
# Import modules
# ------------------------------------------------------------------------------

# $IMPORT test_module.gms
#  $IMPORT labor_market.gms
$IMPORT energy_markets.gms; 
$IMPORT production_CES_energydemand.gms; 
$IMPORT production.gms; 
$IMPORT emissions.gms; 
$IMPORT energy_and_emissions_taxes.gms; 
# $IMPORT input_output.gms
# $IMPORT aggregates.gms
# $IMPORT imports.gms
# $IMPORT households.gms
$IMPORT abatement.gms

# ------------------------------------------------------------------------------
@inf_growth_adjust()

$IMPORT exist_dummies.gms

# ------------------------------------------------------------------------------

set eP_val /
  '1'
  '0.5'
  '0.3'
  '0.1'
  '0.05'
  /;

parameter
  qE_diff_eP[es,e,i,t,eP_val]
  ;

# eP.l[l,es,i,t] = 1;
# $IMPORT calibration.gms
# $IMPORT report_abatement.gms
# qE_diff_eP[es,e,i,t,'1'] = qE_diff[es,e,i,t];

# eP.l[l,es,i,t] = 0.5;
# $IMPORT calibration.gms
# $IMPORT report_abatement.gms
# qE_diff_eP[es,e,i,t,'0.5'] = qE_diff[es,e,i,t];

# eP.l[l,es,i,t] = 0.3;
# $IMPORT calibration.gms
# $IMPORT report_abatement.gms
# qE_diff_eP[es,e,i,t,'0.3'] = qE_diff[es,e,i,t];

# eP.l[l,es,i,t] = 0.1;
# $IMPORT calibration.gms
# $IMPORT report_abatement.gms
# qE_diff_eP[es,e,i,t,'0.1'] = qE_diff[es,e,i,t];

eP.l[l,es,i,t] = 0.05;
$IMPORT calibration.gms
$IMPORT report_abatement.gms
qE_diff_eP[es,e,i,t,'0.05'] = qE_diff[es,e,i,t];

execute_unloaddi "Abatement_partial.gdx";

# ------------------------------------------------------------------------------
# Calibration of electrification in the baseline
# ------------------------------------------------------------------------------

uTK.l['t_Electricity_calib','heating','10030','2020'] = 2.2;
uTK.l['t_Electricity_calib','heating','10030','2021'] = 2;
uTK.l['t_Electricity_calib','heating','10030','2022'] = 1.5;
uTK.l['t_Electricity_calib','heating','10030','2023'] = 1;

uTK.l['t_Electricity_calib_2','heating','10030','2020'] = 2.8;
uTK.l['t_Electricity_calib_2','heating','10030','2021'] = 2.5;
uTK.l['t_Electricity_calib_2','heating','10030','2022'] = 2.2;
uTK.l['t_Electricity_calib_2','heating','10030','2023'] = 2;

$FIX all_variables;
$UNFIX main_endogenous;

@set(main_endogenous, _mainendosaved, .l); # Save values of data covered variables prior to calibration

Solve main using CNS;
$IMPORT report_abatement.gms
execute_unload 'Abatement_partial_elec.gdx';
$import sanitychecks.gms

# ------------------------------------------------------------------------------
# Increasing carbon tax
# ------------------------------------------------------------------------------

#Shock
tCO2_Emarg.l[em,es,e,i,t] = 1.2 * tCO2_Emarg.l[em,es,e,i,t]; #Increase in CO2-tax of 10%
$FIX all_variables;
$UNFIX main_endogenous;
Solve main using CNS;
$IMPORT report_abatement.gms
execute_unload 'Abatement_partial_carbon_tax.gdx';