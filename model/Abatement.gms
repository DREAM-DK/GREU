# ------------------------------------------------------------------------------
# Abatement Model
# ------------------------------------------------------------------------------
# This partial model implements the technology choice model for energy services
# using a smooth transition approach with log-normal distributions.

# ------------------------------------------------------------------------------
# 1. Variable and Dummy Definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

# 1.1 Dummy Variables
$SetGroup SG_Abatement_dummies
  d1sqTPotential[l,es,d,t] "Dummy determining the existence of technology potentials"
  d1pTE[es,e,d,t] "Dummy determining the existence of input price of energy in technologies for energy services"
  d1pTK[d,t] "Dummy determining the existence of user costs for technologies"
  d1uTE[l,es,e,d,t] "Dummy determining the existence of energy input in technology"
  d1qES_e[es,e,d,t] "Dummy determining the existence of energy use (sum across technologies)"
  d1qES[es,d,t] "Dummy determining the existence of energy service, quantity"
  d1switch_abatement[t] "Dummy to control whether the abatement is turned on (=1) or off (=0)"
;

# 1.2 Main Variables
$Group+ all_variables
  # 1.2.1 Exogenous Variables

  # 1.2.1.1 Exogenous Input Prices
  pTK[d,t]$(d1pTK[d,t]) "User cost of capital in technologies for energy services"
  pTE_base[es,e,d,t]$(d1pTE[es,e,d,t]) "Base price of energy input, excl. taxes, billion EUR per PJ"
  pTE_tax[es,e,d,t]$(d1pTE[es,e,d,t]) "Tax on energy input, billion EUR per PJ"
  
  # 1.2.1.2 Exogenous Energy Service Demand
  qES[es,d,t]$(d1qES[es,d,t]) "Energy service, quantity."
  
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
  pTE[es,e,d,t]$(d1pTE[es,e,d,t]) "Input price of energy in technologies for energy services" 
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

  # 1.2.3.2 Input Quantities
  qES_e[es,e,d,t]$(d1qES_e[es,e,d,t]) "Quantity of energy in energy services"
  qES_k[d,t]$(d1pTK[d,t]) "Quantity of machinery capital in energy services"
  qESE[es,e,d,t]$(d1qES_e[es,e,d,t]) "Quantity of energy in energy services"
  qESK[es,d,t]$(d1pTK[d,t]) "Quantity of machinery capital in energy services"
;

parameter
  LifeSpan[l,es,d] "Life span of technology l in years"
  DiscountRate[l,es,d] "Discount rate of technology l"
  ;

$ENDIF # variables

# ------------------------------------------------------------------------------
# 2. Model Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK abatement_LCOE_equations abatement_LCOE_endogenous $(t1.val <= t.val and t.val <= tEnd.val and d1switch_abatement[t])

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  $(t.val <= tend.val-LifeSpan[l,es,d]+1 and d1sqTPotential[l,es,d,t]).. 
    uTKexp[l,es,d,t] =E=
     (vTI[l,es,d,t] # Investment costs
      + @Discount2t(vTC[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt])) # Discounted variable costs
        / @Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt]) # Dicounted denominator
        ;

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  uTKexp&_tEnd[l,es,d,t]$(t.val > tend.val-LifeSpan[l,es,d]+1 and d1sqTPotential[l,es,d,t]).. 
    uTKexp[l,es,d,t] =E= 
     (vTI[l,es,d,t] # Investment costs
      + @Discount2t(vTC[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt]) # Discounted variable costs until tEnd
      + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({vTC[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
      / (@Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt]) # Discount denominator until tEnd
       + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d]-1+t.val-tEnd.val})) # Discounted denominator after tEnd
       ; 

$ENDBLOCK


# 2.1 Core Model Equations
$BLOCK abatement_equations_core abatement_endogenous_core $(t1.val <= t.val and t.val <= tEnd.val and d1switch_abatement[t]) 
  
  # 2.1.1 Input Price Equations
  # Price on energy input including taxes
  .. pTE[es,e,d,t] =E=  pTE_base[es,e,d,t] + pTE_tax[es,e,d,t]; 

  # 2.1.2 Technology Choice Equations
  # Equality between marginal price of energy service and marginal price of technology 
  # determines capital intensity of technologies at the margin of supply
  uTKmargNoBound[l,es,d,t].. pESmarg[es,d,t] =E= 
    sum(e, uTE[l,es,e,d,t]*pEpj_marg[es,e,d,t]$(d1pEpj[es,e,d,t] and d1uTE[l,es,e,d,t])) + 
    uTKmargNoBound[l,es,d,t]*pTK[d,t];

  # A lower bound close to zero is set to avoid indeterminancy in cdfLognorm in sqTqES
  # uTKmargNoBound<=0 happen when a technology is very energy intensive (ineffecient)
  .. uTKmarg[l,es,d,t] =E= 
    @InInterval(0.001, uTKmargNoBound[l,es,d,t], uTKexp[l,es,d,t]*[1+5*eP[l,es,d,t]]);

  # Supply of technology l in ratio of energy service demand qES
  .. sqT[l,es,d,t] =E= 
    sqTPotential[l,es,d,t]*@cdfLogNorm(uTKmarg[l,es,d,t], uTKexp[l,es,d,t], eP[l,es,d,t]);

  # Shadow value identifying marginal technology for energy purpose
  pESmarg[es,d,t].. 1 =E= sum(l$(d1sqTPotential[l,es,d,t]), sqT[l,es,d,t]);
                
