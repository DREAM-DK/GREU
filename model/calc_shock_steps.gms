## SHOCK TO EXOGENOUS VARIABLES

# Apply carbon tax to specific energy types inkluding household use of energy
tCO2_Emarg.l[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t]) = tCO2_Emarg.l[em,es,e,d,t] + 200 * phaseInTax[t];
# tCO2_Emarg.l[em,es,e,i,t]$(d1tCO2_E[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t] + 200 * phaseInTax[t];

# Apply carbon tax to non-energy emissions
tCO2_xEmarg.l[i,t]$(d1tCO2_xE[i,t]) = tCO2_xEmarg.l[i,t] + 200 * phaseInTax[t];



## RUN CGE MODEL WITHOUT ENERGY TECHNOLOGY MODEL
# We turn the energy technology model off
d1switch_energy_technology = 0;
d1switch_integrate_energy_technology = 0;

$GROUP main_endogenous
  main_endogenous
  vG2vGDP, -qG, 
  vLumpsum, -vGovPrimaryBalance  
;

$FIX all_variables; $UNFIX main_endogenous;
# execute_unload 'Output\pre_CO2_shock.gdx';
solve main using CNS;


$IF %include_energy_technology% = 1:
  ## RUN CGE MODEL WITH ENERGY TECHNOLOGY MODEL
  d1switch_energy_technology = 1;
  d1switch_integrate_energy_technology = 1;

$GROUP main_endogenous
  main_endogenous
  vG2vGDP, -qG, 
  vLumpsum, -vGovPrimaryBalance    
;

  # Set starting values for the energy technology model
  $import initial_values_energy_technology.gms

  # Solve partial energy technology model
  $FIX all_variables;
  $UNFIX energy_technology_partial_endogenous;
  Solve energy_technology_partial_equations using CNS;
  execute_unload 'Output\shock_carbon_tax_energy_technology_partial.gdx';

  $FIX all_variables;
  $UNFIX main_endogenous;
  # @Setbounds_energy_technology();
  Solve main using CNS;

$ENDIF


# Report results
@import_from_modules("report")


EV_fig_steps['%step%_pre','reduction']  = emissions_pre;
EV_fig_steps['%step%_post','reduction'] = -EV_Shadow_price.l['Emissions'];
EV_fig_steps['%step%_pre','GEC']        = (EV_Shadow_price.l['EV']-EV_pre)/(EV_Shadow_price.l['Emissions']+emissions_pre)*1000000;
EV_fig_steps['%step%_post','GEC']       = EV_fig_steps['%step%_pre','GEC'];
emissions_pre = EV_fig_steps['%step%_post','reduction'];
EV_pre = EV_Shadow_price.l['EV'];


EV_steps['%step%',EV_set] = EV.l[EV_set];
EV_income_steps['%step%',income_set] = EV_income.l[income_set];

execute_unload 'Output\steps_tmp.gdx';