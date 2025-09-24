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

$IF %include_abatement% = 1:
  execute_unload 'Output\baseline_abatement.gdx';
$ENDIF

$IF %include_abatement% = 0:
  execute_unload 'Output\baseline.gdx';
$ENDIF

# ------------------------------------------------------------------------------
# Calibrate electrification technologies
# ------------------------------------------------------------------------------
# $IF %include_abatement% = 1:
#   $import calib_electrification.gms;
#   # We recalculate baseline values with the new technologies
#   @import_from_modules("report_baseline")
# $ENDIF # include_abatement

# ------------------------------------------------------------------------------
# Calibrate CCS technologies
# ------------------------------------------------------------------------------
# $IF %include_abatement% = 1:
#   $import calib_CCS_example.gms;
#   # We recalculate baseline values with the new technologies
#   @import_from_modules("report_baseline")
# $ENDIF # include_abatement

# ------------------------------------------------------------------------------
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2021, %terminal_year%);

parameter phaseInTax[t];
  phaseInTax(t)$(t.val > 2024 and t.val < 2030) = (t.val - 2024) / (2030 - 2024);
  phaseInTax(t) $(t.val ge 2030) = 1;
display phaseInTax;


parameter EV_fig_steps, emissions_pre, EV_pre, EV_steps, EV_income_steps;
  emissions_pre = 0.0001;
  EV_pre = 0;


$SETGLOBAL step step1
$import calc_shock_steps.gms


$SETGLOBAL step step2
$import calc_shock_steps.gms


$SETGLOBAL step step3
$import calc_shock_steps.gms


$SETGLOBAL step step4
$import calc_shock_steps.gms


$IF %include_abatement% = 1:
execute_unload 'Output\shock_carbon_tax_abatement_steps.gdx';
$ENDIF

$IF %include_abatement% = 0:
execute_unload 'Output\shock_carbon_tax_steps.gdx';
$ENDIF

jvY_i.l[i,t]$(t.val LE t1.val) = 0;
@import_from_modules("tests")

