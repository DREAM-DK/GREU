set scen_cdf / 1*200/;

parameter
  tech_cost[l]
  tech_pot[l]
  cdf_scen_sigma_low[l,scen_cdf]
  cdf_scen_sigma_med[l,scen_cdf]
  cdf_scen_sigma_high[l,scen_cdf]
  cdf_scen_input[l,scen_cdf]
  cdf_scen_input_max[l]
  ;

# Discrete
tech_cost['t1'] = 1;
tech_pot['t1']  = 1; 

# Smooth
cdf_scen_input_max[l] = tech_cost[l]*2;

cdf_scen_input[l,scen_cdf] = ord(scen_cdf)/200 * cdf_scen_input_max[l];

cdf_scen_sigma_low[l,scen_cdf]$(tech_pot[l])  = tech_pot[l]*@cdfLogNorm(cdf_scen_input[l,scen_cdf],tech_cost[l],0.05);
cdf_scen_sigma_med[l,scen_cdf]$(tech_pot[l])  = tech_pot[l]*@cdfLogNorm(cdf_scen_input[l,scen_cdf],tech_cost[l],0.15);
cdf_scen_sigma_high[l,scen_cdf]$(tech_pot[l]) = tech_pot[l]*@cdfLogNorm(cdf_scen_input[l,scen_cdf],tech_cost[l],0.3);

# Unload
execute_unload 'cdf_log_norm.gdx';