
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

# # tY_i_d.l[i,re,t]$(t.val >= t1.val) = 0.01 + tY_i_d.l[i,re,t];
tE_duty.l['ener_tax',es,e,d,t]$(t.val > t1.val) = 2*tE_duty.l['ener_tax',es,e,d,t]; #Doubling energy-taxes

$FIX all_variables;
$UNFIX main_endogenous;
Solve main using CNS;

@import_from_modules("report")
execute_unload 'Output\shock.gdx';
@import_from_modules("tests")

