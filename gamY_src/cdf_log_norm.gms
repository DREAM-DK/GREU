# ======================================================================================================================
# Log-normal Distribution Visualization
# ======================================================================================================================
# This file generates visualization data for the log-normal distribution
# used in the abatement model's technology adoption curves.

# ----------------------------------------------------------------------------------------------------------------------
# 1. Parameter Definitions
# ----------------------------------------------------------------------------------------------------------------------
# 1.1 Scenario Set
set scen_cdf / 1*200/; # Number of points for distribution visualization

# 1.2 Core Parameters
parameter
  tech_cost[l] "Base cost of technology"
  tech_pot[l] "Potential of technology"
  cdf_scen_sigma_low[l,scen_cdf] "CDF with low sigma (0.05)"
  cdf_scen_sigma_med[l,scen_cdf] "CDF with medium sigma (0.15)"
  cdf_scen_sigma_high[l,scen_cdf] "CDF with high sigma (0.3)"
  cdf_scen_input[l,scen_cdf] "Input values for CDF calculation"
  cdf_scen_input_max[l] "Maximum input value for each technology"
;

# ----------------------------------------------------------------------------------------------------------------------
# 2. Technology Parameters
# ----------------------------------------------------------------------------------------------------------------------
# 2.1 Discrete Technology Values
tech_cost['t1'] = 1; # Base cost
tech_pot['t1']  = 1; # Potential

# ----------------------------------------------------------------------------------------------------------------------
# 3. Distribution Calculation
# ----------------------------------------------------------------------------------------------------------------------
# 3.1 Input Range Setup
# Smooth distribution calculation
cdf_scen_input_max[l] = tech_cost[l]*2; # Maximum input is twice the base cost

# 3.2 Input Value Generation
cdf_scen_input[l,scen_cdf] = ord(scen_cdf)/200 * cdf_scen_input_max[l];

# 3.3 CDF Calculation with Different Sigma Values
# Low sigma (0.05) - Sharp transition
cdf_scen_sigma_low[l,scen_cdf]$(tech_pot[l]) = 
  tech_pot[l]*@cdfLogNorm(cdf_scen_input[l,scen_cdf], tech_cost[l], 0.05);

# Medium sigma (0.15) - Moderate transition
cdf_scen_sigma_med[l,scen_cdf]$(tech_pot[l]) = 
  tech_pot[l]*@cdfLogNorm(cdf_scen_input[l,scen_cdf], tech_cost[l], 0.15);

# High sigma (0.3) - Smooth transition
cdf_scen_sigma_high[l,scen_cdf]$(tech_pot[l]) = 
  tech_pot[l]*@cdfLogNorm(cdf_scen_input[l,scen_cdf], tech_cost[l], 0.3);

# ----------------------------------------------------------------------------------------------------------------------
# 4. Results Export
# ----------------------------------------------------------------------------------------------------------------------
execute_unload 'cdf_log_norm.gdx';