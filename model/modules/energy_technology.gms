# ------------------------------------------------------------------------------
# Energy Technology Choice Model
# ------------------------------------------------------------------------------
# This partial model implements the technology choice model for energy services
# using a smooth transition approach with log-normal distributions.

# ------------------------------------------------------------------------------
# 1. Variable and Dummy Definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

# 1.1 Dummy Variables
$SetGroup SG_Energy_technology_dummies
  d1sqTPotential[l,es,d,t] "Dummy determining the existence of technology potentials"
  d1pTK[d,t] "Dummy determining the existence of user costs for technologies"
  d1uTE[l,es,e,d,t] "Dummy determining the existence of energy input in technology"
  d1qES_e[es,e,d,t] "Dummy determining the existence of energy use (sum across technologies)"
  d1qES[es,d,t] "Dummy determining the existence of energy service, quantity"
  d1qI_k_i_energy_tech[k,i,t] "Dummy determining the existence of energy technology capital use"
;

parameter
  d1switch_energy_technology "Dummy to control whether the energy technology model is turned on (=1) or off (=0)"
  d1switch_integrate_energy_technology "Dummy to control whether the energy technology model is integrated with the CGE-model (=1) or not (=0)"
  jqESE_phaseout[t] "Parameter to phase out jqESE in the calibration model"
  smooth_factor "Parameter governing smoothing of total energy technology costs (pTPotential). This is used for calculating the technology-specific smoothing parameter eP."
;