$ENDBLOCK

# 2.2 Output Equations
$BLOCK abatement_equations_output abatement_endogenous_output $(t1.val <= t.val and t.val <= tEnd.val and d1switch_abatement[t]) 
  # 2.2.1 Energy and Capital Use
  # Use of energy in production of energy service
  .. qESE[es,e,d,t] =E= 
    qES[es,d,t] * sum(l$(d1sqTPotential[l,es,d,t]), sqT[l,es,d,t] * uTE[l,es,e,d,t]);
    
  # Use of machinery capital for technologies
  .. qESK[es,d,t] =E= 
    sum(l$(d1sqTPotential[l,es,d,t]),
        sqTPotential[l,es,d,t]*@PartExpLogNorm(uTKmarg[l,es,d,t], uTKexp[l,es,d,t], eP[l,es,d,t]));

  # 2.2.2 Value and Price Calculations
  # Value of energy service                                       
  .. vES[es,d,t] =E= 
    sum(e, qESE[es,e,d,t]*pEpj_marg[es,e,d,t]) + qESK[es,d,t]*pTK[d,t];

  # Price of energy service
  .. pES[es,d,t] =E= vES[es,d,t] / qES[es,d,t];   

$ENDBLOCK

# 2.3 Model Assembly
$GROUP abatement_endogenous
  abatement_LCOE_endogenous
  abatement_endogenous_core
  abatement_endogenous_output
;

$MODEL abatement_equations  
  abatement_LCOE_equations
  abatement_equations_core
  abatement_equations_output 
;

# Add equation and endogenous variables to main model
model main / abatement_equations /;
$GROUP+ main_endogenous abatement_endogenous;

# 2.4 Solver Helper Function
$FUNCTION Setbounds_abatement():
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
$GROUP abatement_data_variables
  sqTPotential[l,es,d,t]
  # uTE[l,es,e,d,t]
  uTE_load[l,e]  "lirum larum"
  # uTKexp[l,es,d,t]
  vTI[l,es,d,t]
  vTC[l,es,d,t]
  pTE_base[es,e,d,t]
  pTE_tax[es,e,d,t]
  pTK[d,t]
  qES[es,d,t]
;
@load(abatement_data_variables, "../data/Abatement_data/Abatement_dummy_data.gdx")
$GROUP+ data_covered_variables abatement_data_variables;


# 3.2 Initial Values and Dummy Setup
# Calculate initial prices
pTE.l[es,e,d,t] = pTE_base.l[es,e,d,t] + pTE_tax.l[es,e,d,t];

uTE.l[l,es,e,d,t]$(sqTPotential.l[l,es,d,t] and uTE_load.l[l,e]) = uTE_load.l[l,e] ;

# Set smoothing parameters
eP.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = 0.03;

# 3.3 Dummy Variable Setup
# Set dummy determining the existence of technology potentials
d1sqTPotential[l,es,d,t] = yes$(sqTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1pTK[d,t] = yes$(sum((l,es), d1sqTPotential[l,es,d,t]));
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));
d1pTE[es,e,d,t] = yes$(pTE.l[es,e,d,t]);
d1qES[es,d,t] = yes$(qES.l[es,d,t]);
d1switch_abatement[t] = 1;

LifeSpan[l,es,d]$(sum(t, d1sqTPotential[l,es,d,t])) = 5;
DiscountRate[l,es,d]$(sum(t, d1sqTPotential[l,es,d,t])) = 0.05;

# 4.4 Starting values for Levelized Cost of Energy (LCOE)
uTKexp.l[l,es,d,t]$(t.val <= tend.val-LifeSpan[l,es,d]+1 and d1sqTPotential[l,es,d,t]) =
   (vTI.l[l,es,d,t] # Investment costs
    + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt])) # Discounted variable costs
      / @Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt]) # Dicounted denominator
      ;

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  uTKexp.l[l,es,d,t]$(t.val > tend.val-LifeSpan[l,es,d]+1 and d1sqTPotential[l,es,d,t]) =
     (vTI.l[l,es,d,t] # Investment costs
      + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt]) # Discounted variable costs until tEnd
      + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({vTC.l[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
      / (@Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d], d1sqTPotential[l,es,d,tt]) # Discount denominator until tEnd
       + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d]-1+t.val-tEnd.val})) # Discounted denominator after tEnd
       ; 

pTPotential.l[l,es,d,t] = 
  sum(e, uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t]) + uTKexp.l[l,es,d,t]*pTK.l[d,t];


$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# 4. Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

# 4.1 Calibration Model Setup
# $BLOCK abatement_calibration_equations
#     # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
#   $(t.val=2019 and d1sqTPotential[l,es,d,t]).. 
#     vTK_LCOE[l,es,d,t] =E= 
#      (vTI[l,es,d,t] # Investment costs
#       + @FiniteGeometricSeries({vTC[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
#       / @FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d]-1+t.val-tEnd.val}) # Discounted denominator after tEnd
#        ; 

model calibration / abatement_equations /;

# 4.2 Calibration Variables
$GROUP calibration_endogenous
  abatement_endogenous
  calibration_endogenous
;

# 4.3 Flat Variables After Last Data Year
$Group+ G_flat_after_last_data_year
  vES[es,d,t]
  qES_e[es,e,d,t]
  qES_k[d,t]
  vTSupply[l,es,d,t]
  uTKmarg[l,es,d,t]
  pESmarg[es,d,t]
  sqT[l,es,d,t]
  eP[l,es,d,t]
;

$ENDIF # calibration