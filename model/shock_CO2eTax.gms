
$IMPORT base_model.gms


$IMPORT sets/report.sets.gms # Has to be manually fittet to country specifik data
$Group Report_variables ;
@import_from_modules("report_def")

@import_from_modules("report")

execute_unload 'Output\baseline.gdx';

# ------------------------------------------------------------------------------
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2021, %terminal_year%);

parameter fromkrperton2billper1000tons;
fromkrperton2billper1000tons = 1000/1000000000;

parameter phaseInTax[t];
  phaseInTax(t) = (t.val - 2024) / (2030 - 2024);
  phaseInTax(t) $(t.val ge 2030) = 1;
display phaseInTax;

tCO2e.l['energy',t]$(t.val ge 2025) = 750 * phaseInTax[t] * fromkrperton2billper1000tons;


$FIX all_variables;
$UNFIX main_endogenous, vG2vGDP, -qG, 
# vHhTaxes2vGDP, -vGovPrimaryBalance
;
Solve main using CNS;

@import_from_modules("report")
execute_unload 'Output\CO2eTax_Lumpsum2gov.gdx';

jvY_i.l[i,t]$(t.val LE t1.val) = 0;
@import_from_modules("tests")