# 1.2 Main Variables
$Group+ all_variables
  # 1.2.1 Exogenous Variables

  # 1.2.1.1 Exogenous Input Prices
  pTK[d,t]$(d1pTK[d,t]) "User cost of capital in technologies for energy services"
  jpTK[d,t]$(d1pTK[d,t]) "Share parameter linking capital user cost in energy technology model to CGE model"

  # 1.2.1.2 Exogenous Energy Service Demand
  qES[es,d,t]$(d1qES[es,d,t]) "Energy service, quantity."
  jES[es,d,t]$(d1qES[es,d,t]) "Share parameter linking energy service in energy technology model to energy service demand in CGE model"
  
  # 1.2.1.3 Exogenous Technology Parameters
  sqTPotential[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Potential supply by technology l in ratio of energy service (share of qES)"
  theta[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "jsk same sqTPotential. only used adhoc for loading data"
  eP[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Parameter governing efficiency of costs of technology l (smoothing parameter)"
  uTE[l,es,e,d,t]$(d1uTE[l,es,e,d,t]) "Input of energy in technology l per PJ output at full potential"

  vTI[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Investment cost, billion EUR per PJ output at full potential"
  vTC[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Variable capital costs, billion EUR per PJ output at full potential"

  # 1.2.2 Core Endogenous Variables
  # 1.2.2.1 Levelized Cost of Energy (LCOE) 
  uTKexp[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Average input of machinery capital in technology l per PJ output at full potential"

  # 1.2.2.1 Marginal Capital Intensity
  uTKmargNoBound[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Input of machinery capital in technology l per PJ output at the margin of supply - Unrestricted"
  uTKmarg[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Input of machinery capital in technology l per PJ output at the margin of supply - Lower bounded"
  
  # 1.2.2.2 Prices
  pTPotential[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Average price of technology l at full potential, ie. when sTSupply=sqTPotential"
  pT[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Average price of technology l at level of supply"
  pESmarg[es,d,t]$(sum(l, d1sqTPotential[l,es,d,t])) "Marginal price of energy services based on the supply by technologies"

  # 1.2.2.3 Supply Variables
  sqT[l,es,d,t]$(d1sqTPotential[l,es,d,t])   "Supply by technology l in ratio of energy service (share of qES)"

  # 1.2.3 Output Variables
  # 1.2.3.1 Values and Prices
  vTSupply[l,es,d,t]$(d1sqTPotential[l,es,d,t]) "Value (or costs) of energy service supplied by technology l "
  vES[es,d,t]$(sum(l, d1sqTPotential[l,es,d,t])) "Value of energy service" 
  pES[es,d,t]$(sum(l, d1sqTPotential[l,es,d,t])) "Energy service, price."
  vESK[es,d,t]$(d1qES[es,d,t]) "Value of machinery capital"

  # 1.2.3.2 Input Quantities
  qESE[es,e,d,t]$(d1qES_e[es,e,d,t]) "Quantity of energy in energy services"
  qESK[es,d,t]$(d1qES[es,d,t]) "Quantity of machinery capital in energy services"

  # 1.2.4 Variables for integration with CGE-model
  jqESE[es,e,i,t]$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t]) "Share parameter linking energy input in the energy technology model to energy input in the CGE-model"
  qI_k_i_energy_tech[k,i,t] "Quantity of investments from the energy technology model"
  vI_k_i_energy_tech[k,i,t] "Value of investments from the energy technology model"
  qEmmE_CCS[es,e,d,t]$(d1qES_e[es,e,d,t] and sameas(e,'Captured CO2')) "Quantity of CCS in energy services"
  # 1.2.4.1 Baseline variables for integration and testing
  pK_k_i_baseline[k,i,t] "Baseline user cost of capital - for integration"
  qK_k_i_baseline[k,i,t] "Baseline capital quantity - for integration"
  pProd_baseline[pf,i,t] "Price in production tree (baseline) - for testing"
  qProd_baseline[pf,i,t] "Quantity in production tree (baseline) - for testing"
  vI_k_i_baseline[k,i,t] "Value of investments (baseline) - for testing"
  qEtot_baseline[e,t] "Total quantity of energy use (baseline) - for testing"
;

parameter
  LifeSpan[l,es,d,t] "Life span of technology l in years"
  DiscountRate[l,es,d] "Discount rate of technology l"
  ;

$ENDIF # variables

# ------------------------------------------------------------------------------
# 2. Model Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK energy_technology_LCOE_equations energy_technology_LCOE_endogenous $(t1.val <= t.val and t.val <= tEnd.val and d1switch_energy_technology)

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  $(t.val <= tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]).. 
    uTKexp[l,es,d,t] =E=
     (vTI[l,es,d,t] # Investment costs
      + @Discount2t(vTC[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt])) # Discounted variable costs
        / @Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Dicounted denominator
        ;

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  uTKexp&_tEnd[l,es,d,t]$(t.val > tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]).. 
    uTKexp[l,es,d,t] =E= 
     (vTI[l,es,d,t] # Investment costs
      + @Discount2t(vTC[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discounted variable costs until tEnd
      + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({vTC[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
      / (@Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discount denominator until tEnd
       + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted denominator after tEnd
       ; 

$ENDBLOCK


# 2.1 Core Model Equations
$BLOCK energy_technology_equations_core energy_technology_endogenous_core $(t1.val <= t.val and t.val <= tEnd.val and d1switch_energy_technology) 

  # 2.1.2 Technology Choice Equations
  # Equality between marginal price of energy service and marginal price of technology 
  # determines capital intensity of technologies at the margin of supply
  uTKmargNoBound[l,es,d,t].. pESmarg[es,d,t] =E= 
    sum(e$(d1pEpj[es,e,d,t] and d1uTE[l,es,e,d,t]), uTE[l,es,e,d,t]*pEpj_marg[es,e,d,t]) + 
    uTKmargNoBound[l,es,d,t]*pTK[d,t];

  # A lower bound close to zero is set to avoid indeterminancy in cdfLognorm in sqTqES
  # uTKmargNoBound<=0 happen when a technology is very energy intensive (ineffecient)
  .. uTKmarg[l,es,d,t] =E= max(0.0001, uTKmargNoBound[l,es,d,t]);

  # Supply of technology l in ratio of energy service demand qES
  .. sqT[l,es,d,t] =E= 
    sqTPotential[l,es,d,t]*@cdfLogNorm(uTKmarg[l,es,d,t], uTKexp[l,es,d,t], eP[l,es,d,t]);

  # Shadow value identifying marginal technology for energy purpose
  pESmarg[es,d,t].. 1 =E= sum(l$(d1sqTPotential[l,es,d,t]), sqT[l,es,d,t]);
                
$ENDBLOCK

# 2.2 Output Equations
$BLOCK energy_technology_equations_output energy_technology_endogenous_output $(t1.val <= t.val and t.val <= tEnd.val and d1switch_energy_technology) 
  # 2.2.1 Energy and Capital Use
  # Use of energy in production of energy service
  .. qESE[es,e,d,t] =E= 
        max[10**(-6),
            qES[es,d,t] * sum(l$(d1sqTPotential[l,es,d,t]), sqT[l,es,d,t] * uTE[l,es,e,d,t])];
    
  # Use of machinery capital for technologies
  .. qESK[es,d,t] =E= 
    qES[es,d,t] * 
    sum(l$(d1sqTPotential[l,es,d,t]),
        sqTPotential[l,es,d,t]*@PartExpLogNorm(uTKmarg[l,es,d,t], uTKexp[l,es,d,t], eP[l,es,d,t]));

  # 2.2.2 Value and Price Calculations
  # Value of energy service                                       
  .. vES[es,d,t] =E= 
    sum(e, qESE[es,e,d,t]*pEpj_marg[es,e,d,t]) + qESK[es,d,t]*pTK[d,t];

  # Price of energy service
  .. pES[es,d,t] =E= vES[es,d,t] / qES[es,d,t];   

  # Value of machinery capital
  .. vESK[es,d,t] =E= qESK[es,d,t]*pTK[d,t];

$ENDBLOCK

$BLOCK energy_technology_equations_links energy_technology_endogenous_links $(t1.val <= t.val and t.val <= tEnd.val and d1switch_energy_technology and d1switch_integrate_energy_technology)

  # qES is determined by the CGE-model. jES (exogenous) is the difference between qES and qREes in the baseline
  .. qES[es,i,t] =E= jES[es,i,t]*qREes[es,i,t];

  # When integrating the energy technology model with the CGE-model, the change in pTK is determined by the CGE-model. 
  # jpTK (exogenous) is the relative difference between pTK and pK_k_i['iM',i,t] in the baseline
  .. pTK[i,t] =E= pD['iM',t]*jpTK[i,t];

  # jqESE is endogenous when calibrating the model. In shocks, jqESE is exogenous and uREa is endogenous
  # Note that when this equation is used in the calibration model, then it removes E_uREa_flat for these dimensions
  uREa[es,e,i,t]$(d1qES_e[es,e,i,t]).. qESE[es,e,i,t] + jqESE[es,e,i,t] =E= qREa[es,e,i,t];

  # Link energy technology capital use to factor demand module
  .. qI_k_i_energy_tech[k,i,t] =E= sum(es$(es2k[es,k]), qESK[es,i,t]);

  # Link energy technology capital value to factor demand module
  .. vI_k_i_energy_tech[k,i,t] =E= sum(es$(es2k[es,k]), vESK[es,i,t]);

  # CCS in energy services
  .. qEmmE_CCS[es,e,d,t] =E= qESE[es,e,d,t];



$ENDBLOCK

# 2.3 Model Assembly
$GROUP energy_technology_endogenous
  energy_technology_LCOE_endogenous
  energy_technology_endogenous_core
  energy_technology_endogenous_output
  energy_technology_endogenous_links
;

$MODEL energy_technology_equations  
  energy_technology_LCOE_equations
  energy_technology_equations_core
  energy_technology_equations_output 
  energy_technology_equations_links
;

# Add equation and endogenous variables to main model
model main / energy_technology_equations /;
$GROUP+ main_endogenous energy_technology_endogenous;

# Create partial energy technology model
$GROUP energy_technology_partial_endogenous
  energy_technology_LCOE_endogenous
  energy_technology_endogenous_core
  energy_technology_endogenous_output
;

$MODEL energy_technology_partial_equations  
  energy_technology_LCOE_equations
  energy_technology_equations_core
  energy_technology_equations_output 
;

@add_exist_dummies_to_model(energy_technology_partial_equations);

# 2.4 Solver Helper Function
$FUNCTION Setbounds_energy_technology():
  # Set bounds for uTKmarg
  uTKmarg.lo[l,es,d,t]$(sqTPotential.l[l,es,d,t] and uTKmarg.lo[l,es,d,t] ne uTKmarg.up[l,es,d,t]) = 0.001*0.99;
  uTKmarg.up[l,es,d,t]$(sqTPotential.l[l,es,d,t] and uTKmarg.lo[l,es,d,t] ne uTKmarg.up[l,es,d,t]) = 
    uTKexp.l[l,es,d,t]*[1+5*eP.l[l,es,d,t]]*1.01;
  
  # Set bounds for sqT
  sqT.lo[l,es,d,t]$(sqTPotential.l[l,es,d,t] and sqT.lo[l,es,d,t] ne sqT.up[l,es,d,t]) = 0.00000000001;
  sqT.up[l,es,d,t]$(sqTPotential.l[l,es,d,t] and sqT.lo[l,es,d,t] ne sqT.up[l,es,d,t]) = sqTPotential.l[l,es,d,t];
  
  # Set bounds for pESmarg
  pESmarg.lo[es,d,t]$(sum(l,sqTPotential.l[l,es,d,t]) and pESmarg.lo[es,d,t] ne pESmarg.up[es,d,t]) = 0.001;
$ENDFUNCTION

$ENDIF # equations

# ------------------------------------------------------------------------------
# 3. Data and Parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

# 3.1 Data Loading
$GROUP energy_technology_data_variables
  sqTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  vTI[l,es,d,t]
  vTC[l,es,d,t]
  pTK[d,t]
  qES[es,d,t]

;

# Load data from generic dummy data
$IF1 %generic_energy_technology_data% == 1:
  @load(energy_technology_data_variables, "../data/data.gdx")
  $GROUP+ data_covered_variables energy_technology_data_variables;

  # Load LifeSpan from data.gdx
  execute_load "../data/data.gdx" LifeSpan=LifeSpan;
$ENDIF1

# Load data from excel-based data
$IF1 %generic_energy_technology_data% == 0:
  @load(energy_technology_data_variables, "../data/Energy_technology_data/Excel_data/Energy_technology_data.gdx")
  $GROUP+ data_covered_variables energy_technology_data_variables;

  # Load LifeSpan from data.gdx
  execute_load "../data/Energy_technology_data/Excel_data/Energy_technology_data.gdx" LifeSpan=LifeSpan;
$ENDIF1

# 3.2 Initial Values
# Set discount rate
DiscountRate[l,es,d]$(sum(t, sqTPotential.l[l,es,d,t])) = 0.05;

# Set share parameter
jES.l[es,i,t]$(qES.l[es,i,t] and qREes.l[es,i,t]) = qES.l[es,i,t]/qREes.l[es,i,t];
jpTK.l[i,t]$(d1pTK[i,t] and d1K_k_i['iM',i,t]) = pTK.l[i,t]/pK_k_i.l['iM',i,t];

# 3.3 Dummy Variable Setup
# Set dummy determining the existence of technology potentials
d1sqTPotential[l,es,d,t] = yes$(sqTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1pTK[d,t] = yes$(sum((l,es), d1sqTPotential[l,es,d,t]));
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));
d1qES[es,d,t] = yes$(qES.l[es,d,t]);
d1qI_k_i_energy_tech[k,i,t] = yes$(sum((l,es)$(es2k[es,k]), d1sqTPotential[l,es,i,t]));
d1switch_energy_technology = 1;
d1switch_integrate_energy_technology = 1;

# 4.4 Starting values for Levelized Cost of Energy (LCOE)
uTKexp.l[l,es,d,t]$(t.val <= tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
   (vTI.l[l,es,d,t] # Investment costs
    + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt])) # Discounted variable costs
      / @Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Dicounted denominator
      ;

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  uTKexp.l[l,es,d,t]$(t.val > tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
     (vTI.l[l,es,d,t] # Investment costs
      + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discounted variable costs until tEnd
      + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({vTC.l[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
      / (@Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discount denominator until tEnd
       + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted denominator after tEnd
       ; 

pTPotential.l[l,es,d,t] = 
  sum(e, uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t]) + uTKexp.l[l,es,d,t]*pTK.l[d,t];

smooth_factor = 0.04;

# Set smoothing parameters (we recalculate this in base_model_energy_technology.gms because electricity prices are not present in some cases in the data)
eP.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = smooth_factor*pTPotential.l[l,es,d,t]/uTKexp.l[l,es,d,t];

jqESE_phaseout[t]$(t.val = t1.val) = 1;
jqESE_phaseout[t]$(t.val = t1.val+1) = 0.8;
jqESE_phaseout[t]$(t.val = t1.val+2) = 0.6;
jqESE_phaseout[t]$(t.val = t1.val+3) = 0.4;
jqESE_phaseout[t]$(t.val = t1.val+4) = 0.2;
jqESE_phaseout[t]$(t.val >= t1.val+5) = 0;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Starting values
# ------------------------------------------------------------------------------
$IF %stage% == "starting_values":

set_time_periods(%calibration_year%, %calibration_year%);

$Group non_default_starting_values
  # Variables that require custom starting values
;

# Set custom starting values for the variables in non_default_starting_values here

$ENDIF # starting_values

# ------------------------------------------------------------------------------
# 4. Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK energy_technology_calibration energy_technology_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val and d1switch_energy_technology)

  qK_k_i&energy_tech[k,i,t]$(t1[t] and d1qI_k_i_energy_tech[k,i,t])..
    pK_k_i[k,i,t]*qK_k_i[k,i,t] =E= pK_k_i_baseline[k,i,t]*qK_k_i_baseline[k,i,t] 
                                  - vI_k_i_energy_tech[k,i,t];

  jES[es,i,t]$(not t1[t] and d1qES[es,i,t1])..
    jES[es,i,t] =E= jES[es,i,t1];

  jqESE[es,e,i,t]$(not t1[t] and d1qES_e[es,e,i,t])..
    jqESE[es,e,i,t] =E= jqESE[es,e,i,t1]*jqESE_phaseout[t];

$ENDBLOCK

model calibration / 
  energy_technology_equations
  energy_technology_calibration
/;

# 4.2 Calibration Variables
$GROUP calibration_endogenous
  calibration_endogenous
  energy_technology_endogenous
  energy_technology_calibration_endogenous
  -jI_k_i[k,i]$(sum(t, d1qI_k_i_energy_tech[k,i,t]) and d1switch_energy_technology), qK_k_i$(t0[t] and sum(tt, d1qI_k_i_energy_tech[k,i,tt]) and d1switch_energy_technology)
  -qES[es,i,t1], jES[es,i,t]
  -pTK[i,t], jpTK[i,t]
  jqESE[es,e,i,t]
;

# 4.3 Flat Variables After Last Data Year
$Group+ G_flat_after_last_data_year
  vES[es,d,t]
  qESE[es,e,d,t]
  qESK[d,t]
  vTSupply[l,es,d,t]
  uTKmarg[l,es,d,t]
  pESmarg[es,d,t]
  sqT[l,es,d,t]
  eP[l,es,d,t]
;


$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests calibration
# ------------------------------------------------------------------------------
$IF %stage% == "tests_baseline":

# Test that the value of capital-energy nest in CGE model does not change.
# Tests only the dimensions where energy technologies exists
LOOP((pfNest,i,t)$(tDataEnd[t] and sum(k$(sum(pf_bottom_capital$(sameas[pf_bottom_capital,k]), pf_mapping[pfNest,pf_bottom_capital,i])), d1qI_k_i_energy_tech[k,i,t]) and d1switch_energy_technology),
  ABORT$(abs((pProd.l[pfNest,i,t]*qProd.l[pfNest,i,t] / (pProd_baseline.l[pfNest,i,t]*qProd_baseline.l[pfNest,i,t]) - 1)*100) > 1e-7)
        'Value of capital-energy nest has changed when integrating energy technology model');

# Test that the quantity of capital-energy nest in CGE model does not change.
# Tests only the dimensions where energy technologies exists
LOOP((pfNest,i,t)$(tDataEnd[t] and sum(k$(sum(pf_bottom_capital$(sameas[pf_bottom_capital,k]), pf_mapping[pfNest,pf_bottom_capital,i])), d1qI_k_i_energy_tech[k,i,t]) and d1switch_energy_technology),
  ABORT$(abs((qProd.l[pfNest,i,t] / qProd_baseline.l[pfNest,i,t] - 1)*100) > 1e-7)
        'Quantity of capital-energy nest has changed when integrating energy technology model');

# Test that investments for energy technologies do not exceed investments in data
LOOP((k,i,t)$(tDataEnd[t] and (sameas[k,'iB'] or sameas[k,'iT'] or sameas[k,'iM']) and d1qI_k_i_energy_tech[k,i,t] and d1switch_energy_technology),
  ABORT$(vI_k_i_baseline.l[k,i,t] - vI_k_i_energy_tech.l[k,i,t] < 0)
        'Investments in the energy-technology model exceeds investments in the CGE model');

LOOP((e,t)$(t1.val <= t.val and t.val <= tEnd.val and sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t]) and d1switch_energy_technology),
  if (abs(qEtot.l[e,t] / qEtot_baseline.l[e,t] - 1) > 0.03,
    put_utility 'log' / 'WARNING: The total amount of energy use has changed more than 3% from the baseline';
  );
);

$ENDIF # tests

# ------------------------------------------------------------------------------
# Tests shock
# ------------------------------------------------------------------------------
$IF %stage% == "tests_shock":

LOOP((es,i,t)$(t1.val <= t.val and t.val <= tEnd.val and d1qES[es,i,t] and sum((em,e), tCO2_Emarg_pj.l[em,es,e,i,t]-tCO2_Emarg_pj_baseline.l[em,es,e,i,t])>0 and d1switch_energy_technology),
  if (pREes_change.l[es,i,t] < 0,
    put_utility 'log' / 'WARNING: Negative change in price of energy service in the CGE model (continuing run)';
  );
);

LOOP((es,i,t)$(t1.val <= t.val and t.val <= tEnd.val and d1qES[es,i,t] and sum((em,e), tCO2_Emarg_pj.l[em,es,e,i,t]-tCO2_Emarg_pj_baseline.l[em,es,e,i,t])>0 and d1switch_energy_technology),
  if (pREes_change.l[es,i,t] > pREes_mechanic_change.l[es,i,t],
    put_utility 'log' / "WARNING: Change in price of energy service in the CGE model exceed mechanical price change (continuing run)";
  );
);

# Test that price changes in the CGE model are the same as in the energy technology model
LOOP((es,i,t)$(t1.val <= t.val and t.val <= tEnd.val and not jqESE_phaseout[t] and d1qES[es,i,t] and sum((em,e), tCO2_Emarg_pj.l[em,es,e,i,t]-tCO2_Emarg_pj_baseline.l[em,es,e,i,t])>0 and d1switch_energy_technology),
  ABORT$(abs(pREes_change.l[es,i,t] - pES_change.l[es,i,t]) > 1e-7)
        'Price change in the CGE model does not match price change in the energy technology model');

$ENDIF # tests