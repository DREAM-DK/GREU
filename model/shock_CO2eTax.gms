
$IMPORT base_model.gms


$IMPORT sets/report.sets.gms # Has to be manually fittet to country specifik data
$Group Report_variables ;
@import_from_modules("report_def")

@import_from_modules("report")

execute_unload 'Output\baseline.gdx';

# ------------------------------------------------------------------------------
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2020, %terminal_year%);

tCO2e.l['energy',t] = 100 /1000000;

$FIX all_variables;
$UNFIX main_endogenous;
Solve main using CNS;

@import_from_modules("report")
execute_unload 'Output\CO2eTax.gdx';
@import_from_modules("tests")

