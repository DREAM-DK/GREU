
$IMPORT base_model.gms


$IMPORT sets/report.sets.gms # Has to be manually fittet to country specifik data
$Group Report_variables ;
@import_from_modules("report_def")
@import_from_modules("report_baseline")

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

# tCO2e.l['energy_Corp',t]$(t.val ge 2025) = 750 * phaseInTax[t] * fromkrperton2billper1000tons;
# tCO2e.l['energy_Hh',t]$(t.val ge 2025)   = 750 * phaseInTax[t] * fromkrperton2billper1000tons;
# tCO2e.l['non_energy',t]$(t.val ge 2025)  = 750 * phaseInTax[t] * fromkrperton2billper1000tons;


tCO2e.l['energy_Corp',t]$(t.val ge 2025) = 150 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['energy_Hh',t]$(t.val ge 2025)   = 150 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['non_energy',t]$(t.val ge 2025)  = 150 * phaseInTax[t] * fromkrperton2billper1000tons;


$FIX all_variables;
$UNFIX main_endogenous, 
vG2vGDP, -qG, 
vLumpsum, -vGovPrimaryBalance
;
Solve main using CNS;

@import_from_modules("report")
execute_unload 'Output\CO2eTax.gdx';

jvY_i.l[i,t]$(t.val LE t1.val) = 0;
@import_from_modules("tests")

parameter EV_steps, emissions_pre;

EV_steps['step1_pre','emissions'] = 0;
EV_steps['step1_pre','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step1_pre','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
EV_steps['step1_post','emissions'] = Shadow_price.l['Emissions'];
EV_steps['step1_post','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step1_pre','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
emissions_pre = Shadow_price.l['Emissions'];


# Step 2
tCO2e.l['energy_Corp',t]$(t.val ge 2025) = 150*2 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['energy_Hh',t]$(t.val ge 2025)   = 150*2 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['non_energy',t]$(t.val ge 2025)  = 150*2 * phaseInTax[t] * fromkrperton2billper1000tons;

$FIX all_variables;
$UNFIX main_endogenous, 
vG2vGDP, -qG, 
vLumpsum, -vGovPrimaryBalance
;
Solve main using CNS;

@import_from_modules("report")

EV_steps['step2_pre','emissions'] = emissions_pre;
EV_steps['step2_pre','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step2_pre','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
EV_steps['step2_post','emissions'] = Shadow_price.l['Emissions'];
EV_steps['step2_post','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step2_post','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
emissions_pre = Shadow_price.l['Emissions'];


# Step 3
tCO2e.l['energy_Corp',t]$(t.val ge 2025) = 150*3 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['energy_Hh',t]$(t.val ge 2025)   = 150*3 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['non_energy',t]$(t.val ge 2025)  = 150*3 * phaseInTax[t] * fromkrperton2billper1000tons;

$FIX all_variables;
$UNFIX main_endogenous, 
vG2vGDP, -qG, 
vLumpsum, -vGovPrimaryBalance
;
Solve main using CNS;

@import_from_modules("report")

EV_steps['step3_pre','emissions'] = emissions_pre;
EV_steps['step3_pre','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step3_pre','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
EV_steps['step3_post','emissions'] = Shadow_price.l['Emissions'];
EV_steps['step3_post','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step3_post','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
emissions_pre = Shadow_price.l['Emissions'];


# Step 4
tCO2e.l['energy_Corp',t]$(t.val ge 2025) = 150*4 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['energy_Hh',t]$(t.val ge 2025)   = 150*4 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['non_energy',t]$(t.val ge 2025)  = 150*4 * phaseInTax[t] * fromkrperton2billper1000tons;

$FIX all_variables;
$UNFIX main_endogenous, 
vG2vGDP, -qG, 
vLumpsum, -vGovPrimaryBalance
;
Solve main using CNS;

@import_from_modules("report")

EV_steps['step4_pre','emissions'] = emissions_pre;
EV_steps['step4_pre','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step4_pre','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
EV_steps['step4_post','emissions'] = Shadow_price.l['Emissions'];
EV_steps['step4_post','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step4_post','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
emissions_pre = Shadow_price.l['Emissions'];




# Step 5
tCO2e.l['energy_Corp',t]$(t.val ge 2025) = 150*5 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['energy_Hh',t]$(t.val ge 2025)   = 150*5 * phaseInTax[t] * fromkrperton2billper1000tons;
tCO2e.l['non_energy',t]$(t.val ge 2025)  = 150*5 * phaseInTax[t] * fromkrperton2billper1000tons;

$FIX all_variables;
$UNFIX main_endogenous, 
vG2vGDP, -qG, 
vLumpsum, -vGovPrimaryBalance
;
Solve main using CNS;

@import_from_modules("report")

EV_steps['step5_pre','emissions'] = emissions_pre;
EV_steps['step5_pre','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step5_pre','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
EV_steps['step5_post','emissions'] = Shadow_price.l['Emissions'];
EV_steps['step5_post','Shadow_price'] = Shadow_price.l['Shadow_price'];
EV_steps['step5_post','tCO2e'] = tCO2e.l['energy_Corp','2030']/fromkrperton2billper1000tons;
emissions_pre = Shadow_price.l['Emissions'];




execute_unload 'Output\CO2eTax_steps.gdx';